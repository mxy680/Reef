"use client"

import { usePathname } from "next/navigation"
import { colors } from "../../lib/colors"
import { useDashboard } from "./DashboardContext"

const fontFamily = `"Epilogue", sans-serif`

const GRADE_LABELS: Record<string, string> = {
  middle_school: "Middle School",
  high_school: "High School",
  college: "College",
  graduate: "Graduate",
  other: "Other",
}

const PAGE_TITLES: Record<string, string> = {
  "/dashboard": "Documents",
  "/dashboard/documents": "Documents",
  "/dashboard/analytics": "Analytics",
  "/dashboard/courses": "Courses",
  "/dashboard/settings": "Settings",
  "/dashboard/billing": "Billing",
  "/dashboard/reef": "My Reef",
}

export default function DashboardHeader() {
  const pathname = usePathname()
  const { profile } = useDashboard()
  const title = PAGE_TITLES[pathname] || "Dashboard"

  return (
    <header
      style={{
        height: 64,
        backgroundColor: colors.white,
        borderBottom: `2px solid ${colors.black}`,
        boxShadow: `0px 4px 0px 0px ${colors.black}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "0 32px",
        position: "relative",
        zIndex: 1,
      }}
    >
      <h1
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 20,
          letterSpacing: "-0.04em",
          color: colors.black,
          margin: 0,
        }}
      >
        {title}
      </h1>

      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <span
          style={{
            fontFamily,
            fontWeight: 600,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.black,
          }}
        >
          {profile.display_name}
        </span>
        <span
          style={{
            padding: "4px 10px",
            backgroundColor: colors.gray100,
            borderRadius: 999,
            fontFamily,
            fontWeight: 600,
            fontSize: 12,
            letterSpacing: "-0.04em",
            color: colors.gray600,
          }}
        >
          {GRADE_LABELS[profile.grade] || profile.grade}
        </span>
      </div>
    </header>
  )
}
