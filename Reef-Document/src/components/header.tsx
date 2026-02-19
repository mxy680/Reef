"use client"

import Link from "next/link"
import { useSession, signOut } from "next-auth/react"
import { Button } from "@/components/ui/button"

export function Header() {
  const { data: session } = useSession()

  if (!session?.user) return null

  return (
    <header className="border-b">
      <div className="mx-auto flex max-w-4xl items-center justify-between p-4">
        <Link href="/upload" className="text-lg font-semibold">Reef Document</Link>
        <nav className="flex items-center gap-4">
          <Link href="/upload" className="text-sm text-muted-foreground hover:text-foreground">Upload</Link>
          <Link href="/documents" className="text-sm text-muted-foreground hover:text-foreground">History</Link>
          <Button variant="ghost" size="sm" onClick={() => signOut({ callbackUrl: "/" })}>
            Sign Out
          </Button>
        </nav>
      </div>
    </header>
  )
}
