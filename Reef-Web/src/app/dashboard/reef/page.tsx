"use client"

import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

function CoralReefIllustration() {
  return (
    <svg width="200" height="160" viewBox="0 0 200 160" fill="none">
      {/* Ocean floor */}
      <path d="M0 140 Q50 130 100 135 Q150 140 200 132 V160 H0 Z" fill={colors.accent} stroke={colors.black} strokeWidth="2" />

      {/* Coral branch 1 */}
      <path d="M40 140 Q38 110 30 90 Q25 80 35 75 Q28 65 40 60 Q35 50 45 45" stroke={colors.primary} strokeWidth="3" strokeLinecap="round" fill="none" />
      <path d="M40 140 Q42 115 50 100 Q55 90 45 85" stroke={colors.primary} strokeWidth="3" strokeLinecap="round" fill="none" />
      <circle cx="45" cy="45" r="5" fill={colors.accent} stroke={colors.black} strokeWidth="1.5" />
      <circle cx="30" cy="75" r="4" fill={colors.accent} stroke={colors.black} strokeWidth="1.5" />

      {/* Coral branch 2 — fan shape */}
      <path d="M120 135 Q115 100 105 80" stroke="#E8847C" strokeWidth="3" strokeLinecap="round" fill="none" />
      <path d="M120 135 Q120 95 120 75" stroke="#E8847C" strokeWidth="3" strokeLinecap="round" fill="none" />
      <path d="M120 135 Q125 100 135 80" stroke="#E8847C" strokeWidth="3" strokeLinecap="round" fill="none" />
      <circle cx="105" cy="77" r="4" fill={colors.surface} stroke={colors.black} strokeWidth="1.5" />
      <circle cx="120" cy="72" r="4" fill={colors.surface} stroke={colors.black} strokeWidth="1.5" />
      <circle cx="135" cy="77" r="4" fill={colors.surface} stroke={colors.black} strokeWidth="1.5" />

      {/* Seaweed */}
      <path d="M170 140 Q175 120 165 105 Q155 90 165 75 Q175 60 168 45" stroke={colors.accent} strokeWidth="2.5" strokeLinecap="round" fill="none" />

      {/* Fish */}
      <g>
        <ellipse cx="80" cy="50" rx="12" ry="7" fill={colors.surface} stroke={colors.black} strokeWidth="1.5" />
        <path d="M92 50 L100 44 L100 56 Z" fill={colors.surface} stroke={colors.black} strokeWidth="1.5" />
        <circle cx="75" cy="49" r="1.5" fill={colors.black} />
      </g>

      {/* Small fish */}
      <g>
        <ellipse cx="155" cy="35" rx="8" ry="5" fill={colors.accent} stroke={colors.black} strokeWidth="1.5" />
        <path d="M163 35 L169 30 L169 40 Z" fill={colors.accent} stroke={colors.black} strokeWidth="1.5" />
        <circle cx="151" cy="34" r="1" fill={colors.black} />
      </g>

      {/* Bubbles */}
      <circle cx="60" cy="25" r="3" stroke={colors.gray400} strokeWidth="1" fill="none" />
      <circle cx="140" cy="18" r="2" stroke={colors.gray400} strokeWidth="1" fill="none" />
      <circle cx="95" cy="12" r="2.5" stroke={colors.gray400} strokeWidth="1" fill="none" />
    </svg>
  )
}

function StarIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill={colors.accent} stroke={colors.black} strokeWidth="1.5">
      <path d="M8 1 L9.8 5.8 L15 6.2 L11 9.6 L12.2 15 L8 12 L3.8 15 L5 9.6 L1 6.2 L6.2 5.8 Z" />
    </svg>
  )
}

export default function MyReefPage() {
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
          <CoralReefIllustration />
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
              My Reef
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
              Your personal ocean ecosystem
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
            <StarIcon />
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
            Build Your Reef Ecosystem
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
            As you study and master new topics, you&apos;ll unlock species for your personal reef.
            Watch your ocean grow from a quiet sandy floor into a thriving coral ecosystem.
          </p>

          {/* Feature previews */}
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {[
              { label: "Unlock species as you learn", color: colors.accent },
              { label: "Track mastery across subjects", color: colors.surface },
              { label: "Compare reefs with friends", color: colors.accent },
            ].map((item, i) => (
              <motion.div
                key={item.label}
                initial={{ opacity: 0, x: -12 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.3, delay: 0.45 + i * 0.08 }}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                }}
              >
                <div
                  style={{
                    width: 8,
                    height: 8,
                    borderRadius: 999,
                    backgroundColor: item.color,
                    border: `1.5px solid ${colors.black}`,
                    flexShrink: 0,
                  }}
                />
                <span
                  style={{
                    fontFamily,
                    fontWeight: 600,
                    fontSize: 14,
                    letterSpacing: "-0.02em",
                    color: colors.black,
                  }}
                >
                  {item.label}
                </span>
              </motion.div>
            ))}
          </div>
        </div>
    </motion.div>
  )
}
