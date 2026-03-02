import { NextResponse } from "next/server"
import { Agent } from "undici"
import { createClient, createServiceClient } from "@/lib/supabase/server"

const REEF_SERVER_URL = process.env.REEF_SERVER_URL || "http://localhost:8000"

// Reconstruction can take 5-10 min with verification retries + rate limits
const reconstructAgent = new Agent({
  headersTimeout: 10 * 60 * 1000,
  bodyTimeout: 10 * 60 * 1000,
})

export const maxDuration = 600 // 10 minutes

export async function POST(request: Request) {
  let documentId: string | undefined
  let userId: string | undefined

  try {
    const body = await request.json()
    documentId = body.documentId
    userId = body.userId

    if (!documentId || !userId) {
      return NextResponse.json({ error: "Missing documentId or userId" }, { status: 400 })
    }

    // Get the user's Supabase access token (passed via cookies from the browser)
    const supabaseAuth = await createClient()
    const { data: { session } } = await supabaseAuth.auth.getSession()
    if (!session?.access_token) {
      return NextResponse.json({ error: "Not authenticated" }, { status: 401 })
    }

    const supabase = createServiceClient()

    // Download original PDF from Supabase Storage
    const storagePath = `${userId}/${documentId}/original.pdf`
    const { data: fileData, error: downloadError } = await supabase.storage
      .from("documents")
      .download(storagePath)

    if (downloadError || !fileData) {
      await supabase.from("documents").update({
        status: "failed",
        error_message: `Failed to download original PDF: ${downloadError?.message}`,
      }).eq("id", documentId)
      return NextResponse.json({ error: "Failed to download PDF" }, { status: 500 })
    }

    // Send to Reef-Server for merged reconstruction
    const formData = new FormData()
    formData.append("pdf", fileData, "original.pdf")

    const response = await fetch(
      `${REEF_SERVER_URL}/ai/reconstruct?document_id=${documentId}`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${session.access_token}` },
        body: formData,
        // @ts-expect-error Node.js undici dispatcher option
        dispatcher: reconstructAgent,
      },
    )

    if (!response.ok) {
      const errorText = await response.text()
      await supabase.from("documents").update({
        status: "failed",
        error_message: `Reconstruction failed: ${errorText.slice(0, 500)}`,
      }).eq("id", documentId)
      return NextResponse.json({ error: "Reconstruction failed" }, { status: 500 })
    }

    const problemCount = parseInt(response.headers.get("X-Problem-Count") || "0", 10)
    const pageCount = parseInt(response.headers.get("X-Page-Count") || "0", 10)

    // Upload reconstructed output.pdf to Supabase Storage
    const outputPdf = await response.arrayBuffer()
    const outputPath = `${userId}/${documentId}/output.pdf`
    await supabase.storage
      .from("documents")
      .upload(outputPath, new Uint8Array(outputPdf), {
        contentType: "application/pdf",
        upsert: true,
      })

    // Update document status with metadata
    await supabase.from("documents").update({
      status: "completed",
      page_count: pageCount || null,
      problem_count: problemCount || null,
    }).eq("id", documentId)

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error("[process] Error:", error)

    // Try to mark as failed
    if (documentId) {
      try {
        const supabase = createServiceClient()
        await supabase.from("documents").update({
          status: "failed",
          error_message: error instanceof Error ? error.message : "Unknown error",
        }).eq("id", documentId)
      } catch {
        // Ignore cleanup errors
      }
    }

    return NextResponse.json({ error: "Internal server error" }, { status: 500 })
  }
}
