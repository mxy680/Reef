"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "../../lib/supabase/client"
import { getProfile } from "../../lib/profiles"
import { motion } from "framer-motion"
import { colors } from "../../lib/colors"
import { DashboardProvider, useDashboard, type DashboardProfile } from "../../components/dashboard/DashboardContext"
import DashboardSidebar, { SIDEBAR_WIDTH_OPEN, SIDEBAR_WIDTH_COLLAPSED } from "../../components/dashboard/DashboardSidebar"
import DashboardHeader from "../../components/dashboard/DashboardHeader"

function SkeletonBlock({ width, height }: { width: string | number; height: number }) {
  return (
    <div
      style={{
        width,
        height,
        backgroundColor: colors.gray100,
        borderRadius: 8,
      }}
    />
  )
}

const cardStyle: React.CSSProperties = {
  backgroundColor: colors.white,
  border: `1.5px solid ${colors.gray500}`,
  borderRadius: 16,
  boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
}

function LoadingSkeleton() {
  return (
    <div className="dotted-grid" style={{ display: "flex", minHeight: "100vh", backgroundColor: colors.white }}>
      {/* Sidebar skeleton */}
      <div
        style={{
          ...cardStyle,
          width: SIDEBAR_WIDTH_OPEN,
          position: "fixed",
          top: 12,
          left: 12,
          height: "calc(100vh - 24px)",
          padding: "24px 20px",
          boxSizing: "border-box",
          display: "flex",
          flexDirection: "column",
          gap: 16,
        }}
      >
        <SkeletonBlock width={80} height={28} />
        <div style={{ marginTop: 16, display: "flex", flexDirection: "column", gap: 8 }}>
          {[1, 2, 3, 4].map((i) => (
            <SkeletonBlock key={i} width="100%" height={36} />
          ))}
        </div>
      </div>
      {/* Main column */}
      <div style={{ flex: 1, marginLeft: SIDEBAR_WIDTH_OPEN + 28, display: "flex", flexDirection: "column" }}>
        {/* Header skeleton */}
        <div
          style={{
            ...cardStyle,
            height: 64,
            margin: "12px 12px 0 0",
            padding: "0 24px",
            display: "flex",
            alignItems: "center",
          }}
        >
          <SkeletonBlock width={140} height={24} />
        </div>
        {/* Content skeleton */}
        <div
          style={{
            ...cardStyle,
            flex: 1,
            margin: "12px 12px 12px 0",
            padding: 32,
            display: "flex",
            flexDirection: "column",
            gap: 16,
          }}
        >
          <SkeletonBlock width={260} height={32} />
          <div style={{ display: "flex", gap: 16 }}>
            {[1, 2, 3].map((i) => (
              <SkeletonBlock key={i} width="33%" height={100} />
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

function DashboardInner({ children }: { children: React.ReactNode }) {
  const { sidebarOpen } = useDashboard()
  const marginLeft = sidebarOpen ? SIDEBAR_WIDTH_OPEN : SIDEBAR_WIDTH_COLLAPSED

  return (
    <div className="dotted-grid" style={{ display: "flex", minHeight: "100vh", backgroundColor: colors.white }}>
      <DashboardSidebar />
      <motion.div
        initial={false}
        animate={{ marginLeft: marginLeft + 28 }}
        transition={{ type: "spring", bounce: 0.15, duration: 0.35 }}
        style={{ flex: 1, display: "flex", flexDirection: "column" }}
      >
        <DashboardHeader />
        <main
          style={{
            flex: 1,
            overflowY: "auto",
            padding: 32,
            margin: "12px 12px 12px 0",
            backgroundColor: colors.white,
            border: `1.5px solid ${colors.gray500}`,
            borderRadius: 16,
            boxShadow: `3px 3px 0px 0px ${colors.gray500}`,
          }}
        >
          {children}
        </main>
      </motion.div>
    </div>
  )
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const [profile, setProfile] = useState<DashboardProfile | null>(null)
  const [userId, setUserId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function init() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        router.push("/auth")
        return
      }

      try {
        const p = await getProfile()
        if (!p || !p.onboarding_completed) {
          router.push("/onboarding")
          return
        }
        setProfile({ ...p, email: p.email ?? "" })
        setUserId(user.id)
      } catch {
        router.push("/onboarding")
        return
      }

      setLoading(false)
    }
    init()
  }, [router])

  if (loading || !profile || !userId) {
    return <LoadingSkeleton />
  }

  return (
    <DashboardProvider value={{ profile, setProfile: (p) => setProfile(p), userId }}>
      <DashboardInner>{children}</DashboardInner>
    </DashboardProvider>
  )
}
