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

  if (isActive) {
    return (
      <Link
        href={href}
        style={{
          display: "flex",
          alignItems: "center",
          gap: 12,
          padding: "10px 14px",
          textDecoration: "none",
          fontFamily,
          fontWeight: 700,
          fontSize: 15,
          letterSpacing: "-0.04em",
          color: colors.black,
          backgroundColor: colors.surface,
          border: `2px solid ${colors.black}`,
          borderRadius: 10,
          boxShadow: `3px 3px 0px 0px ${colors.black}`,
        }}
      >
        {icon}
        {label}
      </Link>
    )
  }

  return (
    <motion.div
      whileHover={{ x: 2 }}
      transition={{ type: "spring", bounce: 0.3, duration: 0.25 }}
    >
      <Link
        href={href}
        style={{
          display: "flex",
          alignItems: "center",
          gap: 12,
          padding: "10px 14px",
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
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.color = colors.black
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.color = colors.gray600
        }}
      >
        {icon}
        {label}
      </Link>
    </motion.div>
  )
}
