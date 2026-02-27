"use client"

import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

type DocStatus = "completed" | "processing" | "failed"

interface MockDocument {
  id: string
  filename: string
  status: DocStatus
  problems: number | null
  pages: number
  date: string
}

const MOCK_DOCUMENTS: MockDocument[] = [
  { id: "1", filename: "Calculus_II_Midterm.pdf", status: "completed", problems: 12, pages: 4, date: "Feb 25, 2026" },
  { id: "2", filename: "Linear_Algebra_HW3.pdf", status: "completed", problems: 8, pages: 2, date: "Feb 23, 2026" },
  { id: "3", filename: "Physics_Quiz_5.pdf", status: "processing", problems: null, pages: 1, date: "Feb 22, 2026" },
  { id: "4", filename: "Differential_Equations_Final.pdf", status: "failed", problems: null, pages: 6, date: "Feb 20, 2026" },
  { id: "5", filename: "Statistics_Problem_Set.pdf", status: "completed", problems: 15, pages: 3, date: "Feb 18, 2026" },
]

const STATUS_COLORS: Record<DocStatus, { bg: string; text: string; dot: string }> = {
  completed: { bg: "#E6F4EA", text: "#1E7E34", dot: "#1E7E34" },
  processing: { bg: "#FFF8E1", text: "#B8860B", dot: "#B8860B" },
  failed: { bg: "#FDECEA", text: "#C62828", dot: "#C62828" },
}

const GRID_COLUMNS = "2fr 1fr 0.7fr 0.7fr 1fr 48px"

function FileIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={colors.gray500} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
    </svg>
  )
}

function DownloadIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" y1="15" x2="12" y2="3" />
    </svg>
  )
}

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

function StatusBadge({ status }: { status: DocStatus }) {
  const c = STATUS_COLORS[status]
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 6,
        padding: "4px 10px",
        backgroundColor: c.bg,
        borderRadius: 999,
        fontFamily,
        fontWeight: 600,
        fontSize: 12,
        letterSpacing: "-0.04em",
        color: c.text,
      }}
    >
      <span
        style={{
          width: 6,
          height: 6,
          borderRadius: "50%",
          backgroundColor: c.dot,
          flexShrink: 0,
        }}
      />
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
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

function UploadButton({ onClick }: { onClick: () => void }) {
  return (
    <motion.button
      onClick={onClick}
      whileHover={{ y: -2, boxShadow: `4px 4px 0px 0px ${colors.black}` }}
      whileTap={{ y: 1, boxShadow: `1px 1px 0px 0px ${colors.black}` }}
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
        boxShadow: `3px 3px 0px 0px ${colors.black}`,
        cursor: "pointer",
      }}
    >
      <UploadIcon />
      Upload Document
    </motion.button>
  )
}

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
        Upload a document to get started with Reef.
      </p>
      <UploadButton onClick={onUpload} />
    </motion.div>
  )
}

export default function DocumentsPage() {
  const [toast, setToast] = useState<string | null>(null)
  const documents = MOCK_DOCUMENTS

  const showToast = (msg: string) => setToast(msg)
  const handleUpload = () => showToast("Upload coming soon")

  return (
    <>
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
              }}
            >
              Upload and manage your study documents.
            </p>
          </div>
          {documents.length > 0 && <UploadButton onClick={handleUpload} />}
        </div>

        {/* Table or Empty State */}
        {documents.length === 0 ? (
          <EmptyState onUpload={handleUpload} />
        ) : (
          <div>
            {/* Column headers */}
            <div
              style={{
                display: "grid",
                gridTemplateColumns: GRID_COLUMNS,
                padding: "0 16px 10px",
                borderBottom: `1px solid ${colors.gray100}`,
              }}
            >
              {["Name", "Status", "Problems", "Pages", "Date", ""].map((h) => (
                <span
                  key={h || "actions"}
                  style={{
                    fontFamily,
                    fontWeight: 600,
                    fontSize: 12,
                    letterSpacing: "-0.04em",
                    color: colors.gray500,
                    textTransform: "uppercase",
                  }}
                >
                  {h}
                </span>
              ))}
            </div>

            {/* Rows */}
            {documents.map((doc, i) => (
              <motion.div
                key={doc.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3, delay: 0.15 + i * 0.05 }}
                style={{
                  display: "grid",
                  gridTemplateColumns: GRID_COLUMNS,
                  alignItems: "center",
                  padding: "14px 16px",
                  borderBottom: `1px solid ${colors.gray100}`,
                  borderRadius: 8,
                  cursor: "default",
                  transition: "background-color 0.15s",
                }}
                whileHover={{ backgroundColor: "#F9F9FA" }}
              >
                {/* Filename */}
                <span
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
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
                  <FileIcon />
                  {doc.filename}
                </span>

                {/* Status */}
                <span><StatusBadge status={doc.status} /></span>

                {/* Problems */}
                <span
                  style={{
                    fontFamily,
                    fontWeight: 600,
                    fontSize: 14,
                    letterSpacing: "-0.04em",
                    color: doc.problems != null ? colors.black : colors.gray400,
                  }}
                >
                  {doc.problems != null ? doc.problems : "--"}
                </span>

                {/* Pages */}
                <span
                  style={{
                    fontFamily,
                    fontWeight: 600,
                    fontSize: 14,
                    letterSpacing: "-0.04em",
                    color: colors.black,
                  }}
                >
                  {doc.pages}
                </span>

                {/* Date */}
                <span
                  style={{
                    fontFamily,
                    fontWeight: 500,
                    fontSize: 13,
                    letterSpacing: "-0.04em",
                    color: colors.gray600,
                  }}
                >
                  {doc.date}
                </span>

                {/* Actions */}
                <span>
                  {doc.status === "completed" && (
                    <motion.button
                      whileHover={{ scale: 1.1 }}
                      whileTap={{ scale: 0.95 }}
                      style={{
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        width: 32,
                        height: 32,
                        borderRadius: 8,
                        border: `1px solid ${colors.gray100}`,
                        backgroundColor: "transparent",
                        color: colors.gray600,
                        cursor: "pointer",
                      }}
                      title="Download"
                    >
                      <DownloadIcon />
                    </motion.button>
                  )}
                </span>
              </motion.div>
            ))}
          </div>
        )}
      </motion.div>

      {/* Toast */}
      <AnimatePresence>
        {toast && <Toast message={toast} onDone={() => setToast(null)} />}
      </AnimatePresence>
    </>
  )
}
