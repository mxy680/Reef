"use client"

import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

function LibraryIllustration() {
  return (
    <svg width="200" height="150" viewBox="0 0 200 150" fill="none">
      {/* Shelf */}
      <line x1="25" y1="120" x2="175" y2="120" stroke={colors.black} strokeWidth="2.5" />

      {/* Book 1 — tall, teal */}
      <rect x="35" y="45" width="22" height="75" rx="3" fill={colors.accent} stroke={colors.black} strokeWidth="2" />
      <line x1="40" y1="55" x2="52" y2="55" stroke={colors.black} strokeWidth="1.5" />
      <line x1="40" y1="60" x2="48" y2="60" stroke={colors.black} strokeWidth="1" />
      <rect x="41" y="95" width="10" height="14" rx="2" fill={colors.white} stroke={colors.black} strokeWidth="1" />

      {/* Book 2 — medium, warm */}
      <rect x="60" y="55" width="18" height="65" rx="3" fill={colors.surface} stroke={colors.black} strokeWidth="2" />
      <line x1="64" y1="63" x2="74" y2="63" stroke={colors.black} strokeWidth="1.5" />
      <line x1="64" y1="68" x2="71" y2="68" stroke={colors.black} strokeWidth="1" />

      {/* Book 3 — short, primary */}
      <rect x="81" y="70" width="20" height="50" rx="3" fill={colors.primary} stroke={colors.black} strokeWidth="2" />
      <line x1="85" y1="78" x2="97" y2="78" stroke={colors.white} strokeWidth="1.5" />
      <line x1="85" y1="83" x2="93" y2="83" stroke={colors.white} strokeWidth="1" />

      {/* Book 4 — leaning */}
      <g transform="rotate(-8, 115, 120)">
        <rect x="105" y="50" width="20" height="70" rx="3" fill={colors.accent} stroke={colors.black} strokeWidth="2" />
        <line x1="109" y1="58" x2="121" y2="58" stroke={colors.black} strokeWidth="1.5" />
        <line x1="109" y1="63" x2="117" y2="63" stroke={colors.black} strokeWidth="1" />
      </g>

      {/* Book 5 — wide, lying flat */}
      <rect x="130" y="104" width="35" height="16" rx="3" fill={colors.surface} stroke={colors.black} strokeWidth="2" />
      <line x1="135" y1="112" x2="155" y2="112" stroke={colors.black} strokeWidth="1" />

      {/* Open book on top of stack */}
      <g transform="translate(135, 85)">
        <path d="M0 15 Q12 8 24 15 V0 Q12 -5 0 0 Z" fill={colors.white} stroke={colors.black} strokeWidth="1.5" />
        <path d="M24 15 Q36 8 48 15 V0 Q36 -5 24 0 Z" fill={colors.white} stroke={colors.black} strokeWidth="1.5" />
        <line x1="24" y1="0" x2="24" y2="15" stroke={colors.black} strokeWidth="1.5" />
        {/* Text lines */}
        <line x1="4" y1="5" x2="18" y2="5" stroke={colors.gray400} strokeWidth="0.8" />
        <line x1="4" y1="8" x2="15" y2="8" stroke={colors.gray400} strokeWidth="0.8" />
        <line x1="30" y1="5" x2="44" y2="5" stroke={colors.gray400} strokeWidth="0.8" />
        <line x1="30" y1="8" x2="41" y2="8" stroke={colors.gray400} strokeWidth="0.8" />
      </g>

      {/* Floating sparkles */}
      <path d="M50 25 L52 19 L54 25 L60 27 L54 29 L52 35 L50 29 L44 27 Z" fill={colors.accent} stroke={colors.black} strokeWidth="1" />
      <path d="M155 35 L156.5 31 L158 35 L162 36.5 L158 38 L156.5 42 L155 38 L151 36.5 Z" fill={colors.surface} stroke={colors.black} strokeWidth="1" />
    </svg>
  )
}

export default function LibraryPage() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.1 }}
      style={{
        display: "flex",
        flexDirection: "column",
        minHeight: "calc(100vh - 200px)",
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
            backgroundColor: colors.accent,
            borderBottom: `2px solid ${colors.black}`,
            padding: "48px 0",
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            flex: 1,
            minHeight: 240,
            gap: 24,
          }}
        >
          <LibraryIllustration />
          <div style={{ textAlign: "center" }}>
            <h1
              style={{
                fontFamily,
                fontWeight: 900,
                fontSize: 32,
                letterSpacing: "-0.04em",
                color: colors.black,
                margin: 0,
                marginBottom: 6,
              }}
            >
              Library
            </h1>
            <p
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 15,
                letterSpacing: "-0.04em",
                color: colors.gray600,
                margin: 0,
              }}
            >
              Shared resources and study materials
            </p>
          </div>
        </div>

        {/* Content */}
        <div style={{ padding: "24px 32px" }}>
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
              backgroundColor: colors.surface,
              border: `2px solid ${colors.black}`,
              borderRadius: 999,
              marginBottom: 16,
            }}
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.black} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M2 2 V12 H5 L7 10 L9 12 H12 V2 Z" />
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
            Community Library
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
            Browse and share study materials with classmates. Find textbooks, problem
            sets, and notes organized by course — all in one place.
          </p>

          {/* Category preview grid */}
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: 0.45 }}
            style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}
          >
            {[
              { label: "Textbooks", count: "120+", bg: colors.accent },
              { label: "Problem Sets", count: "85+", bg: colors.surface },
              { label: "Lecture Notes", count: "200+", bg: colors.surface },
              { label: "Study Guides", count: "60+", bg: colors.accent },
            ].map((cat, i) => (
              <motion.div
                key={cat.label}
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.25, delay: 0.5 + i * 0.06 }}
                style={{
                  backgroundColor: cat.bg,
                  border: `1.5px solid ${colors.black}`,
                  borderRadius: 10,
                  padding: "12px 14px",
                }}
              >
                <div
                  style={{
                    fontFamily,
                    fontWeight: 900,
                    fontSize: 18,
                    letterSpacing: "-0.04em",
                    color: colors.black,
                    marginBottom: 2,
                  }}
                >
                  {cat.count}
                </div>
                <div
                  style={{
                    fontFamily,
                    fontWeight: 600,
                    fontSize: 12,
                    letterSpacing: "-0.02em",
                    color: colors.gray600,
                  }}
                >
                  {cat.label}
                </div>
              </motion.div>
            ))}
          </motion.div>
        </div>
    </motion.div>
  )
}
