"use client"

import { useState } from "react"

const fontFamily = `"Epilogue", sans-serif`

const colors = {
  black: "rgb(0, 0, 0)",
  deepSea: "rgb(21, 49, 75)",
}

export default function InputField({ type = "text", placeholder, value, onChange, name }) {
  const [showPassword, setShowPassword] = useState(false)
  const isPassword = type === "password"

  return (
    <div
      style={{
        width: "100%",
        height: 48,
        border: `2px solid ${colors.black}`,
        borderRadius: 999,
        boxShadow: `2px 2px 0px 0px ${colors.black}`,
        display: "flex",
        alignItems: "center",
        padding: "0 18px",
        boxSizing: "border-box",
        backgroundColor: "rgb(255, 255, 255)",
      }}
    >
      <input
        type={isPassword && showPassword ? "text" : type}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        name={name}
        style={{
          width: "100%",
          height: "100%",
          border: "none",
          background: "transparent",
          outline: "none",
          fontFamily,
          fontWeight: 500,
          fontSize: 16,
          lineHeight: "1.2",
          letterSpacing: "-0.04em",
          color: colors.deepSea,
          padding: 0,
          margin: 0,
        }}
      />
      {isPassword && (
        <button
          type="button"
          onClick={() => setShowPassword(!showPassword)}
          tabIndex={-1}
          style={{
            background: "none",
            border: "none",
            cursor: "pointer",
            padding: 4,
            display: "flex",
            alignItems: "center",
            color: "rgb(119, 119, 119)",
            flexShrink: 0,
          }}
          aria-label={showPassword ? "Hide password" : "Show password"}
        >
          {showPassword ? (
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" />
              <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" />
              <line x1="1" y1="1" x2="23" y2="23" />
            </svg>
          ) : (
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
              <circle cx="12" cy="12" r="3" />
            </svg>
          )}
        </button>
      )}
    </div>
  )
}
