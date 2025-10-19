/**
 * API Route: POST /api/actions/invoke
 *
 * Invokes a RUBEDO action Lambda with the standard payload contract:
 * {
 *   action: string,
 *   user: { id: string, group: string },
 *   context: { request_id: string, persona: string, system: {...} },
 *   params: {...}
 * }
 *
 * Flow:
 * 1. Resolve persona from user groups
 * 2. Load catalog and find Lambda ARN
 * 3. (Optional) Pre-check with OPA
 * 4. Invoke Lambda
 * 5. Return result or error
 */

import { NextRequest, NextResponse } from "next/server";
import { invokeLambda, s3Json } from "@/lib/aws";
import { resolvePersona, personaToSystemContext } from "@/lib/persona";

const BUCKET = process.env.AWS_S3_BUCKET || "vaultmesh-knowledge-base";
const DEFAULT_GROUP = process.env.DEFAULT_GROUP || "VaultMesh-Engineering";
const DEFAULT_USER_ID = process.env.DEFAULT_USER_ID || "anon@vaultmesh.io";
const OPA_URL = process.env.OPA_URL;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { actionId, params, user } = body as {
      actionId: string;
      params?: Record<string, unknown>;
      user?: { id?: string; groups?: string[] };
    };

    // Validate request
    if (!actionId) {
      return NextResponse.json(
        { error: "actionId is required" },
        { status: 400 }
      );
    }

    // 1. Resolve persona from groups
    const groups = user?.groups?.length ? user.groups : [DEFAULT_GROUP];
    const persona = await resolvePersona(groups);
    const systemContext = personaToSystemContext(persona);

    // 2. Load catalog and find action
    const catalog = await s3Json(BUCKET, "actions/catalog.json");
    const entry = (catalog.catalog || []).find(
      (c: any) => c.id === actionId
    );

    if (!entry) {
      return NextResponse.json(
        { error: `Action '${actionId}' not found in catalog` },
        { status: 404 }
      );
    }

    // Check if action is enabled
    if (entry.enabled === false) {
      return NextResponse.json(
        { error: `Action '${actionId}' is currently disabled` },
        { status: 403 }
      );
    }

    // 3. Build Lambda payload
    const lambdaArn = entry.lambda;
    const payload = {
      action: actionId,
      user: {
        id: user?.id ?? DEFAULT_USER_ID,
        group: groups[0],
      },
      context: {
        request_id: `rq-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        persona: persona.id,
        system: systemContext,
      },
      params: params ?? {},
    };

    // 4. (Optional) Pre-check with OPA
    if (OPA_URL) {
      const allowed = await preCheckOPA(payload);
      if (!allowed) {
        return NextResponse.json(
          { error: "Action denied by policy" },
          { status: 403 }
        );
      }
    }

    // 5. Invoke Lambda
    const { statusCode, json } = await invokeLambda(lambdaArn, payload);

    // Parse Lambda response body if it's a string
    let responseBody = json;
    if (json.body && typeof json.body === "string") {
      try {
        responseBody = { ...json, body: JSON.parse(json.body) };
      } catch {
        // Keep as-is if body isn't valid JSON
      }
    }

    return NextResponse.json(responseBody, { status: statusCode });
  } catch (error: any) {
    console.error("Action invocation failed:", error);
    return NextResponse.json(
      { error: error.message || "Action invocation failed" },
      { status: 500 }
    );
  }
}

/**
 * Pre-check authorization with OPA server
 * Returns true if allowed, false otherwise
 */
async function preCheckOPA(payload: any): Promise<boolean> {
  if (!OPA_URL) return true;

  try {
    const res = await fetch(`${OPA_URL}/allow`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ input: payload }),
      next: { revalidate: 0 } as any, // Next.js specific
    });

    const json = await res.json();
    return !!json.result;
  } catch (error) {
    console.warn("OPA pre-check failed, allowing by default:", error);
    return true; // Fail open to let Lambda's policy gate handle it
  }
}

/**
 * For non-Next.js frameworks (Express, Fastify, etc.):
 *
 * export async function invokeAction(req, res) {
 *   const { actionId, params, user } = req.body;
 *
 *   if (!actionId) {
 *     return res.status(400).json({ error: "actionId is required" });
 *   }
 *
 *   const groups = user?.groups?.length ? user.groups : [DEFAULT_GROUP];
 *   const persona = await resolvePersona(groups);
 *   const systemContext = personaToSystemContext(persona);
 *
 *   const catalog = await s3Json(BUCKET, "actions/catalog.json");
 *   const entry = catalog.catalog.find(c => c.id === actionId);
 *
 *   if (!entry) {
 *     return res.status(404).json({ error: `Action not found: ${actionId}` });
 *   }
 *
 *   const payload = {
 *     action: actionId,
 *     user: { id: user?.id ?? DEFAULT_USER_ID, group: groups[0] },
 *     context: { request_id: `rq-${Date.now()}`, persona: persona.id, system: systemContext },
 *     params: params ?? {}
 *   };
 *
 *   const { statusCode, json } = await invokeLambda(entry.lambda, payload);
 *   res.status(statusCode).json(json);
 * }
 */
