"use client"

import { createContext, useContext, useState, useCallback, useEffect } from "react"

export interface DashboardProfile {
  display_name: string
  email: string
  grade: string
  subjects: string[]
  onboarding_completed: boolean
}

export interface DashboardContextValue {
  profile: DashboardProfile
  userId: string
  sidebarOpen: boolean
  toggleSidebar: () => void
  commandPaletteOpen: boolean
  openCommandPalette: () => void
  closeCommandPalette: () => void
}

const DashboardContext = createContext<DashboardContextValue | null>(null)

export function DashboardProvider({
  children,
  value,
}: {
  children: React.ReactNode
  value: Omit<DashboardContextValue, "sidebarOpen" | "toggleSidebar" | "commandPaletteOpen" | "openCommandPalette" | "closeCommandPalette">
}) {
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const toggleSidebar = useCallback(() => setSidebarOpen((o) => !o), [])
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false)
  const openCommandPalette = useCallback(() => setCommandPaletteOpen(true), [])
  const closeCommandPalette = useCallback(() => setCommandPaletteOpen(false), [])

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault()
        setCommandPaletteOpen((o) => !o)
      }
    }
    document.addEventListener("keydown", onKeyDown)
    return () => document.removeEventListener("keydown", onKeyDown)
  }, [])

  return (
    <DashboardContext.Provider value={{ ...value, sidebarOpen, toggleSidebar, commandPaletteOpen, openCommandPalette, closeCommandPalette }}>
      {children}
    </DashboardContext.Provider>
  )
}

export function useDashboard() {
  const ctx = useContext(DashboardContext)
  if (!ctx) throw new Error("useDashboard must be used within DashboardProvider")
  return ctx
}
