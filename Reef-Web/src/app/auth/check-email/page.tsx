"use client"

import Link from "next/link"
import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"
import { useIsMobile } from "../../../lib/useIsMobile"

const fontFamily = `"Epilogue", sans-serif`

function MailIcon() {
  return (
    <svg
      width="48"
      height="48"
      viewBox="0 0 24 24"
      fill="none"
      stroke={colors.primary}
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="2" y="4" width="20" height="16" rx="2" />
      <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
    </svg>
  )
}

export default function CheckEmailPage() {
  const isMobile = useIsMobile()

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
          boxShadow: isMobile ? `4px 4px 0px 0px ${colors.black}` : `6px 6px 0px 0px ${colors.black}`,
          padding: isMobile ? "32px 20px" : "48px 36px",
          boxSizing: "border-box",
          textAlign: "center",
        }}
      >
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.35, delay: 0.3 }}
          style={{ marginBottom: 24 }}
        >
          <MailIcon />
        </motion.div>

        <motion.h2
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.4 }}
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: isMobile ? 24 : 28,
            lineHeight: "1.2em",
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: colors.black,
            margin: 0,
            marginBottom: 12,
          }}
        >
          Check Your Email
        </motion.h2>

        <motion.p
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.5 }}
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 15,
            lineHeight: "1.6em",
            letterSpacing: "-0.04em",
            color: colors.gray600,
            margin: 0,
            marginBottom: 28,
          }}
        >
          We sent you a magic link. Click the link in your email to sign in.
        </motion.p>

        <motion.a
          href="/auth"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.35, delay: 0.6 }}
          style={{
            fontFamily,
            fontWeight: 600,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.primary,
            textDecoration: "none",
            cursor: "pointer",
          }}
        >
          Back to sign in
        </motion.a>
      </motion.div>
    </div>
  )
}
