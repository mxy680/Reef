"use client"

import { motion } from "framer-motion"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  coral: "rgb(235, 140, 115)",
  teal: "rgb(50, 172, 166)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  deepSea: "rgb(21, 49, 75)",
  gray: "rgb(119, 119, 119)",
}

const SUBJECTS = [
  "Algebra",
  "Geometry",
  "Precalculus",
  "Calculus",
  "Statistics",
  "Linear Algebra",
  "Physics",
  "Chemistry",
  "Biology",
  "Computer Science",
  "Economics",
  "Engineering",
]

export default function StepSubjects({ value, onChange, onSubmit, onBack, submitting }) {
  function toggle(subject) {
    if (value.includes(subject)) {
      onChange(value.filter((s) => s !== subject))
    } else {
      onChange([...value, subject])
    }
  }

  const canSubmit = value.length >= 1 && !submitting

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
          color: colors.deepSea,
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
          color: colors.gray,
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
                backgroundColor: selected ? colors.teal : colors.white,
                border: `2px solid ${selected ? colors.teal : colors.black}`,
                borderRadius: 999,
                fontFamily,
                fontWeight: 600,
                fontSize: 13,
                letterSpacing: "-0.04em",
                color: selected ? colors.white : colors.deepSea,
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
          disabled={submitting}
          style={{
            background: "none",
            border: "none",
            fontFamily,
            fontWeight: 600,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.gray,
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
          whileHover={canSubmit ? { boxShadow: `2px 2px 0px 0px ${colors.black}` } : {}}
          whileTap={canSubmit ? { boxShadow: `0px 0px 0px 0px ${colors.black}` } : {}}
          transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
          style={{
            padding: "12px 32px",
            backgroundColor: canSubmit ? colors.coral : "rgb(230, 230, 230)",
            border: `2px solid ${colors.black}`,
            borderRadius: 0,
            boxShadow: `4px 4px 0px 0px ${colors.black}`,
            fontFamily,
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: canSubmit ? colors.white : colors.gray,
            cursor: canSubmit ? "pointer" : "not-allowed",
          }}
        >
          {submitting ? "Saving..." : "Get Started"}
        </motion.button>
      </div>
    </motion.div>
  )
}
