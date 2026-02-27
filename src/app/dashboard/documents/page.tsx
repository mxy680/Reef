"use client"

import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

interface MockDocument {
  id: string
  filename: string
  pages: number
  date: string
}

const MOCK_DOCUMENTS: MockDocument[] = [
  { id: "1", filename: "Calculus II Midterm", pages: 4, date: "Feb 25, 2026" },
  { id: "2", filename: "Linear Algebra HW3", pages: 2, date: "Feb 23, 2026" },
  { id: "3", filename: "Physics Quiz 5", pages: 1, date: "Feb 22, 2026" },
  { id: "4", filename: "Differential Equations Final", pages: 6, date: "Feb 20, 2026" },
  { id: "5", filename: "Statistics Problem Set", pages: 3, date: "Feb 18, 2026" },
]

// Each doc gets a unique thumbnail "sketch" — faint lines simulating handwritten content
const THUMBNAIL_SKETCHES: Record<string, React.ReactNode> = {
  "1": (
    // Calculus — integral symbol + curve
    <g opacity="0.18">
      <text x="20" y="36" fontSize="22" fontFamily="serif" fill={colors.black}>∫</text>
      <path d="M38 28 Q50 18, 62 28 T86 28" stroke={colors.black} strokeWidth="1.2" fill="none" />
      <line x1="20" y1="50" x2="80" y2="50" stroke={colors.black} strokeWidth="0.8" />
      <text x="20" y="68" fontSize="9" fontFamily="serif" fill={colors.black}>f(x) = 2x³ - 5x + 1</text>
      <line x1="20" y1="80" x2="70" y2="80" stroke={colors.black} strokeWidth="0.6" />
      <line x1="20" y1="90" x2="60" y2="90" stroke={colors.black} strokeWidth="0.6" />
      <line x1="20" y1="100" x2="75" y2="100" stroke={colors.black} strokeWidth="0.6" />
      <text x="20" y="118" fontSize="9" fontFamily="serif" fill={colors.black}>lim x→∞</text>
      <line x1="20" y1="128" x2="65" y2="128" stroke={colors.black} strokeWidth="0.6" />
    </g>
  ),
  "2": (
    // Linear algebra — matrix
    <g opacity="0.18">
      <text x="18" y="34" fontSize="10" fontFamily="monospace" fill={colors.black}>[ 1  0  3 ]</text>
      <text x="18" y="48" fontSize="10" fontFamily="monospace" fill={colors.black}>[ 0  2 -1 ]</text>
      <text x="18" y="62" fontSize="10" fontFamily="monospace" fill={colors.black}>[ 4  1  0 ]</text>
      <line x1="18" y1="74" x2="72" y2="74" stroke={colors.black} strokeWidth="0.6" />
      <text x="18" y="90" fontSize="9" fontFamily="serif" fill={colors.black}>det(A) = ?</text>
      <line x1="18" y1="100" x2="65" y2="100" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="110" x2="58" y2="110" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="120" x2="70" y2="120" stroke={colors.black} strokeWidth="0.6" />
    </g>
  ),
  "3": (
    // Physics — force diagram hints
    <g opacity="0.18">
      <text x="18" y="34" fontSize="9" fontFamily="serif" fill={colors.black}>F = ma</text>
      <line x1="50" y1="60" x2="50" y2="40" stroke={colors.black} strokeWidth="1" markerEnd="url(#arrow)" />
      <line x1="50" y1="60" x2="50" y2="80" stroke={colors.black} strokeWidth="1" />
      <line x1="50" y1="60" x2="70" y2="60" stroke={colors.black} strokeWidth="1" />
      <circle cx="50" cy="60" r="3" fill={colors.black} />
      <line x1="18" y1="100" x2="75" y2="100" stroke={colors.black} strokeWidth="0.6" />
      <text x="18" y="116" fontSize="9" fontFamily="serif" fill={colors.black}>v = v₀ + at</text>
      <line x1="18" y1="126" x2="60" y2="126" stroke={colors.black} strokeWidth="0.6" />
    </g>
  ),
  "4": (
    // Diff eq — dy/dx notation
    <g opacity="0.18">
      <text x="18" y="34" fontSize="9" fontFamily="serif" fill={colors.black}>dy/dx + 2y = eˣ</text>
      <line x1="18" y1="48" x2="70" y2="48" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="58" x2="60" y2="58" stroke={colors.black} strokeWidth="0.6" />
      <text x="18" y="78" fontSize="9" fontFamily="serif" fill={colors.black}>y(0) = 1</text>
      <line x1="18" y1="90" x2="72" y2="90" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="100" x2="55" y2="100" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="110" x2="68" y2="110" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="120" x2="62" y2="120" stroke={colors.black} strokeWidth="0.6" />
    </g>
  ),
  "5": (
    // Statistics — sigma, x-bar
    <g opacity="0.18">
      <text x="18" y="34" fontSize="9" fontFamily="serif" fill={colors.black}>μ = Σxᵢ / n</text>
      <line x1="18" y1="48" x2="68" y2="48" stroke={colors.black} strokeWidth="0.6" />
      <text x="18" y="66" fontSize="9" fontFamily="serif" fill={colors.black}>σ² = Σ(xᵢ - μ)²</text>
      <line x1="18" y1="78" x2="72" y2="78" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="88" x2="58" y2="88" stroke={colors.black} strokeWidth="0.6" />
      <text x="18" y="106" fontSize="9" fontFamily="serif" fill={colors.black}>P(X ≤ x)</text>
      <line x1="18" y1="116" x2="65" y2="116" stroke={colors.black} strokeWidth="0.6" />
      <line x1="18" y1="126" x2="70" y2="126" stroke={colors.black} strokeWidth="0.6" />
    </g>
  ),
}

function DocumentThumbnail({ docId }: { docId: string }) {
  return (
    <div
      style={{
        width: "100%",
        aspectRatio: "8.5 / 11",
        backgroundColor: "#FAFAFA",
        borderRadius: 8,
        border: `1px solid ${colors.gray100}`,
        position: "relative",
        overflow: "hidden",
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
      {/* Document content sketch */}
      <svg
        width="100%"
        height="100%"
        viewBox="0 0 100 140"
        preserveAspectRatio="xMidYMid meet"
        style={{ position: "absolute", inset: 0 }}
      >
        {THUMBNAIL_SKETCHES[docId]}
      </svg>
    </div>
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

function DocumentCard({ doc, index }: { doc: MockDocument; index: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: 0.1 + index * 0.05 }}
      whileHover={{ boxShadow: `2px 2px 0px 0px ${colors.gray500}`, x: 2, y: 2 }}
      whileTap={{ boxShadow: `0px 0px 0px 0px ${colors.gray500}`, x: 4, y: 4 }}
      style={{
        backgroundColor: colors.white,
        border: `1.5px solid ${colors.gray500}`,
        borderRadius: 14,
        boxShadow: `4px 4px 0px 0px ${colors.gray500}`,
        overflow: "hidden",
        cursor: "pointer",
        display: "flex",
        flexDirection: "column",
      }}
    >
      {/* Thumbnail */}
      <div style={{ padding: "14px 14px 0" }}>
        <DocumentThumbnail docId={doc.id} />
      </div>

      {/* Info */}
      <div style={{ padding: "12px 14px 14px" }}>
        {/* Filename */}
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
          }}
        >
          {doc.filename}
        </div>

        {/* Pages + Date */}
        <div
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 11,
            letterSpacing: "-0.04em",
            color: colors.gray500,
          }}
        >
          {doc.pages} {doc.pages === 1 ? "page" : "pages"} · {doc.date}
        </div>
      </div>
    </motion.div>
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

  const handleUpload = () => setToast("Upload coming soon")

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

        {/* Card grid or Empty State */}
        {documents.length === 0 ? (
          <EmptyState onUpload={handleUpload} />
        ) : (
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))",
              gap: 20,
            }}
          >
            {documents.map((doc, i) => (
              <DocumentCard key={doc.id} doc={doc} index={i} />
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
