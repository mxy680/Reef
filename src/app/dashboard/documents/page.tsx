"use client"

import { useState, useEffect, useRef, useCallback } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../../lib/colors"
import { listDocuments, uploadDocument, getDocumentDownloadUrl, deleteDocument, LimitError, type Document } from "../../../lib/documents"
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

function AlertIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#C62828" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="8" x2="12" y2="12" />
      <line x1="12" y1="16" x2="12.01" y2="16" />
    </svg>
  )
}

// ─── Dropdown Menu ────────────────────────────────────────

function DropdownMenu({ onDelete, onClose }: { onDelete: () => void; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) onClose()
    }
    document.addEventListener("mousedown", handleClick)
    return () => document.removeEventListener("mousedown", handleClick)
  }, [onClose])

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
        onClick={(e) => { e.stopPropagation(); onDelete(); onClose() }}
        onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = "#FDECEA")}
        onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "transparent")}
        style={{
          display: "block",
          width: "100%",
          padding: "8px 14px",
          background: "none",
          border: "none",
          fontFamily,
          fontWeight: 600,
          fontSize: 13,
          letterSpacing: "-0.04em",
          color: "#C62828",
          cursor: "pointer",
          textAlign: "left",
        }}
      >
        Delete
      </button>
    </motion.div>
  )
}

// ─── Document Thumbnail ──────────────────────────────────

function DocumentThumbnail({ status }: { status: Document["status"] }) {
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
      {/* Ruled lines background */}
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

      {status === "processing" && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "linear-gradient(90deg, transparent 0%, rgba(91,158,173,0.08) 50%, transparent 100%)",
            backgroundSize: "200% 100%",
            animation: "shimmer 1.5s infinite",
          }}
        />
      )}

      {status === "failed" && (
        <div style={{ position: "relative", zIndex: 1 }}>
          <AlertIcon />
        </div>
      )}
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
  onDelete,
  onClick,
}: {
  doc: Document
  index: number
  onDelete: (d: Document) => void
  onClick: (d: Document) => void
}) {
  const [menuOpen, setMenuOpen] = useState(false)

  const dateStr = new Date(doc.created_at).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  })

  // Strip .pdf extension for display
  const displayName = doc.filename.replace(/\.pdf$/i, "")

  function statusLabel() {
    if (doc.status === "processing") return "Processing..."
    if (doc.status === "failed") return "Failed"
    const parts: string[] = []
    if (doc.page_count) parts.push(`${doc.page_count} ${doc.page_count === 1 ? "page" : "pages"}`)
    if (doc.problem_count) parts.push(`${doc.problem_count} ${doc.problem_count === 1 ? "problem" : "problems"}`)
    if (parts.length > 0) return parts.join(" · ")
    return dateStr
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: 0.1 + index * 0.05 }}
      whileHover={doc.status === "completed" ? { boxShadow: `2px 2px 0px 0px ${colors.gray500}`, x: 2, y: 2, transition: { duration: 0.15 } } : {}}
      whileTap={doc.status === "completed" ? { boxShadow: `0px 0px 0px 0px ${colors.gray500}`, x: 4, y: 4, transition: { duration: 0.1 } } : {}}
      onClick={() => onClick(doc)}
      style={{
        position: "relative",
        backgroundColor: colors.white,
        border: `1.5px solid ${doc.status === "failed" ? "#E57373" : colors.gray500}`,
        borderRadius: 14,
        boxShadow: `4px 4px 0px 0px ${doc.status === "failed" ? "#E57373" : colors.gray500}`,
        overflow: "hidden",
        cursor: doc.status === "completed" ? "pointer" : "default",
        display: "flex",
        flexDirection: "column",
        opacity: doc.status === "processing" ? 0.85 : 1,
      }}
    >
      {/* 3-dot menu */}
      <div style={{ position: "absolute", top: 8, right: 8, zIndex: 5 }}>
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
            color: colors.gray500,
            cursor: "pointer",
          }}
        >
          <DotsIcon />
        </motion.button>
        <AnimatePresence>
          {menuOpen && (
            <DropdownMenu
              onDelete={() => onDelete(doc)}
              onClose={() => setMenuOpen(false)}
            />
          )}
        </AnimatePresence>
      </div>

      {/* Thumbnail */}
      <div style={{ padding: "14px 14px 0" }}>
        <DocumentThumbnail status={doc.status} />
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
            color: doc.status === "failed" ? "#C62828" : doc.status === "processing" ? colors.primary : colors.gray500,
          }}
        >
          {statusLabel()}
        </div>
      </div>
    </motion.div>
  )
}

// ─── Loading Skeleton ─────────────────────────────────────

function LoadingSkeleton() {
  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(180px, 220px))",
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
        flex: 1,
        padding: "24px",
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

// ─── Shimmer Keyframes (injected once) ────────────────────

function ShimmerStyle() {
  return (
    <style>{`
      @keyframes shimmer {
        0% { background-position: 200% 0; }
        100% { background-position: -200% 0; }
      }
    `}</style>
  )
}

// ─── Main Page ────────────────────────────────────────────

export default function DocumentsPage() {
  const [documents, setDocuments] = useState<Document[]>([])
  const [loading, setLoading] = useState(true)
  const [toast, setToast] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<Document | null>(null)
  const [maxDocuments, setMaxDocuments] = useState<number | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const fetchDocuments = useCallback(async () => {
    try {
      const data = await listDocuments()
      setDocuments(data)
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

  // Poll every 3s while any document is processing
  useEffect(() => {
    const hasProcessing = documents.some(d => d.status === "processing")
    if (!hasProcessing) return

    const interval = setInterval(fetchDocuments, 3000)
    return () => clearInterval(interval)
  }, [documents, fetchDocuments])

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
      const doc = await uploadDocument(file)
      // Optimistically add the new document to the list
      setDocuments(prev => [doc, ...prev])
      setToast("Document uploading — processing will begin shortly")
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

  return (
    <>
      <ShimmerStyle />

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
        style={{ display: "flex", flexDirection: "column", flex: 1, minHeight: 0 }}
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
              gridTemplateColumns: "repeat(auto-fill, minmax(180px, 220px))",
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
                onDelete={setDeleteTarget}
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

      {/* Toast */}
      <AnimatePresence>
        {toast && <Toast message={toast} onDone={() => setToast(null)} />}
      </AnimatePresence>
    </>
  )
}
