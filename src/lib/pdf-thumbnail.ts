import { getDocument } from "pdfjs-dist/webpack.mjs"

const THUMBNAIL_WIDTH = 400 // 2x retina for ~200px card width

export async function generateThumbnail(file: File): Promise<Blob> {
  const arrayBuffer = await file.arrayBuffer()
  const pdf = await getDocument({ data: arrayBuffer }).promise
  const page = await pdf.getPage(1)

  const unscaled = page.getViewport({ scale: 1 })
  const scale = THUMBNAIL_WIDTH / unscaled.width
  const viewport = page.getViewport({ scale })

  const canvas = document.createElement("canvas")
  canvas.width = viewport.width
  canvas.height = viewport.height

  await page.render({
    canvasContext: canvas.getContext("2d")!,
    viewport,
  }).promise

  pdf.destroy()

  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("toBlob failed"))),
      "image/png"
    )
  })
}
