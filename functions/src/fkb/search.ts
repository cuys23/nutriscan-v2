/**
 * FKB search — ranks `fkb_foods` against a free-text query.
 *
 * MVP candidate generation (docs/plan.md Phase 1B): the collection is small
 * (seed import, low hundreds of docs), so we load it into the function
 * instance and score in memory rather than building Firestore compound
 * indexes for partial-text search. Revisit (Postgres + pg_trgm, or a search
 * service) once the collection is too large to read on every call — see
 * ADR-002.
 */

import { getFirestore } from "firebase-admin/firestore";
import { FkbFood } from "./types";

const FKB_COLLECTION = "fkb_foods";

export interface FkbSearchHit {
  food_id: string;
  name_en: string;
  name_vi: string;
  score: number;
  nutrients_per_100g: FkbFood["nutrients_per_100g"];
  source: FkbFood["source"];
  source_ref: string;
}

/** Trim, lowercase, collapse whitespace. */
function normalize(text: string): string {
  return text.toLowerCase().trim().replace(/\s+/g, " ");
}

/**
 * Strip punctuation before splitting into words — without this, "Bananas,
 * raw" tokenizes to {"bananas,", "raw"} and the trailing comma silently
 * blocks every Jaccard match against a punctuation-free query. Mirrors the
 * word-extraction step in `buildSearchTokens` (./types.ts) so a name and a
 * query normalize to the same token shape.
 */
export function tokenize(text: string): Set<string> {
  const stripped = normalize(text).replace(/[^a-z0-9À-ɏḀ-ỿ\s]/g, "");
  return new Set(stripped.split(/\s+/).filter((w) => w.length >= 2));
}

function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const t of a) if (b.has(t)) intersection++;
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

/**
 * Score a single food against the normalized query per plan.md Phase 1B:
 *   exact name_en or name_vi = 1.0
 *   alias exact               = 0.95
 *   token Jaccard on names     = 0.0–0.9
 *
 * Jaccard is scored per-field (name_en, name_vi, each alias) and the best
 * one wins, rather than pooling every field into one token set — pooling
 * let an unrelated field (e.g. the Vietnamese name, or a plural variant in
 * name_en) inflate the union and silently drag down a field that was
 * actually an exact word-for-word match.
 */
export function scoreFood(food: FkbFood, normalizedQuery: string, queryTokens: Set<string>): number {
  if (
    normalize(food.name_en) === normalizedQuery ||
    normalize(food.name_vi) === normalizedQuery
  ) {
    return 1.0;
  }

  if (food.aliases.some((alias) => normalize(alias) === normalizedQuery)) {
    return 0.95;
  }

  const candidateFields = [food.name_en, food.name_vi, ...food.aliases];
  let best = 0;
  for (const field of candidateFields) {
    const score = jaccard(queryTokens, tokenize(field));
    if (score > best) best = score;
  }

  return best * 0.9;
}

/**
 * Search `fkb_foods` for foods matching `query`, ranked by score descending.
 * Returns at most `limit` hits with score > 0.
 */
export async function searchFkbFoods(
  query: string,
  limit = 10
): Promise<FkbSearchHit[]> {
  const normalizedQuery = normalize(query);
  if (normalizedQuery.length < 2) return [];

  const queryTokens = tokenize(query);
  const db = getFirestore();
  const snapshot = await db.collection(FKB_COLLECTION).get();

  const scored: FkbSearchHit[] = [];
  snapshot.forEach((doc) => {
    const food = doc.data() as FkbFood;
    const score = scoreFood(food, normalizedQuery, queryTokens);
    if (score > 0) {
      scored.push({
        food_id: food.food_id,
        name_en: food.name_en,
        name_vi: food.name_vi,
        score,
        nutrients_per_100g: food.nutrients_per_100g,
        source: food.source,
        source_ref: food.source_ref,
      });
    }
  });

  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, limit);
}
