"use client"

import { colors } from "../../lib/colors"

export default function ProgressBar({ step, total = 3 }: { step: number; total?: number }) {
  return (
    <div style={{ display: "flex", gap: 8, justifyContent: "center", marginBottom: 32 }}>
      {Array.from({ length: total }, (_, i) => (
        <div
          key={i}
          style={{
            width: 10,
            height: 10,
            borderRadius: "50%",
            backgroundColor: i <= step ? colors.primary : colors.white,
            border: `2px solid ${colors.black}`,
            transition: "all 0.3s ease",
          }}
        />
      ))}
    </div>
  )
}
