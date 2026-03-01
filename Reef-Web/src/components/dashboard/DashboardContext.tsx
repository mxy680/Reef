"use client"

import { createContext, useContext, useState, useCallback, useEffect } from "react"
import { useIsMobile } from "../../lib/useIsMobile"

export interface DashboardProfile {
  display_name: string
  email: string
  grade: string
  subjects: string[]
  onboarding_completed: boolean
}

export interface DashboardContextValue {
  profile: DashboardProfile
  setProfile: (p: DashboardProfile) => void
  userId: string
  isMobile: boolean
  sidebarOpen: boolean
  toggleSidebar: () => void
  closeSidebar: () => void
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
  value: Omit<DashboardContextValue, "isMobile" | "sidebarOpen" | "toggleSidebar" | "closeSidebar" | "commandPaletteOpen" | "openCommandPalette" | "closeCommandPalette">
}) {
  const isMobile = useIsMobile()
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const toggleSidebar = useCallback(() => setSidebarOpen((o) => !o), [])
  const closeSidebar = useCallback(() => setSidebarOpen(false), [])
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false)
  const openCommandPalette = useCallback(() => setCommandPaletteOpen(true), [])
  const closeCommandPalette = useCallback(() => setCommandPaletteOpen(false), [])

  // Auto-close sidebar when switching to mobile
  useEffect(() => {
    if (isMobile) setSidebarOpen(false)
  }, [isMobile])

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
    <DashboardContext.Provider value={{ ...value, isMobile, sidebarOpen, toggleSidebar, closeSidebar, commandPaletteOpen, openCommandPalette, closeCommandPalette }}>
      {children}
    </DashboardContext.Provider>
  )
}

export function useDashboard() {
  const ctx = useContext(DashboardContext)
  if (!ctx) throw new Error("useDashboard must be used within DashboardProvider")
  return ctx
}
