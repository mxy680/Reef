import { auth } from "@/lib/auth"
import { redirect } from "next/navigation"
import { UploadForm } from "@/components/upload-form"

export default async function UploadPage() {
  const session = await auth()
  if (!session?.user?.id) redirect("/")

  return (
    <main className="mx-auto max-w-2xl p-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold">Upload a Document</h1>
      </div>
      <UploadForm />
    </main>
  )
}
