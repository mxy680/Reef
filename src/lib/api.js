const API_URL = process.env.NEXT_PUBLIC_REEF_API_URL || "http://localhost:8000"

export async function getProfile(userId) {
  const res = await fetch(`${API_URL}/users/profile`, {
    headers: { Authorization: `Bearer ${userId}` },
  })
  if (res.status === 404) return null
  if (!res.ok) throw new Error(`GET /users/profile failed: ${res.status}`)
  return res.json()
}

export async function upsertProfile(userId, data) {
  const res = await fetch(`${API_URL}/users/profile`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${userId}`,
    },
    body: JSON.stringify(data),
  })
  if (!res.ok) throw new Error(`PUT /users/profile failed: ${res.status}`)
  return res.json()
}
