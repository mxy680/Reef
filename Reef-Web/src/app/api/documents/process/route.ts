import { NextRequest, NextResponse } from "next/server"
import { createClient, createServiceClient } from "../../../../lib/supabase/server"
import { getUserTier, getLimits } from "../../../../lib/limits"

const REEF_SERVER_URL = process.env.NEXT_PUBLIC_REEF_API_URL || "http://localhost:8000"

export async function POST(request: NextRequest) {
  try {
    const { documentId } = await request.json()
    if (!documentId) {
      return NextResponse.json({ error: "documentId required" }, { status: 400 })
    }

    // Validate user session — try cookies first, then Bearer token (iOS)
    const supabase = await createClient()
    let { data: { user } } = await supabase.auth.getUser()

    if (!user) {
      const authHeader = request.headers.get("authorization")
      if (authHeader?.startsWith("Bearer ")) {
        const token = authHeader.slice(7)
        const { data: { user: tokenUser } } = await createServiceClient().auth.getUser(token)
        user = tokenUser
      }
    }

    if (!user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    // Service role client — bypasses RLS, works regardless of auth method
    const serviceClient = createServiceClient()

    // Enforce document count limit
    const tier = await getUserTier()
    const limits = getLimits(tier)
    const { count, error: countError } = await serviceClient
      .from("documents")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)

    if (countError) {
      return NextResponse.json({ error: "Failed to check document count" }, { status: 500 })
    }
    if ((count ?? 0) > limits.maxDocuments) {
      return NextResponse.json({ error: "Document limit reached" }, { status: 403 })
    }

    // Fetch document row and verify ownership
    const { data: doc, error: fetchError } = await serviceClient
      .from("documents")
      .select("*")
      .eq("id", documentId)
      .eq("user_id", user.id)
      .single()

    if (fetchError || !doc) {
      return NextResponse.json({ error: "Document not found" }, { status: 404 })
    }

    // Download original PDF from Supabase Storage
    const storagePath = `${user.id}/${documentId}/original.pdf`
    const { data: fileData, error: downloadError } = await serviceClient.storage
      .from("documents")
      .download(storagePath)

    if (downloadError || !fileData) {
      await serviceClient
        .from("documents")
        .update({ status: "failed", error_message: "Failed to download original PDF" })
        .eq("id", documentId)
      return NextResponse.json({ error: "Failed to download PDF" }, { status: 500 })
    }

    // Send to server /ai/reconstruct
    const formData = new FormData()
    formData.append("pdf", fileData, doc.filename)

    let response: Response
    try {
      response = await fetch(`${REEF_SERVER_URL}/ai/reconstruct`, {
        method: "POST",
        body: formData,
        signal: AbortSignal.timeout(10 * 60 * 1000), // 10 minute timeout
      })
    } catch (e) {
      const message = e instanceof Error ? e.message : "Reef Server unreachable"
      await serviceClient
        .from("documents")
        .update({ status: "failed", error_message: message })
        .eq("id", documentId)
      return NextResponse.json({ error: message }, { status: 502 })
    }

    if (!response.ok) {
      const errorText = await response.text().catch(() => "Unknown error")
      await serviceClient
        .from("documents")
        .update({ status: "failed", error_message: errorText.slice(0, 500) })
        .eq("id", documentId)
      return NextResponse.json({ error: "Reconstruction failed" }, { status: 502 })
    }

    // Parse response headers
    const pageCount = parseInt(response.headers.get("X-Page-Count") || "0", 10) || null
    const problemCount = parseInt(response.headers.get("X-Problem-Count") || "0", 10) || null

    // Upload reconstructed PDF to Storage
    const outputBlob = await response.blob()
    const outputPath = `${user.id}/${documentId}/output.pdf`
    const { error: uploadError } = await serviceClient.storage
      .from("documents")
      .upload(outputPath, outputBlob, {
        contentType: "application/pdf",
        upsert: true,
      })

    if (uploadError) {
      await serviceClient
        .from("documents")
        .update({ status: "failed", error_message: "Failed to save reconstructed PDF" })
        .eq("id", documentId)
      return NextResponse.json({ error: "Failed to save output" }, { status: 500 })
    }

    // Update document status to completed
    await serviceClient
      .from("documents")
      .update({
        status: "completed",
        page_count: pageCount,
        problem_count: problemCount,
      })
      .eq("id", documentId)

    return NextResponse.json({ status: "ok" })
  } catch (e) {
    console.error("[documents/process]", e)
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Internal error" },
      { status: 500 }
    )
  }
}
