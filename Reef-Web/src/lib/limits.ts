export type Tier = "shore" | "reef" | "abyss"

export const TIER_LIMITS = {
  shore: { maxDocuments: 5, maxFileSizeMB: 20, maxCourses: 1 },
  reef: { maxDocuments: 50, maxFileSizeMB: 50, maxCourses: 5 },
  abyss: { maxDocuments: Infinity, maxFileSizeMB: 100, maxCourses: Infinity },
} as const

// Returns the user's current tier. Hardcoded to "shore" until billing ships.
export async function getUserTier(): Promise<Tier> {
  return "shore"
}

export function getLimits(tier: Tier) {
  return TIER_LIMITS[tier]
}
