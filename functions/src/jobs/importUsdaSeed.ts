/**
 * USDA seed import job — fetches foods from the USDA FDC API and upserts
 * them into the `fkb_foods` Firestore collection.
 *
 * Callable as `importUsdaSeed` — requires authenticated user.
 * In production, restrict to admin UIDs or use a custom claim.
 *
 * Flow:
 *   1. Read seed list (hardcoded common foods)
 *   2. Fetch each from USDA FDC API in batches of 20
 *   3. Map nutrients → NutrientsPer100g
 *   4. Upsert to Firestore as FkbFood
 */

import { logger } from "firebase-functions";
import { getFood, getFoodsBatch, FdcFoodDetail } from "../usda/client";
import { mapUsdaDetailNutrients } from "../usda/mapNutrients";
import { FkbFood } from "../fkb/types";
import { upsertBatch, getFkbCount, deleteFkbFoodsBySource } from "../fkb/upsert";

/**
 * Hardcoded seed list of common food FDC IDs.
 * These are Foundation / SR Legacy entries — authoritative per-100g data.
 *
 * Re-verified 2026-08-05 against the real USDA FDC API after discovering the
 * original list's fdcIds were misaligned against their hints — most pointed
 * at a completely unrelated food (see CLAUDE.md known debt,
 * eval/USDA_FDC_FIX_NOTES.md). Every id below was fetched via
 * `usdaFdcSearchDebug` / cross-referenced with `fkbGet` against production
 * data, not hand-typed from memory. Hints reflect the real prep state of the
 * matched entry (e.g. "raw" where no cooked Foundation/SR Legacy entry
 * exists) rather than the aspirational one — a wrong prep-state label is the
 * same class of bug this re-verification fixes. Six foods with no confident
 * match (lemon, egg noodles, turkey breast, green peas, soybeans, dark
 * chocolate) were dropped rather than guessed.
 */
const SEED_FOODS: Array<{ fdcId: number; hint: string; nameVi?: string }> = [
  // ── Fruits ──
  { fdcId: 173944, hint: "Banana, raw", nameVi: "Chuối" },
  { fdcId: 171688, hint: "Apple, raw, with skin", nameVi: "Táo" },
  { fdcId: 169097, hint: "Orange, raw", nameVi: "Cam" },
  { fdcId: 174683, hint: "Grapes, red or green", nameVi: "Nho" },
  { fdcId: 169910, hint: "Mango, raw", nameVi: "Xoài" },
  { fdcId: 169926, hint: "Papaya, raw", nameVi: "Đu đủ" },
  { fdcId: 167765, hint: "Watermelon, raw", nameVi: "Dưa hấu" },
  { fdcId: 169124, hint: "Pineapple, raw", nameVi: "Dứa" },
  { fdcId: 167762, hint: "Strawberries, raw", nameVi: "Dâu tây" },
  { fdcId: 2710824, hint: "Avocado, raw", nameVi: "Bơ" },
  { fdcId: 2346411, hint: "Blueberries, raw", nameVi: "Việt quất" },

  // ── Grains ──
  { fdcId: 168878, hint: "Rice, white, long-grain, cooked", nameVi: "Cơm trắng" },
  { fdcId: 2512380, hint: "Rice, brown, long-grain, raw", nameVi: "Cơm gạo lứt" },
  { fdcId: 2758993, hint: "Bread, white", nameVi: "Bánh mì trắng" },
  { fdcId: 2758994, hint: "Bread, whole-wheat", nameVi: "Bánh mì lúa mạch" },
  { fdcId: 2346397, hint: "Oats, steel cut, raw", nameVi: "Yến mạch" },
  { fdcId: 2758998, hint: "Pasta, dry, spaghetti", nameVi: "Mì Ý" },
  { fdcId: 2710826, hint: "Corn, sweet, raw", nameVi: "Bắp ngọt" },
  { fdcId: 789890, hint: "Wheat flour, all-purpose", nameVi: "Bột mì" },

  // ── Proteins ──
  { fdcId: 2646170, hint: "Chicken breast, raw", nameVi: "Ức gà nướng" },
  { fdcId: 2646171, hint: "Chicken thigh, raw", nameVi: "Đùi gà nướng" },
  { fdcId: 174032, hint: "Beef, ground, 80% lean, cooked", nameVi: "Thịt bò xay" },
  { fdcId: 2646168, hint: "Pork, loin, raw", nameVi: "Thịt heo thăn" },
  { fdcId: 2684441, hint: "Salmon, Atlantic, raw", nameVi: "Cá hồi" },
  { fdcId: 175180, hint: "Shrimp, cooked", nameVi: "Tôm" },
  { fdcId: 171287, hint: "Egg, whole, raw", nameVi: "Trứng gà sống" },
  { fdcId: 172475, hint: "Tofu, firm", nameVi: "Đậu phụ" },
  { fdcId: 175158, hint: "Tuna, canned in water", nameVi: "Cá ngừ đóng hộp" },
  { fdcId: 2684442, hint: "Tilapia, raw", nameVi: "Cá rô phi" },

  // ── Dairy ──
  { fdcId: 171265, hint: "Milk, whole", nameVi: "Sữa nguyên kem" },
  { fdcId: 171267, hint: "Milk, 2% fat", nameVi: "Sữa ít béo" },
  { fdcId: 170899, hint: "Cheese, cheddar", nameVi: "Phô mai cheddar" },
  { fdcId: 2259793, hint: "Yogurt, plain, whole milk", nameVi: "Sữa chua" },
  { fdcId: 790508, hint: "Butter, salted", nameVi: "Bơ mặn" },

  // ── Vegetables ──
  { fdcId: 170440, hint: "Potato, boiled", nameVi: "Khoai tây luộc" },
  { fdcId: 169967, hint: "Broccoli, cooked, boiled", nameVi: "Bông cải xanh" },
  { fdcId: 168462, hint: "Spinach, raw", nameVi: "Rau chân vịt" },
  { fdcId: 2258586, hint: "Carrot, raw", nameVi: "Cà rốt" },
  { fdcId: 170457, hint: "Tomato, red, raw", nameVi: "Cà chua" },
  { fdcId: 790646, hint: "Onion, raw", nameVi: "Hành tây" },
  { fdcId: 2346406, hint: "Cucumber, raw", nameVi: "Dưa chuột" },
  { fdcId: 2258588, hint: "Bell pepper, green", nameVi: "Ớt chuông xanh" },
  { fdcId: 169230, hint: "Garlic, raw", nameVi: "Tỏi" },
  { fdcId: 2346407, hint: "Cabbage, raw", nameVi: "Bắp cải" },
  { fdcId: 1999629, hint: "Mushroom, white, raw", nameVi: "Nấm" },
  { fdcId: 2685573, hint: "Cauliflower, raw", nameVi: "Súp lơ trắng" },

  // ── Nuts & Seeds ──
  { fdcId: 2262072, hint: "Peanut butter", nameVi: "Bơ đậu phộng" },
  { fdcId: 2346393, hint: "Almonds, raw", nameVi: "Hạnh nhân" },
  { fdcId: 2515374, hint: "Cashew nuts", nameVi: "Hạt điều" },

  // ── Oils ──
  { fdcId: 171413, hint: "Olive oil", nameVi: "Dầu ô liu" },
  { fdcId: 330458, hint: "Coconut oil", nameVi: "Dầu dừa" },

  // ── Sweeteners ──
  { fdcId: 169640, hint: "Honey", nameVi: "Mật ong" },
  { fdcId: 169655, hint: "Sugar, white", nameVi: "Đường trắng" },

  // ── Legumes ──
  { fdcId: 175237, hint: "Beans, black, cooked", nameVi: "Đậu đen" },
  { fdcId: 2644283, hint: "Lentils, dry", nameVi: "Đậu lăng" },

  // ── Beverages ──
  { fdcId: 171890, hint: "Coffee, brewed", nameVi: "Cà phê" },
  { fdcId: 171917, hint: "Tea, green, brewed", nameVi: "Trà" },
  { fdcId: 169098, hint: "Orange juice, raw", nameVi: "Nước cam" },

  // ── Condiments ──
  { fdcId: 174278, hint: "Soy sauce made from soy (tamari)", nameVi: "Nước tương" },
  { fdcId: 746775, hint: "Salt, table, iodized", nameVi: "Muối" },

  // ── Desserts ──
  { fdcId: 167575, hint: "Ice creams, vanilla", nameVi: "Kem vani" },
];

/**
 * Convert a USDA FDC detail response into an FkbFood object.
 */
function fdcToFkbFood(
  detail: FdcFoodDetail,
  seed?: { hint: string; nameVi?: string }
): FkbFood {
  const nutrients = mapUsdaDetailNutrients(detail.foodNutrients ?? []);

  const nameEn = detail.description || seed?.hint || "Unknown";
  const nameVi = seed?.nameVi || nameEn;

  // Build aliases from the hint (often more readable than USDA description)
  const aliases: string[] = [];
  if (seed?.hint && seed.hint.toLowerCase() !== nameEn.toLowerCase()) {
    aliases.push(seed.hint.toLowerCase());
  }
  if (seed?.nameVi) {
    aliases.push(seed.nameVi.toLowerCase());
  }

  return {
    food_id: `usda_${detail.fdcId}`,
    name_en: nameEn,
    name_vi: nameVi,
    aliases,
    nutrients_per_100g: nutrients,
    source: "usda",
    source_ref: String(detail.fdcId),
    data_type: detail.dataType,
    verified_at: new Date().toISOString(),
    verified_by: "import_usda_v1",
  };
}

/**
 * Run the USDA seed import.
 *
 * Fetches foods in batches of 20 from USDA, maps to FkbFood,
 * and upserts to Firestore.
 *
 * @param apiKey  USDA FDC API key (from Secret Manager)
 * @returns Summary of import results
 */
export async function runUsdaSeedImport(apiKey: string): Promise<{
  requested: number;
  fetched: number;
  written: number;
  deletedStale: number;
  errors: string[];
}> {
  const errors: string[] = [];
  const allFoods: FkbFood[] = [];

  // Wipe existing usda-sourced docs first. A fixed fdcId writes a *new*
  // food_id — upsert alone would leave the old, wrong-fdcId doc live
  // alongside the corrected one (see CLAUDE.md known debt, 2026-08-05).
  const deletedStale = await deleteFkbFoodsBySource("usda");
  logger.info(`Deleted ${deletedStale} stale usda-sourced fkb_foods docs before reimport`);

  // Build lookup map for seed metadata
  const seedMap = new Map(SEED_FOODS.map((s) => [s.fdcId, s]));

  // Deduplicate FDC IDs
  const uniqueIds = [...new Set(SEED_FOODS.map((s) => s.fdcId))];

  logger.info(`Starting USDA seed import: ${uniqueIds.length} unique foods`);

  // Fetch in batches of 20 (USDA batch limit)
  for (let i = 0; i < uniqueIds.length; i += 20) {
    const batchIds = uniqueIds.slice(i, i + 20);

    try {
      const details = await getFoodsBatch(batchIds, apiKey);
      const returnedIds = new Set(details.map((d) => d.fdcId));

      for (const detail of details) {
        try {
          const seed = seedMap.get(detail.fdcId);
          const fkbFood = fdcToFkbFood(detail, seed);

          // Sanity check: calories should be present
          if (fkbFood.nutrients_per_100g.calories_kcal === 0) {
            logger.warn(`Zero calories for ${fkbFood.food_id} (${fkbFood.name_en})`);
          }

          allFoods.push(fkbFood);
        } catch (err) {
          const msg = `Failed to map fdcId=${detail.fdcId}: ${err}`;
          logger.error(msg);
          errors.push(msg);
        }
      }

      // The batch endpoint sometimes silently omits an id from the response
      // instead of erroring — fetch those individually rather than losing
      // them, same as the full-batch-failure fallback below.
      const droppedIds = batchIds.filter((id) => !returnedIds.has(id));
      for (const fdcId of droppedIds) {
        try {
          const detail = await getFood(fdcId, apiKey);
          const seed = seedMap.get(fdcId);
          allFoods.push(fdcToFkbFood(detail, seed));
        } catch (innerErr) {
          const msg = `Failed to fetch dropped fdcId=${fdcId}: ${innerErr}`;
          logger.error(msg);
          errors.push(msg);
        }
      }
    } catch (err) {
      // If batch fails, try individual fetches as fallback
      logger.warn(`Batch fetch failed for ids ${batchIds.join(",")}, trying individually`);
      for (const fdcId of batchIds) {
        try {
          const detail = await getFood(fdcId, apiKey);
          const seed = seedMap.get(fdcId);
          allFoods.push(fdcToFkbFood(detail, seed));
        } catch (innerErr) {
          const msg = `Failed to fetch fdcId=${fdcId}: ${innerErr}`;
          logger.error(msg);
          errors.push(msg);
        }
      }
    }

    // Small delay between batches to respect rate limits
    if (i + 20 < uniqueIds.length) {
      await new Promise((r) => setTimeout(r, 200));
    }
  }

  // Upsert all collected foods to Firestore
  let written = 0;
  if (allFoods.length > 0) {
    written = await upsertBatch(allFoods);
  }

  const countAfter = await getFkbCount();
  logger.info(
    `USDA seed import complete: requested=${uniqueIds.length}, fetched=${allFoods.length}, written=${written}, totalFkb=${countAfter}, errors=${errors.length}`
  );

  return {
    requested: uniqueIds.length,
    fetched: allFoods.length,
    written,
    deletedStale,
    errors,
  };
}
