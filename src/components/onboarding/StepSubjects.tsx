"use client"

import { motion } from "framer-motion"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  blue: "rgb(95, 168, 211)",
  black: "rgb(0, 0, 0)",
  white: "rgb(255, 255, 255)",
  steel: "rgb(27, 73, 101)",
  gray: "rgb(119, 119, 119)",
}

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
          color: colors.steel,
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
                backgroundColor: selected ? colors.blue : colors.white,
                border: `2px solid ${selected ? colors.blue : colors.black}`,
                borderRadius: 999,
                fontFamily,
                fontWeight: 600,
                fontSize: 13,
                letterSpacing: "-0.04em",
                color: selected ? colors.white : colors.steel,
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
            color: colors.gray,
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
          whileHover={canContinue ? { boxShadow: `2px 2px 0px 0px ${colors.black}` } : {}}
          whileTap={canContinue ? { boxShadow: `0px 0px 0px 0px ${colors.black}` } : {}}
          transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
          style={{
            padding: "12px 32px",
            backgroundColor: canContinue ? colors.blue : "rgb(255, 229, 217)",
            border: `2px solid ${colors.black}`,
            borderRadius: 0,
            boxShadow: `4px 4px 0px 0px ${colors.black}`,
            fontFamily,
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: canContinue ? colors.white : colors.gray,
            cursor: canContinue ? "pointer" : "not-allowed",
          }}
        >
          Continue
        </motion.button>
      </div>
    </motion.div>
  )
}
