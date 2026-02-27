import { createClient } from "./supabase/client"

export interface Document {
  id: string
  user_id: string
  filename: string
  status: "processing" | "completed" | "failed"
  page_count: number | null
  problem_count: number | null
  error_message: string | null
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

export async function uploadDocument(file: File): Promise<Document> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

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

  // 3. Fire-and-forget POST to processing API route
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
