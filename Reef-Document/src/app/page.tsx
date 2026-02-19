import { auth } from "@/lib/auth"
import { redirect } from "next/navigation"
import { SignInButton } from "@/components/sign-in-button"

export default async function Home() {
  const session = await auth()
  if (session?.user) redirect("/upload")

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-8">
      <div className="max-w-2xl text-center">
        <h1 className="text-4xl font-bold tracking-tight">Reef Document</h1>
        <p className="mt-4 text-lg text-muted-foreground">
          Upload a messy PDF — homework, handout, worksheet — and get a clean,
          professionally typeset version back in seconds.
        </p>
      </div>
      <SignInButton />
    </main>
  )
}
