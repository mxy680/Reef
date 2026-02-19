"use client"

import { useTransition } from "react"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import { deleteDocument } from "./actions"

type Document = {
  id: string
  filename: string
  status: string
  pageCount: number | null
  problemCount: number | null
  createdAt: Date
  user: { email: string; name: string | null }
}

const statusVariant: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  completed: "default",
  processing: "secondary",
  pending: "outline",
  failed: "destructive",
}

export function DocumentsTable({ documents }: { documents: Document[] }) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Filename</TableHead>
          <TableHead>User</TableHead>
          <TableHead>Status</TableHead>
          <TableHead>Pages</TableHead>
          <TableHead>Problems</TableHead>
          <TableHead>Created</TableHead>
          <TableHead />
        </TableRow>
      </TableHeader>
      <TableBody>
        {documents.map((doc) => (
          <DocumentRow key={doc.id} doc={doc} />
        ))}
      </TableBody>
    </Table>
  )
}

function DocumentRow({ doc }: { doc: Document }) {
  const [isPending, startTransition] = useTransition()

  return (
    <TableRow>
      <TableCell className="max-w-[200px] truncate font-medium">{doc.filename}</TableCell>
      <TableCell className="text-muted-foreground">{doc.user.email}</TableCell>
      <TableCell>
        <Badge variant={statusVariant[doc.status] || "outline"}>{doc.status}</Badge>
      </TableCell>
      <TableCell>{doc.pageCount ?? "—"}</TableCell>
      <TableCell>{doc.problemCount ?? "—"}</TableCell>
      <TableCell className="text-muted-foreground">
        {new Date(doc.createdAt).toLocaleDateString()}
      </TableCell>
      <TableCell>
        <span className="flex items-center gap-1">
          {doc.status === "completed" && (
            <Button size="xs" variant="outline" asChild>
              <a href={`/api/admin/documents/${doc.id}/download`}>Download</a>
            </Button>
          )}
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button size="xs" variant="destructive" disabled={isPending}>Delete</Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Delete document?</AlertDialogTitle>
                <AlertDialogDescription>
                  This will permanently delete &ldquo;{doc.filename}&rdquo; and its PDF file.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  onClick={() => startTransition(() => deleteDocument(doc.id))}
                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                >
                  Delete
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </span>
      </TableCell>
    </TableRow>
  )
}
