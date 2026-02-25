import "../framer/styles.css"
import "./globals.css"

export const metadata = {
  title: "Reef — AI Tutoring for STEM Students",
  description:
    "Reef watches your work in real-time and gives personalized, step-by-step guidance — like having a tutor who never sleeps.",
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
