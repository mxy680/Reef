import { auth } from "@/lib/auth"
import { redirect } from "next/navigation"
import { UploadForm } from "@/components/upload-form"
import { prisma } from "@/lib/db"

export default async function UploadPage() {
  const session = await auth()
  if (!session?.user?.id) redirect("/")

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000)
  const used = await prisma.document.count({
    where: { userId: session.user.id, createdAt: { gte: since } },
  })
  const limit = (session as any).dailyLimit ?? 3

  return (
    <main className="mx-auto max-w-2xl p-8">
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Upload a Document</h1>
        <p className="text-sm text-muted-foreground">{used}/{limit} today</p>
      </div>
      <UploadForm />
    </main>
  )
}
