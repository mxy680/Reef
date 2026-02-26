"use client"

import { motion } from "framer-motion"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  deepSea: "rgb(21, 49, 75)",
  coralSoft: "rgb(253, 228, 219)",
}

const valueProps = [
  "Sees your handwriting in real-time",
  "Understands your thought process",
  "Guides without giving answers",
]

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

export default function LoginHero() {
  return (
    <div
      className="login-hero-panel"
      style={{
        flex: 1,
        backgroundColor: colors.coralSoft,
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
        <div style={{ display: "flex", justifyContent: "center", gap: 4, marginBottom: 16 }}>
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

        {/* Product screenshot in neo-brutalist frame */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.4 }}
          style={{
            border: `3px solid ${colors.black}`,
            boxShadow: `6px 6px 0px 0px ${colors.black}`,
            borderRadius: 0,
            overflow: "hidden",
            backgroundColor: colors.white,
            marginBottom: 28,
            transform: "rotate(2deg)",
          }}
        >
          <img
            src="https://framerusercontent.com/images/28E4wGiqpajUZYTPMvIOS9l2XE.png"
            alt="Reef app on iPad"
            style={{
              width: "100%",
              height: "auto",
              display: "block",
            }}
          />
        </motion.div>

        {/* Subtitle */}
        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.5 }}
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 16,
            lineHeight: "1.5em",
            letterSpacing: "-0.04em",
            color: colors.deepSea,
            margin: 0,
            marginBottom: 28,
          }}
        >
          Your AI study partner that watches you work and guides you.
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
