import { auth } from "@/lib/auth"
import { redirect } from "next/navigation"
import { prisma } from "@/lib/db"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { Download } from "lucide-react"
import Link from "next/link"

export default async function DocumentsPage() {
  const session = await auth()
  if (!session?.user?.id) redirect("/")

  const documents = await prisma.document.findMany({
    where: { userId: session.user.id },
    orderBy: { createdAt: "desc" },
  })

  return (
    <main className="mx-auto max-w-4xl p-8">
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Your Documents</h1>
        <Button asChild><Link href="/upload">New Upload</Link></Button>
      </div>

      {documents.length === 0 ? (
        <p className="text-muted-foreground">No documents yet.</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Filename</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Problems</TableHead>
              <TableHead>Date</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {documents.map((doc) => (
              <TableRow key={doc.id}>
                <TableCell className="font-medium">{doc.filename}</TableCell>
                <TableCell>
                  <Badge variant={doc.status === "completed" ? "default" : doc.status === "failed" ? "destructive" : "secondary"}>
                    {doc.status}
                  </Badge>
                </TableCell>
                <TableCell>{doc.problemCount ?? "—"}</TableCell>
                <TableCell>{doc.createdAt.toLocaleDateString()}</TableCell>
                <TableCell>
                  {doc.status === "completed" && (
                    <Button variant="ghost" size="icon" asChild>
                      <a href={`/api/documents/${doc.id}/download`}><Download className="h-4 w-4" /></a>
                    </Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </main>
  )
}
