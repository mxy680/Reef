"use client"

import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

function HelpIllustration() {
  return (
    <svg width="200" height="150" viewBox="0 0 200 150" fill="none">
      {/* Main question mark speech bubble */}
      <rect x="50" y="15" width="100" height="80" rx="14" fill={colors.white} stroke={colors.black} strokeWidth="2" />
      <path d="M85 95 L80 115 L95 95" fill={colors.white} stroke={colors.black} strokeWidth="2" strokeLinejoin="round" />
      {/* Patch the overlap */}
      <line x1="83" y1="95" x2="96" y2="95" stroke={colors.white} strokeWidth="3" />

      {/* Question mark */}
      <path d="M90 38 Q90 30 100 30 Q110 30 110 40 Q110 48 100 52 L100 58" stroke={colors.primary} strokeWidth="4" strokeLinecap="round" fill="none" />
      <circle cx="100" cy="68" r="3" fill={colors.primary} />

      {/* Small floating icons — book */}
      <g>
        <rect x="15" y="40" width="24" height="20" rx="3" fill={colors.accent} stroke={colors.black} strokeWidth="1.5" />
        <line x1="27" y1="40" x2="27" y2="60" stroke={colors.black} strokeWidth="1.5" />
      </g>

      {/* Lightning bolt */}
      <path d="M175 30 L170 48 L177 46 L172 62" stroke={colors.black} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M175 30 L170 48 L177 46" fill={colors.surface} stroke={colors.black} strokeWidth="1.5" />

      {/* Chat dots */}
      <circle cx="35" cy="100" r="3" fill={colors.gray400} />
      <circle cx="45" cy="100" r="3" fill={colors.gray400} />
      <circle cx="55" cy="100" r="3" fill={colors.gray400} />

      {/* Star */}
      <path d="M170 95 L172 100 L177 100.5 L173 104 L174 109 L170 106 L166 109 L167 104 L163 100.5 L168 100 Z" fill={colors.accent} stroke={colors.black} strokeWidth="1" />
    </svg>
  )
}

function HelpTopicRow({ icon, label, delay }: { icon: React.ReactNode; label: string; delay: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -12 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.3, delay }}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        padding: "10px 14px",
        backgroundColor: colors.gray100,
        border: `1.5px solid ${colors.gray500}`,
        borderRadius: 10,
      }}
    >
      <div
        style={{
          width: 28,
          height: 28,
          borderRadius: 8,
          backgroundColor: colors.white,
          border: `1.5px solid ${colors.black}`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          flexShrink: 0,
        }}
      >
        {icon}
      </div>
      <span
        style={{
          fontFamily,
          fontWeight: 600,
          fontSize: 14,
          letterSpacing: "-0.02em",
          color: colors.black,
        }}
      >
        {label}
      </span>
    </motion.div>
  )
}

export default function HelpPage() {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "calc(100vh - 200px)" }}>
      <div style={{ width: "100%", maxWidth: 560 }}>
      {/* Page header */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
        style={{ marginBottom: 24 }}
      >
        <h1
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 28,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 6,
            textAlign: "center",
          }}
        >
          Help
        </h1>
        <p
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 15,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            margin: 0,
            textAlign: "center",
          }}
        >
          Guides, FAQs, and support
        </p>
      </motion.div>

      {/* Hero card */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.2 }}
        style={{
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 16,
          boxShadow: `4px 4px 0px 0px ${colors.black}`,
          overflow: "hidden",
        }}
      >
        {/* Illustration area */}
        <div
          style={{
            background: `linear-gradient(135deg, ${colors.primary}22, ${colors.accent}66)`,
            borderBottom: `2px solid ${colors.black}`,
            padding: "28px 0",
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
          }}
        >
          <HelpIllustration />
        </div>

        {/* Content */}
        <div style={{ padding: "24px 28px" }}>
          {/* Badge */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.3, delay: 0.35 }}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 6,
              padding: "5px 12px",
              backgroundColor: colors.accent,
              border: `2px solid ${colors.black}`,
              borderRadius: 999,
              marginBottom: 16,
            }}
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.black} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="7" cy="7" r="6" />
              <path d="M5.5 5.5 Q5.5 4 7 4 Q8.5 4 8.5 5.5 Q8.5 6.5 7 7 L7 8" />
              <circle cx="7" cy="10" r="0.5" fill={colors.black} />
            </svg>
            <span
              style={{
                fontFamily,
                fontWeight: 800,
                fontSize: 11,
                letterSpacing: "0.04em",
                textTransform: "uppercase",
                color: colors.black,
              }}
            >
              Coming Soon
            </span>
          </motion.div>

          <h2
            style={{
              fontFamily,
              fontWeight: 900,
              fontSize: 22,
              letterSpacing: "-0.04em",
              color: colors.black,
              margin: 0,
              marginBottom: 10,
            }}
          >
            Help Center
          </h2>

          <p
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 15,
              lineHeight: 1.6,
              letterSpacing: "-0.02em",
              color: colors.gray600,
              margin: 0,
              marginBottom: 20,
            }}
          >
            We&apos;re building a comprehensive help center with guides, tutorials,
            and answers to common questions. In the meantime, reach out anytime.
          </p>

          {/* Topic previews */}
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <HelpTopicRow
              delay={0.45}
              label="Getting started with Reef"
              icon={
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.primary} strokeWidth="2" strokeLinecap="round">
                  <path d="M2 7 L6 11 L12 3" />
                </svg>
              }
            />
            <HelpTopicRow
              delay={0.53}
              label="How the AI tutor works"
              icon={
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.primary} strokeWidth="2" strokeLinecap="round">
                  <circle cx="7" cy="5" r="4" />
                  <path d="M3 12 Q7 9 11 12" />
                </svg>
              }
            />
            <HelpTopicRow
              delay={0.61}
              label="Uploading and managing documents"
              icon={
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.primary} strokeWidth="2" strokeLinecap="round">
                  <path d="M3 2 H9 L11 4 V12 H3 Z" />
                  <line x1="5" y1="7" x2="9" y2="7" />
                  <line x1="5" y1="9.5" x2="9" y2="9.5" />
                </svg>
              }
            />
            <HelpTopicRow
              delay={0.69}
              label="Contact support"
              icon={
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.primary} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M1 3 L7 8 L13 3" />
                  <rect x="1" y="3" width="12" height="8" rx="1.5" />
                </svg>
              }
            />
          </div>
        </div>
      </motion.div>
      </div>
    </div>
  )
}
