"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { motion } from "framer-motion"
import { createClient } from "../../lib/supabase/client"
import { getProfile } from "../../lib/api"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  teal: "rgb(50, 172, 166)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  deepSea: "rgb(21, 49, 75)",
  gray: "rgb(119, 119, 119)",
  tealSoft: "rgb(214, 243, 241)",
}

const GRADE_LABELS = {
  middle_school: "Middle School",
  high_school: "High School",
  college: "College",
  graduate: "Graduate",
  other: "Other",
}

export default function DashboardPage() {
  const router = useRouter()
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function init() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        router.push("/auth")
        return
      }

      try {
        const p = await getProfile(user.id)
        if (!p || !p.onboarding_completed) {
          router.push("/onboarding")
          return
        }
        setProfile(p)
      } catch {
        router.push("/onboarding")
        return
      }

      setLoading(false)
    }
    init()
  }, [router])

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    document.cookie = "reef_onboarded=; path=/; max-age=0"
    router.push("/auth")
  }

  if (loading) return null

  return (
    <div
      style={{
        width: "100%",
        minHeight: "100vh",
        backgroundColor: colors.tealSoft,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "40px 24px",
        boxSizing: "border-box",
      }}
    >
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.15 }}
        style={{
          width: 440,
          maxWidth: "100%",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          padding: "48px 36px",
          boxSizing: "border-box",
        }}
      >
        <motion.h2
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.3 }}
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 28,
            lineHeight: "1.2em",
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: colors.deepSea,
            margin: 0,
            marginBottom: 8,
          }}
        >
          Welcome, {profile?.display_name}
        </motion.h2>

        <motion.p
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.4 }}
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 15,
            color: colors.gray,
            letterSpacing: "-0.04em",
            margin: 0,
            marginBottom: 28,
          }}
        >
          {GRADE_LABELS[profile?.grade] || profile?.grade}
        </motion.p>

        {profile?.subjects?.length > 0 && (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.35, delay: 0.5 }}
            style={{
              display: "flex",
              flexWrap: "wrap",
              gap: 8,
              marginBottom: 32,
            }}
          >
            {profile.subjects.map((subject) => (
              <span
                key={subject}
                style={{
                  padding: "6px 14px",
                  backgroundColor: colors.teal,
                  border: `2px solid ${colors.teal}`,
                  borderRadius: 999,
                  fontFamily,
                  fontWeight: 600,
                  fontSize: 13,
                  letterSpacing: "-0.04em",
                  color: colors.white,
                }}
              >
                {subject}
              </span>
            ))}
          </motion.div>
        )}

        <motion.button
          type="button"
          onClick={handleSignOut}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          whileHover={{
            backgroundColor: "rgb(235, 235, 235)",
            boxShadow: `2px 2px 0px 0px ${colors.black}`,
          }}
          whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}` }}
          transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
          style={{
            backgroundColor: colors.white,
            border: `2px solid ${colors.black}`,
            borderRadius: 0,
            padding: "12px 28px",
            boxShadow: `4px 4px 0px 0px ${colors.black}`,
            fontFamily,
            fontWeight: 600,
            fontSize: 15,
            letterSpacing: "-0.04em",
            color: colors.deepSea,
            cursor: "pointer",
          }}
        >
          Sign Out
        </motion.button>
      </motion.div>
    </div>
  )
}
