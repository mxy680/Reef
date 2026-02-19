"use server"

import { requireAdmin } from "@/lib/admin"
import { prisma } from "@/lib/db"
import { revalidatePath } from "next/cache"
import { unlink } from "fs/promises"

export async function updateDailyLimit(userId: string, limit: number) {
  await requireAdmin()

  if (limit < 0 || limit > 100 || !Number.isInteger(limit)) {
    throw new Error("Limit must be an integer between 0 and 100")
  }

  await prisma.user.update({
    where: { id: userId },
    data: { dailyLimit: limit },
  })

  revalidatePath("/admin")
  revalidatePath(`/admin/users/${userId}`)
}

export async function deleteUser(userId: string) {
  await requireAdmin()

  // Find all documents to clean up files
  const documents = await prisma.document.findMany({
    where: { userId },
    select: { outputPath: true },
  })

  // Delete user (cascade deletes documents in DB)
  await prisma.user.delete({ where: { id: userId } })

  // Clean up PDF files from disk
  for (const doc of documents) {
    if (doc.outputPath) {
      try {
        await unlink(doc.outputPath)
      } catch {
        // File may already be gone
      }
    }
  }

  revalidatePath("/admin")
}

export async function deleteDocument(documentId: string) {
  await requireAdmin()

  const doc = await prisma.document.findUnique({
    where: { id: documentId },
    select: { outputPath: true, userId: true },
  })

  if (!doc) throw new Error("Document not found")

  await prisma.document.delete({ where: { id: documentId } })

  if (doc.outputPath) {
    try {
      await unlink(doc.outputPath)
    } catch {
      // File may already be gone
    }
  }

  revalidatePath("/admin")
  revalidatePath(`/admin/users/${doc.userId}`)
}
