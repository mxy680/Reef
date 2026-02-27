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

  return (
    <motion.div
      whileHover={isActive ? {} : { y: -1 }}
      whileTap={isActive ? {} : { y: 1 }}
      transition={{ type: "spring", bounce: 0.3, duration: 0.3 }}
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
          fontWeight: 700,
          fontSize: 15,
          letterSpacing: "-0.04em",
          color: colors.black,
          backgroundColor: isActive ? colors.surface : colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 10,
          boxShadow: isActive
            ? `3px 3px 0px 0px ${colors.black}`
            : "none",
          transition: "background-color 0.15s, box-shadow 0.15s",
        }}
        onMouseEnter={(e) => {
          if (!isActive) {
            e.currentTarget.style.backgroundColor = colors.surface
            e.currentTarget.style.boxShadow = `2px 2px 0px 0px ${colors.black}`
          }
        }}
        onMouseLeave={(e) => {
          if (!isActive) {
            e.currentTarget.style.backgroundColor = colors.white
            e.currentTarget.style.boxShadow = "none"
          }
        }}
      >
        {icon}
        {label}
      </Link>
    </motion.div>
  )
}
