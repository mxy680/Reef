import { redirect } from "next/navigation"
import { auth } from "./auth"

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "markshteyn1@gmail.com"

export function isAdminEmail(email: string | null | undefined): boolean {
  return email === ADMIN_EMAIL
}

export async function requireAdmin() {
  const session = await auth()
  if (!session?.user?.email || !isAdminEmail(session.user.email)) {
    redirect("/")
  }
  return session
}
