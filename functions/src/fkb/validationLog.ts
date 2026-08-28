/**
 * Online validation sampling — docs/plan.md Phase 3C.
 *
 * After a successful matchFood call, sample a fraction of requests and write
 * a `validation_logs` doc for offline drift monitoring (AI macros vs FKB
 * truth). Never throws — a broken audit write must not fail the user's scan.
 */

import { createHash } from "crypto";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { NUTRIENT_KEYS, NutrientsPer100g } from "./types";

export interface ValidationLogInput {
  uid: string;
  sampleRate: number;
  foodName: string;
  status: "verified" | "estimated";
  foodId: string | null;
  matchScore: number;
  portionGrams: number | null | undefined;
  aiNutrients: NutrientsPer100g;
  nutrientsTotal: NutrientsPer100g;
  modelId?: string;
  promptVersion?: string;
}

/** One-way hash so the log doesn't store a raw uid (product privacy policy). */
function hashUid(uid: string): string {
  return createHash("sha256").update(uid).digest("hex");
}

/** Absolute percentage error per nutrient, keyed `ape_<nutrient>`. Null where
 * there's no verified FKB reference to compare against (can't judge AI
 * accuracy without ground truth). */
export function computeApe(
  aiNutrients: NutrientsPer100g,
  nutrientsTotal: NutrientsPer100g,
  isVerified: boolean
): Record<string, number | null> {
  const ape: Record<string, number | null> = {};
  for (const key of NUTRIENT_KEYS) {
    const ref = nutrientsTotal[key];
    ape[`ape_${key}`] =
      isVerified && ref > 0
        ? Math.round((Math.abs(aiNutrients[key] - ref) / ref) * 1000) / 10
        : null;
  }
  return ape;
}

export async function maybeLogValidationSample(input: ValidationLogInput): Promise<void> {
  try {
    if (Math.random() >= input.sampleRate) return;

    const isVerified = input.status === "verified";
    const ape = computeApe(input.aiNutrients, input.nutrientsTotal, isVerified);

    await getFirestore()
      .collection("validation_logs")
      .add({
        uid_hash: hashUid(input.uid),
        food_name: input.foodName,
        food_id: input.foodId,
        status: input.status,
        match_score: input.matchScore,
        portion_grams: input.portionGrams ?? null,
        ai_nutrients: input.aiNutrients,
        fkb_nutrients: isVerified ? input.nutrientsTotal : null,
        ...ape,
        model_id: input.modelId ?? null,
        prompt_version: input.promptVersion ?? null,
        ts: FieldValue.serverTimestamp(),
      });
  } catch (err) {
    logger.error("validation_logs write failed (non-fatal)", err);
  }
}
