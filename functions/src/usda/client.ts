/**
 * USDA FoodData Central API client (server-side only).
 *
 * Endpoints used:
 *   POST /fdc/v1/foods/search   — full-text search
 *   GET  /fdc/v1/food/{fdcId}   — single food detail
 *   POST /fdc/v1/foods          — batch food details (up to 20 per call)
 *
 * The API key is passed at call time (from Secret Manager); it is never
 * stored in this module.
 */

import { logger } from "firebase-functions";

const FDC_BASE_URL = "https://api.nal.usda.gov/fdc/v1";

// ---------------------------------------------------------------------------
// Response shapes (minimal — only what we actually read)
// ---------------------------------------------------------------------------

export interface FdcSearchFood {
  fdcId: number;
  description: string;
  dataType?: string;
  foodNutrients?: Array<{
    nutrientId?: number;
    nutrientNumber?: string;
    nutrientName?: string;
    value?: number;
  }>;
}

export interface FdcSearchResponse {
  totalHits: number;
  foods: FdcSearchFood[];
}

export interface FdcFoodDetail {
  fdcId: number;
  description: string;
  dataType?: string;
  foodNutrients?: Array<{
    nutrient?: { number?: number | string; id?: number; name?: string };
    amount?: number;
  }>;
}

// ---------------------------------------------------------------------------
// API functions
// ---------------------------------------------------------------------------

/**
 * Search USDA FDC for foods matching `query`.
 *
 * @param query      Free-text query (e.g. "banana raw")
 * @param apiKey     USDA FDC API key
 * @param dataTypes  Filter by data type. Default: Foundation + SR Legacy
 * @param pageSize   Max results. Default: 25
 */
export async function searchFoods(
  query: string,
  apiKey: string,
  dataTypes: string[] = ["Foundation", "SR Legacy"],
  pageSize = 25
): Promise<FdcSearchResponse> {
  const body = {
    query,
    dataType: dataTypes,
    pageSize,
    sortBy: "dataType.keyword",
    sortOrder: "asc",
  };

  const response = await fetch(`${FDC_BASE_URL}/foods/search?api_key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    logger.error("USDA search failed", { status: response.status, body: text });
    throw new Error(`USDA search failed: HTTP ${response.status}`);
  }

  return (await response.json()) as FdcSearchResponse;
}

/**
 * Fetch a single food by FDC ID.
 */
export async function getFood(
  fdcId: number,
  apiKey: string
): Promise<FdcFoodDetail> {
  const response = await fetch(
    `${FDC_BASE_URL}/food/${fdcId}?api_key=${apiKey}`,
    { method: "GET" }
  );

  if (!response.ok) {
    const text = await response.text();
    logger.error("USDA getFood failed", { fdcId, status: response.status, body: text });
    throw new Error(`USDA getFood(${fdcId}) failed: HTTP ${response.status}`);
  }

  return (await response.json()) as FdcFoodDetail;
}

/**
 * Fetch multiple foods by FDC IDs in a single request (max 20 per call).
 */
export async function getFoodsBatch(
  fdcIds: number[],
  apiKey: string
): Promise<FdcFoodDetail[]> {
  if (fdcIds.length === 0) return [];
  if (fdcIds.length > 20) {
    throw new Error("USDA batch limit is 20 per call");
  }

  const response = await fetch(
    `${FDC_BASE_URL}/foods?api_key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fdcIds }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    logger.error("USDA batch failed", { status: response.status, body: text });
    throw new Error(`USDA batch failed: HTTP ${response.status}`);
  }

  return (await response.json()) as FdcFoodDetail[];
}
