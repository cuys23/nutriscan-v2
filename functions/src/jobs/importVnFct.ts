/**
 * Vietnamese Food Composition Table (VN FCT) import job.
 *
 * Manually curated entries for common Vietnamese dishes.
 * Sources: Vietnamese National Institute of Nutrition tables + standard references.
 *
 * These cannot be reliably fetched from USDA because they are culturally specific
 * dishes with unique preparations. Values are per 100g.
 */

import { logger } from "firebase-functions";
import { FkbFood } from "../fkb/types";
import { upsertBatch, getFkbCount } from "../fkb/upsert";

/**
 * Hand-curated Vietnamese food entries.
 * Per 100g values from VN National Institute of Nutrition reference tables.
 */
const VN_FOODS: FkbFood[] = [
  {
    food_id: "vn_001",
    name_en: "Pho bo (Vietnamese beef noodle soup)",
    name_vi: "Phở bò",
    aliases: ["pho", "phở", "pho bo", "beef pho", "phở bò tái"],
    nutrients_per_100g: {
      calories_kcal: 48,
      protein_g: 3.5,
      carbs_g: 5.8,
      fat_g: 1.2,
      fiber_g: 0.3,
      sugar_g: 0.5,
      sodium_mg: 350,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_PHO_BO",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_002",
    name_en: "Pho ga (Vietnamese chicken noodle soup)",
    name_vi: "Phở gà",
    aliases: ["pho ga", "chicken pho", "phở gà"],
    nutrients_per_100g: {
      calories_kcal: 45,
      protein_g: 3.2,
      carbs_g: 5.5,
      fat_g: 1.0,
      fiber_g: 0.2,
      sugar_g: 0.4,
      sodium_mg: 320,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_PHO_GA",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_003",
    name_en: "Bun bo Hue (Hue spicy beef noodle soup)",
    name_vi: "Bún bò Huế",
    aliases: ["bun bo hue", "bún bò", "bun bo"],
    nutrients_per_100g: {
      calories_kcal: 55,
      protein_g: 4.0,
      carbs_g: 6.0,
      fat_g: 1.5,
      fiber_g: 0.4,
      sugar_g: 0.3,
      sodium_mg: 380,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_BUN_BO_HUE",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_004",
    name_en: "Banh mi (Vietnamese baguette sandwich)",
    name_vi: "Bánh mì",
    aliases: ["banh mi", "banhmi", "bánh mì thịt"],
    nutrients_per_100g: {
      calories_kcal: 250,
      protein_g: 9.5,
      carbs_g: 33.0,
      fat_g: 8.5,
      fiber_g: 1.8,
      sugar_g: 3.5,
      sodium_mg: 520,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_BANH_MI",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_005",
    name_en: "Com tam (broken rice with grilled pork)",
    name_vi: "Cơm tấm sườn",
    aliases: ["com tam", "cơm tấm", "broken rice"],
    nutrients_per_100g: {
      calories_kcal: 185,
      protein_g: 8.5,
      carbs_g: 25.0,
      fat_g: 5.5,
      fiber_g: 0.5,
      sugar_g: 1.0,
      sodium_mg: 280,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_COM_TAM",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_006",
    name_en: "Goi cuon (Vietnamese fresh spring rolls)",
    name_vi: "Gỏi cuốn",
    aliases: ["goi cuon", "spring rolls", "summer rolls", "gỏi cuốn tôm thịt"],
    nutrients_per_100g: {
      calories_kcal: 110,
      protein_g: 5.5,
      carbs_g: 16.0,
      fat_g: 2.5,
      fiber_g: 1.2,
      sugar_g: 2.0,
      sodium_mg: 350,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_GOI_CUON",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_007",
    name_en: "Bun cha (grilled pork with noodles, Hanoi style)",
    name_vi: "Bún chả Hà Nội",
    aliases: ["bun cha", "bún chả", "bun cha ha noi"],
    nutrients_per_100g: {
      calories_kcal: 130,
      protein_g: 7.0,
      carbs_g: 12.0,
      fat_g: 5.5,
      fiber_g: 0.8,
      sugar_g: 3.0,
      sodium_mg: 420,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_BUN_CHA",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_008",
    name_en: "Che (Vietnamese sweet dessert soup)",
    name_vi: "Chè",
    aliases: ["che", "chè đậu", "sweet soup"],
    nutrients_per_100g: {
      calories_kcal: 95,
      protein_g: 2.0,
      carbs_g: 20.0,
      fat_g: 1.0,
      fiber_g: 1.5,
      sugar_g: 15.0,
      sodium_mg: 20,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_CHE",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_009",
    name_en: "Ca phe sua da (Vietnamese iced coffee with milk)",
    name_vi: "Cà phê sữa đá",
    aliases: ["ca phe sua da", "vietnamese coffee", "cà phê sữa"],
    nutrients_per_100g: {
      calories_kcal: 45,
      protein_g: 0.8,
      carbs_g: 8.5,
      fat_g: 1.0,
      fiber_g: 0.0,
      sugar_g: 8.0,
      sodium_mg: 15,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_CAPHE_SUA",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
  {
    food_id: "vn_010",
    name_en: "Steamed white rice (Vietnamese style)",
    name_vi: "Cơm trắng",
    aliases: ["com trang", "cơm", "white rice", "steamed rice"],
    nutrients_per_100g: {
      calories_kcal: 130,
      protein_g: 2.7,
      carbs_g: 28.0,
      fat_g: 0.3,
      fiber_g: 0.4,
      sugar_g: 0.0,
      sodium_mg: 1,
    },
    source: "vn_fct",
    source_ref: "VN_NINN_COM_TRANG",
    data_type: "Curated",
    verified_at: new Date().toISOString(),
    verified_by: "import_vn_fct_v1",
  },
];

/**
 * Run the VN FCT import — upserts curated Vietnamese food entries.
 */
export async function runVnFctImport(): Promise<{
  written: number;
  totalFkb: number;
}> {
  logger.info(`Starting VN FCT import: ${VN_FOODS.length} foods`);

  const written = await upsertBatch(VN_FOODS);
  const totalFkb = await getFkbCount();

  logger.info(`VN FCT import complete: written=${written}, totalFkb=${totalFkb}`);

  return { written, totalFkb };
}
