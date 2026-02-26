"use client"

import { motion } from "framer-motion"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  teal: "rgb(50, 172, 166)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  deepSea: "rgb(21, 49, 75)",
  tealSoft: "rgb(214, 243, 241)",
  coralSoft: "rgb(253, 228, 219)",
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

const SIZE = 80

// Drifts continuously from right to left across the panel with gentle vertical wobble
function DriftingCreature({ src, alt, top, duration, delay, wobble = 15 }) {
  return (
    <motion.img
      src={src}
      alt={alt}
      initial={{ x: 700, opacity: 0 }}
      animate={{
        x: [700, -100],
        y: [0, wobble, -wobble, wobble, 0],
        rotate: [0, 2, -2, 2, 0],
        opacity: [0, 1, 1, 1, 0],
      }}
      transition={{
        x: { duration, repeat: Infinity, ease: "linear", delay },
        y: { duration: duration / 2, repeat: Infinity, ease: "easeInOut", delay },
        rotate: { duration: duration / 2, repeat: Infinity, ease: "easeInOut", delay },
        opacity: { duration, repeat: Infinity, times: [0, 0.05, 0.5, 0.95, 1], ease: "linear", delay },
      }}
      style={{
        position: "absolute",
        top,
        left: 0,
        zIndex: 2,
        width: SIZE,
        height: "auto",
        pointerEvents: "none",
      }}
    />
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

      <DriftingCreature src="/fish.png" alt="" top="5%" duration={14} delay={0} wobble={12} />
      <DriftingCreature src="/jellyfish.png" alt="" top="25%" duration={18} delay={3} wobble={18} />
      <DriftingCreature src="/seahorse.png" alt="" top="45%" duration={22} delay={7} wobble={10} />
      <DriftingCreature src="/turtle.png" alt="" top="65%" duration={16} delay={5} wobble={14} />
      <DriftingCreature src="/starfish.png" alt="" top="82%" duration={20} delay={10} wobble={8} />

      <div style={{ position: "relative", zIndex: 3, textAlign: "center", maxWidth: 400 }}>
        {/* REEF letters stagger in */}
        <div style={{ display: "flex", justifyContent: "center", gap: 4, marginBottom: 24 }}>
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
            marginBottom: 48,
          }}
        >
          Join thousands of students learning smarter with AI-powered tutoring that adapts to how you think.
        </motion.p>

        {/* Value props */}
        {valueProps.map((text, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: 0.5 + i * 0.1 }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
              marginBottom: 16,
            }}
          >
            <div
              style={{
                width: 28,
                height: 28,
                backgroundColor: colors.coral,
                border: `2px solid ${colors.black}`,
                boxShadow: `3px 3px 0px 0px ${colors.black}`,
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
                fontSize: 16,
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
