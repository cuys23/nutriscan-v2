import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { z } from "zod";
import { runUsdaSeedImport } from "./jobs/importUsdaSeed";
import { runVnFctImport } from "./jobs/importVnFct";
import { searchFkbFoods } from "./fkb/search";
import { getFkbFood } from "./fkb/get";
import { matchFood as matchFoodImpl } from "./fkb/match";
import { NutrientsPer100gSchema } from "./fkb/types";
import { maybeLogValidationSample } from "./fkb/validationLog";

initializeApp();
const db = getFirestore();

const OPENROUTER_API_KEY = defineSecret("OPENROUTER_API_KEY");
const USDA_FDC_API_KEY = defineSecret("USDA_FDC_API_KEY");
const OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1/chat/completions";

// OpenRouter attributes usage to these two headers on its dashboard/leaderboard.
// Optional for the API to work, but without them every call shows up as
// "unknown app", which makes per-app spend impossible to read.
const OPENROUTER_REFERER = "https://nourishshot.app";
const OPENROUTER_TITLE = "NourishShot";

// Fraction of successful matchFood calls sampled into `validation_logs` for
// offline drift monitoring (docs/plan.md Phase 3C). Override per-environment
// via the VALIDATION_SAMPLE_RATE functions param, not by editing this default.
const VALIDATION_SAMPLE_RATE = defineString("VALIDATION_SAMPLE_RATE", {
  default: "0.05",
});

// Real backstop for AI-call abuse — the client's "coin" balance is only a UX gate,
// this is what actually stops someone from running unlimited billed AI requests.
const DAILY_GROQ_CALL_LIMIT = 100;

/**
 * Increments today's call counter for `uid` in a transaction and throws
 * resource-exhausted if the daily cap is already reached.
 */
async function enforceDailyRateLimit(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD, UTC
  const ref = db.collection("rateLimits").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : undefined;

    const count = data?.date === today ? (data?.count ?? 0) : 0;
    if (count >= DAILY_GROQ_CALL_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily AI request limit reached. Please try again tomorrow.",
      );
    }

    tx.set(ref, { date: today, count: count + 1 }, { merge: true });
  });
}

interface ChatCompletionRequest {
  model: string;
  messages: unknown[];
  temperature?: number;
  top_p?: number;
  max_tokens?: number;
  receiveTimeoutMs?: number;
}

function isValidChatRequest(data: unknown): data is ChatCompletionRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return typeof d.model === "string" && Array.isArray(d.messages);
}

// Rate-limit 429s regularly ask for 20-35s of cooldown, far longer than any
// fixed client-side retry would wait — a blind 3s retry just burns a second
// billed request and the scan still fails silently. Honour the provider's own
// suggested delay server-side instead of guessing: `Retry-After` when present,
// otherwise the "try again in Ns" phrasing some upstreams put in the message.
const RETRY_AFTER_MESSAGE_RE = /try again in ([\d.]+)\s*s/i;
const MAX_RETRY_AFTER_MS = 40_000;

function retryAfterMsFromError(
  response: Response,
  json: unknown,
): number | null {
  const headerValue = response.headers.get("retry-after");
  if (headerValue) {
    const seconds = Number(headerValue);
    if (Number.isFinite(seconds) && seconds > 0) {
      return Math.min(seconds * 1000, MAX_RETRY_AFTER_MS);
    }
  }
  const message = (json as { error?: { message?: unknown } })?.error?.message;
  if (typeof message === "string") {
    const match = RETRY_AFTER_MESSAGE_RE.exec(message);
    if (match) {
      const seconds = Number(match[1]);
      if (Number.isFinite(seconds) && seconds > 0) {
        // A little padding — the countdown is to the millisecond and retrying
        // at exactly t=0 still occasionally 429s again.
        return Math.min((seconds + 1) * 1000, MAX_RETRY_AFTER_MS);
      }
    }
  }
  return null;
}

async function fetchOpenRouter(
  body: Record<string, unknown>,
  apiKey: string,
  receiveTimeoutMs: number,
): Promise<{ response: Response; json: Record<string, unknown> }> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), receiveTimeoutMs);
  try {
    const response = await fetch(OPENROUTER_BASE_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
        "HTTP-Referer": OPENROUTER_REFERER,
        "X-Title": OPENROUTER_TITLE,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const json = (await response.json()) as Record<string, unknown>;
    return { response, json };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Callable proxy for every AI chat-completion the app makes (food image
 * validation, food analysis, meal plans, insights, health coach chat).
 *
 * Keeps the real OpenRouter API key out of the client entirely and enforces a
 * per-user daily cap — the mobile app never talks to openrouter.ai directly.
 * The client sends the same OpenAI-shaped chat-completions body it would have
 * sent upstream; this function forwards it with the real key attached.
 *
 * Name kept as `groqChatCompletion` (rather than renamed to match the new
 * provider) because it is the deployed callable name the shipped client calls;
 * renaming it would break every build already in the field.
 */
export const groqChatCompletion = onCall(
  { secrets: [OPENROUTER_API_KEY], timeoutSeconds: 120, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    if (!isValidChatRequest(request.data)) {
      throw new HttpsError("invalid-argument", "Malformed AI request body.");
    }

    await enforceDailyRateLimit(request.auth.uid);

    const { receiveTimeoutMs, ...clientBody } = request.data;
    const timeoutMs = receiveTimeoutMs ?? 30_000;
    const apiKey = OPENROUTER_API_KEY.value();

    // Every Qwen model the app can be pointed at is a reasoning ("thinking")
    // model, and left alone they spend the entire max_tokens budget on hidden
    // reasoning and return an EMPTY content string. Measured against
    // openrouter.ai: qwen3.7-flash burned 256/256 tokens on the food-validation
    // call (max_tokens 256) and 1024/1024 when given more room — content empty
    // both times, finish_reason "length". With reasoning off the same call
    // answers in 16 tokens.
    //
    // Injected here rather than in the client so it also covers builds already
    // in the field, and spread first so a caller can still opt back in.
    const aiBody = { reasoning: { enabled: false }, ...clientBody };

    const startTime = Date.now();
    try {
      let { response, json } = await fetchOpenRouter(aiBody, apiKey, timeoutMs);

      if (!response.ok && response.status === 429) {
        const retryAfterMs = retryAfterMsFromError(response, json);
        logger.warn("OpenRouter 429, retrying once", {
          uid: request.auth.uid,
          model: aiBody.model,
          retryAfterMs,
          json,
        });
        if (retryAfterMs != null) {
          await new Promise((resolve) => setTimeout(resolve, retryAfterMs));
          ({ response, json } = await fetchOpenRouter(aiBody, apiKey, timeoutMs));
        }
      }

      const latencyMs = Date.now() - startTime;

      if (!response.ok) {
        logger.warn("OpenRouter error", {
          uid: request.auth.uid,
          model: aiBody.model,
          latencyMs,
          status: response.status,
          json,
        });
        throw new HttpsError(
          response.status === 429 ? "resource-exhausted" : "internal",
          `AI request failed with status ${response.status}`,
        );
      }

      logger.info("OpenRouter success", {
        uid: request.auth.uid,
        model: aiBody.model,
        latencyMs,
        usage: json.usage,
      });

      return json;
    } catch (err) {
      const latencyMs = Date.now() - startTime;
      if (err instanceof HttpsError) {
        logger.warn("AI request failed with HttpsError", {
          uid: request.auth.uid,
          model: aiBody.model,
          latencyMs,
          code: err.code,
          message: err.message,
        });
        throw err;
      }
      if ((err as Error).name === "AbortError") {
        logger.error("AI request timeout", {
          uid: request.auth.uid,
          model: aiBody.model,
          latencyMs,
        });
        throw new HttpsError("deadline-exceeded", "AI request timed out.");
      }
      logger.error("Unexpected error calling OpenRouter", {
        uid: request.auth.uid,
        model: aiBody.model,
        latencyMs,
        error: String(err),
      });
      throw new HttpsError("internal", "Failed to reach the AI service.");
    }
  },
);

// ---------------------------------------------------------------------------
// IAP receipt verification
// ---------------------------------------------------------------------------

/**
 * NOTE: fill these in from App Store Connect (Users and Access > Integrations
 * > In-App Purchase) before deploying. Needed for the App Store Server API
 * JWT used to verify iOS transactions server-side.
 */
const APPLE_ISSUER_ID = defineSecret("APPLE_ISSUER_ID");
const APPLE_KEY_ID = defineSecret("APPLE_KEY_ID");
const APPLE_PRIVATE_KEY = defineSecret("APPLE_PRIVATE_KEY");
const APPLE_BUNDLE_ID = "com.vin.nourishshot";

/**
 * NOTE: fill this in with a Google Cloud service-account JSON that has the
 * "Pub/Sub" + Play Android Developer API access granted in Play Console
 * (Setup > API access) before deploying. Needed to verify Android purchases
 * server-side via the Play Developer API.
 */
const GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = defineSecret(
  "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
);
// Deliberately different from APPLE_BUNDLE_ID. The iOS app ships as
// com.vin.nourishshot; Android is not shipping yet and its applicationId in
// android/app/build.gradle.kts is still com.vin.nutrisnap, which is what its
// google-services.json is registered under. Change both together or neither.
const ANDROID_PACKAGE_NAME = "com.vin.nutrisnap";

/**
 * Skips real App Store / Play receipt verification and trusts the
 * client-reported purchase. Only for a staging project that has no
 * APPLE_ISSUER_ID/KEY_ID/PRIVATE_KEY or GOOGLE_PLAY_SERVICE_ACCOUNT_JSON yet.
 *
 * A functions param rather than a code constant so production is safe by
 * default: leaving it alone verifies for real, and turning it on takes a
 * deliberate per-project override that is visible in the deploy config —
 * whereas a hardcoded `true` ships to production the moment someone forgets
 * to flip it back.
 *
 *   firebase functions:config unset / set via .env.<project>:
 *     IAP_TEST_MODE=true
 */
const IAP_TEST_MODE = defineString("IAP_TEST_MODE", { default: "false" });

interface VerifyPurchaseRequest {
  platform: "ios" | "android";
  productId: string;
  verificationData: string;
}

function isValidVerifyRequest(data: unknown): data is VerifyPurchaseRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    (d.platform === "ios" || d.platform === "android") &&
    typeof d.productId === "string" &&
    typeof d.verificationData === "string"
  );
}

async function verifyAppleTransaction(
  transactionId: string,
): Promise<{ isActive: boolean; expiryDate: number | null }> {
  const jwt = await import("jsonwebtoken");
  const token = jwt.sign(
    {
      iss: APPLE_ISSUER_ID.value(),
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 300,
      aud: "appstoreconnect-v1",
      bid: APPLE_BUNDLE_ID,
    },
    APPLE_PRIVATE_KEY.value(),
    { algorithm: "ES256", keyid: APPLE_KEY_ID.value() },
  );

  // A transaction lives in exactly one of the two App Store environments and
  // the receipt does not say which, so Apple's documented approach is to ask
  // production first and fall back to sandbox on 404. Hardcoding production —
  // as this did — makes every sandbox and TestFlight purchase 404, which is
  // precisely the case anyone testing IAP is in.
  const hosts = [
    "https://api.storekit.itunes.apple.com",
    "https://api.storekit-sandbox.itunes.apple.com",
  ];

  let response: Response | undefined;
  for (const host of hosts) {
    response = await fetch(`${host}/inApps/v1/transactions/${transactionId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (response.status !== 404) break;
    logger.info("Transaction not in this App Store environment, trying next", {
      host,
      transactionId,
    });
  }

  if (!response || !response.ok) {
    // A 401 here almost always means the bundle id in the JWT is not an app
    // this key can see — i.e. the app has not been created in App Store
    // Connect yet — rather than a bad key.
    throw new HttpsError(
      "permission-denied",
      `Apple transaction verification failed with status ${response?.status}`,
    );
  }

  const body = (await response.json()) as { signedTransactionInfo: string };
  // signedTransactionInfo is a JWS; decode without verifying the signature here
  // since it was fetched directly from Apple's server over TLS. Payload carries
  // expiresDate (ms since epoch) and revocationDate when applicable.
  const payloadB64 = body.signedTransactionInfo.split(".")[1];
  const payload = JSON.parse(Buffer.from(payloadB64, "base64").toString());

  const expiryDate: number | null = payload.expiresDate ?? null;
  const isActive =
    !payload.revocationDate && (!expiryDate || expiryDate > Date.now());

  return { isActive, expiryDate };
}

async function verifyGooglePlaySubscription(
  productId: string,
  purchaseToken: string,
): Promise<{ isActive: boolean; expiryDate: number | null }> {
  const { GoogleAuth } = await import("google-auth-library");
  const credentials = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.value());
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const accessToken = (await client.getAccessToken()).token;

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${ANDROID_PACKAGE_NAME}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    throw new HttpsError(
      "permission-denied",
      `Play subscription verification failed with status ${response.status}`,
    );
  }

  const body = (await response.json()) as {
    expiryTimeMillis: string;
    paymentState?: number;
    cancelReason?: number;
  };
  const expiryDate = parseInt(body.expiryTimeMillis, 10);
  const isActive = expiryDate > Date.now();

  return { isActive, expiryDate };
}

/**
 * Callable that verifies an in-app purchase server-side before granting
 * premium. This is the only path allowed to write `subscription` on
 * `/users/{uid}` — firestore.rules already blocks the client from writing
 * that field directly, so no rules change is needed; the Admin SDK used here
 * bypasses Security Rules by design.
 */
export const verifyPurchase = onCall(
  {
    secrets: [
      APPLE_ISSUER_ID,
      APPLE_KEY_ID,
      APPLE_PRIVATE_KEY,
      GOOGLE_PLAY_SERVICE_ACCOUNT_JSON,
    ],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    if (!isValidVerifyRequest(request.data)) {
      throw new HttpsError("invalid-argument", "Malformed purchase payload.");
    }

    const { platform, productId, verificationData } = request.data;
    const uid = request.auth.uid;

    const testMode = IAP_TEST_MODE.value() === "true";
    if (testMode) {
      logger.warn("IAP_TEST_MODE is on — granting premium WITHOUT verifying", {
        uid,
        platform,
        productId,
      });
    }
    const result = testMode
      ? { isActive: true, expiryDate: Date.now() + 30 * 24 * 60 * 60 * 1000 }
      : platform === "ios"
        ? await verifyAppleTransaction(verificationData)
        : await verifyGooglePlaySubscription(productId, verificationData);

    if (!result.isActive) {
      throw new HttpsError(
        "failed-precondition",
        "Purchase could not be verified as an active subscription.",
      );
    }

    const subscriptionType = productId.toLowerCase().includes("year")
      ? "yearly"
      : "monthly";

    await db.collection("users").doc(uid).set(
      {
        subscription: {
          isSubscribed: true,
          subscriptionType,
          expiryDate: result.expiryDate,
          verifiedAt: FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );

    return { isSubscribed: true, subscriptionType, expiryDate: result.expiryDate };
  },
);

// ---------------------------------------------------------------------------
// FKB (Food Knowledge Base) import callables
// ---------------------------------------------------------------------------

/**
 * Import seed foods from USDA FoodData Central into the `fkb_foods`
 * Firestore collection. Should be run once to populate the initial FKB,
 * then again whenever new seeds are added to the list.
 *
 * Requires authentication. In production, restrict to admin UIDs.
 */
export const importUsdaSeed = onCall(
  {
    secrets: [USDA_FDC_API_KEY],
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    logger.info(`importUsdaSeed called by uid=${request.auth.uid}`);

    try {
      const result = await runUsdaSeedImport(USDA_FDC_API_KEY.value());
      return { ok: true, data: result };
    } catch (err) {
      logger.error("importUsdaSeed failed", err);
      throw new HttpsError("internal", `Import failed: ${err}`);
    }
  },
);

/**
 * Import curated Vietnamese foods into the `fkb_foods` collection.
 * These are hand-entered entries for common VN dishes.
 */
export const importVnFct = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    logger.info(`importVnFct called by uid=${request.auth.uid}`);

    try {
      const result = await runVnFctImport();
      return { ok: true, data: result };
    } catch (err) {
      logger.error("importVnFct failed", err);
      throw new HttpsError("internal", `Import failed: ${err}`);
    }
  },
);

// ---------------------------------------------------------------------------
// FKB (Food Knowledge Base) query callables
// ---------------------------------------------------------------------------

const FkbSearchRequestSchema = z.object({
  query: z.string().min(1),
  locale: z.string().optional(),
  limit: z.number().int().min(1).max(50).optional(),
});

/**
 * Search verified foods in `fkb_foods` by name/alias. See
 * `functions/src/fkb/search.ts` for the ranking algorithm.
 */
export const fkbSearch = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const parsed = FkbSearchRequestSchema.safeParse(request.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Malformed fkbSearch request.");
    }

    try {
      const items = await searchFkbFoods(parsed.data.query, parsed.data.limit ?? 10);
      return { ok: true, data: { items } };
    } catch (err) {
      logger.error("fkbSearch failed", err);
      throw new HttpsError("internal", "FKB search failed.");
    }
  },
);

const FkbGetRequestSchema = z.object({
  food_id: z.string().min(1),
});

/** Fetch a single verified food by `food_id` from `fkb_foods`. */
export const fkbGet = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const parsed = FkbGetRequestSchema.safeParse(request.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Malformed fkbGet request.");
    }

    const food = await getFkbFood(parsed.data.food_id);
    if (!food) {
      throw new HttpsError("not-found", `No FKB food with id ${parsed.data.food_id}`);
    }

    return { ok: true, data: food };
  },
);

const MatchFoodRequestSchema = z.object({
  food_name: z.string().min(1),
  portion_grams: z.number().positive().nullable().optional(),
  locale: z.string().optional(),
  ai_nutrients: NutrientsPer100gSchema,
  model_id: z.string().optional(),
  prompt_version: z.string().optional(),
});

/**
 * After AI vision identifies a food, decide verified (FKB per_100g × grams)
 * vs estimated (AI passthrough). See functions/src/fkb/match.ts and
 * docs/plan.md Phase 1C — the threshold/edge-case rules live there, not here.
 */
export const matchFood = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const parsed = MatchFoodRequestSchema.safeParse(request.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Malformed matchFood request.");
    }

    try {
      const { food_name, portion_grams, ai_nutrients, model_id, prompt_version } = parsed.data;
      const result = await matchFoodImpl(food_name, portion_grams, ai_nutrients);

      await maybeLogValidationSample({
        uid: request.auth.uid,
        sampleRate: parseFloat(VALIDATION_SAMPLE_RATE.value()) || 0,
        foodName: food_name,
        status: result.status,
        foodId: result.food_id,
        matchScore: result.match_score,
        portionGrams: portion_grams,
        aiNutrients: ai_nutrients,
        nutrientsTotal: result.nutrients_total,
        modelId: model_id,
        promptVersion: prompt_version,
      });

      return { ok: true, data: result };
    } catch (err) {
      // Fail soft to estimated rather than failing the whole scan — the AI
      // macros are still usable even if the FKB lookup itself broke.
      logger.error("matchFood failed, falling back to estimated", err);
      return {
        ok: true,
        data: {
          status: "estimated" as const,
          food_id: null,
          match_score: 0,
          nutrients_total: parsed.data.ai_nutrients,
          source_label: "AI estimate",
        },
      };
    }
  },
);
