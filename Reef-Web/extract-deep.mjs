import { connect } from "framer-api"
import { writeFileSync } from "fs"

const projectUrl = "https://framer.com/projects/Reef--dkPOwaxVc30EuVTIh3bM-9T7V4"
const apiKey = "f3146db6-9fbe-4c3c-a900-b6382f6f28fb"

const framer = await connect(projectUrl, apiKey)

async function extractTree(nodeId, depth = 0) {
  const node = await framer.getNode(nodeId)
  if (!node) return null

  const children = await framer.getChildren(nodeId)
  const rect = await framer.getRect(nodeId)

  const result = {
    id: node.id,
    type: node.__class,
    name: node.name,
    rect,
    // Extract key visual properties
    ...(node.backgroundColor && { backgroundColor: node.backgroundColor }),
    ...(node.backgroundGradient && { backgroundGradient: node.backgroundGradient }),
    ...(node.backgroundImage && { backgroundImage: node.backgroundImage }),
    ...(node.opacity !== undefined && node.opacity !== 1 && { opacity: node.opacity }),
    ...(node.borderRadius && { borderRadius: node.borderRadius }),
    ...(node.border && { border: node.border }),
    ...(node.overflow && { overflow: node.overflow }),
    ...(node.visible === false && { visible: false }),
    // Text properties
    ...(node.text && { text: node.text }),
    ...(node.fontFamily && { fontFamily: node.fontFamily }),
    ...(node.fontSize && { fontSize: node.fontSize }),
    ...(node.fontWeight && { fontWeight: node.fontWeight }),
    ...(node.color && { color: node.color }),
    ...(node.letterSpacing && { letterSpacing: node.letterSpacing }),
    ...(node.lineHeight && { lineHeight: node.lineHeight }),
    ...(node.textAlignment && { textAlignment: node.textAlignment }),
    ...(node.textTransform && { textTransform: node.textTransform }),
    // Layout
    ...(node.layoutMode && { layoutMode: node.layoutMode }),
    ...(node.layoutAlign && { layoutAlign: node.layoutAlign }),
    ...(node.layoutGap && { layoutGap: node.layoutGap }),
    ...(node.layoutPadding && { layoutPadding: node.layoutPadding }),
    ...(node.layoutWrap && { layoutWrap: node.layoutWrap }),
    ...(node.layoutSizing && { layoutSizing: node.layoutSizing }),
    // Size
    ...(node.width && { width: node.width }),
    ...(node.height && { height: node.height }),
    // Link
    ...(node.link && { link: node.link }),
    // Component info
    ...(node.componentIdentifier && { componentIdentifier: node.componentIdentifier }),
    ...(node.componentName && { componentName: node.componentName }),
    // SVG
    ...(node.svg && { svg: node.svg }),
    // Image
    ...(node.image && { image: node.image }),
  }

  if (children.length > 0 && depth < 6) {
    result.children = []
    for (const child of children) {
      const childTree = await extractTree(child.id, depth + 1)
      if (childTree) result.children.push(childTree)
    }
  }

  return result
}

try {
  // Get the home page Desktop frame
  const desktopFrameId = "WQLkyLRf1"
  console.log("Extracting full Desktop page tree...")
  const tree = await extractTree(desktopFrameId, 0)
  writeFileSync("page-tree.json", JSON.stringify(tree, null, 2))
  console.log("Written to page-tree.json")

  // Also get color styles
  const colorStyles = await framer.getColorStyles()
  console.log("\n=== COLOR STYLES ===")
  for (const cs of colorStyles) {
    console.log(JSON.stringify({ id: cs.id, name: cs.name, light: cs.light, dark: cs.dark }))
  }

  // Get text styles
  const textStyles = await framer.getTextStyles()
  console.log("\n=== TEXT STYLES ===")
  for (const ts of textStyles) {
    console.log(JSON.stringify({ id: ts.id, name: ts.name, tag: ts.tag, font: ts.font, fontSize: ts.fontSize, fontWeight: ts.fontWeight, letterSpacing: ts.letterSpacing, lineHeight: ts.lineHeight, color: ts.color, textTransform: ts.textTransform }))
  }
} finally {
  await framer.disconnect()
}
