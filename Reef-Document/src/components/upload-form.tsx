"use client"

import { useState, useRef } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Upload, FileText, CheckCircle, XCircle } from "lucide-react"

type Status = "idle" | "uploading" | "completed" | "error"

export function UploadForm() {
  const [status, setStatus] = useState<Status>("idle")
  const [error, setError] = useState<string>("")
  const [result, setResult] = useState<{ id: string; pageCount: number; problemCount: number } | null>(null)
  const [dragOver, setDragOver] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  async function handleFile(file: File) {
    if (file.type !== "application/pdf") {
      setError("Please upload a PDF file.")
      setStatus("error")
      return
    }

    setStatus("uploading")
    setError("")
    setResult(null)

    const form = new FormData()
    form.append("pdf", file)

    try {
      const resp = await fetch("/api/upload", { method: "POST", body: form })
      const data = await resp.json()
      if (!resp.ok) {
        setError(data.error || "Upload failed")
        setStatus("error")
        return
      }
      setResult(data)
      setStatus("completed")
    } catch {
      setError("Network error — please try again.")
      setStatus("error")
    }
  }

  return (
    <Card
      className={`border-2 border-dashed p-12 text-center transition-colors ${
        dragOver ? "border-primary bg-primary/5" : "border-muted-foreground/25"
      }`}
      onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
      onDragLeave={() => setDragOver(false)}
      onDrop={(e) => {
        e.preventDefault()
        setDragOver(false)
        const file = e.dataTransfer.files[0]
        if (file) handleFile(file)
      }}
    >
      <CardContent className="flex flex-col items-center gap-4">
        {status === "idle" && (
          <>
            <Upload className="h-12 w-12 text-muted-foreground" />
            <p className="text-muted-foreground">Drag and drop a PDF here, or</p>
            <Button onClick={() => inputRef.current?.click()}>Choose File</Button>
            <input
              ref={inputRef}
              type="file"
              accept="application/pdf"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0]
                if (file) handleFile(file)
              }}
            />
          </>
        )}

        {status === "uploading" && (
          <>
            <FileText className="h-12 w-12 animate-pulse text-primary" />
            <p>Reconstructing your document...</p>
            <p className="text-sm text-muted-foreground">This may take 1-2 minutes</p>
            <Progress className="w-64" />
          </>
        )}

        {status === "completed" && result && (
          <>
            <CheckCircle className="h-12 w-12 text-green-500" />
            <p className="font-medium">Reconstruction complete</p>
            <p className="text-sm text-muted-foreground">
              {result.pageCount} pages, {result.problemCount} problems
            </p>
            <div className="flex gap-3">
              <Button asChild>
                <a href={`/api/documents/${result.id}/download`}>Download PDF</a>
              </Button>
              <Button variant="outline" onClick={() => { setStatus("idle"); setResult(null) }}>
                Upload Another
              </Button>
            </div>
          </>
        )}

        {status === "error" && (
          <>
            <XCircle className="h-12 w-12 text-destructive" />
            <p className="text-destructive">{error}</p>
            <Button variant="outline" onClick={() => setStatus("idle")}>Try Again</Button>
          </>
        )}
      </CardContent>
    </Card>
  )
}
