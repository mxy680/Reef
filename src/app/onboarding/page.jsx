"use client"

import { useRouter } from "next/navigation"
import { motion } from "framer-motion"
import { createClient } from "../../lib/supabase/client"

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

export default function OnboardingPage() {
  const router = useRouter()

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push("/auth")
  }

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
          textAlign: "center",
        }}
      >
        <motion.h2
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.3 }}
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 32,
            lineHeight: "1.2em",
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: colors.deepSea,
            margin: 0,
            marginBottom: 12,
          }}
        >
          Welcome to Reef
        </motion.h2>

        <motion.p
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.4 }}
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 15,
            lineHeight: "1.6em",
            letterSpacing: "-0.04em",
            color: colors.gray,
            margin: 0,
            marginBottom: 32,
          }}
        >
          You're signed in. Onboarding coming soon.
        </motion.p>

        <motion.button
          type="button"
          onClick={handleSignOut}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          whileHover={{
            backgroundColor: "rgb(235, 235, 235)",
            boxShadow: "2px 2px 0px 0px rgb(0, 0, 0)",
          }}
          whileTap={{
            boxShadow: "0px 0px 0px 0px rgb(0, 0, 0)",
          }}
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
