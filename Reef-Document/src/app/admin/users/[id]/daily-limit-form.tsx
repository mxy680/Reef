"use client"

import { useState, useTransition } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { updateDailyLimit } from "../../actions"

export function DailyLimitForm({ userId, currentLimit }: { userId: string; currentLimit: number }) {
  const [limit, setLimit] = useState(String(currentLimit))
  const [isPending, startTransition] = useTransition()
  const [saved, setSaved] = useState(false)

  const isDirty = limit !== String(currentLimit)

  function save() {
    const parsed = parseInt(limit)
    if (isNaN(parsed) || parsed < 0 || parsed > 100) return
    startTransition(async () => {
      await updateDailyLimit(userId, parsed)
      setSaved(true)
      setTimeout(() => setSaved(false), 2000)
    })
  }

  return (
    <div className="space-y-1">
      <label className="text-sm text-muted-foreground">Daily limit</label>
      <div className="flex items-center gap-2">
        <Input
          type="number"
          value={limit}
          onChange={(e) => { setLimit(e.target.value); setSaved(false) }}
          className="h-8 w-20"
          min={0}
          max={100}
          onKeyDown={(e) => e.key === "Enter" && save()}
        />
        <Button size="sm" onClick={save} disabled={isPending || !isDirty}>
          {isPending ? "Saving..." : "Save"}
        </Button>
        {saved && <span className="text-xs text-green-600">Saved</span>}
      </div>
    </div>
  )
}
