"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "../../lib/supabase/client"
import { getProfile } from "../../lib/api"
import { colors } from "../../lib/colors"
import { DashboardProvider, type DashboardProfile } from "../../components/dashboard/DashboardContext"
import DashboardSidebar from "../../components/dashboard/DashboardSidebar"
import DashboardHeader from "../../components/dashboard/DashboardHeader"

const fontFamily = `"Epilogue", sans-serif`
const SIDEBAR_WIDTH = 260

function SkeletonBlock({ width, height }: { width: string | number; height: number }) {
  return (
    <div
      style={{
        width,
        height,
        backgroundColor: colors.gray100,
        borderRadius: 4,
      }}
    />
  )
}

function LoadingSkeleton() {
  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      {/* Sidebar skeleton */}
      <div
        style={{
          width: SIDEBAR_WIDTH,
          minHeight: "100vh",
          backgroundColor: colors.white,
          borderRight: `2px solid ${colors.black}`,
          padding: "24px 20px",
          boxSizing: "border-box",
          display: "flex",
          flexDirection: "column",
          gap: 16,
        }}
      >
        <SkeletonBlock width={80} height={28} />
        <div style={{ marginTop: 16, display: "flex", flexDirection: "column", gap: 12 }}>
          {[1, 2, 3, 4].map((i) => (
            <SkeletonBlock key={i} width="100%" height={36} />
          ))}
        </div>
      </div>
      {/* Main skeleton */}
      <div style={{ flex: 1 }}>
        <div
          style={{
            height: 64,
            borderBottom: `2px solid ${colors.black}`,
            backgroundColor: colors.white,
            padding: "0 32px",
            display: "flex",
            alignItems: "center",
          }}
        >
          <SkeletonBlock width={140} height={24} />
        </div>
        <div style={{ padding: 32, display: "flex", flexDirection: "column", gap: 16 }}>
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
        const p = await getProfile(user.id)
        if (!p || !p.onboarding_completed) {
          router.push("/onboarding")
          return
        }
        setProfile(p)
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
    <DashboardProvider value={{ profile, userId }}>
      <div style={{ display: "flex", minHeight: "100vh", backgroundColor: colors.surface }}>
        <DashboardSidebar />
        <div style={{ flex: 1, marginLeft: SIDEBAR_WIDTH, display: "flex", flexDirection: "column" }}>
          <DashboardHeader />
          <main
            style={{
              flex: 1,
              overflowY: "auto",
              padding: 32,
            }}
          >
            {children}
          </main>
        </div>
      </div>
    </DashboardProvider>
  )
}
