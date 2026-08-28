/**
 * Run FKB import locally using Firebase Admin SDK with emulated or
 * service-account credentials.
 *
 * Usage:
 *   USDA_FDC_API_KEY=xxx FIRESTORE_EMULATOR_HOST=localhost:8080 node lib/run_import_local.js
 *   OR
 *   USDA_FDC_API_KEY=xxx GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json node lib/run_import_local.js
 *   OR (Firebase Auth via gcloud):
 *   USDA_FDC_API_KEY=xxx node lib/run_import_local.js
 */

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { runUsdaSeedImport } from "./jobs/importUsdaSeed";
import { runVnFctImport } from "./jobs/importVnFct";
import { getFkbCount } from "./fkb/upsert";

// Try to init with various credential strategies
try {
  initializeApp({
    projectId: "nutriscan-75d57",
    credential: applicationDefault(),
  });
} catch {
  // Fallback: init with just project ID (works with emulator or default SA)
  initializeApp({ projectId: "nutriscan-75d57" });
}

async function main() {
  console.log("=== FKB Import (Local) ===\n");

  // 1. VN FCT
  console.log("1. Importing Vietnamese foods...");
  try {
    const vnResult = await runVnFctImport();
    console.log(`   ✅ Written: ${vnResult.written}, Total FKB: ${vnResult.totalFkb}`);
  } catch (err) {
    console.error(`   ❌ VN import failed: ${err}`);
  }

  // 2. USDA Seed
  const apiKey = process.env.USDA_FDC_API_KEY;
  if (!apiKey) {
    console.error("\n❌ ERROR: Set USDA_FDC_API_KEY env var");
    process.exit(1);
  }

  console.log("\n2. Importing USDA seed foods (30-60s)...");
  try {
    const usdaResult = await runUsdaSeedImport(apiKey);
    console.log(`   Requested: ${usdaResult.requested}`);
    console.log(`   Fetched:   ${usdaResult.fetched}`);
    console.log(`   Written:   ${usdaResult.written}`);
    if (usdaResult.errors.length > 0) {
      console.log(`   Errors:    ${usdaResult.errors.length}`);
      usdaResult.errors.forEach((e) => console.log(`     - ${e}`));
    }
    console.log(`   ✅ USDA import complete`);
  } catch (err) {
    console.error(`   ❌ USDA import failed: ${err}`);
  }

  // 3. Final count
  try {
    const totalCount = await getFkbCount();
    console.log(`\n=== Done. Total FKB foods: ${totalCount} ===`);
  } catch {
    console.log("\n=== Import attempted. Check Firestore console for results. ===");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Import failed:", err);
  process.exit(1);
});
