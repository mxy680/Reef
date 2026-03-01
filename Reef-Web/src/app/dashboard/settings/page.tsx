"use client"

import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../../lib/colors"
import { upsertProfile } from "../../../lib/profiles"
import { createClient } from "../../../lib/supabase/client"
import { useDashboard } from "../../../components/dashboard/DashboardContext"
import { TIER_LIMITS, type Tier } from "../../../lib/limits"

const fontFamily = `"Epilogue", sans-serif`

type Tab = "profile" | "preferences" | "privacy" | "about" | "account"

const TABS: { key: Tab; label: string; icon: React.ReactNode }[] = [
  {
    key: "profile",
    label: "Profile",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
        <circle cx="12" cy="7" r="4" />
      </svg>
    ),
  },
  {
    key: "preferences",
    label: "Preferences",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <line x1="4" y1="21" x2="4" y2="14" />
        <line x1="4" y1="10" x2="4" y2="3" />
        <line x1="12" y1="21" x2="12" y2="12" />
        <line x1="12" y1="8" x2="12" y2="3" />
        <line x1="20" y1="21" x2="20" y2="16" />
        <line x1="20" y1="12" x2="20" y2="3" />
        <line x1="1" y1="14" x2="7" y2="14" />
        <line x1="9" y1="8" x2="15" y2="8" />
        <line x1="17" y1="16" x2="23" y2="16" />
      </svg>
    ),
  },
  {
    key: "privacy",
    label: "Privacy",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
      </svg>
    ),
  },
  {
    key: "about",
    label: "About",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="10" />
        <line x1="12" y1="16" x2="12" y2="12" />
        <line x1="12" y1="8" x2="12.01" y2="8" />
      </svg>
    ),
  },
  {
    key: "account",
    label: "Account",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
        <circle cx="12" cy="12" r="3" />
      </svg>
    ),
  },
]

const GRADES = [
  { value: "middle_school", label: "Middle School" },
  { value: "high_school", label: "High School" },
  { value: "college", label: "College" },
  { value: "graduate", label: "Graduate" },
  { value: "other", label: "Other" },
]

const SUBJECTS = [
  "Algebra",
  "Geometry",
  "Precalculus",
  "Calculus",
  "Statistics",
  "Linear Algebra",
  "Trigonometry",
  "Differential Equations",
  "Physics",
  "Chemistry",
  "Biology",
  "Computer Science",
  "Economics",
  "Engineering",
  "Accounting",
]

const TIER_INFO: Record<Tier, { label: string; price: string; color: string }> = {
  shore: { label: "Shore", price: "Free", color: colors.accent },
  reef: { label: "Reef", price: "$9.99/mo", color: colors.primary },
  abyss: { label: "Abyss", price: "$29.99/mo", color: "#6C3FA0" },
}

// ─── Icons ────────────────────────────────────────────────

function PencilIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
      <path d="m15 5 4 4" />
    </svg>
  )
}

function CheckIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  )
}

function XIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="18" y1="6" x2="6" y2="18" />
      <line x1="6" y1="6" x2="18" y2="18" />
    </svg>
  )
}

function LogOutIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" y1="12" x2="9" y2="12" />
    </svg>
  )
}

function TrashIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="3 6 5 6 21 6" />
      <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
      <line x1="10" y1="11" x2="10" y2="17" />
      <line x1="14" y1="11" x2="14" y2="17" />
    </svg>
  )
}

// ─── Shared Components ────────────────────────────────────

function SectionHeader({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        fontFamily,
        fontWeight: 800,
        fontSize: 11,
        letterSpacing: "0.06em",
        textTransform: "uppercase",
        color: colors.gray500,
        marginBottom: 16,
      }}
    >
      {children}
    </div>
  )
}

function FieldLabel({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        fontFamily,
        fontWeight: 500,
        fontSize: 13,
        letterSpacing: "-0.04em",
        color: colors.gray600,
        marginBottom: 8,
      }}
    >
      {children}
    </div>
  )
}

function Divider() {
  return <div style={{ height: 1, backgroundColor: colors.gray100, margin: "24px 0" }} />
}

function Card({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div
      style={{
        backgroundColor: colors.white,
        border: `1.5px solid ${colors.gray500}`,
        borderRadius: 16,
        boxShadow: `4px 4px 0px 0px ${colors.gray500}`,
        padding: "28px 24px",
        ...style,
      }}
    >
      {children}
    </div>
  )
}

function Toast({ message, onDone }: { message: string; onDone: () => void }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: 12 }}
      transition={{ duration: 0.25 }}
      onAnimationComplete={(def: { opacity?: number }) => {
        if (def.opacity === 1) setTimeout(onDone, 2500)
      }}
      style={{
        position: "fixed",
        bottom: 24,
        right: 24,
        backgroundColor: colors.black,
        color: colors.white,
        fontFamily,
        fontWeight: 600,
        fontSize: 14,
        letterSpacing: "-0.04em",
        padding: "12px 20px",
        borderRadius: 10,
        boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
        zIndex: 9999,
      }}
    >
      {message}
    </motion.div>
  )
}

function DeleteConfirmModal({ onConfirm, onClose }: { onConfirm: () => void; onClose: () => void }) {
  const [deleting, setDeleting] = useState(false)
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.2 }}
      onClick={onClose}
      style={{ position: "fixed", inset: 0, backgroundColor: "rgba(0,0,0,0.3)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100, padding: 24 }}
    >
      <motion.div
        initial={{ opacity: 0, y: 20, scale: 0.97 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 20, scale: 0.97 }}
        transition={{ duration: 0.25 }}
        onClick={(e) => e.stopPropagation()}
        style={{ width: 380, maxWidth: "100%", backgroundColor: colors.white, border: `2px solid ${colors.black}`, borderRadius: 12, boxShadow: `6px 6px 0px 0px ${colors.black}`, padding: "36px 32px", boxSizing: "border-box", textAlign: "center" }}
      >
        <div style={{ fontSize: 40, marginBottom: 16 }}>🗑️</div>
        <h3 style={{ fontFamily, fontWeight: 900, fontSize: 20, letterSpacing: "-0.04em", color: colors.black, margin: 0, marginBottom: 8 }}>
          Delete your account?
        </h3>
        <p style={{ fontFamily, fontWeight: 500, fontSize: 14, letterSpacing: "-0.04em", color: colors.gray600, margin: 0, marginBottom: 24 }}>
          This action cannot be undone. All your data, documents, and courses will be permanently deleted.
        </p>
        <div style={{ display: "flex", justifyContent: "center", gap: 10 }}>
          <button type="button" onClick={onClose} style={{ padding: "10px 20px", background: "none", border: "none", fontFamily, fontWeight: 600, fontSize: 14, letterSpacing: "-0.04em", color: colors.gray600, cursor: "pointer" }}>
            Cancel
          </button>
          <motion.button
            type="button"
            onClick={() => { setDeleting(true); onConfirm() }}
            disabled={deleting}
            whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 }}
            whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 }}
            transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
            style={{ padding: "10px 24px", backgroundColor: "#C62828", border: `2px solid ${colors.black}`, borderRadius: 10, boxShadow: `4px 4px 0px 0px ${colors.black}`, fontFamily, fontWeight: 700, fontSize: 14, letterSpacing: "-0.04em", color: colors.white, cursor: deleting ? "not-allowed" : "pointer" }}
          >
            {deleting ? "Deleting..." : "Delete Account"}
          </motion.button>
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Usage Bar ────────────────────────────────────────────

function UsageBar({ label, used, max }: { label: string; used: number; max: number }) {
  const isUnlimited = max === Infinity
  const pct = isUnlimited ? 0 : Math.min((used / max) * 100, 100)
  const displayMax = isUnlimited ? "∞" : max

  return (
    <div style={{ marginBottom: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
        <span style={{ fontFamily, fontWeight: 600, fontSize: 13, letterSpacing: "-0.04em", color: colors.black }}>
          {label}
        </span>
        <span style={{ fontFamily, fontWeight: 600, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600 }}>
          {used} / {displayMax}
        </span>
      </div>
      <div style={{ height: 8, backgroundColor: colors.gray100, borderRadius: 999, overflow: "hidden" }}>
        <motion.div
          initial={{ width: 0 }}
          animate={{ width: `${pct}%` }}
          transition={{ duration: 0.6, ease: "easeOut" }}
          style={{
            height: "100%",
            backgroundColor: pct > 80 ? "#E57373" : colors.primary,
            borderRadius: 999,
          }}
        />
      </div>
    </div>
  )
}

// ─── Profile Tab ──────────────────────────────────────────

function ProfileTab({
  profile,
  setProfile,
  setToast,
}: {
  profile: ReturnType<typeof useDashboard>["profile"]
  setProfile: ReturnType<typeof useDashboard>["setProfile"]
  setToast: (msg: string) => void
}) {
  const [name, setName] = useState(profile.display_name)
  const [grade, setGrade] = useState(profile.grade)
  const [subjects, setSubjects] = useState<string[]>(profile.subjects)
  const [editingName, setEditingName] = useState(false)
  const [saving, setSaving] = useState(false)
  const nameInputRef = useRef<HTMLInputElement>(null)

  const isDirty =
    grade !== profile.grade ||
    JSON.stringify([...subjects].sort()) !== JSON.stringify([...profile.subjects].sort())

  useEffect(() => {
    if (editingName && nameInputRef.current) nameInputRef.current.focus()
  }, [editingName])

  async function handleSaveName() {
    const trimmed = name.trim()
    if (!trimmed || trimmed === profile.display_name) {
      setName(profile.display_name)
      setEditingName(false)
      return
    }
    setSaving(true)
    try {
      await upsertProfile({ display_name: trimmed })
      setProfile({ ...profile, display_name: trimmed })
      setToast("Name updated")
    } catch {
      setToast("Failed to update name")
      setName(profile.display_name)
    }
    setSaving(false)
    setEditingName(false)
  }

  async function handleSaveProfile() {
    setSaving(true)
    try {
      await upsertProfile({ grade, subjects })
      setProfile({ ...profile, grade, subjects })
      setToast("Settings saved")
    } catch {
      setToast("Failed to save")
      setGrade(profile.grade)
      setSubjects(profile.subjects)
    }
    setSaving(false)
  }

  function toggleSubject(subject: string) {
    setSubjects((prev) =>
      prev.includes(subject) ? prev.filter((s) => s !== subject) : [...prev, subject]
    )
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20, height: "100%" }}>
      {/* Name & Email row */}
      <Card>
        <SectionHeader>Personal Info</SectionHeader>

        {/* Name */}
        <div style={{ marginBottom: 20 }}>
          <FieldLabel>Name</FieldLabel>
          {editingName ? (
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <input
                ref={nameInputRef}
                value={name}
                onChange={(e) => setName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleSaveName()
                  if (e.key === "Escape") { setName(profile.display_name); setEditingName(false) }
                }}
                style={{
                  flex: 1, padding: "10px 14px", fontFamily, fontWeight: 600, fontSize: 15,
                  letterSpacing: "-0.04em", color: colors.black, border: `2px solid ${colors.primary}`,
                  borderRadius: 10, outline: "none", boxSizing: "border-box",
                }}
              />
              <motion.button onClick={handleSaveName} disabled={saving} whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
                style={{ display: "flex", alignItems: "center", justifyContent: "center", width: 36, height: 36, borderRadius: 10, backgroundColor: colors.primary, border: "none", color: colors.white, cursor: "pointer" }}>
                <CheckIcon />
              </motion.button>
              <motion.button onClick={() => { setName(profile.display_name); setEditingName(false) }} whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
                style={{ display: "flex", alignItems: "center", justifyContent: "center", width: 36, height: 36, borderRadius: 10, backgroundColor: colors.gray100, border: "none", color: colors.gray600, cursor: "pointer" }}>
                <XIcon />
              </motion.button>
            </div>
          ) : (
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ fontFamily, fontWeight: 700, fontSize: 16, letterSpacing: "-0.04em", color: colors.black }}>
                {profile.display_name}
              </span>
              <motion.button onClick={() => setEditingName(true)} whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}
                style={{ display: "flex", alignItems: "center", justifyContent: "center", width: 28, height: 28, borderRadius: 6, backgroundColor: "transparent", border: "none", color: colors.gray500, cursor: "pointer" }}>
                <PencilIcon />
              </motion.button>
            </div>
          )}
        </div>

        {/* Email */}
        <div>
          <FieldLabel>Email</FieldLabel>
          <span style={{ fontFamily, fontWeight: 700, fontSize: 16, letterSpacing: "-0.04em", color: colors.black }}>
            {profile.email}
          </span>
        </div>
      </Card>

      {/* Grade & Subjects */}
      <Card style={{ flex: 1 }}>
        <SectionHeader>Education</SectionHeader>

        {/* Grade */}
        <div style={{ marginBottom: 24 }}>
          <FieldLabel>Grade Level</FieldLabel>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {GRADES.map((g) => {
              const selected = grade === g.value
              return (
                <motion.button
                  key={g.value} type="button" onClick={() => setGrade(g.value)}
                  whileHover={{ y: -1 }} whileTap={{ y: 1 }}
                  style={{
                    padding: "8px 16px", backgroundColor: selected ? colors.primary : colors.white,
                    border: `1.5px solid ${selected ? colors.primary : colors.gray400}`, borderRadius: 10,
                    fontFamily, fontWeight: 600, fontSize: 13, letterSpacing: "-0.04em",
                    color: selected ? colors.white : colors.black, cursor: "pointer",
                  }}
                >
                  {g.label}
                </motion.button>
              )
            })}
          </div>
        </div>

        {/* Subjects */}
        <div>
          <FieldLabel>Subjects</FieldLabel>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {SUBJECTS.map((subject) => {
              const selected = subjects.includes(subject)
              return (
                <motion.button
                  key={subject} type="button" onClick={() => toggleSubject(subject)}
                  whileHover={{ y: -1 }} whileTap={{ y: 1 }}
                  style={{
                    padding: "6px 14px", backgroundColor: selected ? colors.primary : colors.white,
                    border: `1.5px solid ${selected ? colors.primary : colors.gray400}`, borderRadius: 999,
                    fontFamily, fontWeight: 600, fontSize: 13, letterSpacing: "-0.04em",
                    color: selected ? colors.white : colors.black, cursor: "pointer",
                  }}
                >
                  {subject}
                </motion.button>
              )
            })}
          </div>
        </div>

        {/* Save */}
        <AnimatePresence>
          {isDirty && (
            <motion.div
              initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }} transition={{ duration: 0.2 }}
              style={{ overflow: "hidden" }}
            >
              <div style={{ display: "flex", justifyContent: "flex-end", paddingTop: 20 }}>
                <motion.button
                  onClick={handleSaveProfile} disabled={saving || subjects.length === 0}
                  whileHover={subjects.length > 0 ? { boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 } : {}}
                  whileTap={subjects.length > 0 ? { boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 } : {}}
                  transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
                  style={{
                    padding: "10px 24px", backgroundColor: subjects.length > 0 ? colors.primary : colors.gray100,
                    border: `2px solid ${colors.black}`, borderRadius: 10,
                    boxShadow: `4px 4px 0px 0px ${colors.black}`, fontFamily, fontWeight: 700, fontSize: 14,
                    letterSpacing: "-0.04em", color: subjects.length > 0 ? colors.white : colors.gray500,
                    cursor: subjects.length > 0 ? "pointer" : "not-allowed",
                  }}
                >
                  {saving ? "Saving..." : "Save Changes"}
                </motion.button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </Card>
    </div>
  )
}

// ─── Preferences Tab ──────────────────────────────────────

function PreferencesTab({ setToast }: { setToast: (msg: string) => void }) {
  const [darkMode, setDarkMode] = useState(false)
  const [focusWeakAreas, setFocusWeakAreas] = useState(true)
  const [defaultDifficulty, setDefaultDifficulty] = useState("medium")
  const [defaultQuestionCount, setDefaultQuestionCount] = useState(10)

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20, height: "100%" }}>
      {/* Appearance */}
      <Card>
        <SectionHeader>Appearance</SectionHeader>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div>
            <div style={{ fontFamily, fontWeight: 700, fontSize: 15, letterSpacing: "-0.04em", color: colors.black, marginBottom: 2 }}>
              Dark Mode
            </div>
            <div style={{ fontFamily, fontWeight: 500, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600 }}>
              Switch between light and dark themes
            </div>
          </div>
          <motion.button
            onClick={() => { setDarkMode(!darkMode); setToast(darkMode ? "Light mode enabled" : "Dark mode enabled") }}
            whileTap={{ scale: 0.9 }}
            style={{
              width: 52, height: 30, borderRadius: 999, border: "none",
              backgroundColor: darkMode ? colors.primary : colors.gray100,
              cursor: "pointer", position: "relative", padding: 0,
            }}
          >
            <motion.div
              animate={{ x: darkMode ? 24 : 4 }}
              transition={{ type: "spring", bounce: 0.3, duration: 0.35 }}
              style={{
                width: 22, height: 22, borderRadius: 999,
                backgroundColor: colors.white, position: "absolute", top: 4,
                boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
              }}
            />
          </motion.button>
        </div>

        <Divider />

        <div>
          <div style={{ fontFamily, fontWeight: 700, fontSize: 15, letterSpacing: "-0.04em", color: colors.black, marginBottom: 2 }}>
            Theme Color
          </div>
          <div style={{ fontFamily, fontWeight: 500, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600, marginBottom: 12 }}>
            Accent color used throughout the app
          </div>
          <div style={{ display: "flex", gap: 10 }}>
            {["#5B9EAD", "#E07A5F", "#81B29A", "#F2CC8F", "#3D405B", "#A78BFA"].map((c) => (
              <motion.button
                key={c} whileHover={{ scale: 1.15 }} whileTap={{ scale: 0.9 }}
                style={{
                  width: 32, height: 32, borderRadius: "50%", backgroundColor: c,
                  border: c === colors.primary ? `3px solid ${colors.black}` : `2px solid ${colors.gray400}`,
                  cursor: "pointer", boxShadow: c === colors.primary ? `2px 2px 0px 0px ${colors.black}` : "none",
                }}
              />
            ))}
          </div>
        </div>
      </Card>

      {/* Study Preferences */}
      <Card style={{ flex: 1 }}>
        <SectionHeader>Study Preferences</SectionHeader>

        {/* Focus on weak areas */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 24 }}>
          <div>
            <div style={{ fontFamily, fontWeight: 700, fontSize: 15, letterSpacing: "-0.04em", color: colors.black, marginBottom: 2 }}>
              Focus on Weak Areas
            </div>
            <div style={{ fontFamily, fontWeight: 500, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600 }}>
              Prioritize topics you struggle with in quizzes
            </div>
          </div>
          <motion.button
            onClick={() => setFocusWeakAreas(!focusWeakAreas)}
            whileTap={{ scale: 0.9 }}
            style={{
              width: 52, height: 30, borderRadius: 999, border: "none",
              backgroundColor: focusWeakAreas ? colors.primary : colors.gray100,
              cursor: "pointer", position: "relative", padding: 0,
            }}
          >
            <motion.div
              animate={{ x: focusWeakAreas ? 24 : 4 }}
              transition={{ type: "spring", bounce: 0.3, duration: 0.35 }}
              style={{
                width: 22, height: 22, borderRadius: 999,
                backgroundColor: colors.white, position: "absolute", top: 4,
                boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
              }}
            />
          </motion.button>
        </div>

        {/* Default difficulty */}
        <div style={{ marginBottom: 24 }}>
          <FieldLabel>Default Quiz Difficulty</FieldLabel>
          <div style={{ display: "flex", gap: 8 }}>
            {["easy", "medium", "hard"].map((d) => {
              const selected = defaultDifficulty === d
              return (
                <motion.button
                  key={d} type="button" onClick={() => setDefaultDifficulty(d)}
                  whileHover={{ y: -1 }} whileTap={{ y: 1 }}
                  style={{
                    flex: 1, padding: "10px 0", backgroundColor: selected ? colors.primary : colors.white,
                    border: `1.5px solid ${selected ? colors.primary : colors.gray400}`, borderRadius: 10,
                    fontFamily, fontWeight: 600, fontSize: 13, letterSpacing: "-0.04em",
                    color: selected ? colors.white : colors.black, cursor: "pointer",
                    textTransform: "capitalize",
                  }}
                >
                  {d}
                </motion.button>
              )
            })}
          </div>
        </div>

        {/* Default question count */}
        <div>
          <FieldLabel>Default Question Count</FieldLabel>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <motion.button
              onClick={() => setDefaultQuestionCount(Math.max(5, defaultQuestionCount - 5))}
              whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
              style={{
                width: 36, height: 36, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center",
                border: `1.5px solid ${colors.gray400}`, backgroundColor: colors.white, cursor: "pointer",
                fontFamily, fontWeight: 800, fontSize: 18, color: colors.black,
              }}
            >
              −
            </motion.button>
            <span style={{ fontFamily, fontWeight: 800, fontSize: 20, letterSpacing: "-0.04em", color: colors.black, minWidth: 40, textAlign: "center" }}>
              {defaultQuestionCount}
            </span>
            <motion.button
              onClick={() => setDefaultQuestionCount(Math.min(50, defaultQuestionCount + 5))}
              whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
              style={{
                width: 36, height: 36, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center",
                border: `1.5px solid ${colors.gray400}`, backgroundColor: colors.white, cursor: "pointer",
                fontFamily, fontWeight: 800, fontSize: 18, color: colors.black,
              }}
            >
              +
            </motion.button>
          </div>
        </div>
      </Card>
    </div>
  )
}

// ─── Toggle Row (shared by Privacy tab) ──────────────────

function ToggleRow({
  title,
  description,
  value,
  onChange,
}: {
  title: string
  description: string
  value: boolean
  onChange: (v: boolean) => void
}) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
      <div>
        <div style={{ fontFamily, fontWeight: 700, fontSize: 15, letterSpacing: "-0.04em", color: colors.black, marginBottom: 2 }}>
          {title}
        </div>
        <div style={{ fontFamily, fontWeight: 500, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600 }}>
          {description}
        </div>
      </div>
      <motion.button
        onClick={() => onChange(!value)}
        whileTap={{ scale: 0.9 }}
        style={{
          width: 52, height: 30, borderRadius: 999, border: "none",
          backgroundColor: value ? colors.primary : colors.gray100,
          cursor: "pointer", position: "relative", padding: 0, flexShrink: 0, marginLeft: 16,
        }}
      >
        <motion.div
          animate={{ x: value ? 24 : 4 }}
          transition={{ type: "spring", bounce: 0.3, duration: 0.35 }}
          style={{
            width: 22, height: 22, borderRadius: 999,
            backgroundColor: colors.white, position: "absolute", top: 4,
            boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
          }}
        />
      </motion.button>
    </div>
  )
}

// ─── Link Row (shared by About tab) ──────────────────────

function LinkRow({
  icon,
  label,
  href,
  external,
}: {
  icon: React.ReactNode
  label: string
  href: string
  external?: boolean
}) {
  return (
    <motion.a
      href={href}
      target={external ? "_blank" : undefined}
      rel={external ? "noopener noreferrer" : undefined}
      whileHover={{ backgroundColor: colors.gray100 }}
      style={{
        display: "flex", alignItems: "center", gap: 12, padding: "12px 14px",
        backgroundColor: "transparent", border: `1.5px solid ${colors.gray400}`, borderRadius: 10,
        fontFamily, fontWeight: 600, fontSize: 14, letterSpacing: "-0.04em", color: colors.black,
        cursor: "pointer", textDecoration: "none",
      }}
    >
      {icon}
      <span style={{ flex: 1 }}>{label}</span>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={colors.gray500} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <polyline points="9 18 15 12 9 6" />
      </svg>
    </motion.a>
  )
}

// ─── Privacy Tab ──────────────────────────────────────────

function PrivacyTab({ setToast }: { setToast: (msg: string) => void }) {
  const [usageAnalytics, setUsageAnalytics] = useState(true)
  const [crashReports, setCrashReports] = useState(true)

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20, height: "100%" }}>
      {/* Analytics */}
      <Card>
        <SectionHeader>Analytics</SectionHeader>

        <ToggleRow
          title="Usage Analytics"
          description="Help us improve Reef by sharing anonymous usage data"
          value={usageAnalytics}
          onChange={(v) => { setUsageAnalytics(v); setToast(v ? "Usage analytics enabled" : "Usage analytics disabled") }}
        />

        <Divider />

        <ToggleRow
          title="Crash Reports"
          description="Automatically send crash reports to help us fix bugs"
          value={crashReports}
          onChange={(v) => { setCrashReports(v); setToast(v ? "Crash reports enabled" : "Crash reports disabled") }}
        />
      </Card>

      {/* Your Data */}
      <Card style={{ flex: 1 }}>
        <SectionHeader>Your Data</SectionHeader>

        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <motion.button
            whileHover={{ backgroundColor: colors.gray100 }}
            onClick={() => setToast("Export started — you'll receive an email when it's ready")}
            style={{
              display: "flex", alignItems: "center", gap: 12, padding: "12px 14px",
              backgroundColor: "transparent", border: `1.5px solid ${colors.gray400}`, borderRadius: 10,
              fontFamily, fontWeight: 600, fontSize: 14, letterSpacing: "-0.04em", color: colors.black,
              cursor: "pointer", width: "100%", textAlign: "left",
            }}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="7 10 12 15 17 10" />
              <line x1="12" y1="15" x2="12" y2="3" />
            </svg>
            Export My Data
          </motion.button>

          <motion.button
            whileHover={{ backgroundColor: colors.gray100 }}
            style={{
              display: "flex", alignItems: "center", gap: 12, padding: "12px 14px",
              backgroundColor: "transparent", border: `1.5px solid ${colors.gray400}`, borderRadius: 10,
              fontFamily, fontWeight: 600, fontSize: 14, letterSpacing: "-0.04em", color: colors.black,
              cursor: "pointer", width: "100%", textAlign: "left",
            }}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
              <polyline points="14 2 14 8 20 8" />
              <line x1="16" y1="13" x2="8" y2="13" />
              <line x1="16" y1="17" x2="8" y2="17" />
              <polyline points="10 9 9 9 8 9" />
            </svg>
            What We Collect
          </motion.button>
        </div>

        <Divider />

        <div style={{ fontFamily, fontWeight: 500, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600, lineHeight: 1.5 }}>
          We only collect data necessary to provide and improve Reef. Your documents and study content are never shared with third parties. You can request a full export or deletion of your data at any time.
        </div>
      </Card>
    </div>
  )
}

// ─── About Tab ────────────────────────────────────────────

function AboutTab() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20, height: "100%" }}>
      {/* App Info */}
      <Card>
        <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 20 }}>
          <div
            style={{
              width: 56, height: 56, borderRadius: 14, backgroundColor: colors.primary,
              border: `2px solid ${colors.black}`, boxShadow: `3px 3px 0px 0px ${colors.black}`,
              display: "flex", alignItems: "center", justifyContent: "center",
            }}
          >
            <span style={{ fontFamily, fontWeight: 900, fontSize: 24, color: colors.white }}>R</span>
          </div>
          <div>
            <div style={{ fontFamily, fontWeight: 900, fontSize: 20, letterSpacing: "-0.04em", color: colors.black }}>
              Reef
            </div>
            <div style={{ fontFamily, fontWeight: 500, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600 }}>
              Version 1.0.0
            </div>
          </div>
        </div>
        <div style={{ fontFamily, fontWeight: 500, fontSize: 14, letterSpacing: "-0.04em", color: colors.gray600, lineHeight: 1.6 }}>
          Reef is your AI-powered study companion. Upload documents, organize courses, and master your material with intelligent quizzes and analytics.
        </div>
      </Card>

      {/* Support */}
      <Card>
        <SectionHeader>Support</SectionHeader>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
                <polyline points="22,6 12,13 2,6" />
              </svg>
            }
            label="Contact Support"
            href="mailto:support@studyreef.com"
          />
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="10" />
                <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
                <line x1="12" y1="17" x2="12.01" y2="17" />
              </svg>
            }
            label="Help Center"
            href="https://studyreef.com/help"
            external
          />
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
            }
            label="Report a Bug"
            href="mailto:bugs@studyreef.com?subject=Bug Report"
          />
        </div>
      </Card>

      {/* Social */}
      <Card>
        <SectionHeader>Social</SectionHeader>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
            }
            label="Follow us on X"
            href="https://x.com/studyreef"
            external
          />
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <rect x="2" y="2" width="20" height="20" rx="5" ry="5" />
                <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z" />
                <line x1="17.5" y1="6.5" x2="17.51" y2="6.5" />
              </svg>
            }
            label="Instagram"
            href="https://instagram.com/studyreef"
            external
          />
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03z" />
              </svg>
            }
            label="Discord Community"
            href="https://discord.gg/studyreef"
            external
          />
        </div>
      </Card>

      {/* Legal */}
      <Card>
        <SectionHeader>Legal</SectionHeader>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="16" y1="13" x2="8" y2="13" />
                <line x1="16" y1="17" x2="8" y2="17" />
                <polyline points="10 9 9 9 8 9" />
              </svg>
            }
            label="Terms of Service"
            href="https://studyreef.com/terms"
            external
          />
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              </svg>
            }
            label="Privacy Policy"
            href="https://studyreef.com/privacy"
            external
          />
          <LinkRow
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="16 18 22 12 16 6" />
                <polyline points="8 6 2 12 8 18" />
              </svg>
            }
            label="Open Source Licenses"
            href="https://studyreef.com/licenses"
            external
          />
        </div>
      </Card>
    </div>
  )
}

// ─── Account Tab ──────────────────────────────────────────

function AccountTab({
  handleSignOut,
  signingOut,
  setShowDeleteModal,
}: {
  handleSignOut: () => void
  signingOut: boolean
  setShowDeleteModal: (v: boolean) => void
}) {
  const tier: Tier = "shore"
  const limits = TIER_LIMITS[tier]
  const info = TIER_INFO[tier]

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20, height: "100%" }}>
      {/* Plan */}
      <Card style={{ flex: 1 }}>
        <SectionHeader>Your Plan</SectionHeader>

        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
          <div
            style={{
              display: "inline-flex", alignItems: "center", gap: 8,
              padding: "6px 14px", backgroundColor: info.color, border: `2px solid ${colors.black}`,
              borderRadius: 10, boxShadow: `3px 3px 0px 0px ${colors.black}`,
            }}
          >
            <span style={{ fontFamily, fontWeight: 800, fontSize: 15, letterSpacing: "-0.04em", color: colors.black }}>
              {info.label}
            </span>
          </div>
          <span style={{ fontFamily, fontWeight: 600, fontSize: 14, letterSpacing: "-0.04em", color: colors.gray600 }}>
            {info.price}
          </span>
        </div>

        <UsageBar label="Documents" used={0} max={limits.maxDocuments} />
        <UsageBar label="Courses" used={0} max={limits.maxCourses} />

        <div style={{ marginTop: 4 }}>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
            <span style={{ fontFamily, fontWeight: 600, fontSize: 13, letterSpacing: "-0.04em", color: colors.black }}>
              Max File Size
            </span>
            <span style={{ fontFamily, fontWeight: 600, fontSize: 13, letterSpacing: "-0.04em", color: colors.gray600 }}>
              {limits.maxFileSizeMB} MB
            </span>
          </div>
        </div>

        <Divider />

        <motion.button
          whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 }}
          whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 }}
          transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
          style={{
            width: "100%", padding: "12px 0", backgroundColor: colors.surface,
            border: `2px solid ${colors.black}`, borderRadius: 10,
            boxShadow: `4px 4px 0px 0px ${colors.black}`, fontFamily, fontWeight: 700, fontSize: 14,
            letterSpacing: "-0.04em", color: colors.black, cursor: "pointer", textAlign: "center",
          }}
        >
          Upgrade Plan
        </motion.button>
      </Card>

      {/* Actions */}
      <Card>
        <SectionHeader>Actions</SectionHeader>

        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <motion.button
            onClick={handleSignOut} disabled={signingOut}
            whileHover={{ backgroundColor: colors.gray100 }}
            style={{
              display: "flex", alignItems: "center", gap: 10, padding: "12px 14px",
              backgroundColor: "transparent", border: `1.5px solid ${colors.gray400}`, borderRadius: 10,
              fontFamily, fontWeight: 600, fontSize: 14, letterSpacing: "-0.04em", color: colors.black,
              cursor: signingOut ? "not-allowed" : "pointer", width: "100%", textAlign: "left",
            }}
          >
            <LogOutIcon />
            {signingOut ? "Signing out..." : "Sign Out"}
          </motion.button>

          <motion.button
            onClick={() => setShowDeleteModal(true)}
            whileHover={{ backgroundColor: "#FFF5F5" }}
            style={{
              display: "flex", alignItems: "center", gap: 10, padding: "12px 14px",
              backgroundColor: "transparent", border: `1.5px solid #E57373`, borderRadius: 10,
              fontFamily, fontWeight: 600, fontSize: 14, letterSpacing: "-0.04em", color: "#C62828",
              cursor: "pointer", width: "100%", textAlign: "left",
            }}
          >
            <TrashIcon />
            Delete Account
          </motion.button>
        </div>
      </Card>
    </div>
  )
}

// ─── Main Settings Page ───────────────────────────────────

export default function SettingsPage() {
  const router = useRouter()
  const { profile, setProfile } = useDashboard()
  const [activeTab, setActiveTab] = useState<Tab>("profile")
  const [toast, setToast] = useState<string | null>(null)
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [signingOut, setSigningOut] = useState(false)

  async function handleSignOut() {
    setSigningOut(true)
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push("/auth")
  }

  async function handleDeleteAccount() {
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (user) await fetch(`/api/admin/users/${user.id}`, { method: "DELETE" })
      await supabase.auth.signOut()
      router.push("/")
    } catch {
      setToast("Failed to delete account")
      setShowDeleteModal(false)
    }
  }

  return (
    <>
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
        style={{ display: "flex", flexDirection: "column", height: "100%" }}
      >
        {/* Header + Tabs */}
        <div style={{ marginBottom: 28, flexShrink: 0 }}>
          <h2 style={{ fontFamily, fontWeight: 900, fontSize: 24, letterSpacing: "-0.04em", color: colors.black, margin: 0, marginBottom: 20 }}>
            Settings
          </h2>

          {/* Tabs */}
          <div style={{ display: "flex", gap: 10 }}>
            {TABS.map((tab) => {
              const active = activeTab === tab.key
              return (
                <motion.button
                  key={tab.key}
                  onClick={() => setActiveTab(tab.key)}
                  whileHover={active ? {} : { boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 1, y: 1 }}
                  whileTap={active ? {} : { boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 3, y: 3 }}
                  transition={{ type: "spring", bounce: 0.2, duration: 0.3 }}
                  style={{
                    display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
                    padding: "10px 20px", cursor: "pointer",
                    fontFamily, fontWeight: 700, fontSize: 14, letterSpacing: "-0.04em",
                    border: `2px solid ${colors.black}`, borderRadius: 10,
                    backgroundColor: active ? colors.primary : colors.white,
                    color: active ? colors.white : colors.black,
                    boxShadow: active ? `3px 3px 0px 0px ${colors.black}` : `4px 4px 0px 0px ${colors.black}`,
                  }}
                >
                  {tab.icon}
                  {tab.label}
                </motion.button>
              )
            })}
          </div>
        </div>

        {/* Tab Content */}
        <div style={{ flex: 1, minHeight: 0, overflowY: "auto", paddingBottom: 24 }}>
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, x: 12 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -12 }}
              transition={{ duration: 0.2 }}
              style={{ height: "100%" }}
            >
              {activeTab === "profile" && (
                <ProfileTab profile={profile} setProfile={setProfile} setToast={setToast} />
              )}
              {activeTab === "preferences" && (
                <PreferencesTab setToast={setToast} />
              )}
              {activeTab === "privacy" && (
                <PrivacyTab setToast={setToast} />
              )}
              {activeTab === "about" && (
                <AboutTab />
              )}
              {activeTab === "account" && (
                <AccountTab handleSignOut={handleSignOut} signingOut={signingOut} setShowDeleteModal={setShowDeleteModal} />
              )}
            </motion.div>
          </AnimatePresence>
        </div>
      </motion.div>

      <AnimatePresence>
        {showDeleteModal && <DeleteConfirmModal onConfirm={handleDeleteAccount} onClose={() => setShowDeleteModal(false)} />}
      </AnimatePresence>

      <AnimatePresence>
        {toast && <Toast message={toast} onDone={() => setToast(null)} />}
      </AnimatePresence>
    </>
  )
}
