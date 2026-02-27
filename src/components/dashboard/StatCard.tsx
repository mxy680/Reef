"use client"

import { motion } from "framer-motion"
import { colors } from "../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

export default function StatCard({
  label,
  value,
  delay = 0,
}: {
  label: string
  value: string
  delay?: number
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay }}
      style={{
        flex: 1,
        minWidth: 180,
        backgroundColor: colors.white,
        border: `2px solid ${colors.black}`,
        boxShadow: `4px 4px 0px 0px ${colors.black}`,
        padding: "24px 20px",
      }}
    >
      <div
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 13,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          marginBottom: 8,
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 28,
          letterSpacing: "-0.04em",
          color: colors.black,
        }}
      >
        {value}
      </div>
    </motion.div>
  )
}
