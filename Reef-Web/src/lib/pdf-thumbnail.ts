const PDFJS_VERSION = "4.10.38"
const PDFJS_CDN = `https://unpkg.com/pdfjs-dist@${PDFJS_VERSION}/build`
const THUMBNAIL_WIDTH = 400 // 2x retina for ~200px card width

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let cached: any = null

async function loadPdfjs() {
  if (cached) return cached
  // webpackIgnore prevents webpack from bundling — loads from CDN at runtime
  const lib = await import(/* webpackIgnore: true */ `${PDFJS_CDN}/pdf.min.mjs`)
  lib.GlobalWorkerOptions.workerSrc = `${PDFJS_CDN}/pdf.worker.min.mjs`
  cached = lib
  return lib
}

export async function generateThumbnail(file: File): Promise<Blob> {
  const { getDocument } = await loadPdfjs()

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
