import { NextResponse } from "next/server"
import { createClient, createServiceClient } from "../../../../lib/supabase/server"

const ADMIN_EMAIL = "markshteyn1@gmail.com"

export async function GET() {
  // Auth check: verify caller is admin
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user || user.email !== ADMIN_EMAIL) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 })
  }

  // Use service role client to bypass RLS
  const service = createServiceClient()

  const [profilesRes, documentsRes] = await Promise.all([
    service.from("profiles").select("*").order("created_at", { ascending: false }),
    service.from("documents").select("*").order("created_at", { ascending: false }),
  ])

  if (profilesRes.error || documentsRes.error) {
    return NextResponse.json(
      { error: profilesRes.error?.message || documentsRes.error?.message },
      { status: 500 }
    )
  }

  const users = profilesRes.data
  const documents = documentsRes.data

  // Aggregate stats
  const totalUsers = users.length
  const totalDocuments = documents.length
  const statusCounts: Record<string, number> = {}
  for (const doc of documents) {
    const s = doc.status || "unknown"
    statusCounts[s] = (statusCounts[s] || 0) + 1
  }

  // Sign-ups per day (last 30 days)
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
  const signupsPerDay: Record<string, number> = {}
  for (const u of users) {
    const day = u.created_at?.slice(0, 10)
    if (day && new Date(day) >= thirtyDaysAgo) {
      signupsPerDay[day] = (signupsPerDay[day] || 0) + 1
    }
  }

  // Count documents per user
  const docsPerUser: Record<string, number> = {}
  for (const doc of documents) {
    const uid = doc.user_id || doc.id
    docsPerUser[uid] = (docsPerUser[uid] || 0) + 1
  }

  return NextResponse.json({
    users: users.map((u: any) => ({
      id: u.id,
      email: u.email,
      display_name: u.display_name,
      grade: u.grade,
      subjects: u.subjects,
      documents_count: docsPerUser[u.id] || 0,
      created_at: u.created_at,
    })),
    documents: documents.map((d: any) => ({
      id: d.id,
      filename: d.filename,
      user_id: d.user_id,
      user_email: users.find((u: any) => u.id === d.user_id)?.email || null,
      status: d.status,
      pages: d.pages,
      problems: d.problems,
      created_at: d.created_at,
    })),
    stats: {
      totalUsers,
      totalDocuments,
      statusCounts,
      signupsPerDay,
    },
  })
}
