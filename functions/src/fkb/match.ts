/**
 * matchFood — decides whether a scanned food resolves to a verified FKB
 * entry or stays an AI estimate, per docs/plan.md Phase 1C.
 *
 * Rule (product law, do not soften):
 *   verified  = FKB per_100g × (portion_grams / 100), match_score >= threshold
 *   estimated = anything else (low score, no FKB hit, or portion_grams
 *               missing/<=0 — scaling would be dishonest without it)
 */

import { searchFkbFoods } from "./search";
import { NutrientsPer100g, FkbSource, scaleNutrients } from "./types";

const MATCH_THRESHOLD = 0.65;

const SOURCE_LABELS: Record<FkbSource, string> = {
  usda: "USDA FoodData Central",
  vn_fct: "Vietnamese Food Composition Table",
  off: "Open Food Facts",
  curated: "Curated",
};

export interface MatchFoodResult {
  status: "verified" | "estimated";
  food_id: string | null;
  match_score: number;
  nutrients_total: NutrientsPer100g;
  source_label: string;
}

export async function matchFood(
  foodName: string,
  portionGrams: number | null | undefined,
  aiNutrients: NutrientsPer100g
): Promise<MatchFoodResult> {
  const hasValidPortion =
    typeof portionGrams === "number" && Number.isFinite(portionGrams) && portionGrams > 0;

  const trimmedName = foodName.trim();
  const candidates = trimmedName.length >= 2 ? await searchFkbFoods(trimmedName, 1) : [];
  const best = candidates[0];

  if (best && best.score >= MATCH_THRESHOLD && hasValidPortion) {
    return {
      status: "verified",
      food_id: best.food_id,
      match_score: best.score,
      nutrients_total: scaleNutrients(best.nutrients_per_100g, portionGrams as number),
      source_label: SOURCE_LABELS[best.source],
    };
  }

  return {
    status: "estimated",
    food_id: null,
    match_score: best?.score ?? 0,
    nutrients_total: aiNutrients,
    source_label: "AI estimate",
  };
}
