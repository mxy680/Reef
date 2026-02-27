"use client"

import { useEffect, useState } from "react"
import { motion } from "framer-motion"
import { colors } from "../../../lib/colors"

const fontFamily = `"Epilogue", sans-serif`

interface AdminUser {
  id: string
  email: string | null
  display_name: string | null
  grade: string | null
  subjects: string[] | null
  documents_count: number
  created_at: string
}

interface AdminDocument {
  id: string
  filename: string | null
  user_id: string
  user_email: string | null
  status: string | null
  pages: number | null
  problems: number | null
  created_at: string
}

interface AdminStats {
  totalUsers: number
  totalDocuments: number
  statusCounts: Record<string, number>
  signupsPerDay: Record<string, number>
}

interface AdminData {
  users: AdminUser[]
  documents: AdminDocument[]
  stats: AdminStats
}

const cardStyle: React.CSSProperties = {
  backgroundColor: colors.white,
  border: `1.5px solid ${colors.gray500}`,
  borderRadius: 12,
  boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
  padding: 20,
}

const thStyle: React.CSSProperties = {
  fontFamily,
  fontWeight: 800,
  fontSize: 12,
  letterSpacing: "0.04em",
  textTransform: "uppercase",
  color: colors.gray600,
  textAlign: "left",
  padding: "10px 12px",
  borderBottom: `2px solid ${colors.gray500}`,
  whiteSpace: "nowrap",
}

const tdStyle: React.CSSProperties = {
  fontFamily,
  fontWeight: 500,
  fontSize: 13,
  color: colors.black,
  padding: "10px 12px",
  borderBottom: `1px solid ${colors.gray100}`,
  whiteSpace: "nowrap",
  maxWidth: 220,
  overflow: "hidden",
  textOverflow: "ellipsis",
}

const statusColors: Record<string, string> = {
  completed: "#22c55e",
  processing: colors.primary,
  failed: "#ef4444",
  pending: colors.gray500,
  uploading: colors.accent,
}

function StatusBadge({ status }: { status: string | null }) {
  const s = status || "unknown"
  const bg = statusColors[s] || colors.gray400
  return (
    <span
      style={{
        display: "inline-block",
        padding: "3px 10px",
        borderRadius: 6,
        backgroundColor: bg,
        border: `1.5px solid ${colors.black}`,
        fontFamily,
        fontWeight: 800,
        fontSize: 10,
        letterSpacing: "0.04em",
        textTransform: "uppercase",
        color: colors.white,
      }}
    >
      {s}
    </span>
  )
}

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ ...cardStyle, flex: 1, minWidth: 140, textAlign: "center" }}>
      <div
        style={{
          fontFamily,
          fontWeight: 900,
          fontSize: 32,
          letterSpacing: "-0.04em",
          color: colors.black,
        }}
      >
        {value}
      </div>
      <div
        style={{
          fontFamily,
          fontWeight: 700,
          fontSize: 12,
          letterSpacing: "0.04em",
          textTransform: "uppercase",
          color: colors.gray600,
          marginTop: 4,
        }}
      >
        {label}
      </div>
    </div>
  )
}

function SkeletonRow({ cols }: { cols: number }) {
  return (
    <tr>
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} style={tdStyle}>
          <div style={{ width: 80, height: 14, backgroundColor: colors.gray100, borderRadius: 4 }} />
        </td>
      ))}
    </tr>
  )
}

function LoadingSkeleton() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
      <div style={{ display: "flex", gap: 16, flexWrap: "wrap" }}>
        {[1, 2, 3, 4, 5].map((i) => (
          <div key={i} style={{ ...cardStyle, flex: 1, minWidth: 140, textAlign: "center", padding: 20 }}>
            <div style={{ width: 48, height: 32, backgroundColor: colors.gray100, borderRadius: 6, margin: "0 auto" }} />
            <div style={{ width: 60, height: 12, backgroundColor: colors.gray100, borderRadius: 4, margin: "8px auto 0" }} />
          </div>
        ))}
      </div>
      <div style={cardStyle}>
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <tbody>
            {[1, 2, 3].map((i) => <SkeletonRow key={i} cols={6} />)}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  })
}

function ConfirmModal({
  email,
  onConfirm,
  onCancel,
  loading,
}: {
  email: string
  onConfirm: () => void
  onCancel: () => void
  loading: boolean
}) {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 9999,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "rgba(0,0,0,0.4)",
      }}
      onClick={onCancel}
    >
      <div
        style={{
          ...cardStyle,
          maxWidth: 420,
          width: "90%",
          display: "flex",
          flexDirection: "column",
          gap: 16,
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <h3
          style={{
            fontFamily,
            fontWeight: 800,
            fontSize: 16,
            color: colors.black,
            margin: 0,
          }}
        >
          Remove User
        </h3>
        <p
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 13,
            color: colors.gray600,
            margin: 0,
            lineHeight: 1.5,
          }}
        >
          Permanently delete <strong style={{ color: colors.black }}>{email}</strong>? This removes
          their account, all documents, and courses.
        </p>
        <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
          <button
            onClick={onCancel}
            disabled={loading}
            style={{
              fontFamily,
              fontWeight: 700,
              fontSize: 13,
              padding: "8px 18px",
              borderRadius: 8,
              border: `1.5px solid ${colors.gray500}`,
              backgroundColor: colors.white,
              color: colors.black,
              cursor: "pointer",
            }}
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            style={{
              fontFamily,
              fontWeight: 700,
              fontSize: 13,
              padding: "8px 18px",
              borderRadius: 8,
              border: `1.5px solid #ef4444`,
              backgroundColor: "#ef4444",
              color: colors.white,
              cursor: loading ? "not-allowed" : "pointer",
              opacity: loading ? 0.6 : 1,
            }}
          >
            {loading ? "Removing…" : "Remove"}
          </button>
        </div>
      </div>
    </div>
  )
}

export default function AdminPage() {
  const [data, setData] = useState<AdminData | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<AdminUser | null>(null)
  const [deleting, setDeleting] = useState(false)

  useEffect(() => {
    fetch("/api/admin/stats")
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        return r.json()
      })
      .then(setData)
      .catch((e) => setError(e.message))
  }, [])

  // Determine admin's own user ID (to hide their Remove button)
  const adminEmail = "markshteyn1@gmail.com"
  const currentUserId = data?.users.find((u) => u.email === adminEmail)?.id

  async function handleDelete(userId: string) {
    setDeleting(true)
    try {
      const res = await fetch(`/api/admin/users/${userId}`, { method: "DELETE" })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.error || `HTTP ${res.status}`)
      }
      // Update local state
      setData((prev) => {
        if (!prev) return prev
        const removedUser = prev.users.find((u) => u.id === userId)
        const updatedUsers = prev.users.filter((u) => u.id !== userId)
        const updatedDocs = prev.documents.filter((d) => d.user_id !== userId)
        const removedDocCount = removedUser?.documents_count || 0
        // Recompute status counts from remaining docs
        const statusCounts: Record<string, number> = {}
        for (const d of updatedDocs) {
          const s = d.status || "unknown"
          statusCounts[s] = (statusCounts[s] || 0) + 1
        }
        return {
          users: updatedUsers,
          documents: updatedDocs,
          stats: {
            ...prev.stats,
            totalUsers: updatedUsers.length,
            totalDocuments: prev.stats.totalDocuments - removedDocCount,
            statusCounts,
          },
        }
      })
    } catch (e: any) {
      alert(`Failed to remove user: ${e.message}`)
    } finally {
      setDeleting(false)
      setDeleteTarget(null)
    }
  }

  if (error) {
    return (
      <div style={{ fontFamily, fontWeight: 700, fontSize: 18, color: "#ef4444", padding: 32 }}>
        Failed to load admin data: {error}
      </div>
    )
  }

  if (!data) return <LoadingSkeleton />

  const { users, documents, stats } = data

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      style={{ display: "flex", flexDirection: "column", gap: 28 }}
    >
      {/* Header */}
      <div>
        <h1
          style={{
            fontFamily,
            fontWeight: 900,
            fontSize: 28,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: 0,
          }}
        >
          Admin Dashboard
        </h1>
        <p
          style={{
            fontFamily,
            fontWeight: 500,
            fontSize: 14,
            color: colors.gray600,
            margin: "4px 0 0",
          }}
        >
          System-wide overview
        </p>
      </div>

      {/* Stat cards */}
      <div style={{ display: "flex", gap: 16, flexWrap: "wrap" }}>
        <StatCard label="Users" value={stats.totalUsers} />
        <StatCard label="Documents" value={stats.totalDocuments} />
        <StatCard label="Completed" value={stats.statusCounts.completed || 0} />
        <StatCard label="Processing" value={stats.statusCounts.processing || 0} />
        <StatCard label="Failed" value={stats.statusCounts.failed || 0} />
      </div>

      {/* Users table */}
      <div style={cardStyle}>
        <h2
          style={{
            fontFamily,
            fontWeight: 800,
            fontSize: 18,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: "0 0 16px",
          }}
        >
          Users ({users.length})
        </h2>
        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                <th style={thStyle}>Email</th>
                <th style={thStyle}>Display Name</th>
                <th style={thStyle}>Grade</th>
                <th style={thStyle}>Subjects</th>
                <th style={thStyle}>Docs</th>
                <th style={thStyle}>Joined</th>
                <th style={thStyle}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td style={tdStyle}>{u.email || "—"}</td>
                  <td style={tdStyle}>{u.display_name || "—"}</td>
                  <td style={tdStyle}>{u.grade || "—"}</td>
                  <td style={tdStyle}>{u.subjects?.join(", ") || "—"}</td>
                  <td style={{ ...tdStyle, fontWeight: 700 }}>{u.documents_count}</td>
                  <td style={tdStyle}>{u.created_at ? formatDate(u.created_at) : "—"}</td>
                  <td style={tdStyle}>
                    {u.id !== currentUserId && (
                      <button
                        onClick={() => setDeleteTarget(u)}
                        style={{
                          fontFamily,
                          fontWeight: 700,
                          fontSize: 11,
                          padding: "4px 12px",
                          borderRadius: 6,
                          border: `1.5px solid #ef4444`,
                          backgroundColor: "transparent",
                          color: "#ef4444",
                          cursor: "pointer",
                        }}
                      >
                        Remove
                      </button>
                    )}
                  </td>
                </tr>
              ))}
              {users.length === 0 && (
                <tr>
                  <td style={{ ...tdStyle, color: colors.gray500 }} colSpan={7}>
                    No users found
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Documents table */}
      <div style={cardStyle}>
        <h2
          style={{
            fontFamily,
            fontWeight: 800,
            fontSize: 18,
            letterSpacing: "-0.04em",
            color: colors.black,
            margin: "0 0 16px",
          }}
        >
          Documents ({documents.length})
        </h2>
        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                <th style={thStyle}>Filename</th>
                <th style={thStyle}>User</th>
                <th style={thStyle}>Status</th>
                <th style={thStyle}>Pages</th>
                <th style={thStyle}>Problems</th>
                <th style={thStyle}>Created</th>
              </tr>
            </thead>
            <tbody>
              {documents.map((d) => (
                <tr key={d.id}>
                  <td style={tdStyle}>{d.filename || "—"}</td>
                  <td style={tdStyle}>{d.user_email || "—"}</td>
                  <td style={tdStyle}><StatusBadge status={d.status} /></td>
                  <td style={tdStyle}>{d.pages ?? "—"}</td>
                  <td style={tdStyle}>{d.problems ?? "—"}</td>
                  <td style={tdStyle}>{d.created_at ? formatDate(d.created_at) : "—"}</td>
                </tr>
              ))}
              {documents.length === 0 && (
                <tr>
                  <td style={{ ...tdStyle, color: colors.gray500 }} colSpan={6}>
                    No documents found
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
      {/* Delete confirmation modal */}
      {deleteTarget && (
        <ConfirmModal
          email={deleteTarget.email || deleteTarget.id}
          onConfirm={() => handleDelete(deleteTarget.id)}
          onCancel={() => setDeleteTarget(null)}
          loading={deleting}
        />
      )}
    </motion.div>
  )
}
