/**
 * Maps USDA FoodData Central nutrient numbers to canonical NourishShot keys.
 *
 * USDA nutrient numbers (docs/MASTER_PLAN.md §7.2):
 *   1008 → calories_kcal
 *   1003 → protein_g
 *   1005 → carbs_g
 *   1004 → fat_g
 *   1079 → fiber_g
 *   2000 → sugar_g
 *   1093 → sodium_mg
 */

import { NutrientsPer100g } from "../fkb/types";

/** USDA FDC nutrient number → canonical key mapping */
const NUTRIENT_MAP: Record<number, keyof NutrientsPer100g> = {
  1008: "calories_kcal",
  1003: "protein_g",
  1005: "carbs_g",
  1004: "fat_g",
  1079: "fiber_g",
  2000: "sugar_g",
  1093: "sodium_mg",
};

/**
 * A single nutrient entry from the USDA FDC API response.
 */
interface UsdaNutrient {
  nutrientId?: number;
  nutrientNumber?: string;
  nutrientName?: string;
  value?: number;
  amount?: number;
  unitName?: string;
}

/**
 * Extract canonical nutrients from a USDA food's nutrient array.
 *
 * Handles both "search" response format (nutrientId + value) and
 * "detail" response format (nutrient.number + amount).
 *
 * Missing nutrients default to 0.
 */
export function mapUsdaNutrients(
  nutrients: UsdaNutrient[]
): NutrientsPer100g {
  const result: NutrientsPer100g = {
    calories_kcal: 0,
    protein_g: 0,
    carbs_g: 0,
    fat_g: 0,
    fiber_g: 0,
    sugar_g: 0,
    sodium_mg: 0,
  };

  for (const n of nutrients) {
    // Search endpoint uses `nutrientId` + `value`
    // Detail endpoint uses `nutrient.number` (string) + `amount`
    const id = n.nutrientId ?? (n.nutrientNumber ? parseInt(n.nutrientNumber, 10) : undefined);
    const val = n.value ?? n.amount ?? 0;

    if (id !== undefined && NUTRIENT_MAP[id] !== undefined) {
      result[NUTRIENT_MAP[id]] = Math.round(val * 100) / 100;
    }
  }

  // Convert sodium from mg if reported in a different unit (USDA is always mg for 1093)
  return result;
}

/**
 * Map nutrients from a USDA "detail" API response where nutrients
 * are nested under `foodNutrients[].nutrient.number`.
 */
export function mapUsdaDetailNutrients(
  foodNutrients: Array<{
    nutrient?: { number?: number | string; id?: number };
    amount?: number;
  }>
): NutrientsPer100g {
  const flat: UsdaNutrient[] = foodNutrients.map((fn) => ({
    nutrientId: fn.nutrient?.id,
    nutrientNumber:
      fn.nutrient?.number !== undefined
        ? String(fn.nutrient.number)
        : undefined,
    amount: fn.amount,
  }));

  return mapUsdaNutrients(flat);
}
