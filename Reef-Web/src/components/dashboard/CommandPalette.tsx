"use client"

import { useState, useEffect, useRef, useCallback } from "react"
import { useRouter } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../lib/colors"
import { listDocuments, type Document } from "../../lib/documents"
import { listCourses, type Course } from "../../lib/courses"
import { useDashboard } from "./DashboardContext"

const fontFamily = `"Epilogue", sans-serif`

// -- Icons -------------------------------------------------------------------

function SearchIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke={colors.gray400} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="9" cy="9" r="6" />
      <line x1="13.5" y1="13.5" x2="17" y2="17" />
    </svg>
  )
}

function PageIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="1" width="12" height="14" rx="2" />
      <line x1="5" y1="5" x2="11" y2="5" />
      <line x1="5" y1="8" x2="11" y2="8" />
      <line x1="5" y1="11" x2="8" y2="11" />
    </svg>
  )
}

function DocumentIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 1.5 H10 L13 4.5 V14.5 H3 Z" />
      <polyline points="10,1.5 10,4.5 13,4.5" />
    </svg>
  )
}

function CourseIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M1.5 3 L8 6 L14.5 3 L8 0 Z" />
      <path d="M1.5 3 V10 L8 13 L14.5 10 V3" />
      <line x1="8" y1="6" x2="8" y2="13" />
    </svg>
  )
}

// -- Types -------------------------------------------------------------------

interface ResultItem {
  id: string
  type: "navigation" | "document" | "course"
  label: string
  subtitle?: string
  href: string
  icon: React.ReactNode
}

// -- Nav items (mirrors sidebar) ---------------------------------------------

const NAV_RESULTS: ResultItem[] = [
  { id: "nav-documents", type: "navigation", label: "Documents", href: "/dashboard/documents", icon: <PageIcon /> },
  { id: "nav-courses", type: "navigation", label: "Courses", href: "/dashboard/courses", icon: <PageIcon /> },
  { id: "nav-analytics", type: "navigation", label: "Analytics", href: "/dashboard/analytics", icon: <PageIcon /> },
  { id: "nav-reef", type: "navigation", label: "My Reef", href: "/dashboard/reef", icon: <PageIcon /> },
  { id: "nav-library", type: "navigation", label: "Library", href: "/dashboard/library", icon: <PageIcon /> },
  { id: "nav-help", type: "navigation", label: "Help", href: "/dashboard/help", icon: <PageIcon /> },
  { id: "nav-billing", type: "navigation", label: "Billing", href: "/dashboard/billing", icon: <PageIcon /> },
  { id: "nav-settings", type: "navigation", label: "Settings", href: "/dashboard/settings", icon: <PageIcon /> },
]

// -- Component ---------------------------------------------------------------

export default function CommandPalette() {
  const { isMobile, commandPaletteOpen, closeCommandPalette } = useDashboard()
  const router = useRouter()
  const inputRef = useRef<HTMLInputElement>(null)

  const [query, setQuery] = useState("")
  const [activeIndex, setActiveIndex] = useState(0)
  const [documents, setDocuments] = useState<Document[] | null>(null)
  const [courses, setCourses] = useState<Course[] | null>(null)
  const [loading, setLoading] = useState(false)
  const [fetched, setFetched] = useState(false)

  // Fetch data on first open
  useEffect(() => {
    if (!commandPaletteOpen || fetched) return
    setLoading(true)
    Promise.all([listDocuments(), listCourses()])
      .then(([docs, crs]) => {
        setDocuments(docs)
        setCourses(crs)
      })
      .catch(() => {
        setDocuments([])
        setCourses([])
      })
      .finally(() => {
        setLoading(false)
        setFetched(true)
      })
  }, [commandPaletteOpen, fetched])

  // Lock body scroll while open
  useEffect(() => {
    if (!commandPaletteOpen) return
    const prev = document.body.style.overflow
    document.body.style.overflow = "hidden"
    return () => { document.body.style.overflow = prev }
  }, [commandPaletteOpen])

  // Reset state when closing
  useEffect(() => {
    if (!commandPaletteOpen) {
      setQuery("")
      setActiveIndex(0)
    }
  }, [commandPaletteOpen])

  // Build filtered results
  const lowerQuery = query.toLowerCase().trim()

  const filteredNav = NAV_RESULTS.filter(
    (r) => !lowerQuery || r.label.toLowerCase().includes(lowerQuery)
  )

  const docResults: ResultItem[] = (documents ?? [])
    .filter((d) => !lowerQuery || d.filename.toLowerCase().includes(lowerQuery))
    .map((d) => ({
      id: `doc-${d.id}`,
      type: "document" as const,
      label: d.filename.replace(/\.pdf$/i, ""),
      subtitle: d.status === "completed" ? `${d.problem_count ?? 0} problems` : d.status,
      href: "/dashboard/documents",
      icon: <DocumentIcon />,
    }))

  const courseResults: ResultItem[] = (courses ?? [])
    .filter((c) => !lowerQuery || c.name.toLowerCase().includes(lowerQuery))
    .map((c) => ({
      id: `course-${c.id}`,
      type: "course" as const,
      label: `${c.emoji} ${c.name}`,
      href: "/dashboard/courses",
      icon: <CourseIcon />,
    }))

  // Flatten into sections for rendering, but flat list for keyboard nav
  const sections: { title: string; items: ResultItem[] }[] = []
  if (filteredNav.length > 0) sections.push({ title: "Navigation", items: filteredNav })
  if (docResults.length > 0) sections.push({ title: "Documents", items: docResults })
  if (courseResults.length > 0) sections.push({ title: "Courses", items: courseResults })

  const allItems = sections.flatMap((s) => s.items)

  // Keyboard navigation
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "ArrowDown") {
        e.preventDefault()
        setActiveIndex((i) => (i + 1) % Math.max(allItems.length, 1))
      } else if (e.key === "ArrowUp") {
        e.preventDefault()
        setActiveIndex((i) => (i - 1 + allItems.length) % Math.max(allItems.length, 1))
      } else if (e.key === "Enter") {
        e.preventDefault()
        const item = allItems[activeIndex]
        if (item) {
          router.push(item.href)
          closeCommandPalette()
        }
      } else if (e.key === "Escape") {
        e.preventDefault()
        closeCommandPalette()
      }
    },
    [allItems, activeIndex, router, closeCommandPalette]
  )

  // Reset active index when query changes
  useEffect(() => {
    setActiveIndex(0)
  }, [query])

  // Scroll active item into view
  const listRef = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!listRef.current) return
    const activeEl = listRef.current.querySelector(`[data-index="${activeIndex}"]`)
    if (activeEl) {
      activeEl.scrollIntoView({ block: "nearest" })
    }
  }, [activeIndex])

  if (!commandPaletteOpen) return null

  let flatIndex = -1

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.2 }}
      onClick={closeCommandPalette}
      onWheel={(e) => e.preventDefault()}
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 200,
        backgroundColor: "rgba(0,0,0,0.3)",
        display: "flex",
        justifyContent: "center",
        alignItems: "flex-start",
        paddingTop: 80,
        overflow: "hidden",
      }}
    >
      <motion.div
        initial={{ opacity: 0, y: 20, scale: 0.97 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 20, scale: 0.97 }}
        transition={{ duration: 0.25 }}
        onClick={(e) => e.stopPropagation()}
        onWheel={(e) => e.stopPropagation()}
        style={{
          width: isMobile ? "calc(100vw - 32px)" : 560,
          maxHeight: isMobile ? "min(400px, calc(100vh - 120px))" : "min(480px, calc(100vh - 160px))",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 16,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          display: "flex",
          flexDirection: "column",
          overflow: "hidden",
        }}
      >
        {/* Search input */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            padding: "18px 24px",
            borderBottom: `1.5px solid ${colors.gray100}`,
          }}
        >
          <SearchIcon />
          <input
            ref={inputRef}
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Search documents, courses, pages..."
            style={{
              flex: 1,
              border: "none",
              outline: "none",
              fontFamily,
              fontWeight: 600,
              fontSize: 16,
              letterSpacing: "-0.04em",
              color: colors.black,
              backgroundColor: "transparent",
            }}
          />
          <div
            style={{
              padding: "2px 6px",
              borderRadius: 6,
              border: `1.5px solid ${colors.gray400}`,
              fontFamily,
              fontWeight: 600,
              fontSize: 11,
              letterSpacing: "-0.02em",
              color: colors.gray600,
            }}
          >
            ESC
          </div>
        </div>

        {/* Results */}
        <div ref={listRef} style={{ flex: 1, minHeight: 0, overflowY: "auto", overscrollBehavior: "contain", padding: "10px 0" }}>
          {loading && (
            <div
              style={{
                padding: "24px 24px",
                textAlign: "center",
                fontFamily,
                fontWeight: 600,
                fontSize: 14,
                letterSpacing: "-0.02em",
                color: colors.gray600,
              }}
            >
              Loading...
            </div>
          )}

          {!loading && allItems.length === 0 && (
            <div
              style={{
                padding: "24px 24px",
                textAlign: "center",
                fontFamily,
                fontWeight: 600,
                fontSize: 14,
                letterSpacing: "-0.02em",
                color: colors.gray600,
              }}
            >
              No results found
            </div>
          )}

          {!loading &&
            sections.map((section) => (
              <div key={section.title}>
                {/* Section header */}
                <div
                  style={{
                    padding: "12px 24px 6px",
                    fontFamily,
                    fontWeight: 700,
                    fontSize: 11,
                    letterSpacing: "0.04em",
                    textTransform: "uppercase",
                    color: colors.gray400,
                  }}
                >
                  {section.title}
                </div>

                {/* Items */}
                {section.items.map((item) => {
                  flatIndex++
                  const isActive = flatIndex === activeIndex
                  const idx = flatIndex
                  return (
                    <div
                      key={item.id}
                      data-index={idx}
                      onClick={() => {
                        router.push(item.href)
                        closeCommandPalette()
                      }}
                      onMouseEnter={() => setActiveIndex(idx)}
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 12,
                        padding: "10px 24px",
                        cursor: "pointer",
                        backgroundColor: isActive ? colors.accent : "transparent",
                        transition: "background-color 0.08s",
                      }}
                    >
                      <div style={{ color: isActive ? colors.black : colors.gray600, flexShrink: 0 }}>
                        {item.icon}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
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
                          {item.label}
                        </div>
                        {item.subtitle && (
                          <div
                            style={{
                              fontFamily,
                              fontWeight: 500,
                              fontSize: 12,
                              letterSpacing: "-0.02em",
                              color: colors.gray600,
                              marginTop: 1,
                            }}
                          >
                            {item.subtitle}
                          </div>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            ))}
        </div>
      </motion.div>
    </motion.div>
  )
}
