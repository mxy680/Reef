"use client"

import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

function BillingIllustration() {
  return (
    <svg width="200" height="140" viewBox="0 0 200 140" fill="none">
      {/* Main card */}
      <rect x="30" y="25" width="140" height="90" rx="10" fill={colors.white} stroke={colors.black} strokeWidth="2" />
      <rect x="30" y="25" width="140" height="28" rx="10" fill={colors.surface} stroke={colors.black} strokeWidth="2" />
      {/* Clip bottom corners of header — overlay rectangles */}
      <rect x="31" y="43" width="138" height="12" fill={colors.surface} />
      <line x1="30" y1="53" x2="170" y2="53" stroke={colors.black} strokeWidth="2" />

      {/* Chip */}
      <rect x="45" y="63" width="24" height="18" rx="3" fill={colors.accent} stroke={colors.black} strokeWidth="1.5" />
      <line x1="45" y1="72" x2="69" y2="72" stroke={colors.black} strokeWidth="1" />
      <line x1="57" y1="63" x2="57" y2="81" stroke={colors.black} strokeWidth="1" />

      {/* Card number dots */}
      {[0, 1, 2, 3].map((g) => (
        <g key={g}>
          {[0, 1, 2, 3].map((d) => (
            <circle key={d} cx={45 + g * 32 + d * 7} cy="96" r="2" fill={colors.gray500} />
          ))}
        </g>
      ))}

      {/* Floating sparkles */}
      <path d="M20 20 L22 14 L24 20 L30 22 L24 24 L22 30 L20 24 L14 22 Z" fill={colors.accent} stroke={colors.black} strokeWidth="1" />
      <path d="M172 10 L173.5 6 L175 10 L179 11.5 L175 13 L173.5 17 L172 13 L168 11.5 Z" fill={colors.surface} stroke={colors.black} strokeWidth="1" />
      <path d="M180 85 L181.5 81 L183 85 L187 86.5 L183 88 L181.5 92 L180 88 L176 86.5 Z" fill={colors.accent} stroke={colors.black} strokeWidth="1" />
    </svg>
  )
}

function PlanCard({ name, price, features, highlighted }: { name: string; price: string; features: string[]; highlighted?: boolean }) {
  return (
    <div
      style={{
        flex: 1,
        backgroundColor: highlighted ? colors.surface : colors.white,
        border: `2px solid ${colors.black}`,
        borderRadius: 12,
        padding: "16px 18px",
        boxShadow: highlighted ? `3px 3px 0px 0px ${colors.black}` : "none",
      }}
    >
      <div
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 12,
          letterSpacing: "0.04em",
          textTransform: "uppercase",
          color: colors.gray600,
          marginBottom: 4,
        }}
      >
        {name}
      </div>
      <div
        style={{
          fontFamily,
          fontWeight: 900,
          fontSize: 24,
          letterSpacing: "-0.04em",
          color: colors.black,
          marginBottom: 12,
        }}
      >
        {price}
      </div>
      {features.map((f) => (
        <div
          key={f}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            marginBottom: 6,
          }}
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.primary} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="3,7 6,10 11,4" />
          </svg>
          <span
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 13,
              letterSpacing: "-0.02em",
              color: colors.gray600,
            }}
          >
            {f}
          </span>
        </div>
      ))}
    </div>
  )
}

export default function BillingPage() {
  return (
    <div style={{ maxWidth: 560 }}>
      {/* Page header */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
        style={{ marginBottom: 24 }}
      >
        <h1
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 28,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 6,
          }}
        >
          Billing
        </h1>
        <p
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 15,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            margin: 0,
          }}
        >
          Plans and payment
        </p>
      </motion.div>

      {/* Hero card */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.2 }}
        style={{
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 16,
          boxShadow: `4px 4px 0px 0px ${colors.black}`,
          overflow: "hidden",
        }}
      >
        {/* Illustration area */}
        <div
          style={{
            backgroundColor: colors.surface,
            borderBottom: `2px solid ${colors.black}`,
            padding: "28px 0",
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
          }}
        >
          <BillingIllustration />
        </div>

        {/* Content */}
        <div style={{ padding: "24px 28px" }}>
          {/* Badge */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.3, delay: 0.35 }}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 6,
              padding: "5px 12px",
              backgroundColor: colors.accent,
              border: `2px solid ${colors.black}`,
              borderRadius: 999,
              marginBottom: 16,
            }}
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={colors.black} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="7" cy="7" r="6" />
              <line x1="7" y1="4" x2="7" y2="7.5" />
              <line x1="7" y1="7.5" x2="9.5" y2="9" />
            </svg>
            <span
              style={{
                fontFamily,
                fontWeight: 800,
                fontSize: 11,
                letterSpacing: "0.04em",
                textTransform: "uppercase",
                color: colors.black,
              }}
            >
              Coming Soon
            </span>
          </motion.div>

          <h2
            style={{
              fontFamily,
              fontWeight: 900,
              fontSize: 22,
              letterSpacing: "-0.04em",
              color: colors.black,
              margin: 0,
              marginBottom: 10,
            }}
          >
            Subscription Plans
          </h2>

          <p
            style={{
              fontFamily,
              fontWeight: 500,
              fontSize: 15,
              lineHeight: 1.6,
              letterSpacing: "-0.02em",
              color: colors.gray600,
              margin: 0,
              marginBottom: 20,
            }}
          >
            Reef is free during the beta. When we launch paid plans, you&apos;ll
            manage your subscription, view invoices, and update payment methods here.
          </p>

          {/* Plan preview cards */}
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: 0.45 }}
            style={{ display: "flex", gap: 12 }}
          >
            <PlanCard
              name="Free"
              price="$0"
              features={["5 documents", "Basic tutoring", "Community support"]}
            />
            <PlanCard
              name="Pro"
              price="$12/mo"
              features={["Unlimited docs", "Advanced AI tutor", "Priority support"]}
              highlighted
            />
          </motion.div>
        </div>
      </motion.div>
    </div>
  )
}
