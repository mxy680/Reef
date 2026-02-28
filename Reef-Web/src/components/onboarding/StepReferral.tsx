"use client"

import { motion } from "framer-motion"
import { colors } from "../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

const SOURCES = [
  { value: "social_media", label: "Social Media" },
  { value: "friend_family", label: "Friend or Family" },
  { value: "teacher_school", label: "Teacher or School" },
  { value: "google", label: "Google Search" },
  { value: "youtube", label: "YouTube" },
  { value: "other", label: "Other" },
]

export default function StepReferral({ value, onChange, onSubmit, onBack, submitting }: { value: string; onChange: (v: string) => void; onSubmit: () => void; onBack: () => void; submitting: boolean }) {
  const canSubmit = !!value && !submitting

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.25 }}
    >
      <h2
        style={{
          fontFamily,
          fontWeight: 900,
          fontSize: 28,
          lineHeight: "1.2em",
          letterSpacing: "-0.04em",
          textTransform: "uppercase",
          color: colors.black,
          margin: 0,
          marginBottom: 8,
        }}
      >
        How did you hear about us?
      </h2>
      <p
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 14,
          color: colors.gray600,
          letterSpacing: "-0.04em",
          margin: 0,
          marginBottom: 24,
        }}
      >
        This helps us understand how students find Reef.
      </p>

      <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 24 }}>
        {SOURCES.map((source) => {
          const selected = value === source.value
          return (
            <motion.button
              key={source.value}
              type="button"
              onClick={() => onChange(source.value)}
              whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}`, y: 2, x: 2 }}
              whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}`, y: 4, x: 4 }}
              transition={{ type: "spring", bounce: 0.2, duration: 0.3 }}
              style={{
                width: "100%",
                padding: "14px 18px",
                backgroundColor: selected ? colors.primary : colors.white,
                border: `2px solid ${colors.black}`,
                borderRadius: 12,
                boxShadow: selected
                  ? `3px 3px 0px 0px ${colors.black}`
                  : `4px 4px 0px 0px ${colors.black}`,
                fontFamily,
                fontWeight: 600,
                fontSize: 15,
                letterSpacing: "-0.04em",
                color: selected ? colors.white : colors.black,
                cursor: "pointer",
                textAlign: "left",
              }}
            >
              {source.label}
            </motion.button>
          )
        })}
      </div>

      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button
          type="button"
          onClick={onBack}
          disabled={submitting}
          style={{
            background: "none",
            border: "none",
            fontFamily,
            fontWeight: 600,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            cursor: submitting ? "not-allowed" : "pointer",
            padding: 0,
          }}
        >
          Back
        </button>

        <motion.button
          type="button"
          onClick={onSubmit}
          disabled={!canSubmit}
          whileHover={canSubmit ? { boxShadow: `2px 2px 0px 0px ${colors.black}`, y: 2, x: 2 } : {}}
          whileTap={canSubmit ? { boxShadow: `0px 0px 0px 0px ${colors.black}`, y: 4, x: 4 } : {}}
          transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
          style={{
            padding: "12px 32px",
            backgroundColor: canSubmit ? colors.primary : colors.surface,
            border: `2px solid ${colors.black}`,
            borderRadius: 12,
            boxShadow: `4px 4px 0px 0px ${colors.black}`,
            fontFamily,
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: canSubmit ? colors.white : colors.gray600,
            cursor: canSubmit ? "pointer" : "not-allowed",
          }}
        >
          {submitting ? "Saving..." : "Get Started"}
        </motion.button>
      </div>
    </motion.div>
  )
}
