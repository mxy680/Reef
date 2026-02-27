"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { colors } from "../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

export default function NavItem({
  href,
  label,
  icon,
}: {
  href: string
  label: string
  icon: React.ReactNode
}) {
  const pathname = usePathname()
  const isActive =
    href === "/dashboard"
      ? pathname === "/dashboard"
      : pathname.startsWith(href)

  return (
    <Link
      href={href}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        padding: "12px 20px",
        textDecoration: "none",
        fontFamily,
        fontWeight: 600,
        fontSize: 15,
        letterSpacing: "-0.04em",
        color: isActive ? colors.black : colors.gray600,
        backgroundColor: isActive ? colors.surface : "transparent",
        borderLeft: isActive ? `3px solid ${colors.primary}` : "3px solid transparent",
        transition: "background-color 0.15s, color 0.15s",
      }}
      onMouseEnter={(e) => {
        if (!isActive) {
          e.currentTarget.style.backgroundColor = colors.gray100
        }
      }}
      onMouseLeave={(e) => {
        if (!isActive) {
          e.currentTarget.style.backgroundColor = "transparent"
        }
      }}
    >
      {icon}
      {label}
    </Link>
  )
}
