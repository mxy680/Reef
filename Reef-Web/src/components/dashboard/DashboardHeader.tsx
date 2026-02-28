"use client"

import { useState, useRef, useEffect } from "react"
import { usePathname, useRouter } from "next/navigation"
import Link from "next/link"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../lib/colors"
import { createClient } from "../../lib/supabase/client"
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
  "/dashboard": "Dashboard",
  "/dashboard/documents": "Documents",
  "/dashboard/analytics": "Analytics",
  "/dashboard/courses": "Courses",
  "/dashboard/settings": "Settings",
  "/dashboard/billing": "Billing",
  "/dashboard/reef": "My Reef",
}

// -- SVG Icons ---------------------------------------------------------------

function SearchIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="9" cy="9" r="6" />
      <line x1="13.5" y1="13.5" x2="17" y2="17" />
    </svg>
  )
}

function HelpIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="10" cy="10" r="8" />
      <path d="M7.5 7.5 C7.5 6 8.5 5 10 5 C11.5 5 12.5 6 12.5 7.5 C12.5 9 10 9.5 10 11" />
      <circle cx="10" cy="14" r="0.5" fill="currentColor" stroke="none" />
    </svg>
  )
}

function BellIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10 2 C10 2 5 3 5 9 C5 14 3 15 3 15 L17 15 C17 15 15 14 15 9 C15 3 10 2 10 2 Z" />
      <path d="M8 15 C8 16.5 9 17.5 10 17.5 C11 17.5 12 16.5 12 15" />
    </svg>
  )
}

function FlameIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M8 1 C8 1 12 5 12 9 C12 12 10 14 8 14 C6 14 4 12 4 9 C4 5 8 1 8 1 Z" />
      <path d="M8 14 C7 14 6 13 6 11.5 C6 10 8 8 8 8 C8 8 10 10 10 11.5 C10 13 9 14 8 14 Z" />
    </svg>
  )
}

function ChevronSeparator() {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke={colors.gray400} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="4,2 8,6 4,10" />
    </svg>
  )
}

// -- Sub-components ----------------------------------------------------------

function Breadcrumbs({ pathname }: { pathname: string }) {
  // Build crumbs from pathname
  const segments = pathname.replace(/\/$/, "").split("/").filter(Boolean)
  // segments e.g. ["dashboard", "documents"]
  const crumbs: { label: string; href: string }[] = []

  for (let i = 0; i < segments.length; i++) {
    const href = "/" + segments.slice(0, i + 1).join("/")
    const label = PAGE_TITLES[href] || segments[i].charAt(0).toUpperCase() + segments[i].slice(1)
    crumbs.push({ label, href })
  }

  return (
    <div style={{ display: "flex", alignItems: "center", gap: 6, minWidth: 0 }}>
      {crumbs.map((crumb, i) => {
        const isLast = i === crumbs.length - 1
        return (
          <div key={crumb.href} style={{ display: "flex", alignItems: "center", gap: 6 }}>
            {i > 0 && <ChevronSeparator />}
            {isLast ? (
              <span
                style={{
                  fontFamily,
                  fontWeight: 800,
                  fontSize: 16,
                  letterSpacing: "-0.04em",
                  color: colors.black,
                }}
              >
                {crumb.label}
              </span>
            ) : (
              <Link
                href={crumb.href}
                style={{
                  fontFamily,
                  fontWeight: 600,
                  fontSize: 16,
                  letterSpacing: "-0.04em",
                  color: colors.gray600,
                  textDecoration: "none",
                }}
              >
                {crumb.label}
              </Link>
            )}
          </div>
        )
      })}
    </div>
  )
}

function HeaderIconButton({ children, onClick }: { children: React.ReactNode; onClick?: () => void }) {
  return (
    <motion.button
      onClick={onClick}
      whileHover={{ scale: 1.1 }}
      whileTap={{ scale: 0.95 }}
      style={{
        position: "relative",
        background: "transparent",
        border: "none",
        cursor: "pointer",
        padding: 4,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        color: colors.gray600,
      }}
    >
      {children}
    </motion.button>
  )
}

function NotificationBell({ count = 0 }: { count?: number }) {
  return (
    <motion.button
      whileHover={{ scale: 1.1 }}
      whileTap={{ scale: 0.95 }}
      style={{
        position: "relative",
        background: "transparent",
        border: "none",
        cursor: "pointer",
        padding: 4,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        color: colors.gray600,
      }}
    >
      <BellIcon />
      {count > 0 && (
        <div
          style={{
            position: "absolute",
            top: 2,
            right: 2,
            width: 8,
            height: 8,
            borderRadius: 999,
            backgroundColor: "#e74c3c",
            border: `1.5px solid ${colors.white}`,
          }}
        />
      )}
    </motion.button>
  )
}

function StreakIndicator({ streak = 0 }: { streak?: number }) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 4,
        padding: "4px 10px",
        backgroundColor: colors.surface,
        borderRadius: 999,
        color: colors.black,
      }}
    >
      <FlameIcon />
      <span
        style={{
          fontFamily,
          fontWeight: 600,
          fontSize: 13,
          letterSpacing: "-0.02em",
        }}
      >
        {streak}
      </span>
    </div>
  )
}

function ProfileDropdown() {
  const { profile } = useDashboard()
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  // Outside click
  useEffect(() => {
    if (!open) return
    const handleClick = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener("mousedown", handleClick)
    return () => document.removeEventListener("mousedown", handleClick)
  }, [open])

  const initials = profile.display_name
    .split(" ")
    .map((w) => w[0])
    .join("")
    .toUpperCase()
    .slice(0, 2)

  const handleSignOut = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push("/auth")
  }

  return (
    <div ref={containerRef} style={{ position: "relative" }}>
      <motion.button
        onClick={() => setOpen((o) => !o)}
        whileHover={{ scale: 1.06 }}
        whileTap={{ scale: 0.95 }}
        style={{
          width: 32,
          height: 32,
          borderRadius: 999,
          backgroundColor: colors.accent,
          border: "none",
          cursor: "pointer",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: 0,
        }}
      >
        <span
          style={{
            fontFamily,
            fontWeight: 700,
            fontSize: 12,
            letterSpacing: "-0.02em",
            color: colors.black,
          }}
        >
          {initials}
        </span>
      </motion.button>

      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: -4 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: -4 }}
            transition={{ duration: 0.15 }}
            style={{
              position: "absolute",
              top: "calc(100% + 8px)",
              right: 0,
              width: 200,
              backgroundColor: colors.white,
              border: `1.5px solid ${colors.gray500}`,
              borderRadius: 12,
              boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
              padding: "12px 0",
              zIndex: 100,
            }}
          >
            {/* User info */}
            <div style={{ padding: "0 14px 10px" }}>
              <div
                style={{
                  fontFamily,
                  fontWeight: 700,
                  fontSize: 14,
                  letterSpacing: "-0.04em",
                  color: colors.black,
                }}
              >
                {profile.display_name}
              </div>
              <div
                style={{
                  fontFamily,
                  fontWeight: 500,
                  fontSize: 12,
                  letterSpacing: "-0.02em",
                  color: colors.gray600,
                  marginTop: 2,
                }}
              >
                {GRADE_LABELS[profile.grade] || profile.grade}
              </div>
            </div>

            {/* Divider */}
            <div style={{ height: 1, backgroundColor: colors.gray100, margin: "0 14px" }} />

            {/* Settings */}
            <Link
              href="/dashboard/settings"
              onClick={() => setOpen(false)}
              style={{ textDecoration: "none" }}
            >
              <div
                style={{
                  padding: "10px 14px",
                  fontFamily,
                  fontWeight: 600,
                  fontSize: 13,
                  letterSpacing: "-0.02em",
                  color: colors.black,
                  cursor: "pointer",
                  transition: "background-color 0.1s",
                }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.gray100)}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
              >
                Settings
              </div>
            </Link>

            {/* Log out */}
            <div
              onClick={handleSignOut}
              style={{
                padding: "10px 14px",
                fontFamily,
                fontWeight: 600,
                fontSize: 13,
                letterSpacing: "-0.02em",
                color: "#e74c3c",
                cursor: "pointer",
                transition: "background-color 0.1s",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.gray100)}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
            >
              Log out
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

// -- Main Component ----------------------------------------------------------

export default function DashboardHeader() {
  const pathname = usePathname()

  return (
    <header
      style={{
        height: 64,
        backgroundColor: colors.white,
        border: `1.5px solid ${colors.gray500}`,
        borderRadius: 16,
        boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
        margin: "12px 12px 0 0",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "0 24px",
        position: "relative",
        zIndex: 10,
      }}
    >
      {/* Left — Breadcrumbs */}
      <Breadcrumbs pathname={pathname} />

      {/* Right — Actions */}
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <HeaderIconButton>
          <SearchIcon />
        </HeaderIconButton>
        <HeaderIconButton>
          <HelpIcon />
        </HeaderIconButton>
        <NotificationBell count={0} />
        <StreakIndicator streak={0} />
        <ProfileDropdown />
      </div>
    </header>
  )
}
