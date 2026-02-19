import { notFound } from "next/navigation"
import Link from "next/link"
import { prisma } from "@/lib/db"
import { requireAdmin } from "@/lib/admin"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { DocumentsTable } from "../../documents-table"
import { DailyLimitForm } from "./daily-limit-form"

export const dynamic = "force-dynamic"

export default async function UserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  await requireAdmin()
  const { id } = await params

  const user = await prisma.user.findUnique({
    where: { id },
    include: {
      documents: { orderBy: { createdAt: "desc" } },
      _count: { select: { documents: true } },
    },
  })

  if (!user) notFound()

  const documents = user.documents.map((doc) => ({
    ...doc,
    user: { email: user.email, name: user.name },
  }))

  return (
    <div className="space-y-6">
      <Link href="/admin" className="text-sm text-muted-foreground hover:text-foreground">
        &larr; Back to dashboard
      </Link>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Profile</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm">
            <div><span className="text-muted-foreground">Name:</span> {user.name || "—"}</div>
            <div><span className="text-muted-foreground">Email:</span> {user.email}</div>
            <div><span className="text-muted-foreground">ID:</span> <code className="text-xs">{user.id}</code></div>
            <div><span className="text-muted-foreground">Joined:</span> {user.createdAt.toLocaleDateString()}</div>
            {user.picture && (
              <img src={user.picture} alt="" className="mt-2 h-12 w-12 rounded-full" />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Usage</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="text-sm">
              <span className="text-muted-foreground">Total documents:</span>{" "}
              <Badge variant="secondary">{user._count.documents}</Badge>
            </div>
            <Separator />
            <DailyLimitForm userId={user.id} currentLimit={user.dailyLimit} />
          </CardContent>
        </Card>
      </div>

      <div>
        <h2 className="mb-3 text-lg font-semibold">Documents</h2>
        {documents.length > 0 ? (
          <DocumentsTable documents={documents} />
        ) : (
          <p className="text-sm text-muted-foreground">No documents yet.</p>
        )}
      </div>
    </div>
  )
}
