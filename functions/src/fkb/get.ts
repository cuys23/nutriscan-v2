/**
 * FKB get — fetch a single `fkb_foods` document by food_id.
 */

import { getFirestore } from "firebase-admin/firestore";
import { FkbFood } from "./types";

const FKB_COLLECTION = "fkb_foods";

/** Returns the food, or null if `food_id` does not exist. */
export async function getFkbFood(foodId: string): Promise<FkbFood | null> {
  const db = getFirestore();
  const doc = await db.collection(FKB_COLLECTION).doc(foodId).get();
  if (!doc.exists) return null;
  return doc.data() as FkbFood;
}
