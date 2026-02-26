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

const GRADES = [
  { value: "middle_school", label: "Middle School" },
  { value: "high_school", label: "High School" },
  { value: "college", label: "College" },
  { value: "graduate", label: "Graduate" },
  { value: "other", label: "Other" },
]

export default function StepGrade({ value, onChange, onNext, onBack }) {
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
        What grade are you in?
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
        This helps us tailor content to your level.
      </p>

      <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 24 }}>
        {GRADES.map((grade) => {
          const selected = value === grade.value
          return (
            <motion.button
              key={grade.value}
              type="button"
              onClick={() => onChange(grade.value)}
              whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}` }}
              whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}` }}
              transition={{ type: "spring", bounce: 0.2, duration: 0.3 }}
              style={{
                width: "100%",
                padding: "14px 18px",
                backgroundColor: selected ? colors.blue : colors.white,
                border: `2px solid ${colors.black}`,
                borderRadius: 0,
                boxShadow: selected
                  ? `3px 3px 0px 0px ${colors.black}`
                  : `4px 4px 0px 0px ${colors.black}`,
                fontFamily,
                fontWeight: 600,
                fontSize: 15,
                letterSpacing: "-0.04em",
                color: selected ? colors.white : colors.steel,
                cursor: "pointer",
                textAlign: "left",
              }}
            >
              {grade.label}
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
          disabled={!value}
          whileHover={value ? { boxShadow: `2px 2px 0px 0px ${colors.black}` } : {}}
          whileTap={value ? { boxShadow: `0px 0px 0px 0px ${colors.black}` } : {}}
          transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
          style={{
            padding: "12px 32px",
            backgroundColor: value ? colors.blue : "rgb(255, 229, 217)",
            border: `2px solid ${colors.black}`,
            borderRadius: 0,
            boxShadow: `4px 4px 0px 0px ${colors.black}`,
            fontFamily,
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: value ? colors.white : colors.gray,
            cursor: value ? "pointer" : "not-allowed",
          }}
        >
          Continue
        </motion.button>
      </div>
    </motion.div>
  )
}
