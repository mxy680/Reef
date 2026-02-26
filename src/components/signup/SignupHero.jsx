"use client"

import { motion } from "framer-motion"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  black: "rgb(0, 0, 0)",
  deepSea: "rgb(21, 49, 75)",
  tealSoft: "rgb(214, 243, 241)",
}

const valueProps = [
  "Free during beta \u2014 all features included",
  "Works with any subject or textbook",
  "No credit card required",
]

// 6x6 grid, wave in diagonally
function GridPattern() {
  const size = 6
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      {Array.from({ length: size * size }).map((_, i) => {
        const row = Math.floor(i / size)
        const col = i % size
        const diag = row + col
        return (
          <motion.div
            key={i}
            initial={{ opacity: 0, scale: 0 }}
            animate={{ opacity: 0.08, scale: 1 }}
            transition={{ duration: 0.3, delay: 0.2 + diag * 0.02 }}
            style={{
              position: "absolute",
              width: 8,
              height: 8,
              borderRadius: 0,
              backgroundColor: colors.black,
              top: `${row * (100 / (size - 1))}%`,
              left: `${col * (100 / (size - 1))}%`,
            }}
          />
        )
      })}
    </div>
  )
}

function CheckIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  )
}

export default function SignupHero() {
  return (
    <div
      className="signup-hero-panel"
      style={{
        flex: 1,
        backgroundColor: colors.tealSoft,
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        padding: "60px 40px",
        borderRight: `2px solid ${colors.black}`,
        position: "relative",
        overflow: "hidden",
      }}
    >
      <GridPattern />

      <div style={{ position: "relative", zIndex: 3, textAlign: "center", maxWidth: 420 }}>
        {/* REEF letters stagger in */}
        <div style={{ display: "flex", justifyContent: "center", gap: 4, marginBottom: 20 }}>
          {"REEF".split("").map((letter, i) => (
            <motion.span
              key={i}
              initial={{ opacity: 0, y: -30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: 0.5,
                delay: 0.3 + i * 0.08,
                type: "spring",
                bounce: 0.3,
              }}
              style={{
                fontFamily,
                fontWeight: 900,
                fontSize: 64,
                lineHeight: "1em",
                letterSpacing: "-0.04em",
                color: colors.deepSea,
                display: "inline-block",
              }}
            >
              {letter}
            </motion.span>
          ))}
        </div>

        {/* Subtitle */}
        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.4 }}
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 18,
            lineHeight: "1.5em",
            letterSpacing: "-0.04em",
            color: colors.deepSea,
            margin: 0,
            marginBottom: 40,
          }}
        >
          AI-powered tutoring that adapts to how you think.
        </motion.p>

        {/* Value props */}
        {valueProps.map((text, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: 0.6 + i * 0.1 }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
              marginBottom: 14,
            }}
          >
            <div
              style={{
                width: 24,
                height: 24,
                backgroundColor: colors.coral,
                border: `2px solid ${colors.black}`,
                boxShadow: `2px 2px 0px 0px ${colors.black}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                flexShrink: 0,
              }}
            >
              <CheckIcon />
            </div>
            <span
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 15,
                lineHeight: "1.5em",
                letterSpacing: "-0.04em",
                color: colors.deepSea,
                textAlign: "left",
              }}
            >
              {text}
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  )
}
