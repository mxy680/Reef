"use client"

import { useState } from "react"
import { motion } from "framer-motion"
import InputField from "./InputField"
import OAuthButton from "./OAuthButton"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  teal: "rgb(50, 172, 166)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  deepSea: "rgb(21, 49, 75)",
  gray: "rgb(119, 119, 119)",
  tealSoft: "rgb(214, 243, 241)",
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

export default function SignupPage() {
  const [name, setName] = useState("")
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")

  return (
    <div
      style={{
        width: "100%",
        minHeight: "100vh",
        backgroundColor: colors.tealSoft,
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
            Get Started
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
            Create your free account
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

        {/* Name */}
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
            Name
          </label>
        </FadeUp>
        <FadeUp index={5} style={{ marginBottom: 14 }}>
          <InputField
            type="text"
            placeholder="Your full name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            name="name"
          />
        </FadeUp>

        {/* Email */}
        <FadeUp index={6}>
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
        <FadeUp index={7} style={{ marginBottom: 14 }}>
          <InputField
            type="email"
            placeholder="Enter your email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            name="email"
          />
        </FadeUp>

        {/* Password */}
        <FadeUp index={8}>
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
            Password
          </label>
        </FadeUp>
        <FadeUp index={9} style={{ marginBottom: 22 }}>
          <InputField
            type="password"
            placeholder="Create a password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            name="password"
          />
        </FadeUp>

        {/* CTA */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: getDelay(10), ease: "easeOut" }}
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
            Create Account
          </motion.button>
        </motion.div>

        {/* Login link */}
        <FadeUp index={11}>
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
            Already have an account?{" "}
            <a
              href="/auth"
              style={{
                color: colors.teal,
                textDecoration: "none",
                cursor: "pointer",
                fontWeight: 700,
              }}
            >
              Log in
            </a>
          </p>
        </FadeUp>
      </motion.div>

      {/* Value props below card */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4, delay: 0.8 }}
        style={{
          display: "flex",
          gap: 24,
          marginTop: 28,
          flexWrap: "wrap",
          justifyContent: "center",
        }}
      >
        {["Free during beta", "Works with any subject", "No credit card required"].map((text, i) => (
          <div
            key={i}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
            }}
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={colors.teal} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="20 6 9 17 4 12" />
            </svg>
            <span
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 13,
                letterSpacing: "-0.02em",
                color: colors.deepSea,
                opacity: 0.7,
              }}
            >
              {text}
            </span>
          </div>
        ))}
      </motion.div>
    </div>
  )
}
