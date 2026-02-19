"use client"

import { signIn } from "next-auth/react"
import { Button } from "@/components/ui/button"

export function SignInButton() {
  return (
    <Button size="lg" onClick={() => signIn("google")}>
      Sign in with Google
    </Button>
  )
}
