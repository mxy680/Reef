import { requireAdmin } from "@/lib/admin"

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  await requireAdmin()

  return (
    <div className="mx-auto max-w-6xl p-6">
      <h1 className="mb-6 text-2xl font-bold">Admin Dashboard</h1>
      {children}
    </div>
  )
}
