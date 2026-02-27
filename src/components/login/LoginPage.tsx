"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { motion } from "framer-motion"
import InputField from "../signup/InputField"
import OAuthButton from "../signup/OAuthButton"
import { createClient } from "../../lib/supabase/client"
import { colors } from "../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

const staggerBase = 0.3
const staggerStep = 0.05

function getDelay(index: number) {
  return staggerBase + index * staggerStep
}

function FadeUp({ index, children, style }: { index: number; children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: getDelay(index), ease: "easeOut" }}
      style={style}
    >
      {children}
    </motion.div>
  )
}

export default function LoginPage() {
  const [email, setEmail] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const router = useRouter()

  async function handleMagicLink() {
    if (!email) return
    setLoading(true)
    setError(null)
    const supabase = createClient()
    const { error: otpError } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    })
    setLoading(false)
    if (otpError) {
      setError(otpError.message)
    } else {
      router.push("/auth/check-email")
    }
  }

  return (
    <div
      style={{
        width: "100%",
        minHeight: "100vh",
        backgroundColor: colors.surface,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "40px 24px",
        boxSizing: "border-box",
        position: "relative",
      }}
    >
      {/* Back to home */}
      <Link
        href="/"
        style={{
          position: "absolute",
          top: 28,
          left: 28,
          display: "flex",
          alignItems: "center",
          gap: 6,
          fontFamily,
          fontWeight: 600,
          fontSize: 14,
          letterSpacing: "-0.02em",
          color: colors.black,
          textDecoration: "none",
          cursor: "pointer",
          opacity: 0.6,
        }}
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M19 12H5" />
          <path d="m12 19-7-7 7-7" />
        </svg>
        Home
      </Link>

      {/* Card */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.15 }}
        style={{
          width: 440,
          maxWidth: "100%",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 12,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          padding: "40px 36px",
          boxSizing: "border-box",
        }}
      >
        {/* Title */}
        <FadeUp index={0}>
          <h2
            style={{
              fontFamily,
              fontWeight: 900,
              fontSize: 32,
              lineHeight: "1.2em",
              letterSpacing: "-0.04em",
              textTransform: "uppercase",
              color: colors.black,
              margin: 0,
              marginBottom: 6,
              textAlign: "center",
            }}
          >
            Welcome Back
          </h2>
        </FadeUp>

        <FadeUp index={1} style={{ marginBottom: 28 }}>
          <p
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 15,
              lineHeight: "1.5em",
              letterSpacing: "-0.04em",
              color: colors.gray600,
              margin: 0,
              textAlign: "center",
            }}
          >
            Sign in to continue learning
          </p>
        </FadeUp>

        {/* OAuth */}
        <FadeUp index={2} style={{ display: "flex", gap: 12, marginBottom: 20 }}>
          <OAuthButton provider="google" label="Google" />
          <OAuthButton provider="apple" label="Apple" />
        </FadeUp>

        {/* Divider */}
        <FadeUp index={3} style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 20 }}>
          <div style={{ flex: 1, height: 1, backgroundColor: colors.primary }} />
          <span
            style={{
              fontFamily,
              fontWeight: 600,
              fontSize: 12,
              letterSpacing: "0.08em",
              color: colors.gray600,
              textTransform: "uppercase",
            }}
          >
            OR
          </span>
          <div style={{ flex: 1, height: 1, backgroundColor: colors.primary }} />
        </FadeUp>

        {/* Email */}
        <FadeUp index={4} style={{ marginBottom: 22 }}>
          <InputField
            type="email"
            placeholder="Enter your email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            name="email"
          />
        </FadeUp>

        {/* CTA */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: getDelay(5), ease: "easeOut" }}
          style={{ marginBottom: 20 }}
        >
          {error && (
            <p
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 13,
                color: "#d32f2f",
                margin: "0 0 12px 0",
              }}
            >
              {error}
            </p>
          )}
          <motion.button
            type="button"
            onClick={handleMagicLink}
            disabled={loading}
            whileHover={{
              boxShadow: `2px 2px 0px 0px ${colors.black}`,
              y: 2,
              x: 2,
            }}
            whileTap={{
              boxShadow: `0px 0px 0px 0px ${colors.black}`,
              y: 4,
              x: 4,
            }}
            transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
            style={{
              width: "100%",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: colors.primary,
              border: `2px solid ${colors.black}`,
              borderRadius: 12,
              padding: "14px 16px",
              boxShadow: `4px 4px 0px 0px ${colors.black}`,
              fontFamily,
              fontWeight: 700,
              fontSize: 16,
              lineHeight: "1.5em",
              letterSpacing: "-0.04em",
              color: colors.white,
              cursor: loading ? "default" : "pointer",
              boxSizing: "border-box",
              userSelect: "none",
              opacity: loading ? 0.7 : 1,
            }}
          >
            {loading ? "Sending link..." : "Continue"}
          </motion.button>
        </motion.div>

        {/* Signup link */}
        <FadeUp index={6}>
          <p
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 14,
              lineHeight: "1.5em",
              letterSpacing: "-0.04em",
              color: colors.gray600,
              textAlign: "center",
              margin: 0,
            }}
          >
            Don't have an account?{" "}
            <a
              href="/signup"
              style={{
                color: colors.primary,
                textDecoration: "none",
                cursor: "pointer",
                fontWeight: 700,
              }}
            >
              Sign up
            </a>
          </p>
        </FadeUp>
      </motion.div>
    </div>
  )
}
