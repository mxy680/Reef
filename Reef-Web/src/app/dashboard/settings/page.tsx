"use client"

import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../../lib/colors"
import { upsertProfile } from "../../../lib/profiles"
import { createClient } from "../../../lib/supabase/client"
import { useDashboard } from "../../../components/dashboard/DashboardContext"

const fontFamily = `"Epilogue", sans-serif`

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

// ─── Section Header ───────────────────────────────────────

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

// ─── Toast ────────────────────────────────────────────────

function Toast({ message, onDone }: { message: string; onDone: () => void }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: 12 }}
      transition={{ duration: 0.25 }}
      onAnimationComplete={(def: { opacity?: number }) => {
        if (def.opacity === 1) {
          setTimeout(onDone, 2500)
        }
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

// ─── Delete Confirm Modal ─────────────────────────────────

function DeleteConfirmModal({
  onConfirm,
  onClose,
}: {
  onConfirm: () => void
  onClose: () => void
}) {
  const [deleting, setDeleting] = useState(false)

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.2 }}
      onClick={onClose}
      style={{
        position: "fixed",
        inset: 0,
        backgroundColor: "rgba(0,0,0,0.3)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        zIndex: 100,
        padding: 24,
      }}
    >
      <motion.div
        initial={{ opacity: 0, y: 20, scale: 0.97 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 20, scale: 0.97 }}
        transition={{ duration: 0.25 }}
        onClick={(e) => e.stopPropagation()}
        style={{
          width: 380,
          maxWidth: "100%",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 12,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          padding: "36px 32px",
          boxSizing: "border-box",
          textAlign: "center",
        }}
      >
        <div style={{ fontSize: 40, marginBottom: 16 }}>🗑️</div>
        <h3
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 20,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 8,
          }}
        >
          Delete your account?
        </h3>
        <p
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            margin: 0,
            marginBottom: 24,
          }}
        >
          This action cannot be undone. All your data, documents, and courses will be permanently deleted.
        </p>
        <div style={{ display: "flex", justifyContent: "center", gap: 10 }}>
          <button
            type="button"
            onClick={onClose}
            style={{
              padding: "10px 20px",
              background: "none",
              border: "none",
              fontFamily,
              fontWeight: 600,
              fontSize: 14,
              letterSpacing: "-0.04em",
              color: colors.gray600,
              cursor: "pointer",
            }}
          >
            Cancel
          </button>
          <motion.button
            type="button"
            onClick={() => {
              setDeleting(true)
              onConfirm()
            }}
            disabled={deleting}
            whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 }}
            whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 }}
            transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
            style={{
              padding: "10px 24px",
              backgroundColor: "#C62828",
              border: `2px solid ${colors.black}`,
              borderRadius: 10,
              boxShadow: `4px 4px 0px 0px ${colors.black}`,
              fontFamily,
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: "-0.04em",
              color: colors.white,
              cursor: deleting ? "not-allowed" : "pointer",
            }}
          >
            {deleting ? "Deleting..." : "Delete Account"}
          </motion.button>
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Main Settings Page ───────────────────────────────────

export default function SettingsPage() {
  const router = useRouter()
  const { profile, setProfile } = useDashboard()

  // Local editable state
  const [name, setName] = useState(profile.display_name)
  const [grade, setGrade] = useState(profile.grade)
  const [subjects, setSubjects] = useState<string[]>(profile.subjects)
  const [editingName, setEditingName] = useState(false)
  const [saving, setSaving] = useState(false)
  const [toast, setToast] = useState<string | null>(null)
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  const nameInputRef = useRef<HTMLInputElement>(null)

  // Track dirty state
  const isDirty =
    grade !== profile.grade ||
    JSON.stringify(subjects.sort()) !== JSON.stringify([...profile.subjects].sort())

  useEffect(() => {
    if (editingName && nameInputRef.current) {
      nameInputRef.current.focus()
    }
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
      if (user) {
        await fetch(`/api/admin/users/${user.id}`, { method: "DELETE" })
      }
      await supabase.auth.signOut()
      router.push("/")
    } catch {
      setToast("Failed to delete account")
      setShowDeleteModal(false)
    }
  }

  function toggleSubject(subject: string) {
    if (subjects.includes(subject)) {
      setSubjects(subjects.filter((s) => s !== subject))
    } else {
      setSubjects([...subjects, subject])
    }
  }

  return (
    <>
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
        style={{ maxWidth: 640 }}
      >
        {/* Header */}
        <div style={{ marginBottom: 32 }}>
          <h2
            style={{
              fontFamily,
              fontWeight: 900,
              fontSize: 24,
              letterSpacing: "-0.04em",
              color: colors.black,
              margin: 0,
              marginBottom: 4,
            }}
          >
            Settings
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
            Manage your profile and account
          </p>
        </div>

        {/* ─── Profile Card ─────────────────────────────── */}
        <div
          style={{
            backgroundColor: colors.white,
            border: `1.5px solid ${colors.gray500}`,
            borderRadius: 16,
            boxShadow: `4px 4px 0px 0px ${colors.gray500}`,
            padding: "28px 24px",
            marginBottom: 16,
          }}
        >
          <SectionHeader>Profile</SectionHeader>

          {/* Name */}
          <div style={{ marginBottom: 20 }}>
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
              Name
            </div>
            {editingName ? (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <input
                  ref={nameInputRef}
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleSaveName()
                    if (e.key === "Escape") {
                      setName(profile.display_name)
                      setEditingName(false)
                    }
                  }}
                  style={{
                    flex: 1,
                    padding: "8px 12px",
                    fontFamily,
                    fontWeight: 600,
                    fontSize: 15,
                    letterSpacing: "-0.04em",
                    color: colors.black,
                    border: `1.5px solid ${colors.primary}`,
                    borderRadius: 8,
                    outline: "none",
                    boxSizing: "border-box",
                  }}
                />
                <motion.button
                  onClick={handleSaveName}
                  disabled={saving}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 32,
                    height: 32,
                    borderRadius: 8,
                    backgroundColor: colors.primary,
                    border: "none",
                    color: colors.white,
                    cursor: "pointer",
                  }}
                >
                  <CheckIcon />
                </motion.button>
                <motion.button
                  onClick={() => {
                    setName(profile.display_name)
                    setEditingName(false)
                  }}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 32,
                    height: 32,
                    borderRadius: 8,
                    backgroundColor: colors.gray100,
                    border: "none",
                    color: colors.gray600,
                    cursor: "pointer",
                  }}
                >
                  <XIcon />
                </motion.button>
              </div>
            ) : (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span
                  style={{
                    fontFamily,
                    fontWeight: 700,
                    fontSize: 16,
                    letterSpacing: "-0.04em",
                    color: colors.black,
                  }}
                >
                  {profile.display_name}
                </span>
                <motion.button
                  onClick={() => setEditingName(true)}
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 28,
                    height: 28,
                    borderRadius: 6,
                    backgroundColor: "transparent",
                    border: "none",
                    color: colors.gray500,
                    cursor: "pointer",
                  }}
                >
                  <PencilIcon />
                </motion.button>
              </div>
            )}
          </div>

          {/* Email */}
          <div style={{ marginBottom: 24 }}>
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
              Email
            </div>
            <span
              style={{
                fontFamily,
                fontWeight: 700,
                fontSize: 16,
                letterSpacing: "-0.04em",
                color: colors.black,
              }}
            >
              {profile.email}
            </span>
          </div>

          <div
            style={{
              height: 1,
              backgroundColor: colors.gray100,
              margin: "0 -24px 24px",
            }}
          />

          {/* Grade */}
          <div style={{ marginBottom: 24 }}>
            <div
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 13,
                letterSpacing: "-0.04em",
                color: colors.gray600,
                marginBottom: 10,
              }}
            >
              Grade
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              {GRADES.map((g) => {
                const selected = grade === g.value
                return (
                  <motion.button
                    key={g.value}
                    type="button"
                    onClick={() => setGrade(g.value)}
                    whileHover={{ y: -1 }}
                    whileTap={{ y: 1 }}
                    style={{
                      padding: "8px 16px",
                      backgroundColor: selected ? colors.primary : colors.white,
                      border: `1.5px solid ${selected ? colors.primary : colors.gray400}`,
                      borderRadius: 10,
                      fontFamily,
                      fontWeight: 600,
                      fontSize: 13,
                      letterSpacing: "-0.04em",
                      color: selected ? colors.white : colors.black,
                      cursor: "pointer",
                    }}
                  >
                    {g.label}
                  </motion.button>
                )
              })}
            </div>
          </div>

          {/* Subjects */}
          <div style={{ marginBottom: isDirty ? 24 : 0 }}>
            <div
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 13,
                letterSpacing: "-0.04em",
                color: colors.gray600,
                marginBottom: 10,
              }}
            >
              Subjects
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              {SUBJECTS.map((subject) => {
                const selected = subjects.includes(subject)
                return (
                  <motion.button
                    key={subject}
                    type="button"
                    onClick={() => toggleSubject(subject)}
                    whileHover={{ y: -1 }}
                    whileTap={{ y: 1 }}
                    style={{
                      padding: "6px 14px",
                      backgroundColor: selected ? colors.primary : colors.white,
                      border: `1.5px solid ${selected ? colors.primary : colors.gray400}`,
                      borderRadius: 999,
                      fontFamily,
                      fontWeight: 600,
                      fontSize: 13,
                      letterSpacing: "-0.04em",
                      color: selected ? colors.white : colors.black,
                      cursor: "pointer",
                    }}
                  >
                    {subject}
                  </motion.button>
                )
              })}
            </div>
          </div>

          {/* Save button — only visible when dirty */}
          <AnimatePresence>
            {isDirty && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                transition={{ duration: 0.2 }}
                style={{ overflow: "hidden" }}
              >
                <div style={{ display: "flex", justifyContent: "flex-end", paddingTop: 4 }}>
                  <motion.button
                    onClick={handleSaveProfile}
                    disabled={saving || subjects.length === 0}
                    whileHover={
                      subjects.length > 0
                        ? { boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 }
                        : {}
                    }
                    whileTap={
                      subjects.length > 0
                        ? { boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 }
                        : {}
                    }
                    transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
                    style={{
                      padding: "10px 24px",
                      backgroundColor: subjects.length > 0 ? colors.primary : colors.gray100,
                      border: `2px solid ${colors.black}`,
                      borderRadius: 10,
                      boxShadow: `4px 4px 0px 0px ${colors.black}`,
                      fontFamily,
                      fontWeight: 700,
                      fontSize: 14,
                      letterSpacing: "-0.04em",
                      color: subjects.length > 0 ? colors.white : colors.gray500,
                      cursor: subjects.length > 0 ? "pointer" : "not-allowed",
                    }}
                  >
                    {saving ? "Saving..." : "Save Changes"}
                  </motion.button>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* ─── Account Card ─────────────────────────────── */}
        <div
          style={{
            backgroundColor: colors.white,
            border: `1.5px solid ${colors.gray500}`,
            borderRadius: 16,
            boxShadow: `4px 4px 0px 0px ${colors.gray500}`,
            padding: "28px 24px",
          }}
        >
          <SectionHeader>Account</SectionHeader>

          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {/* Sign Out */}
            <motion.button
              onClick={handleSignOut}
              disabled={signingOut}
              whileHover={{ backgroundColor: colors.gray100 }}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                padding: "12px 14px",
                backgroundColor: "transparent",
                border: `1.5px solid ${colors.gray400}`,
                borderRadius: 10,
                fontFamily,
                fontWeight: 600,
                fontSize: 14,
                letterSpacing: "-0.04em",
                color: colors.black,
                cursor: signingOut ? "not-allowed" : "pointer",
                width: "100%",
                textAlign: "left",
              }}
            >
              <LogOutIcon />
              {signingOut ? "Signing out..." : "Sign Out"}
            </motion.button>

            {/* Delete Account */}
            <motion.button
              onClick={() => setShowDeleteModal(true)}
              whileHover={{ backgroundColor: "#FFF5F5" }}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                padding: "12px 14px",
                backgroundColor: "transparent",
                border: `1.5px solid #E57373`,
                borderRadius: 10,
                fontFamily,
                fontWeight: 600,
                fontSize: 14,
                letterSpacing: "-0.04em",
                color: "#C62828",
                cursor: "pointer",
                width: "100%",
                textAlign: "left",
              }}
            >
              <TrashIcon />
              Delete Account
            </motion.button>
          </div>
        </div>
      </motion.div>

      {/* Delete Confirmation Modal */}
      <AnimatePresence>
        {showDeleteModal && (
          <DeleteConfirmModal
            onConfirm={handleDeleteAccount}
            onClose={() => setShowDeleteModal(false)}
          />
        )}
      </AnimatePresence>

      {/* Toast */}
      <AnimatePresence>
        {toast && <Toast message={toast} onDone={() => setToast(null)} />}
      </AnimatePresence>
    </>
  )
}
