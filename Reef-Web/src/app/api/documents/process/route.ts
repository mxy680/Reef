import { NextResponse } from "next/server"
import { createServiceClient } from "@/lib/supabase/server"

const REEF_SERVER_URL = process.env.REEF_SERVER_URL || "http://localhost:8000"

export async function POST(request: Request) {
  let documentId: string | undefined

  try {
    const body = await request.json()
    documentId = body.documentId
    const userId: string | undefined = body.userId
    const accessToken: string | undefined = body.accessToken

    if (!documentId || !userId) {
      return NextResponse.json({ error: "Missing documentId or userId" }, { status: 400 })
    }

    if (!accessToken) {
      return NextResponse.json({ error: "Not authenticated" }, { status: 401 })
    }

    // Fire-and-forget: tell Reef-Server to process this document.
    // The v2 pipeline downloads the PDF from storage, runs Mathpix OCR,
    // compiles LaTeX, and uploads the result — all in the background.
    const response = await fetch(
      `${REEF_SERVER_URL}/ai/v2/reconstruct-document`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ document_id: documentId }),
      },
    )

    if (!response.ok) {
      const errorText = await response.text()
      const supabase = createServiceClient()
      await supabase.from("documents").update({
        status: "failed",
        error_message: `Reconstruction failed: ${errorText.slice(0, 500)}`,
      }).eq("id", documentId)
      return NextResponse.json({ error: "Reconstruction failed" }, { status: 500 })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error("[process] Error:", error)

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
