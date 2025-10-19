/**
 * VaultMesh Q Business - Persona Resolution & Loading
 *
 * Maps IAM Identity Center groups to persona IDs and loads
 * persona configuration from S3 with 5-minute caching.
 *
 * Personas shape chat tone, preferred sources, and answer guidance
 * without fragmenting content by role.
 */

import { s3Json } from "./aws";

const BUCKET = process.env.AWS_S3_BUCKET || "vaultmesh-knowledge-base";
const CACHE_MS = 5 * 60 * 1000; // 5 minutes

export interface Persona {
  id: string;
  name: string;
  iam_groups: string[];
  tone: string;
  preferred_sources: string[];
  formatting?: string;
  answer_guidance?: string[];
  glossary_aliases?: Record<string, string[]>;
}

export interface SystemContext {
  tone: string;
  preferred_sources: string[];
  answer_guidance: string[];
  glossary_aliases: Record<string, string[]>;
}

// Simple in-memory cache
const cache = new Map<string, { at: number; persona: Persona }>();

/**
 * Resolve persona ID from user groups
 * Priority order: engineer, delivery-manager, compliance
 * Falls back to engineer if no match
 */
export async function resolvePersona(groups: string[]): Promise<Persona> {
  // Priority order matches business logic
  const candidates = ["engineer", "delivery-manager", "compliance"];

  for (const id of candidates) {
    const persona = await loadPersona(id);
    // Check if any of the user's groups match this persona's allowed groups
    if (persona.iam_groups.some((g) => groups.includes(g))) {
      return persona;
    }
  }

  // Default to engineer for unknown groups or anonymous
  return loadPersona("engineer");
}

/**
 * Load persona from S3 with 5-minute cache
 */
export async function loadPersona(id: string): Promise<Persona> {
  const key = `personas/${id}.json`;
  const now = Date.now();
  const hit = cache.get(key);

  // Return cached if still valid
  if (hit && now - hit.at < CACHE_MS) {
    return hit.persona;
  }

  // Fetch from S3
  const persona = await s3Json<Persona>(BUCKET, key);
  cache.set(key, { at: now, persona });

  return persona;
}

/**
 * Extract system context for chat initialization
 */
export function personaToSystemContext(persona: Persona): SystemContext {
  return {
    tone: persona.tone,
    preferred_sources: persona.preferred_sources,
    answer_guidance: persona.answer_guidance ?? [],
    glossary_aliases: persona.glossary_aliases ?? {},
  };
}

/**
 * Map common group names to VaultMesh canonical groups
 * Use this when integrating with Identity Center
 */
export function normalizeGroups(rawGroups: string[]): string[] {
  const mapping: Record<string, string> = {
    "engineering": "VaultMesh-Engineering",
    "delivery": "VaultMesh-Delivery",
    "compliance": "VaultMesh-Compliance",
    "management": "VaultMesh-Management",
  };

  return rawGroups.map(g => mapping[g.toLowerCase()] || g);
}

/**
 * Get default persona for anonymous users
 */
export async function getDefaultPersona(): Promise<Persona> {
  return loadPersona("engineer");
}
