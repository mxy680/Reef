"use client"

import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"
import { useDashboard } from "../../../components/dashboard/DashboardContext"

const fontFamily = `"Epilogue", sans-serif`

const GRADE_LABELS: Record<string, string> = {
  middle_school: "Middle School",
  high_school: "High School",
  college: "College",
  graduate: "Graduate",
  other: "Other",
}

export default function SettingsPage() {
  const { profile } = useDashboard()

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.1 }}
      style={{
        backgroundColor: colors.white,
        border: `2px solid ${colors.black}`,
        boxShadow: `4px 4px 0px 0px ${colors.black}`,
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
          marginBottom: 24,
        }}
      >
        Settings
      </h2>

      <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
        <div>
          <div
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 13,
              letterSpacing: "-0.04em",
              color: colors.gray600,
              marginBottom: 4,
            }}
          >
            Name
          </div>
          <div
            style={{
              fontFamily,
              fontWeight: 700,
              fontSize: 16,
              letterSpacing: "-0.04em",
              color: colors.black,
            }}
          >
            {profile.display_name}
          </div>
        </div>

        <div>
          <div
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 13,
              letterSpacing: "-0.04em",
              color: colors.gray600,
              marginBottom: 4,
            }}
          >
            Grade
          </div>
          <div
            style={{
              fontFamily,
              fontWeight: 700,
              fontSize: 16,
              letterSpacing: "-0.04em",
              color: colors.black,
            }}
          >
            {GRADE_LABELS[profile.grade] || profile.grade}
          </div>
        </div>

        {profile.subjects?.length > 0 && (
          <div>
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
              Subjects
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
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
            </div>
          </div>
        )}
      </div>
    </motion.div>
  )
}
