"use client"

import { useState, useEffect, useRef, useCallback } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../../lib/colors"
import { listDocuments, uploadDocument, getDocumentDownloadUrl, getDocumentShareUrl, getDocumentThumbnailUrls, deleteDocument, renameDocument, duplicateDocument, moveDocumentToCourse, LimitError, type Document } from "../../../lib/documents"
import { listCourses, type Course } from "../../../lib/courses"
import { generateThumbnail } from "../../../lib/pdf-thumbnail"
import { getUserTier, getLimits } from "../../../lib/limits"

const fontFamily = `"Epilogue", sans-serif`

// ─── Icons ────────────────────────────────────────────────

function UploadIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="17 8 12 3 7 8" />
      <line x1="12" y1="3" x2="12" y2="15" />
    </svg>
  )
}

function EmptyDocumentIcon() {
  return (
    <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke={colors.gray400} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="12" y1="11" x2="12" y2="17" />
      <line x1="9" y1="14" x2="15" y2="14" />
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

function AlertIcon({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="#C62828" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="8" x2="12" y2="12" />
      <line x1="12" y1="16" x2="12.01" y2="16" />
    </svg>
  )
}

// ─── Dropdown Menu ────────────────────────────────────────

const menuItemStyle: React.CSSProperties = {
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

function DropdownMenu({
  onRename,
  onDownload,
  onMoveToCourse,
  onDuplicate,
  onShare,
  onViewDetails,
  onDelete,
  onClose,
}: {
  onRename: () => void
  onDownload: () => void
  onMoveToCourse: () => void
  onDuplicate: () => void
  onShare: () => void
  onViewDetails: () => void
  onDelete: () => void
  onClose: () => void
}) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) onClose()
    }
    document.addEventListener("mousedown", handleClick)
    return () => document.removeEventListener("mousedown", handleClick)
  }, [onClose])

  const items = [
    { label: "Rename", action: onRename },
    { label: "Download", action: onDownload },
    { label: "Move to Course", action: onMoveToCourse },
    { label: "Duplicate", action: onDuplicate },
    { label: "Share", action: onShare },
    { label: "View Details", action: onViewDetails },
  ]

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
        minWidth: 160,
      }}
    >
      {items.map((item) => (
        <button
          key={item.label}
          onClick={(e) => { e.stopPropagation(); item.action(); onClose() }}
          onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.gray100)}
          onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
          style={menuItemStyle}
        >
          {item.label}
        </button>
      ))}
      {/* Divider */}
      <div style={{ height: 1, backgroundColor: colors.gray100, margin: "2px 0" }} />
      <button
        onClick={(e) => { e.stopPropagation(); onDelete(); onClose() }}
        onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = "#FDECEA")}
        onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
        style={{ ...menuItemStyle, color: "#C62828" }}
      >
        Delete
      </button>
    </motion.div>
  )
}

// ─── Document Thumbnail ──────────────────────────────────

function DocumentThumbnail({ status, thumbnailUrl }: { status: Document["status"]; thumbnailUrl?: string }) {
  return (
    <div
      style={{
        width: "100%",
        aspectRatio: "8.5 / 11",
        backgroundColor: status === "failed" ? "#FFF5F5" : "#FAFAFA",
        borderRadius: 8,
        border: `1px solid ${status === "failed" ? "#FFCDD2" : colors.gray100}`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      {thumbnailUrl ? (
        /* eslint-disable-next-line @next/next/no-img-element */
        <img
          src={thumbnailUrl}
          alt=""
          style={{
            position: "absolute",
            inset: 0,
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "top",
          }}
        />
      ) : (
        /* Ruled lines placeholder */
        <svg
          width="100%"
          height="100%"
          viewBox="0 0 100 140"
          preserveAspectRatio="none"
          style={{ position: "absolute", inset: 0 }}
        >
          {Array.from({ length: 16 }, (_, i) => (
            <line
              key={i}
              x1="12"
              y1={20 + i * 7.5}
              x2="88"
              y2={20 + i * 7.5}
              stroke={colors.gray100}
              strokeWidth="0.5"
            />
          ))}
        </svg>
      )}

    </div>
  )
}

// ─── Error Tooltip ────────────────────────────────────────

function ErrorTooltip({ message }: { message: string }) {
  // Truncate long raw error messages for display
  const displayMessage = message.length > 100 ? message.slice(0, 100) + "..." : message

  return (
    <motion.div
      initial={{ opacity: 0, y: 4 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: 4 }}
      transition={{ duration: 0.15 }}
      onClick={(e) => e.stopPropagation()}
      style={{
        backgroundColor: colors.white,
        border: `1.5px solid #E57373`,
        borderRadius: 10,
        padding: "10px 14px",
        width: 220,
        boxShadow: "0 4px 12px rgba(0,0,0,0.12)",
      }}
    >
      <div
        style={{
          fontFamily,
          fontWeight: 500,
          fontSize: 12,
          letterSpacing: "-0.04em",
          color: colors.gray600,
          lineHeight: 1.4,
          wordBreak: "break-word",
        }}
      >
        {displayMessage}
      </div>
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

// ─── Upload Button ────────────────────────────────────────

function UploadButton({ onClick }: { onClick: () => void }) {
  return (
    <motion.button
      onClick={onClick}
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
      <UploadIcon />
      Upload Document
    </motion.button>
  )
}

// ─── Document Card ────────────────────────────────────────

function DocumentCard({
  doc,
  index,
  thumbnailUrl,
  onDelete,
  onRename,
  onDownload,
  onDuplicate,
  onMoveToCourse,
  onShare,
  onViewDetails,
  onClick,
}: {
  doc: Document
  index: number
  thumbnailUrl?: string
  onDelete: (d: Document) => void
  onRename: (d: Document) => void
  onDownload: (d: Document) => void
  onDuplicate: (d: Document) => void
  onMoveToCourse: (d: Document) => void
  onShare: (d: Document) => void
  onViewDetails: (d: Document) => void
  onClick: (d: Document) => void
}) {
  const [menuOpen, setMenuOpen] = useState(false)
  const [errorTooltipOpen, setErrorTooltipOpen] = useState(false)
  const [tooltipPos, setTooltipPos] = useState<{ top: number; left: number } | null>(null)
  const alertRef = useRef<HTMLDivElement>(null)
  const [mounted, setMounted] = useState(false)

  useEffect(() => { setMounted(true) }, [])

  const dateStr = new Date(doc.created_at).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  })

  // Strip .pdf extension for display
  const displayName = doc.filename.replace(/\.pdf$/i, "")

  function statusLabel() {
    if (doc.status === "failed") return "Failed"
    return dateStr
  }

  const hoverStyle = { boxShadow: `2px 2px 0px 0px ${colors.gray500}`, x: 2, y: 2 }
  const defaultShadow = `4px 4px 0px 0px ${doc.status === "failed" ? "#E57373" : colors.gray500}`

  return (
    <motion.div
      initial={mounted ? false : { opacity: 0, y: 16 }}
      animate={menuOpen ? { opacity: 1, ...hoverStyle } : { opacity: 1, y: 0, x: 0, boxShadow: defaultShadow }}
      transition={{ duration: mounted ? 0.15 : 0.3, delay: mounted ? 0 : 0.1 + index * 0.05 }}
      whileHover={!menuOpen && doc.status === "completed" ? { ...hoverStyle, transition: { duration: 0.15 } } : {}}
      whileTap={!menuOpen && doc.status === "completed" ? { boxShadow: `0px 0px 0px 0px ${colors.gray500}`, x: 4, y: 4, transition: { duration: 0.1 } } : {}}
      onClick={() => onClick(doc)}
      style={{
        position: "relative",
        backgroundColor: colors.white,
        border: `1.5px solid ${doc.status === "failed" ? "#E57373" : colors.gray500}`,
        borderRadius: 14,
        boxShadow: `4px 4px 0px 0px ${doc.status === "failed" ? "#E57373" : colors.gray500}`,
        overflow: "visible",
        cursor: doc.status === "completed" ? "pointer" : "default",
        display: "flex",
        flexDirection: "column",
        opacity: 1,
      }}
    >
      {/* Top-right controls */}
      <div style={{ position: "absolute", top: 8, right: 8, zIndex: 5, display: "flex", gap: 4, alignItems: "flex-start" }}>
        {/* Error alert icon (failed docs only) */}
        {doc.status === "failed" && (
          <div
            ref={alertRef}
            style={{ position: "relative" }}
            onMouseEnter={() => {
              if (alertRef.current) {
                const rect = alertRef.current.getBoundingClientRect()
                setTooltipPos({ top: rect.bottom + 6, left: Math.max(8, rect.right - 220) })
              }
              setErrorTooltipOpen(true)
            }}
            onMouseLeave={() => setErrorTooltipOpen(false)}
          >
            <button
              onClick={(e) => { e.stopPropagation() }}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                width: 28,
                height: 28,
                borderRadius: 8,
                border: "1.5px solid #E57373",
                backgroundColor: "#FFF5F5",
                cursor: "default",
                padding: 0,
              }}
            >
              <AlertIcon size={15} />
            </button>
          </div>
        )}

        {/* 3-dot menu */}
        <div
          onMouseEnter={() => setMenuOpen(true)}
          onMouseLeave={() => setMenuOpen(false)}
        >
          <button
            onClick={(e) => { e.stopPropagation() }}
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              width: 28,
              height: 28,
              borderRadius: 8,
              border: `1.5px solid ${colors.gray400}`,
              backgroundColor: colors.white,
              color: colors.gray500,
              cursor: "pointer",
            }}
          >
            <DotsIcon />
          </button>
          <AnimatePresence>
            {menuOpen && (
              <DropdownMenu
                onRename={() => onRename(doc)}
                onDownload={() => onDownload(doc)}
                onDuplicate={() => onDuplicate(doc)}
                onMoveToCourse={() => onMoveToCourse(doc)}
                onShare={() => onShare(doc)}
                onViewDetails={() => onViewDetails(doc)}
                onDelete={() => onDelete(doc)}
                onClose={() => setMenuOpen(false)}
              />
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* Thumbnail */}
      <div style={{ padding: "14px 14px 0" }}>
        <DocumentThumbnail status={doc.status} thumbnailUrl={thumbnailUrl} />
      </div>

      {/* Info */}
      <div style={{ padding: "12px 14px 14px" }}>
        <div
          style={{
            fontFamily,
            fontWeight: 700,
            fontSize: 13,
            letterSpacing: "-0.04em",
            color: colors.black,
            marginBottom: 4,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            paddingRight: 24,
          }}
        >
          {displayName}
        </div>
        <div
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 11,
            letterSpacing: "-0.04em",
            color: doc.status === "failed" ? "#C62828" : colors.gray500,
          }}
        >
          {statusLabel()}
        </div>
      </div>

      {/* Error tooltip (rendered with fixed positioning to avoid clipping) */}
      <AnimatePresence>
        {errorTooltipOpen && tooltipPos && doc.status === "failed" && (
          <div
            style={{ position: "fixed", top: tooltipPos.top, left: tooltipPos.left, zIndex: 50 }}
            onMouseEnter={() => setErrorTooltipOpen(true)}
            onMouseLeave={() => setErrorTooltipOpen(false)}
          >
            <ErrorTooltip
              message={doc.error_message || "Upload failed"}
            />
          </div>
        )}
      </AnimatePresence>
    </motion.div>
  )
}

// ─── Loading Skeleton ─────────────────────────────────────

function LoadingSkeleton() {
  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))",
        gap: 20,
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
            borderRadius: 14,
            overflow: "hidden",
          }}
        >
          <div style={{ padding: "14px 14px 0" }}>
            <div style={{ aspectRatio: "8.5 / 11", backgroundColor: colors.white, borderRadius: 8, opacity: 0.6 }} />
          </div>
          <div style={{ padding: "12px 14px 14px" }}>
            <div style={{ width: "70%", height: 13, backgroundColor: colors.white, borderRadius: 6, marginBottom: 6, opacity: 0.6 }} />
            <div style={{ width: "40%", height: 11, backgroundColor: colors.white, borderRadius: 6, opacity: 0.6 }} />
          </div>
        </motion.div>
      ))}
    </div>
  )
}

// ─── Empty State ──────────────────────────────────────────

function EmptyState({ onUpload }: { onUpload: () => void }) {
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
      <EmptyDocumentIcon />
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
        No documents yet
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
        Upload a PDF to get started with Reef.
      </p>
      <UploadButton onClick={onUpload} />
    </motion.div>
  )
}

// ─── Delete Confirm Modal ─────────────────────────────────

function DeleteConfirmModal({
  doc,
  onConfirm,
  onClose,
}: {
  doc: Document
  onConfirm: () => void
  onClose: () => void
}) {
  const [deleting, setDeleting] = useState(false)
  const displayName = doc.filename.replace(/\.pdf$/i, "")

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
          Delete &ldquo;{displayName}&rdquo;?
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
          <button
            type="button"
            onClick={() => { setDeleting(true); onConfirm() }}
            disabled={deleting}
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
          </button>
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Rename Modal ─────────────────────────────────────────

function RenameModal({
  doc,
  onConfirm,
  onClose,
}: {
  doc: Document
  onConfirm: (newName: string) => void
  onClose: () => void
}) {
  const baseName = doc.filename.replace(/\.pdf$/i, "")
  const [value, setValue] = useState(baseName)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    inputRef.current?.select()
  }, [])

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
          padding: "32px 28px",
          boxSizing: "border-box",
        }}
      >
        <h3
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 20,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 16,
          }}
        >
          Rename Document
        </h3>
        <input
          ref={inputRef}
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && value.trim()) onConfirm(value.trim() + ".pdf")
          }}
          style={{
            width: "100%",
            padding: "10px 14px",
            fontFamily,
            fontWeight: 600,
            fontSize: 14,
            letterSpacing: "-0.04em",
            color: colors.black,
            border: `1.5px solid ${colors.gray400}`,
            borderRadius: 8,
            outline: "none",
            boxSizing: "border-box",
            marginBottom: 20,
          }}
        />
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
          <button
            type="button"
            onClick={() => { if (value.trim()) onConfirm(value.trim() + ".pdf") }}
            disabled={!value.trim()}
            style={{
              padding: "10px 24px",
              backgroundColor: colors.primary,
              border: `2px solid ${colors.black}`,
              borderRadius: 10,
              boxShadow: `4px 4px 0px 0px ${colors.black}`,
              fontFamily,
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: "-0.04em",
              color: colors.white,
              cursor: value.trim() ? "pointer" : "not-allowed",
              opacity: value.trim() ? 1 : 0.5,
            }}
          >
            Rename
          </button>
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Details Modal ────────────────────────────────────────

function DetailsModal({ doc, onClose }: { doc: Document; onClose: () => void }) {
  const displayName = doc.filename.replace(/\.pdf$/i, "")
  const dateStr = new Date(doc.created_at).toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  })

  const rows = [
    { label: "Filename", value: doc.filename },
    { label: "Status", value: doc.status.charAt(0).toUpperCase() + doc.status.slice(1) },
    { label: "Uploaded", value: dateStr },
    { label: "ID", value: doc.id },
  ]

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
          width: 400,
          maxWidth: "100%",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 12,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          padding: "32px 28px",
          boxSizing: "border-box",
        }}
      >
        <h3
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 20,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 20,
          }}
        >
          {displayName}
        </h3>
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {rows.map((row) => (
            <div key={row.label} style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
              <span
                style={{
                  fontFamily,
                  fontWeight: 600,
                  fontSize: 13,
                  letterSpacing: "-0.04em",
                  color: colors.gray600,
                }}
              >
                {row.label}
              </span>
              <span
                style={{
                  fontFamily,
                  fontWeight: 600,
                  fontSize: 13,
                  letterSpacing: "-0.04em",
                  color: colors.black,
                  textAlign: "right",
                  maxWidth: "60%",
                  wordBreak: "break-all",
                }}
              >
                {row.value}
              </span>
            </div>
          ))}
        </div>
        <div style={{ marginTop: 24, display: "flex", justifyContent: "flex-end" }}>
          <button
            type="button"
            onClick={onClose}
            style={{
              padding: "10px 24px",
              backgroundColor: colors.gray100,
              border: `2px solid ${colors.black}`,
              borderRadius: 10,
              boxShadow: `4px 4px 0px 0px ${colors.black}`,
              fontFamily,
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: "-0.04em",
              color: colors.black,
              cursor: "pointer",
            }}
          >
            Close
          </button>
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Move to Course Modal ─────────────────────────────────

function MoveToCourseModal({
  doc,
  onConfirm,
  onClose,
}: {
  doc: Document
  onConfirm: (courseId: string | null) => void
  onClose: () => void
}) {
  const [courses, setCourses] = useState<Course[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    listCourses()
      .then(setCourses)
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  const displayName = doc.filename.replace(/\.pdf$/i, "")

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
          padding: "32px 28px",
          boxSizing: "border-box",
        }}
      >
        <h3
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 20,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
            marginBottom: 6,
          }}
        >
          Move to Course
        </h3>
        <p
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 13,
            letterSpacing: "-0.04em",
            color: colors.gray600,
            margin: 0,
            marginBottom: 20,
          }}
        >
          {displayName}
        </p>

        {loading ? (
          <p style={{ fontFamily, fontSize: 13, color: colors.gray500, margin: "16px 0" }}>Loading courses...</p>
        ) : courses.length === 0 ? (
          <p style={{ fontFamily, fontSize: 13, color: colors.gray500, margin: "16px 0" }}>No courses yet. Create one first.</p>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 6, marginBottom: 20 }}>
            {/* Remove from course option */}
            {doc.course_id && (
              <button
                onClick={() => onConfirm(null)}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.gray100)}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  padding: "10px 12px",
                  border: `1.5px dashed ${colors.gray400}`,
                  borderRadius: 10,
                  backgroundColor: "transparent",
                  cursor: "pointer",
                  fontFamily,
                  fontWeight: 600,
                  fontSize: 13,
                  letterSpacing: "-0.04em",
                  color: colors.gray600,
                  width: "100%",
                  textAlign: "left",
                }}
              >
                Remove from course
              </button>
            )}
            {courses.map((course) => (
              <button
                key={course.id}
                onClick={() => onConfirm(course.id)}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.gray100)}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  padding: "10px 12px",
                  border: `1.5px solid ${doc.course_id === course.id ? colors.primary : colors.gray400}`,
                  borderRadius: 10,
                  backgroundColor: doc.course_id === course.id ? `${colors.primary}15` : "transparent",
                  cursor: "pointer",
                  fontFamily,
                  fontWeight: 600,
                  fontSize: 13,
                  letterSpacing: "-0.04em",
                  color: colors.black,
                  width: "100%",
                  textAlign: "left",
                }}
              >
                <span style={{ fontSize: 16 }}>{course.emoji}</span>
                <span style={{ flex: 1 }}>{course.name}</span>
                {doc.course_id === course.id && (
                  <span style={{ fontWeight: 700, fontSize: 11, color: colors.primary }}>Current</span>
                )}
              </button>
            ))}
          </div>
        )}

        <div style={{ display: "flex", justifyContent: "flex-end" }}>
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
        </div>
      </motion.div>
    </motion.div>
  )
}

// ─── Main Page ────────────────────────────────────────────

export default function DocumentsPage() {
  const [documents, setDocuments] = useState<Document[]>([])
  const [loading, setLoading] = useState(true)
  const [toast, setToast] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<Document | null>(null)
  const [renameTarget, setRenameTarget] = useState<Document | null>(null)
  const [detailsTarget, setDetailsTarget] = useState<Document | null>(null)
  const [moveToCourseTarget, setMoveToCourseTarget] = useState<Document | null>(null)
  const [maxDocuments, setMaxDocuments] = useState<number | null>(null)
  const [thumbnails, setThumbnails] = useState<Record<string, string>>({})
  const fileInputRef = useRef<HTMLInputElement>(null)

  const fetchDocuments = useCallback(async () => {
    try {
      const data = await listDocuments()
      setDocuments(data)

      // Fetch thumbnail URLs for all documents
      if (data.length > 0) {
        const urls = await getDocumentThumbnailUrls(data.map((d) => d.id))
        setThumbnails((prev) => ({ ...prev, ...urls }))
      }
    } catch (err) {
      console.error("Failed to fetch documents:", err)
    } finally {
      setLoading(false)
    }
  }, [])

  // Load tier limits
  useEffect(() => {
    getUserTier().then((tier) => {
      const limits = getLimits(tier)
      if (limits.maxDocuments !== Infinity) setMaxDocuments(limits.maxDocuments)
    })
  }, [])

  // Initial load
  useEffect(() => { fetchDocuments() }, [fetchDocuments])

  function triggerUpload() {
    fileInputRef.current?.click()
  }

  async function handleFileSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return

    // Reset input so same file can be re-selected
    e.target.value = ""

    if (!file.name.toLowerCase().endsWith(".pdf")) {
      setToast("Please select a PDF file")
      return
    }

    try {
      // Generate thumbnail from the PDF before uploading
      let thumbnailBlob: Blob | undefined
      try {
        thumbnailBlob = await generateThumbnail(file)
      } catch {
        // Non-critical — upload proceeds without thumbnail
      }

      const doc = await uploadDocument(file, thumbnailBlob)

      // Store local thumbnail URL for immediate display
      if (thumbnailBlob) {
        const localUrl = URL.createObjectURL(thumbnailBlob)
        setThumbnails((prev) => ({ ...prev, [doc.id]: localUrl }))
      }

      // Optimistically add the new document to the list
      setDocuments(prev => [doc, ...prev])
      setToast("Document uploaded")
    } catch (err) {
      if (err instanceof LimitError) {
        setToast(err.message)
      } else {
        console.error("Upload failed:", err)
        setToast("Upload failed — please try again")
      }
    }
  }

  async function handleCardClick(doc: Document) {
    if (doc.status !== "completed") return

    try {
      const url = await getDocumentDownloadUrl(doc.id)
      window.open(url, "_blank")
    } catch (err) {
      console.error("Failed to get download URL:", err)
      setToast("Failed to open document")
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return
    try {
      await deleteDocument(deleteTarget.id)
      setToast("Document deleted")
      setDeleteTarget(null)
      await fetchDocuments()
    } catch (err) {
      console.error("Failed to delete document:", err)
      setToast("Something went wrong")
    }
  }

  async function handleRename(newFilename: string) {
    if (!renameTarget) return
    try {
      await renameDocument(renameTarget.id, newFilename)
      setToast("Document renamed")
      setRenameTarget(null)
      await fetchDocuments()
    } catch (err) {
      console.error("Failed to rename document:", err)
      setToast("Something went wrong")
    }
  }

  async function handleDownload(doc: Document) {
    try {
      const url = await getDocumentDownloadUrl(doc.id)
      const a = document.createElement("a")
      a.href = url
      a.download = doc.filename
      a.click()
    } catch (err) {
      console.error("Failed to download document:", err)
      setToast("Failed to download")
    }
  }

  async function handleDuplicate(doc: Document) {
    try {
      const newDoc = await duplicateDocument(doc.id)
      setToast("Document duplicated")
      // Copy thumbnail locally
      if (thumbnails[doc.id]) {
        setThumbnails((prev) => ({ ...prev, [newDoc.id]: prev[doc.id] }))
      }
      await fetchDocuments()
    } catch (err) {
      console.error("Failed to duplicate document:", err)
      setToast("Something went wrong")
    }
  }

  async function handleMoveToCourse(courseId: string | null) {
    if (!moveToCourseTarget) return
    try {
      await moveDocumentToCourse(moveToCourseTarget.id, courseId)
      setToast(courseId ? "Moved to course" : "Removed from course")
      setMoveToCourseTarget(null)
      await fetchDocuments()
    } catch (err) {
      console.error("Failed to move document:", err)
      setToast("Something went wrong")
    }
  }

  async function handleShare(doc: Document) {
    try {
      const url = await getDocumentShareUrl(doc.id)
      await navigator.clipboard.writeText(url)
      setToast("Share link copied to clipboard")
    } catch (err) {
      console.error("Failed to generate share link:", err)
      setToast("Failed to generate share link")
    }
  }

  return (
    <>

      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".pdf,application/pdf"
        onChange={handleFileSelected}
        style={{ display: "none" }}
      />

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.1 }}
      >
        {/* Header row */}
        <div
          style={{
            display: "flex",
            alignItems: "flex-start",
            justifyContent: "space-between",
            marginBottom: 28,
          }}
        >
          <div>
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
              Documents
            </h2>
            <p
              style={{
                fontFamily,
                fontWeight: 500,
                fontSize: 14,
                letterSpacing: "-0.04em",
                color: colors.gray600,
                margin: 0,
                display: "flex",
                alignItems: "center",
                gap: 10,
                flexWrap: "wrap",
              }}
            >
              Upload and manage your study documents.
              {!loading && maxDocuments !== null && (
                <span
                  style={{
                    fontFamily,
                    fontWeight: 700,
                    fontSize: 12,
                    letterSpacing: "-0.04em",
                    color: documents.length >= maxDocuments ? "#C62828" : colors.gray500,
                    backgroundColor: documents.length >= maxDocuments ? "#FDECEA" : colors.gray100,
                    padding: "3px 10px",
                    borderRadius: 20,
                  }}
                >
                  {documents.length} / {maxDocuments}
                </span>
              )}
            </p>
          </div>
          {!loading && documents.length > 0 && <UploadButton onClick={triggerUpload} />}
        </div>

        {/* Content */}
        {loading ? (
          <LoadingSkeleton />
        ) : documents.length === 0 ? (
          <EmptyState onUpload={triggerUpload} />
        ) : (
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))",
              gap: 20,
            }}
          >
            <motion.button
              onClick={triggerUpload}
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, delay: 0.05 }}
              whileHover={{ borderColor: colors.gray500, transition: { duration: 0.15 } }}
              whileTap={{ borderColor: colors.gray600, transition: { duration: 0.1 } }}
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                gap: 8,
                backgroundColor: "transparent",
                border: `2px dashed ${colors.gray400}`,
                borderRadius: 14,
                padding: "24px 20px",
                cursor: "pointer",
                color: colors.gray500,
                fontFamily,
                fontWeight: 600,
                fontSize: 14,
                letterSpacing: "-0.04em",
              }}
            >
              <UploadIcon />
              Upload
            </motion.button>
            {documents.map((doc, i) => (
              <DocumentCard
                key={doc.id}
                doc={doc}
                index={i}
                thumbnailUrl={thumbnails[doc.id]}
                onDelete={setDeleteTarget}
                onRename={setRenameTarget}
                onDownload={handleDownload}
                onDuplicate={handleDuplicate}
                onMoveToCourse={setMoveToCourseTarget}
                onShare={handleShare}
                onViewDetails={setDetailsTarget}
                onClick={handleCardClick}
              />
            ))}
          </div>
        )}
      </motion.div>

      {/* Delete confirmation modal */}
      <AnimatePresence>
        {deleteTarget && (
          <DeleteConfirmModal
            doc={deleteTarget}
            onConfirm={handleDelete}
            onClose={() => setDeleteTarget(null)}
          />
        )}
      </AnimatePresence>

      {/* Rename modal */}
      <AnimatePresence>
        {renameTarget && (
          <RenameModal
            doc={renameTarget}
            onConfirm={handleRename}
            onClose={() => setRenameTarget(null)}
          />
        )}
      </AnimatePresence>

      {/* Details modal */}
      <AnimatePresence>
        {detailsTarget && (
          <DetailsModal
            doc={detailsTarget}
            onClose={() => setDetailsTarget(null)}
          />
        )}
      </AnimatePresence>

      {/* Move to Course modal */}
      <AnimatePresence>
        {moveToCourseTarget && (
          <MoveToCourseModal
            doc={moveToCourseTarget}
            onConfirm={handleMoveToCourse}
            onClose={() => setMoveToCourseTarget(null)}
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
