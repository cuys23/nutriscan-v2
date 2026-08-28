/**
 * FKB (Food Knowledge Base) — core type definitions & Zod schemas.
 *
 * Canonical nutrient keys used everywhere:
 *   calories_kcal, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg
 *
 * See docs/MASTER_PLAN.md §7.2 and docs/plan.md §0.3.
 */

import { z } from "zod";

// ---------------------------------------------------------------------------
// Source enum
// ---------------------------------------------------------------------------

export const FKB_SOURCES = ["usda", "vn_fct", "off", "curated"] as const;
export type FkbSource = (typeof FKB_SOURCES)[number];

// ---------------------------------------------------------------------------
// Nutrients per 100 g
// ---------------------------------------------------------------------------

export interface NutrientsPer100g {
  calories_kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g: number;
  sodium_mg: number;
}

export const NUTRIENT_KEYS = [
  "calories_kcal",
  "protein_g",
  "carbs_g",
  "fat_g",
  "fiber_g",
  "sugar_g",
  "sodium_mg",
] as const;

export const NutrientsPer100gSchema = z.object({
  calories_kcal: z.number().min(0),
  protein_g: z.number().min(0),
  carbs_g: z.number().min(0),
  fat_g: z.number().min(0),
  fiber_g: z.number().min(0),
  sugar_g: z.number().min(0),
  sodium_mg: z.number().min(0),
});

// ---------------------------------------------------------------------------
// FkbFood — one verified food entry
// ---------------------------------------------------------------------------

export interface FkbFood {
  food_id: string;
  name_en: string;
  name_vi: string;
  aliases: string[];
  nutrients_per_100g: NutrientsPer100g;
  source: FkbSource;
  source_ref: string;
  data_type?: string;
  verified_at: string;
  verified_by?: string;
  /** Lowercase tokens derived from name_en + name_vi + aliases for search. */
  search_tokens?: string[];
}

export const FkbFoodSchema = z.object({
  food_id: z.string().min(1),
  name_en: z.string().min(1),
  name_vi: z.string().min(1),
  aliases: z.array(z.string()),
  nutrients_per_100g: NutrientsPer100gSchema,
  source: z.enum(FKB_SOURCES),
  source_ref: z.string(),
  data_type: z.string().optional(),
  verified_at: z.string(),
  verified_by: z.string().optional(),
  search_tokens: z.array(z.string()).optional(),
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Build search_tokens from the food's names and aliases.
 * Used for Firestore `array-contains` queries.
 */
export function buildSearchTokens(food: {
  name_en: string;
  name_vi: string;
  aliases: string[];
}): string[] {
  const raw = [food.name_en, food.name_vi, ...food.aliases];
  const tokens = new Set<string>();

  for (const text of raw) {
    const normalized = text
      .toLowerCase()
      .replace(/[^a-zA-Z0-9\u00C0-\u024F\u1E00-\u1EFF\s]/g, "")
      .trim();

    // Add individual words
    for (const word of normalized.split(/\s+/)) {
      if (word.length >= 2) {
        tokens.add(word);
      }
    }
    // Add the full normalized string as a token too
    if (normalized.length >= 2) {
      tokens.add(normalized);
    }
  }

  return Array.from(tokens);
}

/**
 * Compute scaled nutrient totals from per-100g values and a portion in grams.
 * Formula: nutrient_total = nutrient_per_100g * (portion_grams / 100.0)
 */
export function scaleNutrients(
  per100g: NutrientsPer100g,
  portionGrams: number
): NutrientsPer100g {
  const factor = portionGrams / 100.0;
  return {
    calories_kcal: Math.round(per100g.calories_kcal * factor * 10) / 10,
    protein_g: Math.round(per100g.protein_g * factor * 10) / 10,
    carbs_g: Math.round(per100g.carbs_g * factor * 10) / 10,
    fat_g: Math.round(per100g.fat_g * factor * 10) / 10,
    fiber_g: Math.round(per100g.fiber_g * factor * 10) / 10,
    sugar_g: Math.round(per100g.sugar_g * factor * 10) / 10,
    sodium_mg: Math.round(per100g.sodium_mg * factor * 10) / 10,
  };
}
