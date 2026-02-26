"use client"

const colors = {
  blue: "rgb(95, 168, 211)",
  gray: "rgb(255, 229, 217)",
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
            backgroundColor: i <= step ? colors.blue : "transparent",
            border: `2px solid ${i <= step ? colors.blue : colors.gray}`,
            transition: "all 0.3s ease",
          }}
        />
      ))}
    </div>
  )
}
