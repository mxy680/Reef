"use client"

import { useState, useTransition } from "react"
import Link from "next/link"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import { updateDailyLimit, deleteUser } from "./actions"

type User = {
  id: string
  email: string
  name: string | null
  dailyLimit: number
  createdAt: Date
  _count: { documents: number }
}

export function UsersTable({ users }: { users: User[] }) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Name</TableHead>
          <TableHead>Email</TableHead>
          <TableHead>Documents</TableHead>
          <TableHead>Daily Limit</TableHead>
          <TableHead>Joined</TableHead>
          <TableHead />
        </TableRow>
      </TableHeader>
      <TableBody>
        {users.map((user) => (
          <UserRow key={user.id} user={user} />
        ))}
      </TableBody>
    </Table>
  )
}

function UserRow({ user }: { user: User }) {
  const [editing, setEditing] = useState(false)
  const [limit, setLimit] = useState(String(user.dailyLimit))
  const [isPending, startTransition] = useTransition()

  function saveLimit() {
    const parsed = parseInt(limit)
    if (isNaN(parsed) || parsed < 0 || parsed > 100) return
    startTransition(async () => {
      await updateDailyLimit(user.id, parsed)
      setEditing(false)
    })
  }

  return (
    <TableRow>
      <TableCell>
        <Link href={`/admin/users/${user.id}`} className="text-blue-600 hover:underline">
          {user.name || "—"}
        </Link>
      </TableCell>
      <TableCell className="text-muted-foreground">{user.email}</TableCell>
      <TableCell>{user._count.documents}</TableCell>
      <TableCell>
        {editing ? (
          <span className="flex items-center gap-1">
            <Input
              type="number"
              value={limit}
              onChange={(e) => setLimit(e.target.value)}
              className="h-7 w-16"
              min={0}
              max={100}
              onKeyDown={(e) => e.key === "Enter" && saveLimit()}
            />
            <Button size="xs" onClick={saveLimit} disabled={isPending}>
              Save
            </Button>
            <Button size="xs" variant="ghost" onClick={() => { setEditing(false); setLimit(String(user.dailyLimit)) }}>
              Cancel
            </Button>
          </span>
        ) : (
          <span
            className="cursor-pointer rounded px-1 hover:bg-muted"
            onClick={() => setEditing(true)}
          >
            {user.dailyLimit}
          </span>
        )}
      </TableCell>
      <TableCell className="text-muted-foreground">
        {new Date(user.createdAt).toLocaleDateString()}
      </TableCell>
      <TableCell>
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button size="xs" variant="destructive">Delete</Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Delete user?</AlertDialogTitle>
              <AlertDialogDescription>
                This will permanently delete {user.email} and all their documents.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction
                onClick={() => startTransition(() => deleteUser(user.id))}
                className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              >
                Delete
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </TableCell>
    </TableRow>
  )
}
