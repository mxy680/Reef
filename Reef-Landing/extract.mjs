import { connect } from "framer-api"

const projectUrl = "https://framer.com/projects/Reef--dkPOwaxVc30EuVTIh3bM-9T7V4"
const apiKey = "f3146db6-9fbe-4c3c-a900-b6382f6f28fb"

const framer = await connect(projectUrl, apiKey)

try {
  const info = await framer.getProjectInfo()
  console.log("=== PROJECT INFO ===")
  console.log(JSON.stringify(info, null, 2))

  // Get web pages
  const webPages = await framer.getNodesWithType("WebPageNode")
  console.log("\n=== WEB PAGES ===")
  console.log(JSON.stringify(webPages.map(p => ({ id: p.id, ...p })), null, 2))

  // Get component nodes
  const components = await framer.getNodesWithType("ComponentNode")
  console.log("\n=== COMPONENTS ===")
  console.log(JSON.stringify(components.map(c => ({ id: c.id, name: c.name, ...c })), null, 2))

  // Get the canvas root
  const root = await framer.getCanvasRoot()
  console.log("\n=== CANVAS ROOT ===")
  console.log(JSON.stringify({ id: root.id }, null, 2))

  // Get children of root
  const rootChildren = await framer.getChildren(root.id)
  console.log("\n=== ROOT CHILDREN ===")
  for (const child of rootChildren) {
    console.log(JSON.stringify({ id: child.id, type: child.__class, name: child.name }, null, 2))
  }

  // For each web page, get its children (sections)
  for (const page of webPages) {
    console.log(`\n=== PAGE: ${page.id} ===`)
    const children = await framer.getChildren(page.id)
    for (const child of children) {
      console.log(JSON.stringify({
        id: child.id,
        type: child.__class,
        name: child.name,
      }, null, 2))

      // Go one level deeper
      const grandchildren = await framer.getChildren(child.id)
      for (const gc of grandchildren) {
        console.log("  ", JSON.stringify({
          id: gc.id,
          type: gc.__class,
          name: gc.name,
        }))
      }
    }
  }

  // Get code files
  const codeFiles = await framer.getCodeFiles()
  console.log("\n=== CODE FILES ===")
  for (const cf of codeFiles) {
    console.log(JSON.stringify({ id: cf.id, name: cf.name, exports: cf.exports }, null, 2))
  }

} finally {
  await framer.disconnect()
}
