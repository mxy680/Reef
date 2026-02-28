import { NextResponse } from "next/server"
import { createClient, createServiceClient } from "../../../../../lib/supabase/server"

const ADMIN_EMAIL = "markshteyn1@gmail.com"

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ userId: string }> }
) {
  const { userId } = await params

  // Auth check: verify caller is admin
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user || user.email !== ADMIN_EMAIL) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 })
  }

  // Prevent self-deletion
  if (userId === user.id) {
    return NextResponse.json({ error: "Cannot delete your own account" }, { status: 400 })
  }

  const service = createServiceClient()

  try {
    // 1. Remove storage files under documents/{userId}/
    const { data: files } = await service.storage
      .from("documents")
      .list(userId)

    if (files && files.length > 0) {
      const paths = files.map((f) => `${userId}/${f.name}`)
      await service.storage.from("documents").remove(paths)
    }

    // 2. Delete documents
    await service.from("documents").delete().eq("user_id", userId)

    // 3. Delete courses
    await service.from("courses").delete().eq("user_id", userId)

    // 4. Delete profile
    await service.from("profiles").delete().eq("id", userId)

    // 5. Delete auth user
    const { error: authError } = await service.auth.admin.deleteUser(userId)
    if (authError) {
      return NextResponse.json({ error: authError.message }, { status: 500 })
    }

    return NextResponse.json({ success: true })
  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Failed to delete user" }, { status: 500 })
  }
}
