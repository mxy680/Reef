"use client"

import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

// ─── Fake Data ────────────────────────────────────────────

const SUBJECTS = [
  { name: "Calculus II", color: "#5B9EAD", mastery: 78, hours: 4.5 },
  { name: "Organic Chemistry", color: "#E07A5F", mastery: 62, hours: 3.2 },
  { name: "Linear Algebra", color: "#81B29A", mastery: 91, hours: 2.8 },
  { name: "Physics II", color: "#F2CC8F", mastery: 45, hours: 1.5 },
]

const WEEKLY_MINUTES = [65, 42, 88, 0, 55, 72, 38]
const DAY_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

const RECENT_SESSIONS = [
  { subject: "Calculus II", date: "Feb 28", duration: "45 min", pages: 3 },
  { subject: "Organic Chemistry", date: "Feb 27", duration: "32 min", pages: 2 },
  { subject: "Linear Algebra", date: "Feb 27", duration: "28 min", pages: 4 },
  { subject: "Calculus II", date: "Feb 26", duration: "55 min", pages: 5 },
  { subject: "Physics II", date: "Feb 25", duration: "18 min", pages: 1 },
]

// ─── Shared Styles ────────────────────────────────────────

const cardStyle: React.CSSProperties = {
  backgroundColor: colors.white,
  border: `1.5px solid ${colors.gray500}`,
  borderRadius: 16,
  boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
  padding: "24px 20px",
}

// ─── Weekly Activity Bar Chart ────────────────────────────

function WeeklyActivityChart() {
  const maxMinutes = Math.max(...WEEKLY_MINUTES)
  const chartH = 120
  const barW = 28
  const gap = 16
  const totalW = WEEKLY_MINUTES.length * (barW + gap) - gap
  const gridLines = [0, 0.25, 0.5, 0.75, 1]

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.3 }}
      style={{ ...cardStyle, display: "flex", flexDirection: "column" }}
    >
      <div
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 16,
          letterSpacing: "-0.04em",
          color: colors.black,
          marginBottom: 4,
        }}
      >
        Weekly Activity
      </div>
      <div
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 13,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          marginBottom: 20,
        }}
      >
        Daily study minutes this week
      </div>

      <div style={{ overflowX: "auto" }}>
        <svg
          viewBox={`0 0 ${totalW + 40} ${chartH + 32}`}
          width="100%"
          style={{ display: "block", minWidth: totalW + 40 }}
        >
          {/* Grid lines */}
          {gridLines.map((frac) => {
            const y = chartH * (1 - frac)
            return (
              <line
                key={frac}
                x1={0}
                y1={y}
                x2={totalW + 40}
                y2={y}
                stroke={colors.gray100}
                strokeWidth={1}
              />
            )
          })}

          {/* Bars */}
          {WEEKLY_MINUTES.map((minutes, i) => {
            const barH = maxMinutes > 0 ? (minutes / maxMinutes) * chartH : 0
            const x = i * (barW + gap) + 20
            const y = chartH - barH

            return (
              <g key={i}>
                <motion.rect
                  x={x}
                  y={y}
                  width={barW}
                  height={barH}
                  rx={6}
                  fill={minutes === 0 ? colors.gray100 : colors.primary}
                  initial={{ scaleY: 0 }}
                  animate={{ scaleY: 1 }}
                  transition={{ duration: 0.5, delay: 0.4 + i * 0.06, ease: "easeOut" }}
                  style={{ transformOrigin: `${x + barW / 2}px ${chartH}px` }}
                />
                {/* Day label */}
                <text
                  x={x + barW / 2}
                  y={chartH + 20}
                  textAnchor="middle"
                  fontFamily={fontFamily}
                  fontWeight={500}
                  fontSize={11}
                  fill={colors.gray600}
                  letterSpacing="-0.04em"
                >
                  {DAY_LABELS[i]}
                </text>
                {/* Minute label above bar (only if > 0) */}
                {minutes > 0 && (
                  <text
                    x={x + barW / 2}
                    y={y - 5}
                    textAnchor="middle"
                    fontFamily={fontFamily}
                    fontWeight={700}
                    fontSize={10}
                    fill={colors.gray500}
                    letterSpacing="-0.04em"
                  >
                    {minutes}
                  </text>
                )}
              </g>
            )
          })}
        </svg>
      </div>
    </motion.div>
  )
}

// ─── Time by Subject ──────────────────────────────────────

function TimeBySubject() {
  const maxHours = Math.max(...SUBJECTS.map((s) => s.hours))

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.35 }}
      style={{ ...cardStyle, display: "flex", flexDirection: "column" }}
    >
      <div
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 16,
          letterSpacing: "-0.04em",
          color: colors.black,
          marginBottom: 4,
        }}
      >
        Time by Subject
      </div>
      <div
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 13,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          marginBottom: 20,
        }}
      >
        Total hours studied
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
        {SUBJECTS.map((subject, i) => {
          const pct = maxHours > 0 ? (subject.hours / maxHours) * 100 : 0
          return (
            <div key={subject.name}>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  marginBottom: 6,
                }}
              >
                <div
                  style={{
                    fontFamily,
                    fontWeight: 600,
                    fontSize: 13,
                    letterSpacing: "-0.04em",
                    color: colors.black,
                  }}
                >
                  {subject.name}
                </div>
                <div
                  style={{
                    fontFamily,
                    fontWeight: 700,
                    fontSize: 13,
                    letterSpacing: "-0.04em",
                    color: colors.gray600,
                  }}
                >
                  {subject.hours}h
                </div>
              </div>
              <div
                style={{
                  width: "100%",
                  height: 8,
                  backgroundColor: colors.gray100,
                  borderRadius: 999,
                  overflow: "hidden",
                }}
              >
                <motion.div
                  initial={{ width: "0%" }}
                  animate={{ width: `${pct}%` }}
                  transition={{ duration: 0.6, delay: 0.45 + i * 0.08, ease: "easeOut" }}
                  style={{
                    height: "100%",
                    backgroundColor: subject.color,
                    borderRadius: 999,
                  }}
                />
              </div>
            </div>
          )
        })}
      </div>
    </motion.div>
  )
}

// ─── Mastery by Subject (Donut rings) ────────────────────

function DonutRing({
  subject,
  delay,
}: {
  subject: { name: string; color: string; mastery: number }
  delay: number
}) {
  const radius = 32
  const stroke = 6
  const circumference = 2 * Math.PI * radius
  const dashoffset = circumference * (1 - subject.mastery / 100)
  const size = (radius + stroke) * 2 + 4

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 6,
      }}
    >
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        style={{ display: "block" }}
      >
        {/* Background circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={colors.gray100}
          strokeWidth={stroke}
        />
        {/* Progress arc */}
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={subject.color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset: dashoffset }}
          transition={{ duration: 0.7, delay, ease: "easeOut" }}
          style={{ transform: "rotate(-90deg)", transformOrigin: "50% 50%" }}
        />
        {/* Percentage text */}
        <text
          x={size / 2}
          y={size / 2 + 1}
          textAnchor="middle"
          dominantBaseline="middle"
          fontFamily={fontFamily}
          fontWeight={800}
          fontSize={13}
          fill={colors.black}
          letterSpacing="-0.04em"
        >
          {subject.mastery}%
        </text>
      </svg>
      <div
        style={{
          fontFamily,
          fontWeight: 600,
          fontSize: 11,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          textAlign: "center",
          maxWidth: 72,
        }}
      >
        {subject.name}
      </div>
    </div>
  )
}

function MasteryBySubject() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.4 }}
      style={{ ...cardStyle, display: "flex", flexDirection: "column" }}
    >
      <div
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 16,
          letterSpacing: "-0.04em",
          color: colors.black,
          marginBottom: 4,
        }}
      >
        Mastery by Subject
      </div>
      <div
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 13,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          marginBottom: 20,
        }}
      >
        Based on session performance
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 16,
          justifyItems: "center",
        }}
      >
        {SUBJECTS.map((subject, i) => (
          <DonutRing
            key={subject.name}
            subject={subject}
            delay={0.5 + i * 0.1}
          />
        ))}
      </div>
    </motion.div>
  )
}

// ─── Recent Sessions ──────────────────────────────────────

function RecentSessions() {
  const subjectColorMap = Object.fromEntries(SUBJECTS.map((s) => [s.name, s.color]))

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.45 }}
      style={{ ...cardStyle, display: "flex", flexDirection: "column" }}
    >
      <div
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 16,
          letterSpacing: "-0.04em",
          color: colors.black,
          marginBottom: 4,
        }}
      >
        Recent Sessions
      </div>
      <div
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 13,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          marginBottom: 20,
        }}
      >
        Your latest study activity
      </div>

      <div>
        {RECENT_SESSIONS.map((session, i) => {
          const subjectColor = subjectColorMap[session.subject] ?? colors.primary
          const isLast = i === RECENT_SESSIONS.length - 1

          return (
            <div key={i}>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  padding: "10px 0",
                  gap: 12,
                }}
              >
                {/* Left: color dot + subject + date */}
                <div style={{ display: "flex", alignItems: "center", gap: 10, minWidth: 0 }}>
                  <div
                    style={{
                      width: 8,
                      height: 8,
                      borderRadius: "50%",
                      backgroundColor: subjectColor,
                      flexShrink: 0,
                    }}
                  />
                  <div style={{ minWidth: 0 }}>
                    <div
                      style={{
                        fontFamily,
                        fontWeight: 600,
                        fontSize: 14,
                        letterSpacing: "-0.04em",
                        color: colors.black,
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      }}
                    >
                      {session.subject}
                    </div>
                    <div
                      style={{
                        fontFamily,
                        fontWeight: 500,
                        fontSize: 12,
                        letterSpacing: "-0.04em",
                        color: colors.gray500,
                      }}
                    >
                      {session.date}
                    </div>
                  </div>
                </div>

                {/* Right: duration + pages */}
                <div style={{ display: "flex", alignItems: "center", gap: 16, flexShrink: 0 }}>
                  <div
                    style={{
                      fontFamily,
                      fontWeight: 600,
                      fontSize: 13,
                      letterSpacing: "-0.04em",
                      color: colors.gray600,
                    }}
                  >
                    {session.duration}
                  </div>
                  <div
                    style={{
                      fontFamily,
                      fontWeight: 500,
                      fontSize: 12,
                      letterSpacing: "-0.04em",
                      color: colors.gray400,
                      minWidth: 44,
                      textAlign: "right",
                    }}
                  >
                    {session.pages} {session.pages === 1 ? "page" : "pages"}
                  </div>
                </div>
              </div>

              {!isLast && (
                <div
                  style={{
                    width: "100%",
                    height: 1,
                    backgroundColor: colors.gray100,
                  }}
                />
              )}
            </div>
          )
        })}
      </div>
    </motion.div>
  )
}

// ─── Main Page ────────────────────────────────────────────

export default function AnalyticsPage() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
      >
        <h2
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 24,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 6,
          }}
        >
          Study Analytics
        </h2>
        <p
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            margin: 0,
          }}
        >
          Track your progress, study time, and subject mastery over time.
        </p>
      </motion.div>

      {/* Stat cards row */}
      <div style={{ display: "flex", gap: 16 }}>
        {[
          { label: "Total Study Time", value: "12.0 hrs", delay: 0.18 },
          { label: "Sessions This Week", value: "18", delay: 0.22 },
          { label: "Avg. Mastery", value: "69%", delay: 0.26 },
          { label: "Study Streak", value: "5 days", delay: 0.3 },
        ].map((stat) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.35, delay: stat.delay }}
            style={{
              ...cardStyle,
              flex: 1,
              padding: "20px 16px",
            }}
          >
            <div
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 13,
                letterSpacing: "-0.04em",
                color: colors.gray600,
                marginBottom: 6,
              }}
            >
              {stat.label}
            </div>
            <div
              style={{
                fontFamily,
                fontWeight: 800,
                fontSize: 28,
                letterSpacing: "-0.04em",
                color: colors.black,
              }}
            >
              {stat.value}
            </div>
          </motion.div>
        ))}
      </div>

      {/* Bento grid — cards stretch to fill each row */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 16,
        }}
      >
        <WeeklyActivityChart />
        <RecentSessions />
        <TimeBySubject />
        <MasteryBySubject />
      </div>
    </div>
  )
}
