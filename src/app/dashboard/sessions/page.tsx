"use client"

import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

export default function SessionsPage() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.1 }}
      style={{
        backgroundColor: colors.white,
        border: `1px solid ${colors.gray100}`,
        borderRadius: 12,
        boxShadow: "0 1px 3px rgba(0,0,0,0.04)",
        padding: "48px 36px",
        maxWidth: 500,
      }}
    >
      <h2
        style={{
          fontFamily,
          fontWeight: 900,
          fontSize: 24,
          letterSpacing: "-0.04em",
          color: colors.black,
          margin: 0,
          marginBottom: 12,
        }}
      >
        Sessions
      </h2>
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
        Your study sessions will appear here. Coming soon.
      </p>
    </motion.div>
  )
}
