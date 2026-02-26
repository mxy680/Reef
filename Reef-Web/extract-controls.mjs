import { connect } from "framer-api"

const projectUrl = "https://framer.com/projects/Reef--dkPOwaxVc30EuVTIh3bM-9T7V4"
const apiKey = "f3146db6-9fbe-4c3c-a900-b6382f6f28fb"

const framer = await connect(projectUrl, apiKey)

// Component instance IDs from the page tree
const ids = {
  // Hero buttons
  heroButton1: "kmrNm0XO2",
  heroButton2: "FVRGnQPSo",
  // Problem section cards
  problemCard1: "HJL3ThUhC",
  problemCard2: "qUqKuNFA0",
  problemCard3: "VIQvO9u0A",
  // Problem badge
  problemBadge: "XefHxKo54",
  // Benefits cards
  benefitsCard1: "OlUKWKfox",
  benefitsCard2: "UVpxZu4zC",
  benefitsCard3: "Y0soqUb4F",
  benefitsCard4: "ZH95WJNmV",
  benefitsCard5: "dWj9LFtvd",
  benefitsCard6: "pirg06gXE",
  // Pricing cards
  pricingCard1: "jxneEElID",
  pricingCard2: "q8EmbbRX0",
  pricingCard3: "awjkyZyJ_",
  // Newsletter button
  ctaButton: "kqlmCCDWq",
}

try {
  for (const [label, id] of Object.entries(ids)) {
    const node = await framer.getNode(id)
    if (!node) { console.log(`${label}: NOT FOUND`); continue }

    // Get the control attributes (typed controls / overrides)
    console.log(`\n=== ${label} (${id}) ===`)
    console.log(`  componentName: ${node.componentName}`)

    // Try to get all properties
    const keys = Object.keys(node)
    for (const key of keys) {
      if (['id', '__class', 'originalId', 'componentIdentifier'].includes(key)) continue
      const val = node[key]
      if (val !== undefined && val !== null) {
        const str = JSON.stringify(val)
        if (str.length > 300) {
          console.log(`  ${key}: ${str.slice(0, 300)}...`)
        } else {
          console.log(`  ${key}: ${str}`)
        }
      }
    }

    // Also try getChildren to see rendered content
    const children = await framer.getChildren(id)
    if (children.length > 0) {
      console.log(`  CHILDREN:`)
      for (const child of children) {
        const text = child.text || ''
        console.log(`    ${child.name} (${child.__class}) ${text ? 'TEXT=' + JSON.stringify(text).slice(0,150) : ''}`)
      }
    }
  }
} finally {
  await framer.disconnect()
}
