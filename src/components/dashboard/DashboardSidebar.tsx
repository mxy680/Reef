"use client"

import Link from "next/link"
import { motion } from "framer-motion"
import { colors } from "../../lib/colors"
import { useDashboard } from "./DashboardContext"
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

function UpgradeIcon() {
  return (
    <div
      style={{
        width: 32,
        height: 32,
        borderRadius: 999,
        backgroundColor: colors.accent,
        border: `2px solid ${colors.black}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
      }}
    >
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke={colors.black} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
        <line x1="8" y1="12" x2="8" y2="4" />
        <polyline points="4,7 8,3 12,7" />
      </svg>
    </div>
  )
}

function UserAvatar({ name }: { name: string }) {
  const initials = name
    .split(" ")
    .map((w) => w[0])
    .join("")
    .toUpperCase()
    .slice(0, 2)

  return (
    <div
      style={{
        width: 32,
        height: 32,
        borderRadius: 999,
        backgroundColor: colors.surface,
        border: `2px solid ${colors.black}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
      }}
    >
      <span
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 12,
          letterSpacing: "-0.02em",
          color: colors.black,
        }}
      >
        {initials}
      </span>
    </div>
  )
}

function ChevronRight() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke={colors.gray400} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="6,3 11,8 6,13" />
    </svg>
  )
}

function SettingsGearIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={colors.gray400} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  )
}

const footerRowStyle: React.CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: 10,
  padding: "8px 6px",
  textDecoration: "none",
  cursor: "pointer",
  borderRadius: 8,
  transition: "background-color 0.12s",
}

export default function DashboardSidebar() {
  const { profile } = useDashboard()

  return (
    <aside
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        width: 260,
        height: "100vh",
        backgroundColor: colors.white,
        borderRight: `2px solid ${colors.black}`,
        display: "flex",
        flexDirection: "column",
        zIndex: 50,
      }}
    >
      {/* Logo */}
      <div
        style={{
          padding: "24px 20px 20px",
          display: "flex",
          alignItems: "center",
          gap: 10,
        }}
      >
        <img
          src="/reef-logo.png"
          alt="Reef logo"
          style={{ width: 28, height: 28 }}
        />
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
      <nav style={{ flex: 1, padding: "0 14px", display: "flex", flexDirection: "column", gap: 6 }}>
        {NAV_ITEMS.map((item) => (
          <NavItem key={item.href} {...item} />
        ))}
      </nav>

      {/* Footer */}
      <div style={{ padding: "0 14px 16px", display: "flex", flexDirection: "column", gap: 2 }}>
        {/* Upgrade */}
        <motion.div
          style={footerRowStyle}
          whileHover={{ backgroundColor: colors.gray100 }}
        >
          <UpgradeIcon />
          <span
            style={{
              flex: 1,
              fontFamily,
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: "-0.04em",
              color: colors.black,
            }}
          >
            Upgrade
          </span>
          <span
            style={{
              padding: "3px 8px",
              backgroundColor: colors.surface,
              border: `2px solid ${colors.black}`,
              borderRadius: 6,
              fontFamily,
              fontWeight: 800,
              fontSize: 10,
              letterSpacing: "0.02em",
              color: colors.black,
              textTransform: "uppercase",
            }}
          >
            Free Beta
          </span>
        </motion.div>

        {/* Other */}
        <motion.div
          style={footerRowStyle}
          whileHover={{ backgroundColor: colors.gray100 }}
        >
          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: 999,
              backgroundColor: colors.gray100,
              border: `2px solid ${colors.black}`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
            }}
          >
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke={colors.black} strokeWidth="2.5" strokeLinecap="round">
              <circle cx="3" cy="8" r="0.5" fill={colors.black} />
              <circle cx="8" cy="8" r="0.5" fill={colors.black} />
              <circle cx="13" cy="8" r="0.5" fill={colors.black} />
            </svg>
          </div>
          <span
            style={{
              flex: 1,
              fontFamily,
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: "-0.04em",
              color: colors.black,
            }}
          >
            Other
          </span>
          <ChevronRight />
        </motion.div>

        {/* User */}
        <Link
          href="/dashboard/settings"
          style={{ textDecoration: "none" }}
        >
          <motion.div
            style={footerRowStyle}
            whileHover={{ backgroundColor: colors.gray100 }}
          >
            <UserAvatar name={profile.display_name} />
            <span
              style={{
                flex: 1,
                fontFamily,
                fontWeight: 700,
                fontSize: 14,
                letterSpacing: "-0.04em",
                color: colors.black,
                overflow: "hidden",
                textOverflow: "ellipsis",
                whiteSpace: "nowrap",
              }}
            >
              {profile.display_name}
            </span>
            <SettingsGearIcon />
          </motion.div>
        </Link>
      </div>
    </aside>
  )
}
