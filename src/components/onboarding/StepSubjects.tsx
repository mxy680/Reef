"use client"

import { motion } from "framer-motion"
import { colors } from "../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

const SUBJECTS = [
  "Algebra",
  "Geometry",
  "Precalculus",
  "Calculus",
  "Statistics",
  "Linear Algebra",
  "Trigonometry",
  "Differential Equations",
  "Physics",
  "Chemistry",
  "Biology",
  "Computer Science",
  "Economics",
  "Engineering",
  "Accounting",
]

export default function StepSubjects({ value, onChange, onNext, onBack }: { value: string[]; onChange: (v: string[]) => void; onNext: () => void; onBack: () => void }) {
  function toggle(subject: string) {
    if (value.includes(subject)) {
      onChange(value.filter((s) => s !== subject))
    } else {
      onChange([...value, subject])
    }
  }

  const canContinue = value.length >= 1

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
        What subjects do you need help with?
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
        Select at least one. You can always change these later.
      </p>

      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: 8,
          marginBottom: 28,
        }}
      >
        {SUBJECTS.map((subject) => {
          const selected = value.includes(subject)
          return (
            <motion.button
              key={subject}
              type="button"
              onClick={() => toggle(subject)}
              whileHover={{ scale: 1.04 }}
              whileTap={{ scale: 0.96 }}
              transition={{ type: "spring", bounce: 0.3, duration: 0.3 }}
              style={{
                padding: "8px 16px",
                backgroundColor: selected ? colors.primary : colors.white,
                border: `2px solid ${selected ? colors.primary : colors.black}`,
                borderRadius: 999,
                fontFamily,
                fontWeight: 600,
                fontSize: 13,
                letterSpacing: "-0.04em",
                color: selected ? colors.white : colors.black,
                cursor: "pointer",
              }}
            >
              {subject}
            </motion.button>
          )
        })}
      </div>

      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button
          type="button"
          onClick={onBack}
          style={{
            background: "none",
            border: "none",
            fontFamily,
            fontWeight: 600,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            cursor: "pointer",
            padding: 0,
          }}
        >
          Back
        </button>

        <motion.button
          type="button"
          onClick={onNext}
          disabled={!canContinue}
          whileHover={canContinue ? { boxShadow: `2px 2px 0px 0px ${colors.black}`, y: 2, x: 2 } : {}}
          whileTap={canContinue ? { boxShadow: `0px 0px 0px 0px ${colors.black}`, y: 4, x: 4 } : {}}
          transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
          style={{
            padding: "12px 32px",
            backgroundColor: canContinue ? colors.primary : colors.surface,
            border: `2px solid ${colors.black}`,
            borderRadius: 12,
            boxShadow: `4px 4px 0px 0px ${colors.black}`,
            fontFamily,
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: canContinue ? colors.white : colors.gray600,
            cursor: canContinue ? "pointer" : "not-allowed",
          }}
        >
          Continue
        </motion.button>
      </div>
    </motion.div>
  )
}
