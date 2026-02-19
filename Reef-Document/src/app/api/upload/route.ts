import { NextRequest, NextResponse } from "next/server"
import { auth } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { writeFile, mkdir } from "fs/promises"
import path from "path"

const REEF_SERVER_URL = process.env.REEF_SERVER_URL || "http://app:8000"
const MAX_FILE_SIZE = 20 * 1024 * 1024 // 20MB

export async function POST(req: NextRequest) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const userId = session.user.id
  const dailyLimit = (session as any).dailyLimit ?? 3

  // Check daily limit
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000)
  const count = await prisma.document.count({
    where: { userId, createdAt: { gte: since } },
  })
  if (count >= dailyLimit) {
    return NextResponse.json(
      { error: "Daily limit reached", limit: dailyLimit, used: count },
      { status: 429 }
    )
  }

  // Parse the uploaded PDF
  const formData = await req.formData()
  const file = formData.get("pdf") as File | null
  if (!file || file.type !== "application/pdf") {
    return NextResponse.json({ error: "A PDF file is required" }, { status: 400 })
  }
  if (file.size > MAX_FILE_SIZE) {
    return NextResponse.json({ error: "File too large (max 20MB)" }, { status: 400 })
  }

  // Create document record
  const doc = await prisma.document.create({
    data: { userId, filename: file.name, status: "processing" },
  })

  try {
    // Proxy to Reef-Server
    const proxyForm = new FormData()
    proxyForm.append("pdf", file)

    const resp = await fetch(`${REEF_SERVER_URL}/ai/reconstruct`, {
      method: "POST",
      body: proxyForm,
      signal: AbortSignal.timeout(10 * 60 * 1000), // 10 min timeout
    })

    if (!resp.ok) {
      const errText = await resp.text()
      await prisma.document.update({
        where: { id: doc.id },
        data: { status: "failed", errorMessage: errText.slice(0, 500) },
      })
      return NextResponse.json({ error: "Reconstruction failed", detail: errText }, { status: 502 })
    }

    // Save the output PDF
    const pdfBytes = await resp.arrayBuffer()
    const dir = path.join("/data/documents", userId)
    await mkdir(dir, { recursive: true })
    const outPath = path.join(dir, `${doc.id}.pdf`)
    await writeFile(outPath, Buffer.from(pdfBytes))

    const pageCount = parseInt(resp.headers.get("X-Page-Count") || "0")
    const problemCount = parseInt(resp.headers.get("X-Problem-Count") || "0")

    await prisma.document.update({
      where: { id: doc.id },
      data: { status: "completed", outputPath: outPath, pageCount, problemCount },
    })

    return NextResponse.json({
      id: doc.id,
      status: "completed",
      pageCount,
      problemCount,
    })
  } catch (err: any) {
    await prisma.document.update({
      where: { id: doc.id },
      data: { status: "failed", errorMessage: err.message?.slice(0, 500) },
    })
    return NextResponse.json({ error: "Reconstruction failed", detail: err.message }, { status: 500 })
  }
}
