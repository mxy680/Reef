"use client"

import { createContext, useContext, useState, useCallback } from "react"

export interface DashboardProfile {
  display_name: string
  grade: string
  subjects: string[]
  onboarding_completed: boolean
}

export interface DashboardContextValue {
  profile: DashboardProfile
  userId: string
  sidebarOpen: boolean
  toggleSidebar: () => void
}

const DashboardContext = createContext<DashboardContextValue | null>(null)

export function DashboardProvider({
  children,
  value,
}: {
  children: React.ReactNode
  value: Omit<DashboardContextValue, "sidebarOpen" | "toggleSidebar">
}) {
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const toggleSidebar = useCallback(() => setSidebarOpen((o) => !o), [])

  return (
    <DashboardContext.Provider value={{ ...value, sidebarOpen, toggleSidebar }}>
      {children}
    </DashboardContext.Provider>
  )
}

export function useDashboard() {
  const ctx = useContext(DashboardContext)
  if (!ctx) throw new Error("useDashboard must be used within DashboardProvider")
  return ctx
}
