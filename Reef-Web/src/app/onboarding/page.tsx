"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "../../lib/supabase/client"
import { getProfile, Profile } from "../../lib/profiles"
import OnboardingWizard from "../../components/onboarding/OnboardingWizard"

export default function OnboardingPage() {
  const router = useRouter()
  const [user, setUser] = useState(null)
  const [partialProfile, setPartialProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function init() {
      const supabase = createClient()
      const { data: { user: u } } = await supabase.auth.getUser()
      if (!u) {
        router.push("/auth")
        return
      }

      try {
        const profile = await getProfile()
        if (profile?.onboarding_completed) {
          document.cookie = "reef_onboarded=true; path=/; max-age=31536000"
          router.push("/dashboard")
          return
        }
        if (profile) {
          setPartialProfile(profile)
        }
      } catch {
        // No profile yet — continue to wizard
      }

      setUser(u)
      setLoading(false)
    }
    init()
  }, [router])

  if (loading) return null

  return <OnboardingWizard user={user} partialProfile={partialProfile} />
}
