"use client"

import { useEffect } from "react"

export default function SuppressRefWarning() {
  useEffect(() => {
    if (process.env.NODE_ENV !== "development") return

    const orig = console.error
    console.error = (...args: unknown[]) => {
      if (typeof args[0] === "string" && args[0].includes("Accessing element.ref was removed")) return
      orig.apply(console, args)
    }
    return () => { console.error = orig }
  }, [])

  return null
}
