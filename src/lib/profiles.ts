import { createClient } from "./supabase/client"

export interface Profile {
  id: string
  display_name: string | null
  email: string | null
  grade: string | null
  subjects: string[]
  onboarding_completed: boolean
  referral_source: string | null
  created_at: string
  updated_at: string
}

export type ProfileUpsert = Partial<
  Omit<Profile, "id" | "created_at" | "updated_at">
>

export async function getProfile(): Promise<Profile | null> {
  const supabase = createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return null

  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single()

  if (error?.code === "PGRST116") return null // no rows
  if (error) throw error
  return data as Profile
}

export async function upsertProfile(fields: ProfileUpsert): Promise<Profile> {
  const supabase = createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

  const { data, error } = await supabase
    .from("profiles")
    .upsert({ id: user.id, ...fields })
    .select()
    .single()

  if (error) throw error
  return data as Profile
}
