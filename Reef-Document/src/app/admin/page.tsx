import { prisma } from "@/lib/db"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { UsersTable } from "./users-table"
import { DocumentsTable } from "./documents-table"

export const dynamic = "force-dynamic"

async function getStats() {
  const now = new Date()
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate())

  const [totalUsers, totalDocs, docsToday, completedDocs] = await Promise.all([
    prisma.user.count(),
    prisma.document.count(),
    prisma.document.count({ where: { createdAt: { gte: startOfDay } } }),
    prisma.document.count({ where: { status: "completed" } }),
  ])

  const successRate = totalDocs > 0 ? Math.round((completedDocs / totalDocs) * 100) : 0

  return { totalUsers, totalDocs, docsToday, successRate }
}

async function getUsers() {
  return prisma.user.findMany({
    orderBy: { createdAt: "desc" },
    include: { _count: { select: { documents: true } } },
  })
}

async function getDocuments() {
  return prisma.document.findMany({
    orderBy: { createdAt: "desc" },
    include: { user: { select: { email: true, name: true } } },
    take: 100,
  })
}

export default async function AdminPage() {
  const [stats, users, documents] = await Promise.all([
    getStats(),
    getUsers(),
    getDocuments(),
  ])

  const kpis = [
    { title: "Total Users", value: stats.totalUsers },
    { title: "Total Documents", value: stats.totalDocs },
    { title: "Documents Today", value: stats.docsToday },
    { title: "Success Rate", value: `${stats.successRate}%` },
  ]

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {kpis.map((kpi) => (
          <Card key={kpi.title}>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                {kpi.title}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{kpi.value}</div>
            </CardContent>
          </Card>
        ))}
      </div>

      <Tabs defaultValue="users">
        <TabsList>
          <TabsTrigger value="users">Users ({users.length})</TabsTrigger>
          <TabsTrigger value="documents">Documents ({documents.length})</TabsTrigger>
        </TabsList>
        <TabsContent value="users" className="mt-4">
          <UsersTable users={users} />
        </TabsContent>
        <TabsContent value="documents" className="mt-4">
          <DocumentsTable documents={documents} />
        </TabsContent>
      </Tabs>
    </div>
  )
}
