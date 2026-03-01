"use client"

import Link from "next/link"
import { motion } from "framer-motion"
import { colors } from "../../lib/colors"
import { useDashboard } from "./DashboardContext"
import NavItem from "./NavItem"

const fontFamily = `"Epilogue", sans-serif`

export const SIDEBAR_WIDTH_OPEN = 260
export const SIDEBAR_WIDTH_COLLAPSED = 68

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

function AnalyticsIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="4" y1="16" x2="4" y2="10" />
      <line x1="8" y1="16" x2="8" y2="6" />
      <line x1="12" y1="16" x2="12" y2="12" />
      <line x1="16" y1="16" x2="16" y2="4" />
    </svg>
  )
}

function CoursesIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M2 4 L10 8 L18 4 L10 0 Z" />
      <path d="M2 4 V12 L10 16 L18 12 V4" />
      <line x1="10" y1="8" x2="10" y2="16" />
    </svg>
  )
}

function AdminIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10 1 L18 5 V10 C18 14.4 14.5 18 10 19 C5.5 18 2 14.4 2 10 V5 Z" />
      <polyline points="7,10 9.5,12.5 13.5,7.5" />
    </svg>
  )
}

function SettingsIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  )
}

function BillingIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="1" y="4" width="18" height="13" rx="2" />
      <line x1="1" y1="9" x2="19" y2="9" />
    </svg>
  )
}

function ReefIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10 18 C10 18 2 14 2 8 C2 5 4 3 6 3 C8 3 10 5 10 5 C10 5 12 3 14 3 C16 3 18 5 18 8 C18 14 10 18 10 18 Z" />
    </svg>
  )
}

function LibraryIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 2 V18" />
      <path d="M8 2 V18" />
      <path d="M12 2 V18" />
      <path d="M15 2 L18 18" />
      <line x1="2" y1="18" x2="18" y2="18" />
    </svg>
  )
}

function HelpIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="10" cy="10" r="8" />
      <path d="M7.5 7.5 C7.5 5.5 9 4.5 10 4.5 C11.5 4.5 13 5.5 12.5 7.5 C12 9 10 9.5 10 11" />
      <circle cx="10" cy="14" r="0.5" fill="currentColor" />
    </svg>
  )
}

const ADMIN_EMAIL = "markshteyn1@gmail.com"

const NAV_ITEMS = [
  { href: "/dashboard/documents", label: "Documents", icon: <DocumentsIcon /> },
  { href: "/dashboard/courses", label: "Courses", icon: <CoursesIcon /> },
  { href: "/dashboard/analytics", label: "Analytics", icon: <AnalyticsIcon /> },
  { href: "/dashboard/reef", label: "My Reef", icon: <ReefIcon /> },
  { href: "/dashboard/library", label: "Library", icon: <LibraryIcon /> },
]

const BOTTOM_NAV_ITEMS = [
  { href: "/dashboard/help", label: "Help", icon: <HelpIcon /> },
  { href: "/dashboard/billing", label: "Billing", icon: <BillingIcon /> },
  { href: "/dashboard/settings", label: "Settings", icon: <SettingsIcon /> },
  { href: "/dashboard/admin", label: "Admin", icon: <AdminIcon />, adminOnly: true },
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

function SidebarToggleIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke={colors.gray600}
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <line x1="9" y1="3" x2="9" y2="21" />
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
  overflow: "hidden",
  whiteSpace: "nowrap",
}

export default function DashboardSidebar() {
  const { profile, sidebarOpen, toggleSidebar } = useDashboard()
  const collapsed = !sidebarOpen
  const sidebarWidth = collapsed ? SIDEBAR_WIDTH_COLLAPSED : SIDEBAR_WIDTH_OPEN

  return (
    <motion.aside
      initial={false}
      animate={{ width: sidebarWidth }}
      transition={{ type: "spring", bounce: 0.15, duration: 0.35 }}
      style={{
        position: "fixed",
        top: 12,
        left: 12,
        height: "calc(100vh - 24px)",
        backgroundColor: colors.white,
        border: `1.5px solid ${colors.gray500}`,
        borderRadius: 16,
        boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
        display: "flex",
        flexDirection: "column",
        zIndex: 50,
        overflow: "hidden",
      }}
    >
      {/* Logo + Toggle — matches header height */}
      <div
        style={{
          height: 64,
          padding: collapsed ? "0 14px" : "0 20px",
          display: "flex",
          alignItems: "center",
          justifyContent: collapsed ? "center" : "flex-start",
          gap: 10,
          flexShrink: 0,
        }}
      >
        {!collapsed && (
          <img
            src="/reef-logo.png"
            alt="Reef logo"
            style={{ width: 28, height: 28, flexShrink: 0 }}
          />
        )}
        {!collapsed && (
          <span
            style={{
              fontFamily,
              fontWeight: 900,
              fontSize: 24,
              letterSpacing: "-0.04em",
              textTransform: "uppercase",
              color: colors.black,
              flex: 1,
            }}
          >
            Reef
          </span>
        )}
        <motion.button
          onClick={toggleSidebar}
          whileHover={{ backgroundColor: colors.gray100 }}
          style={{
            background: "transparent",
            border: "none",
            cursor: "pointer",
            borderRadius: 6,
            width: 28,
            height: 28,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flexShrink: 0,
            padding: 0,
          }}
          title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          <SidebarToggleIcon />
        </motion.button>
      </div>

      {/* Nav */}
      <nav style={{ flex: 1, padding: collapsed ? "12px 10px 0" : "12px 14px 0", display: "flex", flexDirection: "column", gap: 2 }}>
        {NAV_ITEMS.map((item) => (
          <NavItem key={item.href} {...item} collapsed={collapsed} />
        ))}
        <div style={{ height: 1, backgroundColor: colors.gray100, margin: "4px 0" }} />
        {BOTTOM_NAV_ITEMS.filter((item) => !item.adminOnly || profile.email === ADMIN_EMAIL).map((item) => (
          <NavItem key={item.href} {...item} collapsed={collapsed} />
        ))}
      </nav>

      {/* Footer */}
      <div style={{ padding: collapsed ? "0 10px 16px" : "0 14px 16px", display: "flex", flexDirection: "column", gap: 2 }}>
        {/* Upgrade */}
        <motion.div
          style={{
            ...footerRowStyle,
            justifyContent: collapsed ? "center" : "flex-start",
            padding: collapsed ? "8px 0" : "8px 6px",
          }}
          whileHover={{ backgroundColor: colors.gray100 }}
          title={collapsed ? "Upgrade" : undefined}
        >
          <UpgradeIcon />
          {!collapsed && (
            <>
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
            </>
          )}
        </motion.div>

        {/* Socials */}
        <motion.div
          style={{
            ...footerRowStyle,
            justifyContent: collapsed ? "center" : "flex-start",
            padding: collapsed ? "8px 0" : "8px 6px",
          }}
          whileHover={{ backgroundColor: colors.gray100 }}
          title={collapsed ? "Socials" : undefined}
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
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={colors.black} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M4 4l11.733 16h4.267l-11.733-16z" />
              <path d="M4 20l6.768-6.768" />
              <path d="M20 4l-6.768 6.768" />
            </svg>
          </div>
          {!collapsed && (
            <>
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
                Socials
              </span>
              <ChevronRight />
            </>
          )}
        </motion.div>

        {/* User */}
        <Link
          href="/dashboard/settings"
          style={{ textDecoration: "none" }}
          title={collapsed ? profile.display_name : undefined}
        >
          <motion.div
            style={{
              ...footerRowStyle,
              justifyContent: collapsed ? "center" : "flex-start",
              padding: collapsed ? "8px 0" : "8px 6px",
            }}
            whileHover={{ backgroundColor: colors.gray100 }}
          >
            <UserAvatar name={profile.display_name} />
            {!collapsed && (
              <>
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
              </>
            )}
          </motion.div>
        </Link>
      </div>
    </motion.aside>
  )
}
