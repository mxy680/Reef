"use client"

import { useState } from "react"
import { motion } from "framer-motion"
import InputField from "../signup/InputField"
import OAuthButton from "../signup/OAuthButton"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  teal: "rgb(50, 172, 166)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  deepSea: "rgb(21, 49, 75)",
  gray: "rgb(119, 119, 119)",
  coralSoft: "rgb(253, 228, 219)",
}

const staggerBase = 0.3
const staggerStep = 0.05

function getDelay(index) {
  return staggerBase + index * staggerStep
}

function FadeUp({ index, children, style }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: getDelay(index), ease: "easeOut" }}
      style={style}
    >
      {children}
    </motion.div>
  )
}

export default function LoginPage() {
  const [email, setEmail] = useState("")

  return (
    <div
      style={{
        width: "100%",
        minHeight: "100vh",
        backgroundColor: colors.coralSoft,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "40px 24px",
        boxSizing: "border-box",
      }}
    >
      {/* Card */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.15 }}
        style={{
          width: 440,
          maxWidth: "100%",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          padding: "40px 36px",
          boxSizing: "border-box",
        }}
      >
        {/* Title */}
        <FadeUp index={0}>
          <h2
            style={{
              fontFamily,
              fontWeight: 900,
              fontSize: 32,
              lineHeight: "1.2em",
              letterSpacing: "-0.04em",
              textTransform: "uppercase",
              color: colors.deepSea,
              margin: 0,
              marginBottom: 6,
              textAlign: "center",
            }}
          >
            Welcome Back
          </h2>
        </FadeUp>

        <FadeUp index={1} style={{ marginBottom: 28 }}>
          <p
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 15,
              lineHeight: "1.5em",
              letterSpacing: "-0.04em",
              color: colors.gray,
              margin: 0,
              textAlign: "center",
            }}
          >
            Sign in to continue learning
          </p>
        </FadeUp>

        {/* OAuth */}
        <FadeUp index={2} style={{ display: "flex", gap: 12, marginBottom: 20 }}>
          <OAuthButton provider="google" label="Google" />
          <OAuthButton provider="apple" label="Apple" />
        </FadeUp>

        {/* Divider */}
        <FadeUp index={3} style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 20 }}>
          <div style={{ flex: 1, height: 1, backgroundColor: "rgba(0,0,0,0.12)" }} />
          <span
            style={{
              fontFamily,
              fontWeight: 600,
              fontSize: 12,
              letterSpacing: "0.08em",
              color: colors.gray,
              textTransform: "uppercase",
            }}
          >
            OR
          </span>
          <div style={{ flex: 1, height: 1, backgroundColor: "rgba(0,0,0,0.12)" }} />
        </FadeUp>

        {/* Email */}
        <FadeUp index={4}>
          <label
            style={{
              fontFamily,
              fontWeight: 600,
              fontSize: 13,
              letterSpacing: "-0.02em",
              color: colors.deepSea,
              marginBottom: 6,
              display: "block",
            }}
          >
            Email
          </label>
        </FadeUp>
        <FadeUp index={5} style={{ marginBottom: 22 }}>
          <InputField
            type="email"
            placeholder="Enter your email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            name="email"
          />
        </FadeUp>

        {/* CTA */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: getDelay(6), ease: "easeOut" }}
          style={{ marginBottom: 20 }}
        >
          <motion.button
            type="button"
            whileHover={{
              backgroundColor: "rgb(220, 90, 60)",
              boxShadow: "2px 2px 0px 0px rgb(0, 0, 0)",
            }}
            whileTap={{
              boxShadow: "0px 0px 0px 0px rgb(0, 0, 0)",
            }}
            transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
            style={{
              width: "100%",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: colors.coral,
              border: `2px solid ${colors.black}`,
              borderRadius: 0,
              padding: "14px 16px",
              boxShadow: `4px 4px 0px 0px ${colors.black}`,
              fontFamily,
              fontWeight: 600,
              fontSize: 16,
              lineHeight: "1.5em",
              letterSpacing: "-0.04em",
              color: colors.black,
              cursor: "pointer",
              boxSizing: "border-box",
              userSelect: "none",
            }}
          >
            Continue
          </motion.button>
        </motion.div>

        {/* Signup link */}
        <FadeUp index={7}>
          <p
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 14,
              lineHeight: "1.5em",
              letterSpacing: "-0.04em",
              color: colors.gray,
              textAlign: "center",
              margin: 0,
            }}
          >
            Don't have an account?{" "}
            <a
              href="/signup"
              style={{
                color: colors.teal,
                textDecoration: "none",
                cursor: "pointer",
                fontWeight: 700,
              }}
            >
              Sign up
            </a>
          </p>
        </FadeUp>
      </motion.div>
    </div>
  )
}
