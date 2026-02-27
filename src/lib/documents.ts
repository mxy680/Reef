import { createClient } from "./supabase/client"
import { getUserTier, getLimits } from "./limits"

export interface Document {
  id: string
  user_id: string
  filename: string
  status: "processing" | "completed" | "failed"
  page_count: number | null
  problem_count: number | null
  error_message: string | null
  course_id: string | null
  created_at: string
}

export async function listDocuments(): Promise<Document[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("documents")
    .select("*")
    .order("created_at", { ascending: false })

  if (error) throw error
  return data as Document[]
}

export class LimitError extends Error {
  constructor(message: string) {
    super(message)
    this.name = "LimitError"
  }
}

export async function uploadDocument(file: File, thumbnail?: Blob): Promise<Document> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

  // Enforce tier limits
  const tier = await getUserTier()
  const limits = getLimits(tier)

  // File size check
  const maxBytes = limits.maxFileSizeMB * 1024 * 1024
  if (file.size > maxBytes) {
    throw new LimitError(`File too large — max ${limits.maxFileSizeMB} MB on the free plan`)
  }

  // Document count check
  const { count, error: countError } = await supabase
    .from("documents")
    .select("*", { count: "exact", head: true })
    .eq("user_id", user.id)

  if (countError) throw countError
  if ((count ?? 0) >= limits.maxDocuments) {
    throw new LimitError("Document limit reached — upgrade to upload more")
  }

  // 1. Create DB row
  const { data: doc, error: insertError } = await supabase
    .from("documents")
    .insert({ user_id: user.id, filename: file.name })
    .select()
    .single()

  if (insertError) throw insertError
  const document = doc as Document

  // 2. Upload original PDF to Storage
  const storagePath = `${user.id}/${document.id}/original.pdf`
  const { error: uploadError } = await supabase.storage
    .from("documents")
    .upload(storagePath, file, { contentType: "application/pdf" })

  if (uploadError) {
    // Clean up the DB row on storage failure
    await supabase.from("documents").delete().eq("id", document.id)
    throw uploadError
  }

  // 3. Upload thumbnail if provided
  if (thumbnail) {
    const thumbPath = `${user.id}/${document.id}/thumbnail.png`
    await supabase.storage
      .from("documents")
      .upload(thumbPath, thumbnail, { contentType: "image/png" })
      .catch(() => {}) // non-critical
  }

  // 4. Fire-and-forget POST to processing API route
  fetch("/api/documents/process", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ documentId: document.id }),
  }).catch(() => {
    // Fire-and-forget — errors handled server-side
  })

  return document
}

export async function getDocumentDownloadUrl(docId: string): Promise<string> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

  const { data, error } = await supabase.storage
    .from("documents")
    .createSignedUrl(`${user.id}/${docId}/output.pdf`, 60 * 60) // 1 hour

  if (error) throw error
  return data.signedUrl
}

export async function deleteDocument(docId: string): Promise<void> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

  // Delete storage files (both original and output if exists)
  const prefix = `${user.id}/${docId}`
  const { data: files } = await supabase.storage
    .from("documents")
    .list(prefix)

  if (files && files.length > 0) {
    await supabase.storage
      .from("documents")
      .remove(files.map(f => `${prefix}/${f.name}`))
  }

  // Delete DB row
  const { error } = await supabase
    .from("documents")
    .delete()
    .eq("id", docId)

  if (error) throw error
}

export async function moveDocumentToCourse(docId: string, courseId: string | null): Promise<void> {
  const supabase = createClient()
  const { error } = await supabase
    .from("documents")
    .update({ course_id: courseId })
    .eq("id", docId)

  if (error) throw error
}

export async function getDocumentShareUrl(docId: string): Promise<string> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

  // Try output.pdf first, fall back to original.pdf
  const { data, error } = await supabase.storage
    .from("documents")
    .createSignedUrl(`${user.id}/${docId}/output.pdf`, 7 * 24 * 60 * 60) // 7 days

  if (error) {
    // Fall back to original
    const { data: fallback, error: fallbackError } = await supabase.storage
      .from("documents")
      .createSignedUrl(`${user.id}/${docId}/original.pdf`, 7 * 24 * 60 * 60)

    if (fallbackError) throw fallbackError
    return fallback.signedUrl
  }

  return data.signedUrl
}

export async function renameDocument(docId: string, filename: string): Promise<void> {
  const supabase = createClient()
  const { error } = await supabase
    .from("documents")
    .update({ filename })
    .eq("id", docId)

  if (error) throw error
}

export async function duplicateDocument(docId: string): Promise<Document> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

  // Get the original document
  const { data: original, error: fetchError } = await supabase
    .from("documents")
    .select("*")
    .eq("id", docId)
    .single()

  if (fetchError) throw fetchError

  // Create new DB row with "Copy of" prefix
  const newFilename = original.filename.replace(/\.pdf$/i, "") + " (Copy).pdf"
  const { data: doc, error: insertError } = await supabase
    .from("documents")
    .insert({ user_id: user.id, filename: newFilename, status: original.status, page_count: original.page_count, problem_count: original.problem_count })
    .select()
    .single()

  if (insertError) throw insertError
  const newDoc = doc as Document

  // Copy storage files
  const prefix = `${user.id}/${docId}`
  const { data: files } = await supabase.storage.from("documents").list(prefix)

  if (files) {
    for (const file of files) {
      await supabase.storage
        .from("documents")
        .copy(`${prefix}/${file.name}`, `${user.id}/${newDoc.id}/${file.name}`)
    }
  }

  return newDoc
}

export async function getDocumentThumbnailUrls(
  docIds: string[]
): Promise<Record<string, string>> {
  if (docIds.length === 0) return {}

  const supabase = createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return {}

  const paths = docIds.map((id) => `${user.id}/${id}/thumbnail.png`)
  const { data } = await supabase.storage
    .from("documents")
    .createSignedUrls(paths, 60 * 60)

  if (!data) return {}

  const result: Record<string, string> = {}
  data.forEach((item, i) => {
    if (!item.error && item.signedUrl) {
      result[docIds[i]] = item.signedUrl
    }
  })
  return result
}
