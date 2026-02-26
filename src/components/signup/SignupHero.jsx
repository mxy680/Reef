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

function FishSvg({ color = colors.coral }) {
  return (
    <svg width="48" height="32" viewBox="0 0 48 32" fill="none">
      <ellipse cx="22" cy="16" rx="16" ry="11" fill={color} stroke={colors.black} strokeWidth="2" />
      <polygon points="38,16 48,6 48,26" fill={color} stroke={colors.black} strokeWidth="2" strokeLinejoin="round" />
      <circle cx="14" cy="13" r="2.5" fill={colors.white} stroke={colors.black} strokeWidth="1.5" />
      <circle cx="14.5" cy="12.5" r="1" fill={colors.black} />
      <path d="M8 16 Q12 19 18 16" stroke={colors.black} strokeWidth="1.5" fill="none" strokeLinecap="round" />
    </svg>
  )
}

function TurtleSvg({ color = colors.teal }) {
  return (
    <svg width="52" height="38" viewBox="0 0 52 38" fill="none">
      <ellipse cx="26" cy="20" rx="16" ry="12" fill={color} stroke={colors.black} strokeWidth="2" />
      <path d="M18 20 Q22 12 26 10 Q30 12 34 20" stroke={colors.black} strokeWidth="1.5" fill="none" />
      <line x1="26" y1="10" x2="26" y2="32" stroke={colors.black} strokeWidth="1.5" />
      <line x1="18" y1="20" x2="34" y2="20" stroke={colors.black} strokeWidth="1.5" />
      <ellipse cx="42" cy="18" rx="5" ry="3.5" fill={color} stroke={colors.black} strokeWidth="2" />
      <circle cx="44" cy="17" r="1.2" fill={colors.black} />
      <ellipse cx="16" cy="30" rx="4" ry="3" fill={color} stroke={colors.black} strokeWidth="1.5" />
      <ellipse cx="36" cy="30" rx="4" ry="3" fill={color} stroke={colors.black} strokeWidth="1.5" />
      <ellipse cx="14" cy="14" rx="4" ry="3" fill={color} stroke={colors.black} strokeWidth="1.5" />
      <ellipse cx="38" cy="14" rx="4" ry="3" fill={color} stroke={colors.black} strokeWidth="1.5" />
    </svg>
  )
}

function FloatingCreature({ children, style, delay }) {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{
        opacity: 1,
        y: [0, -8, 0, 8, 0],
        rotate: [0, 2, 0, -2, 0],
      }}
      transition={{
        opacity: { duration: 0.4, delay },
        y: { duration: 5, repeat: Infinity, ease: "easeInOut", delay },
        rotate: { duration: 6, repeat: Infinity, ease: "easeInOut", delay },
      }}
      style={{
        position: "absolute",
        zIndex: 2,
        ...style,
      }}
    >
      {children}
    </motion.div>
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

      <FloatingCreature style={{ top: "10%", right: "8%" }} delay={0.4}>
        <FishSvg color={colors.coral} />
      </FloatingCreature>
      <FloatingCreature style={{ bottom: "12%", left: "5%" }} delay={0.5}>
        <TurtleSvg color={colors.teal} />
      </FloatingCreature>

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
