"use client"

import { useState, useEffect, useRef } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../../lib/colors"
import { listCourses, createCourse, updateCourse, deleteCourse, type Course, type CourseInsert, type CourseUpdate } from "../../../lib/courses"

const fontFamily = `"Epilogue", sans-serif`

const EMOJI_OPTIONS = [
  "📐", "🧪", "💻", "📊", "🔬", "📝", "🧮", "🎨",
  "🌍", "📖", "🧬", "⚡", "🏛️", "🎵", "💰", "🔧",
  "📈", "🧠", "🌿", "🔢", "💡", "🏗️", "📚", "✏️",
]

const COLOR_PRESETS = [
  "#5B9EAD", "#E07A5F", "#81B29A", "#F2CC8F",
  "#3D405B", "#A78BFA", "#F87171", "#34D399",
]

// ─── Icons ────────────────────────────────────────────────

function PlusIcon({ size = 24 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  )
}

function DotsIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="5" r="1" />
      <circle cx="12" cy="12" r="1" />
      <circle cx="12" cy="19" r="1" />
    </svg>
  )
}

function EmptyCoursesIcon() {
  return (
    <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke={colors.gray400} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
      <line x1="12" y1="8" x2="12" y2="14" />
      <line x1="9" y1="11" x2="15" y2="11" />
    </svg>
  )
}

// ─── Dropdown Menu ────────────────────────────────────────

function DropdownMenu({ onEdit, onDelete, onClose }: { onEdit: () => void; onDelete: () => void; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) onClose()
    }
    document.addEventListener("mousedown", handleClick)
    return () => document.removeEventListener("mousedown", handleClick)
  }, [onClose])

  const itemStyle: React.CSSProperties = {
    display: "block",
    width: "100%",
    padding: "8px 14px",
    background: "none",
    border: "none",
    fontFamily,
    fontWeight: 600,
    fontSize: 13,
    letterSpacing: "-0.04em",
    color: colors.black,
    cursor: "pointer",
    textAlign: "left",
  }

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, scale: 0.95, y: -4 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.95, y: -4 }}
      transition={{ duration: 0.15 }}
      style={{
        position: "absolute",
        top: 36,
        right: 0,
        backgroundColor: colors.white,
        border: `1.5px solid ${colors.gray500}`,
        borderRadius: 10,
        boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
        overflow: "hidden",
        zIndex: 10,
        minWidth: 120,
      }}
    >
      <button
        onClick={() => { onEdit(); onClose() }}
        onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.gray100)}
        onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
        style={itemStyle}
      >
        Edit
      </button>
      <button
        onClick={() => { onDelete(); onClose() }}
        onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = "#FDECEA")}
        onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
        style={{ ...itemStyle, color: "#C62828" }}
      >
        Delete
      </button>
    </motion.div>
  )
}

// ─── Course Card ──────────────────────────────────────────

function CourseCard({
  course,
  index,
  onEdit,
  onDelete,
}: {
  course: Course
  index: number
  onEdit: (c: Course) => void
  onDelete: (c: Course) => void
}) {
  const [menuOpen, setMenuOpen] = useState(false)

  const dateStr = new Date(course.created_at).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  })

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: 0.1 + index * 0.05 }}
      whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.gray500}`, x: 2, y: 2, transition: { duration: 0.15 } }}
      whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.gray500}`, x: 4, y: 4, transition: { duration: 0.1 } }}
      style={{
        position: "relative",
        backgroundColor: colors.white,
        border: `1.5px solid ${colors.gray500}`,
        borderRadius: 16,
        boxShadow: `4px 4px 0px 0px ${colors.gray500}`,
        padding: "24px 20px",
        cursor: "default",
        overflow: "hidden",
      }}
    >
      {/* Left accent strip */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          width: 4,
          height: "100%",
          backgroundColor: course.color,
          borderRadius: "16px 0 0 16px",
        }}
      />

      {/* 3-dot menu button */}
      <div style={{ position: "absolute", top: 12, right: 12 }}>
        <motion.button
          onClick={(e) => { e.stopPropagation(); setMenuOpen(!menuOpen) }}
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.95 }}
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: 28,
            height: 28,
            borderRadius: 8,
            border: `1.5px solid ${colors.gray400}`,
            backgroundColor: colors.white,
            boxShadow: `2px 2px 0px 0px ${colors.gray500}`,
            color: colors.gray500,
            cursor: "pointer",
          }}
        >
          <DotsIcon />
        </motion.button>
        <AnimatePresence>
          {menuOpen && (
            <DropdownMenu
              onEdit={() => onEdit(course)}
              onDelete={() => onDelete(course)}
              onClose={() => setMenuOpen(false)}
            />
          )}
        </AnimatePresence>
      </div>

      {/* Emoji */}
      <div style={{ fontSize: 32, marginBottom: 12 }}>{course.emoji}</div>

      {/* Name */}
      <div
        style={{
          fontFamily,
          fontWeight: 700,
          fontSize: 16,
          letterSpacing: "-0.04em",
          color: colors.black,
          marginBottom: 4,
          overflow: "hidden",
          textOverflow: "ellipsis",
          whiteSpace: "nowrap",
          paddingRight: 28,
        }}
      >
        {course.name}
      </div>

      {/* Doc count */}
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
        0 documents
      </div>

      {/* Date */}
      <div
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 12,
          letterSpacing: "-0.04em",
          color: colors.gray400,
        }}
      >
        {dateStr}
      </div>
    </motion.div>
  )
}

// ─── Add Course Card ──────────────────────────────────────

function AddCourseCard({ onClick }: { onClick: () => void }) {
  return (
    <motion.button
      onClick={onClick}
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: 0.05 }}
      whileHover={{ borderColor: colors.gray500 }}
      whileTap={{ borderColor: colors.gray600 }}
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
        backgroundColor: "transparent",
        border: `2px dashed ${colors.gray400}`,
        borderRadius: 16,
        padding: "24px 20px",
        minHeight: 140,
        cursor: "pointer",
        color: colors.gray500,
        fontFamily,
        fontWeight: 600,
        fontSize: 14,
        letterSpacing: "-0.04em",
      }}
    >
      <PlusIcon />
      Add Course
    </motion.button>
  )
}

// ─── Course Modal (Create / Edit) ─────────────────────────

function CourseModal({
  course,
  onSave,
  onClose,
}: {
  course: Course | null
  onSave: (data: CourseInsert | (CourseUpdate & { id: string })) => void
  onClose: () => void
}) {
  const isEdit = course !== null
  const [name, setName] = useState(course?.name ?? "")
  const [emoji, setEmoji] = useState(course?.emoji ?? "📚")
  const [selectedColor, setSelectedColor] = useState(course?.color ?? COLOR_PRESETS[0])
  const [saving, setSaving] = useState(false)

  const canSave = name.trim().length > 0

  async function handleSubmit() {
    if (!canSave || saving) return
    setSaving(true)
    if (isEdit) {
      onSave({ id: course.id, name: name.trim(), emoji, color: selectedColor })
    } else {
      onSave({ name: name.trim(), emoji, color: selectedColor })
    }
  }

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
          width: 420,
          maxWidth: "100%",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 12,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          padding: "36px 32px",
          boxSizing: "border-box",
        }}
      >
        <h3
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 22,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 24,
          }}
        >
          {isEdit ? "Edit Course" : "New Course"}
        </h3>

        {/* Name input */}
        <label
          style={{
            fontFamily,
            fontWeight: 600,
            fontSize: 13,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            display: "block",
            marginBottom: 6,
          }}
        >
          Course name
        </label>
        <input
          autoFocus
          value={name}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter") handleSubmit() }}
          placeholder="e.g. Calculus II"
          style={{
            width: "100%",
            padding: "10px 14px",
            fontFamily,
            fontWeight: 600,
            fontSize: 15,
            letterSpacing: "-0.04em",
            color: colors.black,
            border: `1.5px solid ${colors.gray400}`,
            borderRadius: 10,
            outline: "none",
            boxSizing: "border-box",
            marginBottom: 20,
          }}
        />

        {/* Emoji picker */}
        <label
          style={{
            fontFamily,
            fontWeight: 600,
            fontSize: 13,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            display: "block",
            marginBottom: 8,
          }}
        >
          Icon
        </label>
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            gap: 6,
            marginBottom: 20,
          }}
        >
          {EMOJI_OPTIONS.map((em) => {
            const selected = emoji === em
            return (
              <motion.button
                key={em}
                type="button"
                onClick={() => setEmoji(em)}
                whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 1, y: 1 }}
                whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 3, y: 3 }}
                transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
                style={{
                  width: 40,
                  height: 40,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontSize: 20,
                  backgroundColor: selected ? colors.primary : colors.white,
                  border: `2px solid ${colors.black}`,
                  borderRadius: 10,
                  boxShadow: `3px 3px 0px 0px ${colors.black}`,
                  cursor: "pointer",
                }}
              >
                {em}
              </motion.button>
            )
          })}
        </div>

        {/* Color picker */}
        <label
          style={{
            fontFamily,
            fontWeight: 600,
            fontSize: 13,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            display: "block",
            marginBottom: 8,
          }}
        >
          Accent color
        </label>
        <div
          style={{
            display: "flex",
            gap: 10,
            marginBottom: 28,
          }}
        >
          {COLOR_PRESETS.map((c) => (
            <motion.button
              key={c}
              type="button"
              onClick={() => setSelectedColor(c)}
              whileHover={{ scale: 1.15 }}
              whileTap={{ scale: 0.9 }}
              style={{
                width: 32,
                height: 32,
                borderRadius: "50%",
                backgroundColor: c,
                border: selectedColor === c ? `3px solid ${colors.black}` : `2px solid ${colors.gray400}`,
                cursor: "pointer",
                boxShadow: selectedColor === c ? `2px 2px 0px 0px ${colors.black}` : "none",
              }}
            />
          ))}
        </div>

        {/* Buttons */}
        <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
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
            onClick={handleSubmit}
            disabled={!canSave || saving}
            whileHover={canSave ? { boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 } : {}}
            whileTap={canSave ? { boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 } : {}}
            transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
            style={{
              padding: "10px 24px",
              backgroundColor: canSave ? colors.primary : colors.gray100,
              border: `2px solid ${colors.black}`,
              borderRadius: 10,
              boxShadow: `4px 4px 0px 0px ${colors.black}`,
              fontFamily,
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: "-0.04em",
              color: canSave ? colors.white : colors.gray500,
              cursor: canSave ? "pointer" : "not-allowed",
            }}
          >
            {saving ? "Saving..." : isEdit ? "Save" : "Create"}
          </motion.button>
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Delete Confirm Modal ─────────────────────────────────

function DeleteConfirmModal({
  course,
  onConfirm,
  onClose,
}: {
  course: Course
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
          width: 360,
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
        <div style={{ fontSize: 40, marginBottom: 16 }}>{course.emoji}</div>
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
          Delete {course.name}?
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
          This action cannot be undone.
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
            onClick={() => { setDeleting(true); onConfirm() }}
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
            {deleting ? "Deleting..." : "Delete"}
          </motion.button>
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Loading Skeleton ─────────────────────────────────────

function LoadingSkeleton() {
  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
        gap: 16,
        marginTop: 8,
      }}
    >
      {[0, 1, 2].map((i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.3, delay: i * 0.1 }}
          style={{
            backgroundColor: colors.gray100,
            borderRadius: 16,
            padding: "24px 20px",
            minHeight: 140,
          }}
        >
          <div style={{ width: 32, height: 32, backgroundColor: colors.white, borderRadius: 8, marginBottom: 12, opacity: 0.6 }} />
          <div style={{ width: "70%", height: 16, backgroundColor: colors.white, borderRadius: 6, marginBottom: 8, opacity: 0.6 }} />
          <div style={{ width: "40%", height: 12, backgroundColor: colors.white, borderRadius: 6, opacity: 0.6 }} />
        </motion.div>
      ))}
    </div>
  )
}

// ─── Empty State ──────────────────────────────────────────

function EmptyState({ onAdd }: { onAdd: () => void }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: 0.15 }}
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "80px 24px",
        border: `2px dashed ${colors.gray400}`,
        borderRadius: 16,
        marginTop: 8,
      }}
    >
      <EmptyCoursesIcon />
      <h3
        style={{
          fontFamily,
          fontWeight: 800,
          fontSize: 18,
          letterSpacing: "-0.04em",
          color: colors.black,
          margin: "20px 0 6px",
        }}
      >
        No courses yet
      </h3>
      <p
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 14,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          margin: "0 0 24px",
        }}
      >
        Create a course to organize your documents.
      </p>
      <motion.button
        onClick={onAdd}
        whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 }}
        whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 }}
        transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 8,
          padding: "10px 20px",
          backgroundColor: colors.primary,
          color: colors.white,
          fontFamily,
          fontWeight: 700,
          fontSize: 14,
          letterSpacing: "-0.04em",
          border: `1.5px solid ${colors.black}`,
          borderRadius: 10,
          boxShadow: `4px 4px 0px 0px ${colors.black}`,
          cursor: "pointer",
        }}
      >
        <PlusIcon size={16} />
        New Course
      </motion.button>
    </motion.div>
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

// ─── Main Page ────────────────────────────────────────────

export default function CoursesPage() {
  const [courses, setCourses] = useState<Course[]>([])
  const [loading, setLoading] = useState(true)
  const [modalOpen, setModalOpen] = useState(false)
  const [editingCourse, setEditingCourse] = useState<Course | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<Course | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  async function fetchCourses() {
    try {
      const data = await listCourses()
      setCourses(data)
    } catch (err) {
      console.error("Failed to fetch courses:", err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchCourses() }, [])

  function openCreate() {
    setEditingCourse(null)
    setModalOpen(true)
  }

  function openEdit(course: Course) {
    setEditingCourse(course)
    setModalOpen(true)
  }

  async function handleSave(data: CourseInsert | (CourseUpdate & { id: string })) {
    try {
      if ("id" in data) {
        const { id, ...fields } = data
        await updateCourse(id, fields)
        setToast("Course updated")
      } else {
        await createCourse(data as CourseInsert)
        setToast("Course created")
      }
      setModalOpen(false)
      setEditingCourse(null)
      await fetchCourses()
    } catch (err) {
      console.error("Failed to save course:", err)
      setToast("Something went wrong")
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return
    try {
      await deleteCourse(deleteTarget.id)
      setToast("Course deleted")
      setDeleteTarget(null)
      await fetchCourses()
    } catch (err) {
      console.error("Failed to delete course:", err)
      setToast("Something went wrong")
    }
  }

  return (
    <>
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
      >
        {/* Header */}
        <div
          style={{
            display: "flex",
            alignItems: "flex-start",
            justifyContent: "space-between",
            marginBottom: 28,
          }}
        >
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 4 }}>
              <h2
                style={{
                  fontFamily,
                  fontWeight: 900,
                  fontSize: 24,
                  letterSpacing: "-0.04em",
                  color: colors.black,
                  margin: 0,
                }}
              >
                Your Courses
              </h2>
              {!loading && courses.length > 0 && (
                <span
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    justifyContent: "center",
                    padding: "2px 10px",
                    backgroundColor: colors.accent,
                    borderRadius: 999,
                    fontFamily,
                    fontWeight: 700,
                    fontSize: 12,
                    letterSpacing: "-0.04em",
                    color: colors.black,
                  }}
                >
                  {courses.length}
                </span>
              )}
            </div>
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
              Organize your documents by course
            </p>
          </div>
          {!loading && courses.length > 0 && (
            <motion.button
              onClick={openCreate}
              whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.black}`, x: 2, y: 2 }}
              whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.black}`, x: 4, y: 4 }}
              transition={{ type: "spring", bounce: 0.2, duration: 0.4 }}
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 8,
                padding: "10px 20px",
                backgroundColor: colors.primary,
                color: colors.white,
                fontFamily,
                fontWeight: 700,
                fontSize: 14,
                letterSpacing: "-0.04em",
                border: `1.5px solid ${colors.black}`,
                borderRadius: 10,
                boxShadow: `4px 4px 0px 0px ${colors.black}`,
                cursor: "pointer",
              }}
            >
              <PlusIcon size={16} />
              New Course
            </motion.button>
          )}
        </div>

        {/* Content */}
        {loading ? (
          <LoadingSkeleton />
        ) : courses.length === 0 ? (
          <EmptyState onAdd={openCreate} />
        ) : (
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
              gap: 16,
            }}
          >
            <AddCourseCard onClick={openCreate} />
            {courses.map((course, i) => (
              <CourseCard
                key={course.id}
                course={course}
                index={i}
                onEdit={openEdit}
                onDelete={setDeleteTarget}
              />
            ))}
          </div>
        )}
      </motion.div>

      {/* Modals */}
      <AnimatePresence>
        {modalOpen && (
          <CourseModal
            course={editingCourse}
            onSave={handleSave}
            onClose={() => { setModalOpen(false); setEditingCourse(null) }}
          />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {deleteTarget && (
          <DeleteConfirmModal
            course={deleteTarget}
            onConfirm={handleDelete}
            onClose={() => setDeleteTarget(null)}
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
