"use client"

import { motion } from "framer-motion"
import InputField from "../signup/InputField"
import { colors } from "../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

export default function StepName({ value, onChange, onNext }: { value: string; onChange: (v: string) => void; onNext: () => void }) {
  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter" && value.trim()) onNext()
  }

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
          color: colors.accent,
          margin: 0,
          marginBottom: 8,
        }}
      >
        What's your name?
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
        We'll use this to personalize your experience.
      </p>

      <div onKeyDown={handleKeyDown} style={{ marginBottom: 24 }}>
        <InputField
          placeholder="Your name"
          value={value}
          onChange={(e) => onChange(e.target.value)}
        />
      </div>

      <motion.button
        type="button"
        onClick={onNext}
        disabled={!value.trim()}
        whileHover={value.trim() ? { boxShadow: `2px 2px 0px 0px ${colors.black}` } : {}}
        whileTap={value.trim() ? { boxShadow: `0px 0px 0px 0px ${colors.black}` } : {}}
        transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
        style={{
          width: "100%",
          height: 48,
          backgroundColor: value.trim() ? colors.primary : colors.surface,
          border: `2px solid ${colors.black}`,
          borderRadius: 0,
          boxShadow: `4px 4px 0px 0px ${colors.black}`,
          fontFamily,
          fontWeight: 700,
          fontSize: 15,
          letterSpacing: "-0.04em",
          textTransform: "uppercase",
          color: value.trim() ? colors.white : colors.gray600,
          cursor: value.trim() ? "pointer" : "not-allowed",
        }}
      >
        Continue
      </motion.button>
    </motion.div>
  )
}
