import { NextRequest, NextResponse } from "next/server"
import { auth } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { readFile } from "fs/promises"

export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const { id } = await params
  const doc = await prisma.document.findFirst({
    where: { id, userId: session.user.id },
  })

  if (!doc || !doc.outputPath || doc.status !== "completed") {
    return NextResponse.json({ error: "Document not found" }, { status: 404 })
  }

  const pdfBytes = await readFile(doc.outputPath)
  return new NextResponse(pdfBytes, {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${doc.filename.replace(".pdf", "")}-reconstructed.pdf"`,
    },
  })
}
