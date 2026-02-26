"use client"

const colors = {
  teal: "rgb(50, 172, 166)",
  slateBlue: "rgb(165, 185, 220)",
  gray: "rgb(200, 200, 200)",
}

export default function ProgressBar({ step, total = 3 }) {
  return (
    <div style={{ display: "flex", gap: 8, justifyContent: "center", marginBottom: 32 }}>
      {Array.from({ length: total }, (_, i) => (
        <div
          key={i}
          style={{
            width: 10,
            height: 10,
            borderRadius: "50%",
            backgroundColor: i <= step ? colors.teal : "transparent",
            border: `2px solid ${i <= step ? colors.teal : colors.gray}`,
            transition: "all 0.3s ease",
          }}
        />
      ))}
    </div>
  )
}
