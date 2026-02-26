"use client"

import { motion } from "framer-motion"

const fontFamily = `"Epilogue", sans-serif`

function GoogleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 48 48">
      <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
      <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
      <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
    </svg>
  )
}

function AppleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 814 1000">
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57.8-155.5-127.4c-58.3-81.2-105.3-207.6-105.3-328.3 0-193 125.3-295.3 248.3-295.3 65.5 0 120.1 43.1 161.2 43.1 39.2 0 100.4-45.8 174.7-45.8 28.2 0 129.6 2.6 196.6 99.8zM554.1 159.4c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.8 32.4-54.1 83.6-54.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 134.5-71.3z" />
    </svg>
  )
}

const icons = { google: GoogleIcon, apple: AppleIcon }

export default function OAuthButton({ provider, label, delay = 0 }) {
  const Icon = icons[provider]

  return (
    <motion.button
      type="button"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay, ease: "easeOut" }}
      whileHover={{ y: -2, boxShadow: "3px 3px 0px 0px rgb(0, 0, 0)" }}
      whileTap={{ y: 2, boxShadow: "0px 0px 0px 0px rgb(0, 0, 0)" }}
      style={{
        flex: 1,
        height: 48,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 10,
        backgroundColor: "rgb(255, 255, 255)",
        border: "2px solid rgb(0, 0, 0)",
        borderRadius: 0,
        boxShadow: "2px 2px 0px 0px rgb(0, 0, 0)",
        cursor: "pointer",
        fontFamily,
        fontWeight: 500,
        fontSize: 16,
        letterSpacing: "-0.04em",
        color: "rgb(21, 49, 75)",
      }}
    >
      <Icon />
      {label}
    </motion.button>
  )
}
