import { NextRequest, NextResponse } from "next/server"
import { createServiceClient } from "@/lib/supabase/server"

export async function POST(req: NextRequest) {
  const { email } = await req.json()

  if (!email || typeof email !== "string" || !email.includes("@")) {
    return NextResponse.json({ error: "Valid email required" }, { status: 400 })
  }

  const supabase = createServiceClient()

  const { error } = await supabase
    .from("newsletter_subscribers")
    .upsert({ email: email.toLowerCase().trim() }, { onConflict: "email" })

  if (error) {
    console.error("Newsletter signup error:", error)
    return NextResponse.json({ error: "Something went wrong" }, { status: 500 })
  }

  return NextResponse.json({ success: true })
}
