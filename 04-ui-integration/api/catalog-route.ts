/**
 * API Route: GET /api/actions/catalog
 *
 * Returns the RUBEDO actions catalog from S3
 * Filters out disabled actions if enabled flag is set
 *
 * Next.js App Router example (adapt for your framework)
 */

import { NextResponse } from "next/server";
import { s3Json } from "@/lib/aws";

const BUCKET = process.env.AWS_S3_BUCKET || "vaultmesh-knowledge-base";

export async function GET() {
  try {
    const catalog = await s3Json(BUCKET, "actions/catalog.json");

    // Filter for enabled actions (if you adopt the enabled flag)
    const items = (catalog.catalog ?? []).filter(
      (action: any) => action.enabled !== false
    );

    return NextResponse.json({
      version: catalog.version,
      catalog: items,
    });
  } catch (error: any) {
    console.error("Failed to load catalog:", error);
    return NextResponse.json(
      { error: error.message || "Catalog load failed" },
      { status: 500 }
    );
  }
}

/**
 * For non-Next.js frameworks (Express, Fastify, etc.):
 *
 * export async function getCatalog(req, res) {
 *   try {
 *     const catalog = await s3Json(BUCKET, "actions/catalog.json");
 *     const items = (catalog.catalog ?? []).filter(a => a.enabled !== false);
 *     res.json({ version: catalog.version, catalog: items });
 *   } catch (error) {
 *     res.status(500).json({ error: error.message });
 *   }
 * }
 */
