"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { motion } from "framer-motion"
import { colors } from "../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

export default function NavItem({
  href,
  label,
  icon,
  collapsed = false,
  onNavigate,
}: {
  href: string
  label: string
  icon: React.ReactNode
  collapsed?: boolean
  onNavigate?: () => void
}) {
  const pathname = usePathname()
  const isActive = pathname.startsWith(href)

  if (isActive) {
    return (
      <Link
        href={href}
        onClick={onNavigate}
        title={collapsed ? label : undefined}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: collapsed ? "center" : "flex-start",
          gap: collapsed ? 0 : 12,
          padding: collapsed ? "8px 0" : "8px 14px",
          textDecoration: "none",
          fontFamily,
          fontWeight: 700,
          fontSize: 15,
          letterSpacing: "-0.04em",
          color: colors.black,
          backgroundColor: colors.accent,
          border: `2px solid ${colors.black}`,
          borderRadius: 10,
          boxShadow: `3px 3px 0px 0px ${colors.black}`,
          overflow: "hidden",
          whiteSpace: "nowrap",
        }}
      >
        <span style={{ flexShrink: 0 }}>{icon}</span>
        {!collapsed && label}
      </Link>
    )
  }

  return (
    <motion.div
      whileHover={{ x: collapsed ? 0 : 2 }}
      transition={{ type: "spring", bounce: 0.3, duration: 0.25 }}
    >
      <Link
        href={href}
        onClick={onNavigate}
        title={collapsed ? label : undefined}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: collapsed ? "center" : "flex-start",
          gap: collapsed ? 0 : 12,
          padding: collapsed ? "8px 0" : "8px 14px",
          textDecoration: "none",
          fontFamily,
          fontWeight: 600,
          fontSize: 15,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          backgroundColor: "transparent",
          border: "2px solid transparent",
          borderRadius: 10,
          transition: "color 0.12s",
          overflow: "hidden",
          whiteSpace: "nowrap",
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.color = colors.black
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.color = colors.gray600
        }}
      >
        <span style={{ flexShrink: 0 }}>{icon}</span>
        {!collapsed && label}
      </Link>
    </motion.div>
  )
}
