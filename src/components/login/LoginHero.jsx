"use client"

import { motion } from "framer-motion"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  teal: "rgb(50, 172, 166)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  deepSea: "rgb(21, 49, 75)",
}

export default function LoginHero() {
  return (
    <div
      className="login-hero-panel"
      style={{
        width: "38%",
        minWidth: 320,
        backgroundColor: colors.deepSea,
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        padding: "60px 48px",
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Large watermark REEF */}
      <div
        style={{
          position: "absolute",
          top: "50%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          fontFamily,
          fontWeight: 900,
          fontSize: 220,
          lineHeight: "1em",
          letterSpacing: "-0.04em",
          color: colors.white,
          opacity: 0.04,
          userSelect: "none",
          whiteSpace: "nowrap",
        }}
      >
        REEF
      </div>

      <div style={{ position: "relative", zIndex: 1, maxWidth: 280 }}>
        {/* Logo */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          style={{
            display: "flex",
            gap: 6,
            marginBottom: 32,
          }}
        >
          {"REEF".split("").map((letter, i) => (
            <motion.span
              key={i}
              initial={{ opacity: 0, y: -20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: 0.4,
                delay: 0.3 + i * 0.06,
                type: "spring",
                bounce: 0.3,
              }}
              style={{
                fontFamily,
                fontWeight: 900,
                fontSize: 48,
                lineHeight: "1em",
                letterSpacing: "-0.04em",
                color: colors.white,
                display: "inline-block",
              }}
            >
              {letter}
            </motion.span>
          ))}
        </motion.div>

        {/* Tagline */}
        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.5 }}
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 20,
            lineHeight: "1.5em",
            letterSpacing: "-0.02em",
            color: colors.white,
            margin: 0,
            marginBottom: 40,
            opacity: 0.85,
          }}
        >
          Your AI study partner that watches you work and guides you.
        </motion.p>

        {/* Accent line */}
        <motion.div
          initial={{ scaleX: 0 }}
          animate={{ scaleX: 1 }}
          transition={{ duration: 0.6, delay: 0.6, ease: "easeOut" }}
          style={{
            width: 48,
            height: 3,
            backgroundColor: colors.coral,
            marginBottom: 32,
            transformOrigin: "left",
          }}
        />

        {/* Value props */}
        {[
          "Sees your handwriting in real-time",
          "Understands your thought process",
          "Guides without giving answers",
        ].map((text, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, x: -16 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: 0.7 + i * 0.08 }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
              marginBottom: 16,
            }}
          >
            <div
              style={{
                width: 6,
                height: 6,
                backgroundColor: colors.coral,
                borderRadius: 0,
                flexShrink: 0,
              }}
            />
            <span
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 14,
                lineHeight: "1.5em",
                letterSpacing: "-0.02em",
                color: colors.white,
                opacity: 0.7,
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
