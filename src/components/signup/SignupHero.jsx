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

// Each creature swims along its own looping path via x/y keyframes
function SwimmingCreature({ src, alt, width, x, y, rotate, duration, delay, flip }) {
  return (
    <motion.img
      src={src}
      alt={alt}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1, x, y, rotate }}
      transition={{
        opacity: { duration: 0.6, delay },
        x: { duration, repeat: Infinity, ease: "easeInOut", delay },
        y: { duration, repeat: Infinity, ease: "easeInOut", delay },
        rotate: { duration, repeat: Infinity, ease: "easeInOut", delay },
      }}
      style={{
        position: "absolute",
        zIndex: 2,
        width,
        height: "auto",
        pointerEvents: "none",
        transform: flip ? "scaleX(-1)" : undefined,
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

      {/* Fish: drifts right-to-left across the top */}
      <div style={{ position: "absolute", top: "6%", right: "0%", zIndex: 2 }}>
        <SwimmingCreature
          src="/fish.png"
          alt=""
          width={100}
          x={[0, -60, -140, -200, -260, -200, -140, -60, 0]}
          y={[0, -20, -10, 15, 30, 15, -10, -20, 0]}
          rotate={[0, -3, -2, 2, 3, 2, -1, -3, 0]}
          duration={20}
          delay={0.4}
        />
      </div>

      {/* Turtle: slow cruise left-to-right across the bottom */}
      <div style={{ position: "absolute", bottom: "8%", left: "0%", zIndex: 2 }}>
        <SwimmingCreature
          src="/turtle.png"
          alt=""
          width={110}
          x={[0, 50, 120, 200, 260, 200, 120, 50, 0]}
          y={[0, -12, -8, 5, 15, 8, -5, -12, 0]}
          rotate={[0, 2, 3, 2, 0, -2, -3, -2, 0]}
          duration={24}
          delay={0.5}
        />
      </div>

      {/* Jellyfish: gentle vertical drift on the left side */}
      <div style={{ position: "absolute", top: "20%", left: "6%", zIndex: 2 }}>
        <SwimmingCreature
          src="/jellyfish.png"
          alt=""
          width={75}
          x={[0, 20, 50, 70, 50, 20, 0, -20, 0]}
          y={[0, -40, -60, -30, 20, 60, 40, 10, 0]}
          rotate={[0, 2, 1, -1, -2, -1, 1, 2, 0]}
          duration={18}
          delay={0.6}
        />
      </div>

      {/* Seahorse: drifts down the right edge */}
      <div style={{ position: "absolute", top: "35%", right: "8%", zIndex: 2 }}>
        <SwimmingCreature
          src="/seahorse.png"
          alt=""
          width={65}
          x={[0, -30, -70, -100, -70, -30, 0, 20, 0]}
          y={[0, -30, -10, 30, 70, 100, 70, 20, 0]}
          rotate={[0, -3, -2, 1, 3, 2, -1, -3, 0]}
          duration={22}
          delay={0.7}
        />
      </div>

      {/* Starfish: slow diagonal drift near bottom-center */}
      <div style={{ position: "absolute", bottom: "15%", left: "38%", zIndex: 2 }}>
        <SwimmingCreature
          src="/starfish.png"
          alt=""
          width={60}
          x={[0, 40, 80, 100, 80, 40, 0, -30, 0]}
          y={[0, -20, -40, -20, 10, 30, 20, 5, 0]}
          rotate={[0, 8, 15, 8, 0, -8, -15, -8, 0]}
          duration={26}
          delay={0.8}
        />
      </div>

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
