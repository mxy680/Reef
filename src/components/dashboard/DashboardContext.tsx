"use client"

import { createContext, useContext } from "react"

export interface DashboardProfile {
  display_name: string
  grade: string
  subjects: string[]
  onboarding_completed: boolean
}

export interface DashboardContextValue {
  profile: DashboardProfile
  userId: string
}

const DashboardContext = createContext<DashboardContextValue | null>(null)

export function DashboardProvider({
  children,
  value,
}: {
  children: React.ReactNode
  value: DashboardContextValue
}) {
  return (
    <DashboardContext.Provider value={value}>
      {children}
    </DashboardContext.Provider>
  )
}

export function useDashboard() {
  const ctx = useContext(DashboardContext)
  if (!ctx) throw new Error("useDashboard must be used within DashboardProvider")
  return ctx
}
