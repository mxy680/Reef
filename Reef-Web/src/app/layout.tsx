import "../framer/styles.css"
import "lenis/dist/lenis.css"
import "./globals.css"
import SmoothScroll from "../components/smooth-scroll"
import SuppressRefWarning from "../components/suppress-ref-warning"
import { Analytics } from "@vercel/analytics/react"
import { SpeedInsights } from "@vercel/speed-insights/next"

export const metadata = {
  title: "Reef — AI Tutoring for STEM Students",
  description:
    "Reef watches your work in real-time and gives personalized, step-by-step guidance — like having a tutor who never sleeps.",
  icons: [],
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <SuppressRefWarning />
        <SmoothScroll>{children}</SmoothScroll>
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  )
}
