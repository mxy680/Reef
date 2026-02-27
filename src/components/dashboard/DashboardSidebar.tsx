"use client"

import { useRouter } from "next/navigation"
import { motion } from "framer-motion"
import { createClient } from "../../lib/supabase/client"
import { colors } from "../../lib/colors"
import NavItem from "./NavItem"

const fontFamily = `"Epilogue", sans-serif`

function OverviewIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="2" width="7" height="7" rx="1" />
      <rect x="11" y="2" width="7" height="7" rx="1" />
      <rect x="2" y="11" width="7" height="7" rx="1" />
      <rect x="11" y="11" width="7" height="7" rx="1" />
    </svg>
  )
}

function SessionsIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="10" cy="10" r="8" />
      <polyline points="10,5 10,10 14,12" />
    </svg>
  )
}

function DocumentsIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 2 H12 L16 6 V18 H4 Z" />
      <polyline points="12,2 12,6 16,6" />
      <line x1="6" y1="10" x2="14" y2="10" />
      <line x1="6" y1="13" x2="14" y2="13" />
    </svg>
  )
}

function SettingsIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="10" cy="10" r="3" />
      <path d="M10 1 L10 4 M10 16 L10 19 M1 10 L4 10 M16 10 L19 10 M3.5 3.5 L5.6 5.6 M14.4 14.4 L16.5 16.5 M16.5 3.5 L14.4 5.6 M5.6 14.4 L3.5 16.5" />
    </svg>
  )
}

const NAV_ITEMS = [
  { href: "/dashboard", label: "Overview", icon: <OverviewIcon /> },
  { href: "/dashboard/sessions", label: "Sessions", icon: <SessionsIcon /> },
  { href: "/dashboard/documents", label: "Documents", icon: <DocumentsIcon /> },
  { href: "/dashboard/settings", label: "Settings", icon: <SettingsIcon /> },
]

export default function DashboardSidebar() {
  const router = useRouter()

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    document.cookie = "reef_onboarded=; path=/; max-age=0"
    router.push("/auth")
  }

  return (
    <aside
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        width: 260,
        height: "100vh",
        backgroundColor: colors.white,
        borderRight: `1px solid ${colors.gray100}`,
        display: "flex",
        flexDirection: "column",
        zIndex: 50,
      }}
    >
      {/* Logo */}
      <div
        style={{
          padding: "24px 20px",
        }}
      >
        <span
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 24,
            letterSpacing: "-0.04em",
            textTransform: "uppercase",
            color: colors.black,
          }}
        >
          Reef
        </span>
      </div>

      {/* Nav */}
      <nav style={{ flex: 1, padding: "0 12px", display: "flex", flexDirection: "column", gap: 2 }}>
        {NAV_ITEMS.map((item) => (
          <NavItem key={item.href} {...item} />
        ))}
      </nav>

      {/* Sign out */}
      <div style={{ padding: "16px 12px" }}>
        <motion.button
          type="button"
          onClick={handleSignOut}
          whileHover={{ backgroundColor: colors.gray100 }}
          whileTap={{ scale: 0.98 }}
          transition={{ type: "spring", bounce: 0.2, duration: 0.3 }}
          style={{
            width: "100%",
            backgroundColor: "transparent",
            border: "none",
            borderRadius: 8,
            padding: "10px 16px",
            fontFamily,
            fontWeight: 600,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            cursor: "pointer",
          }}
        >
          Sign Out
        </motion.button>
      </div>
    </aside>
  )
}
