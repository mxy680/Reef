"use client"

import { motion } from "framer-motion"
import { colors } from "../../lib/colors"
import { useDashboard } from "../../components/dashboard/DashboardContext"
import StatCard from "../../components/dashboard/StatCard"

const fontFamily = `"Epilogue", sans-serif`

export default function DashboardPage() {
  const { profile } = useDashboard()

  return (
    <div>
      <motion.h2
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
        style={{
          fontFamily,
          fontWeight: 900,
          fontSize: 28,
          lineHeight: "1.2em",
          letterSpacing: "-0.04em",
          color: colors.black,
          margin: 0,
          marginBottom: 8,
        }}
      >
        Welcome back, {profile.display_name}
      </motion.h2>

      {profile.subjects?.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.2 }}
          style={{
            display: "flex",
            flexWrap: "wrap",
            gap: 8,
            marginBottom: 32,
            marginTop: 12,
          }}
        >
          {profile.subjects.map((subject) => (
            <span
              key={subject}
              style={{
                padding: "6px 14px",
                backgroundColor: colors.accent,
                border: `2px solid ${colors.accent}`,
                borderRadius: 999,
                fontFamily,
                fontWeight: 600,
                fontSize: 13,
                letterSpacing: "-0.04em",
                color: colors.white,
              }}
            >
              {subject}
            </span>
          ))}
        </motion.div>
      )}

      <div style={{ display: "flex", gap: 16, flexWrap: "wrap" }}>
        <StatCard label="Sessions" value="0" delay={0.25} />
        <StatCard label="Documents" value="0" delay={0.3} />
        <StatCard label="Time Studied" value="0h" delay={0.35} />
      </div>
    </div>
  )
}
