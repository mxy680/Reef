"use client"

import { useEffect, useRef } from "react"
import dynamic from "next/dynamic"
import "./globals.css"
import Badge from "../framer/badge"
import Button from "../framer/button"
import FeaturesCard from "../framer/features-card"
import PricingCard from "../framer/pricing-card"

const HeaderResponsive = dynamic(() => import("../framer/header").then(m => m.default.Responsive), { ssr: false })
const FooterResponsive = dynamic(() => import("../framer/footer").then(m => m.default.Responsive), { ssr: false })
const IntegrationsResponsive = dynamic(() => import("../framer/integrations").then(m => m.default.Responsive), { ssr: false })
const AccordionResponsive = dynamic(() => import("../framer/accordion").then(m => m.default.Responsive), { ssr: false })


export default function Home() {
  useEffect(() => {

    function smoothScrollTo(element: HTMLElement) {
      const headerOffset = 80
      const top = element.getBoundingClientRect().top + window.scrollY - headerOffset
      window.scrollTo({ top, behavior: "smooth" })
    }

    // Extract hash from any URL format and scroll to it
    function scrollToHash(url: string | URL | null | undefined) {
      let hash: string | null = null
      if (typeof url === "string") {
        if (url.startsWith("/#")) hash = url.slice(2)
        else if (url.startsWith("#")) hash = url.slice(1)
        else {
          try {
            const parsed = new URL(url, window.location.origin)
            if (parsed.origin === window.location.origin && parsed.hash) {
              hash = parsed.hash.slice(1)
            }
          } catch {}
        }
      }
      if (!hash) return false
      const target = document.getElementById(hash)
      if (!target) return false
      smoothScrollTo(target)
      window.history.replaceState(null, "", `/#${hash}`)
      return true
    }

    // Intercept hash-link clicks for smooth scrolling
    // Framer's Link component triggers full Next.js route navigations for
    // anchor links, which causes a page remount instead of a scroll.
    const handleClick = (e: Event) => {
      const link = (e.target as HTMLElement).closest("a[href]")
      if (!link) return
      const href = link.getAttribute("href")
      if (!href) return
      if (scrollToHash(href)) {
        e.preventDefault()
        e.stopPropagation()
        e.stopImmediatePropagation()
      }
    }
    document.addEventListener("click", handleClick, true)

    // Backup: intercept programmatic navigation (Framer's router may use pushState)
    const originalPushState = window.history.pushState.bind(window.history)
    window.history.pushState = function (state: any, title: string, url?: string | URL | null) {
      if (scrollToHash(url)) return
      return originalPushState(state, title, url!)
    }

    return () => {
      document.removeEventListener("click", handleClick, true)
      window.history.pushState = originalPushState
    }
  }, [])

  const heroRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = heroRef.current
    if (!el) return
    const MAX_ROTATE = 30
    function onScroll() {
      const rect = el.getBoundingClientRect()
      const viewH = window.innerHeight
      // progress: 0 when element top is at bottom of viewport, 1 when top reaches top
      const progress = Math.min(Math.max(1 - rect.top / viewH, 0), 1)
      const angle = MAX_ROTATE * (1 - progress)
      el.style.transform = `rotateX(${angle}deg)`
    }
    onScroll()
    window.addEventListener("scroll", onScroll, { passive: true })
    return () => window.removeEventListener("scroll", onScroll)
  }, [])

  return (
    <>
      {/* 1. Header */}
      <HeaderResponsive />

      {/* 2. Hero */}
      <section className="page-section hero-section">
        <div className="section-inner">
          <div className="hero-content">
            <Badge fEv2mISRr="NOW IN BETA" style={{ backgroundColor: "var(--color-surface)" }} />
            <h1 className="hero-heading">Stay afloat this finals season.</h1>
            <p className="hero-subtitle">
              Stop switching apps. Stop waiting for office hours. Get real-time help the moment you need it.
            </p>
            <div className="hero-buttons">
              <Button variant="Solid" label="Get Started" link="/signup" />
              <Button variant="Alternative" label="Log In" link="/auth" />
            </div>
            <p className="hero-beta">
              <svg
                width="20"
                height="20"
                viewBox="0 0 48 48"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
                style={{ display: "inline-block", verticalAlign: "middle", marginRight: 6 }}
              >
                <rect x="6.5" y="3.5" width="32" height="3" rx="1.5" fill="#101010" stroke="#000"/>
                <path fillRule="evenodd" clipRule="evenodd" d="M10.87 5A1.87 1.87 0 0 0 9 6.87v5.205C9 18.171 13.04 23.323 18.59 25 13.04 26.677 9 31.829 9 37.925v5.205A1.87 1.87 0 0 0 10.87 45h23.26A1.87 1.87 0 0 0 36 43.13v-5.205c0-6.096-4.04-11.248-9.59-12.925C31.96 23.323 36 18.171 36 12.075V6.87A1.87 1.87 0 0 0 34.13 5H10.87Z" fill="#101010"/>
                <path d="m18.59 25 .289.957L22.047 25l-3.168-.957-.29.957Zm7.82 0-.289-.957-3.168.957 3.168.957.29-.957ZM10 6.87c0-.48.39-.87.87-.87V4A2.87 2.87 0 0 0 8 6.87h2Zm0 5.205V6.87H8v5.205h2Zm8.879 11.968C13.74 22.49 10 17.718 10 12.075H8c0 6.55 4.341 12.082 10.3 13.882l.579-1.914ZM10 37.925c0-5.643 3.74-10.415 8.879-11.968l-.579-1.914C12.341 25.843 8 31.376 8 37.925h2Zm0 5.205v-5.205H8v5.205h2Zm.87.87a.87.87 0 0 1-.87-.87H8A2.87 2.87 0 0 0 10.87 46v-2Zm23.26 0H10.87v2h23.26v-2Zm.87-.87c0 .48-.39.87-.87.87v2A2.87 2.87 0 0 0 37 43.13h-2Zm0-5.205v5.205h2v-5.205h-2Zm-8.879-11.968C31.26 27.51 35 32.282 35 37.925h2c0-6.55-4.341-12.082-10.3-13.882l-.579 1.914ZM35 12.075c0 5.643-3.74 10.415-8.879 11.968l.579 1.914c5.959-1.8 10.3-7.333 10.3-13.882h-2Zm0-5.205v5.205h2V6.87h-2ZM34.13 6c.48 0 .87.39.87.87h2A2.87 2.87 0 0 0 34.13 4v2ZM10.87 6h23.26V4H10.87v2Z" fill="#000"/>
                <path fillRule="evenodd" clipRule="evenodd" d="M12.87 3A1.87 1.87 0 0 0 11 4.87v5.205c0 6.096 4.04 11.248 9.59 12.925C15.04 24.677 11 29.829 11 35.925v5.205A1.87 1.87 0 0 0 12.87 43h23.26A1.87 1.87 0 0 0 38 41.13v-5.205c0-6.096-4.04-11.248-9.59-12.925C33.96 21.323 38 16.171 38 10.075V4.87A1.87 1.87 0 0 0 36.13 3H12.87Z" fill="#fff"/>
                <path d="m20.59 23 .289.957L24.047 23l-3.168-.957-.29.957Zm7.82 0-.289-.957-3.168.957 3.168.957.29-.957ZM12 4.87c0-.48.39-.87.87-.87V2A2.87 2.87 0 0 0 10 4.87h2Zm0 5.205V4.87h-2v5.205h2Zm8.879 11.968C15.74 20.49 12 15.718 12 10.075h-2c0 6.55 4.341 12.082 10.3 13.882l.579-1.914ZM12 35.925c0-5.643 3.74-10.415 8.879-11.968l-.579-1.914c-5.959 1.8-10.3 7.333-10.3 13.882h2Zm0 5.205v-5.205h-2v5.205h2Zm.87.87a.87.87 0 0 1-.87-.87h-2A2.87 2.87 0 0 0 12.87 44v-2Zm23.26 0H12.87v2h23.26v-2Zm.87-.87c0 .48-.39.87-.87.87v2A2.87 2.87 0 0 0 39 41.13h-2Zm0-5.205v5.205h2v-5.205h-2Zm-8.879-11.968C33.26 25.51 37 30.282 37 35.925h2c0-6.55-4.341-12.082-10.3-13.882l-.579 1.914ZM37 10.075c0 5.643-3.74 10.415-8.879 11.968l.579 1.914c5.959-1.8 10.3-7.333 10.3-13.882h-2Zm0-5.205v5.205h2V4.87h-2ZM36.13 4c.48 0 .87.39.87.87h2A2.87 2.87 0 0 0 36.13 2v2ZM12.87 4h23.26V2H12.87v2Z" fill="#000"/>
                <path fillRule="evenodd" clipRule="evenodd" d="M13.451 13.855a1.312 1.312 0 0 0-1.076 1.895A13.116 13.116 0 0 0 23 22.953v8.491l-10.037 6.32A4.201 4.201 0 0 0 11 41.32a1.68 1.68 0 0 0 1.68 1.681h23.64A1.68 1.68 0 0 0 38 41.32a4.201 4.201 0 0 0-1.963-3.556L26 31.444v-8.507a13.355 13.355 0 0 0 9.5-5.437l1.58-2.895c.612-1.124-.262-2.48-1.539-2.386l-22.09 1.636Z" fill="#FF6610"/>
                <path d="m12.375 15.75.894-.447-.894.447Zm1.076-1.895.074.998-.074-.998ZM23 22.953h1v-.919l-.916-.077-.084.996Zm0 8.491.533.847.467-.294v-.553h-1Zm-10.037 6.32.533.846-.533-.846Zm23.074 0-.533.846.533-.846ZM26 31.444h-1v.553l.467.294.533-.847Zm0-8.507-.097-.996-.903.089v.907h1Zm9.5-5.437.809.588.038-.052.03-.057-.877-.479Zm1.58-2.895.877.478-.878-.478Zm-1.539-2.386-.074-.997.074.997ZM13.27 15.303a.312.312 0 0 1 .256-.45l-.148-1.995a2.312 2.312 0 0 0-1.896 3.34l1.788-.895Zm9.815 6.654a12.116 12.116 0 0 1-9.815-6.654l-1.788.894a14.116 14.116 0 0 0 11.435 7.753l.168-1.993ZM22 22.953v8.491h2v-8.49h-2Zm.467 7.645-10.037 6.32 1.066 1.692 10.037-6.32-1.066-1.692Zm-10.037 6.32A5.201 5.201 0 0 0 10 41.319h2c0-1.1.565-2.123 1.496-2.709l-1.066-1.692ZM10 41.319A2.68 2.68 0 0 0 12.68 44v-2a.68.68 0 0 1-.68-.68h-2ZM12.68 44h23.64v-2H12.68v2Zm23.64 0C37.8 44 39 42.8 39 41.32h-2a.68.68 0 0 1-.68.68v2ZM39 41.32c0-1.788-.918-3.45-2.43-4.402l-1.066 1.692A3.202 3.202 0 0 1 37 41.32h2Zm-2.43-4.402-10.037-6.32-1.066 1.693 10.037 6.32 1.066-1.693ZM27 31.444v-8.507h-2v8.507h2Zm7.691-14.532a12.356 12.356 0 0 1-8.788 5.03l.194 1.99a14.356 14.356 0 0 0 10.212-5.844l-1.618-1.176Zm1.51-2.786-1.579 2.895 1.756.958 1.58-2.896-1.757-.957Zm-.586-.91a.616.616 0 0 1 .586.91l1.756.957c.992-1.819-.423-4.014-2.49-3.861l.148 1.994Zm-22.09 1.637 22.09-1.637-.148-1.994-22.09 1.636.148 1.995Z" fill="#000"/>
                <rect x="6.5" y="43.5" width="32" height="3" rx="1.5" fill="#101010" stroke="#000"/>
                <rect x="8.5" y="1.5" width="32" height="3" rx="1.5" fill="#CCFF6F" stroke="#000"/>
                <rect x="8.5" y="41.5" width="32" height="3" rx="1.5" fill="#CCFF6F" stroke="#000"/>
                <path d="M33.026 14.916c.356.113.556.495.409.84a7 7 0 0 1-6.098 4.236c-.374.018-.663-.303-.645-.677.019-.373.337-.657.71-.684a5.646 5.646 0 0 0 4.735-3.289c.155-.34.532-.54.889-.426Z" fill="#fff"/>
              </svg>
              Now in beta. Free to use.
            </p>
          </div>
          <div className="hero-image-wrapper">
            <div ref={heroRef} className="hero-image" />
          </div>
        </div>
      </section>

      {/* 3. Problem Section */}
      <section className="page-section">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="THE PROBLEM" style={{ backgroundColor: "var(--color-surface)" }} />
            <h2 className="section-heading">STUDYING SHOULDN&rsquo;T FEEL THIS BROKEN</h2>
            <p className="section-subtitle">
              Every night, millions of students get stuck on practice problems with no one to help. They bounce between apps, lose focus, and give up before they actually learn.
            </p>
          </div>
          <div className="problem-cards-row">
            <FeaturesCard
              variant="problem-card"
              headline="SWITCHING APPS KILLS YOUR FLOW"
              subline="You're juggling a notes app, a PDF reader, and ChatGPT. Every context switch breaks your focus."
              background="rgb(255, 255, 255)"
            />
            <FeaturesCard
              variant="problem-card"
              headline="NO HELP WHEN YOU NEED IT MOST"
              subline="Office hours are closed. Chatbots make you stop and type. By the time you get help, you've lost momentum."
              background="rgb(255, 255, 255)"
            />
            <FeaturesCard
              variant="problem-card"
              headline="PROGRESS FEELS INVISIBLE"
              subline="You grind through problem sets for hours with no clear picture of what you've actually mastered."
              background="rgb(255, 255, 255)"
            />
          </div>
        </div>
      </section>

      {/* 4. Features / Benefits Section */}
      <section id="benefits" className="page-section">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="FEATURES" style={{ backgroundColor: "var(--color-surface)" }} />
            <h2 className="section-heading">EVERYTHING YOU NEED IN ONE STUDY APP</h2>
            <p className="section-subtitle">
              Notes, documents, AI tutoring, quizzes, and progress tracking all live inside one app. No more jumping between five tools to get through a problem set.
            </p>
          </div>
          <div className="features-cards-grid">
            {/* Row 1 */}
            <div className="features-cards-row">
              <FeaturesCard
                variant="Double"
                headline="PROACTIVE AI TUTORING"
                subline="Reef reads your handwriting and delivers feedback during natural pauses. No prompts needed."
                image={{ src: "https://framerusercontent.com/images/y5nwVpIi7OrrXnUMddYmFpfR8w.png", alt: "AI Tutoring" }}
              />
              <FeaturesCard
                variant="Single"
                headline="HANDWRITING RECOGNITION"
                subline="Write math, chemistry, or prose with Apple Pencil. Reef transcribes instantly."
                background="rgb(255, 255, 255)"
              />
            </div>
            {/* Row 2 */}
            <div className="features-cards-row">
              <FeaturesCard
                variant="Single"
                headline="ALL YOUR MATERIALS IN ONE PLACE"
                subline="Import PDFs, lecture slides, and photos. Organize by course, unit, and topic."
                background="rgb(255, 255, 255)"
              />
              <FeaturesCard
                variant="Double"
                headline="SMART EXAM GENERATION"
                subline="Upload your course materials and Reef auto-generates practice exams. Multiple choice, free response, and more."
                image={{ src: "https://framerusercontent.com/images/f60AUC3qCLYakCUJvA05aCTSxY.png", alt: "Smart Exam Generation" }}
              />
            </div>
            {/* Row 3 */}
            <div className="features-cards-row">
              <FeaturesCard
                variant="Double"
                headline="GAMIFIED PROGRESS TRACKING"
                subline="Master topics to unlock marine species and build a personal reef that grows with you."
                image={{ src: "https://framerusercontent.com/images/KyGJt180mUl3faZpD14pmQaXfAs.png", alt: "Gamified Progress Tracking" }}
              />
              <FeaturesCard
                variant="Single"
                headline="BUILT FOR APPLE PENCIL"
                subline="Pressure sensitivity, palm rejection, and shape recognition. Feels like paper, works like magic."
                background="rgb(255, 255, 255)"
              />
            </div>
          </div>
        </div>
      </section>

      {/* 5. Integrations Section */}
      <section className="page-section">
        <div className="section-inner">
          <div className="integrations-card">
            <IntegrationsResponsive style={{ width: "100%" }} />
            <div className="integrations-text">
              <Badge fEv2mISRr="BUILT FOR STEM" style={{ backgroundColor: "var(--color-surface)" }} />
              <h2 className="section-heading">WORKS ACROSS EVERY SUBJECT YOU&rsquo;RE TAKING</h2>
              <p className="section-subtitle">
                From calculus problem sets to organic chemistry mechanisms to circuit analysis, Reef understands the notation and concepts across all your STEM courses.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 6. How It Works Section */}
      <section id="how-it-work-1" className="page-section">
        <div className="section-inner">
          <div className="how-it-works-steps">
            {/* Step 1: text left, image card right */}
            <div className="how-it-works-step">
              <div className="step-text">
                <span className="step-badge">Step 1</span>
                <h3 className="step-heading">UPLOAD YOUR COURSE MATERIALS</h3>
                <p className="step-body">
                  Drop in your syllabus, lecture slides, homework PDFs, or even photos of handwritten notes. Reef organizes everything by course and topic so you never lose track of what you need to study. If a document has an answer key, it&rsquo;s extracted automatically so the AI can check your work in real time.
                </p>
              </div>
              <div className="step-card step-card-blue">
                <div className="step-card-inner">
                  <img
                    src="https://framerusercontent.com/images/rbrs5BD6YqQE8Lxfiq0z819bbY.png"
                    alt="Upload course materials"
                  />
                </div>
              </div>
            </div>

            {/* Decorative arrow 1 → 2 */}
            <div className="step-arrow step-arrow-right">
              <div style={{ width: 154, height: 106, transform: "rotate(180deg)" }}>
                <svg width="100%" height="100%" viewBox="0 0 144 141" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ maxWidth: "100%", maxHeight: "100%" }}>
                  <path fillRule="evenodd" clipRule="evenodd" d="M129.189 0.0490494C128.744 0.119441 126.422 0.377545 124.03 0.635648C114.719 1.6446 109.23 2.4893 108.058 3.09936C107.119 3.56864 106.674 4.34295 106.674 5.44576C106.674 6.71281 107.424 7.51058 109.043 7.97986C110.403 8.37875 110.825 8.42567 118.87 9.52847C121.778 9.92736 124.288 10.3028 124.475 10.3732C124.663 10.4436 122.951 11.1006 120.676 11.8749C110.028 15.4414 100.412 20.7677 91.7339 27.9242C88.38 30.7164 81.6957 37.4271 79.2096 40.5009C73.8387 47.2116 69.6874 54.8139 66.5681 63.7302C65.9348 65.4665 65.3484 66.8978 65.2546 66.8978C65.1374 66.8978 63.7771 66.7336 62.2291 66.5693C52.9649 65.5134 43.1847 68.1649 34.1316 74.2186C24.7735 80.46 18.5349 87.7338 10.5371 101.742C2.53943 115.726 -1.0959 127.482 0.287874 135.014C0.89767 138.463 2.0469 140.035 3.97011 140.082C5.28352 140.105 5.37733 139.659 4.20465 139.049C3.05541 138.463 2.6567 137.9 2.32835 136.281C0.616228 128.021 6.24512 113.028 17.4325 96.1104C23.2725 87.241 28.362 81.9147 35.5622 77.1046C43.8649 71.5437 52.7069 69.033 61.1737 69.8308C64.9967 70.1828 64.6917 69.9247 64.1992 72.4822C62.2525 82.5013 63.8005 92.6378 67.9753 97.354C73.1116 103.079 81.9771 102 85.0027 95.2657C86.3395 92.2858 86.3864 87.7103 85.1434 83.9796C83.1498 78.0901 80.007 73.8197 75.4335 70.8163C73.8152 69.7604 70.4848 68.1883 69.875 68.1883C69.359 68.1883 69.4294 67.6487 70.2268 65.3257C72.3377 59.2486 75.457 52.7021 78.4122 48.244C83.2436 40.9232 91.4524 32.5701 99.1687 27.103C105.806 22.4102 113.241 18.5386 120.512 16.0045C123.772 14.8548 129.87 13.1889 130.081 13.3766C130.128 13.447 129.541 14.362 128.791 15.4414C124.78 21.0258 122.716 26.0706 122.388 30.998C122.224 33.7198 122.341 34.588 122.88 34.2595C122.998 34.1891 123.678 32.969 124.405 31.5611C126.281 27.8069 131.722 20.6738 139.579 11.6402C141.127 9.85697 142.652 7.86254 143.027 7.08823C144.552 4.03792 143.52 1.48035 140.377 0.471397C139.439 0.166366 138.102 0.0490408 134.584 0.0255769C132.074 -0.021351 129.635 0.00212153 129.189 0.0490494ZM137.117 4.92955C137.187 5.0234 136.718 5.63346 136.061 6.29045L134.865 7.48712L131.042 6.73627C128.931 6.33739 126.727 5.9385 126.14 5.8681C124.827 5.68039 124.123 5.32843 124.968 5.28151C125.296 5.28151 126.868 5.11725 128.486 4.953C131.3 4.64797 136.812 4.62451 137.117 4.92955ZM71.5168 72.5292C76.2075 74.899 79.4441 78.8175 81.3204 84.355C83.6189 91.1361 81.2266 96.8378 76.0433 96.8847C73.3227 96.9082 70.9773 95.2188 69.5936 92.2389C68.2802 89.4232 67.6938 86.5606 67.5765 82.1259C67.4593 78.3248 67.6 76.4242 68.2333 72.7403L68.4912 71.2856L69.359 71.5906C69.8515 71.7548 70.8132 72.1772 71.5168 72.5292Z" fill="currentColor"/>
                </svg>
              </div>
            </div>

            {/* Step 2: image card left, text right */}
            <div className="how-it-works-step">
              <div className="step-card step-card-white">
                <div className="step-card-inner">
                  <img
                    src="https://framerusercontent.com/images/sciUgoQBql5wKVM5ZcUqjqzKE.png"
                    alt="Solve problems with AI"
                  />
                </div>
              </div>
              <div className="step-text">
                <span className="step-badge">Step 2</span>
                <h3 className="step-heading">SOLVE PROBLEMS WITH AI BY YOUR SIDE</h3>
                <p className="step-body">
                  Open a homework and start writing with Apple Pencil, just like you would on paper. Reef&rsquo;s AI reads your handwriting in real time, understands the math and science behind it, and talks to you about your work out loud. It&rsquo;s a conversational tutor that guides you through mistakes, asks follow-up questions, and nudges you in the right direction. You never have to leave the page.
                </p>
              </div>
            </div>

            {/* Decorative arrow 2 → 3 */}
            <div className="step-arrow step-arrow-left">
              <div style={{ width: 106, height: 154, transform: "rotate(90deg)" }}>
                <svg width="100%" height="100%" viewBox="0 0 144 141" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ maxWidth: "100%", maxHeight: "100%" }}>
                  <path fillRule="evenodd" clipRule="evenodd" d="M129.189 0.0490494C128.744 0.119441 126.422 0.377545 124.03 0.635648C114.719 1.6446 109.23 2.4893 108.058 3.09936C107.119 3.56864 106.674 4.34295 106.674 5.44576C106.674 6.71281 107.424 7.51058 109.043 7.97986C110.403 8.37875 110.825 8.42567 118.87 9.52847C121.778 9.92736 124.288 10.3028 124.475 10.3732C124.663 10.4436 122.951 11.1006 120.676 11.8749C110.028 15.4414 100.412 20.7677 91.7339 27.9242C88.38 30.7164 81.6957 37.4271 79.2096 40.5009C73.8387 47.2116 69.6874 54.8139 66.5681 63.7302C65.9348 65.4665 65.3484 66.8978 65.2546 66.8978C65.1374 66.8978 63.7771 66.7336 62.2291 66.5693C52.9649 65.5134 43.1847 68.1649 34.1316 74.2186C24.7735 80.46 18.5349 87.7338 10.5371 101.742C2.53943 115.726 -1.0959 127.482 0.287874 135.014C0.89767 138.463 2.0469 140.035 3.97011 140.082C5.28352 140.105 5.37733 139.659 4.20465 139.049C3.05541 138.463 2.6567 137.9 2.32835 136.281C0.616228 128.021 6.24512 113.028 17.4325 96.1104C23.2725 87.241 28.362 81.9147 35.5622 77.1046C43.8649 71.5437 52.7069 69.033 61.1737 69.8308C64.9967 70.1828 64.6917 69.9247 64.1992 72.4822C62.2525 82.5013 63.8005 92.6378 67.9753 97.354C73.1116 103.079 81.9771 102 85.0027 95.2657C86.3395 92.2858 86.3864 87.7103 85.1434 83.9796C83.1498 78.0901 80.007 73.8197 75.4335 70.8163C73.8152 69.7604 70.4848 68.1883 69.875 68.1883C69.359 68.1883 69.4294 67.6487 70.2268 65.3257C72.3377 59.2486 75.457 52.7021 78.4122 48.244C83.2436 40.9232 91.4524 32.5701 99.1687 27.103C105.806 22.4102 113.241 18.5386 120.512 16.0045C123.772 14.8548 129.87 13.1889 130.081 13.3766C130.128 13.447 129.541 14.362 128.791 15.4414C124.78 21.0258 122.716 26.0706 122.388 30.998C122.224 33.7198 122.341 34.588 122.88 34.2595C122.998 34.1891 123.678 32.969 124.405 31.5611C126.281 27.8069 131.722 20.6738 139.579 11.6402C141.127 9.85697 142.652 7.86254 143.027 7.08823C144.552 4.03792 143.52 1.48035 140.377 0.471397C139.439 0.166366 138.102 0.0490408 134.584 0.0255769C132.074 -0.021351 129.635 0.00212153 129.189 0.0490494ZM137.117 4.92955C137.187 5.0234 136.718 5.63346 136.061 6.29045L134.865 7.48712L131.042 6.73627C128.931 6.33739 126.727 5.9385 126.14 5.8681C124.827 5.68039 124.123 5.32843 124.968 5.28151C125.296 5.28151 126.868 5.11725 128.486 4.953C131.3 4.64797 136.812 4.62451 137.117 4.92955ZM71.5168 72.5292C76.2075 74.899 79.4441 78.8175 81.3204 84.355C83.6189 91.1361 81.2266 96.8378 76.0433 96.8847C73.3227 96.9082 70.9773 95.2188 69.5936 92.2389C68.2802 89.4232 67.6938 86.5606 67.5765 82.1259C67.4593 78.3248 67.6 76.4242 68.2333 72.7403L68.4912 71.2856L69.359 71.5906C69.8515 71.7548 70.8132 72.1772 71.5168 72.5292Z" fill="currentColor"/>
                </svg>
              </div>
            </div>

            {/* Step 3: text left, outlined card right */}
            <div className="how-it-works-step">
              <div className="step-text">
                <span className="step-badge">Step 3</span>
                <h3 className="step-heading">TRACK MASTERY, BUILD YOUR REEF</h3>
                <p className="step-body">
                  After working through problems, take auto-generated quizzes to prove what you know. Each topic you master unlocks a new marine species in your personal reef, a living visualization of your progress. Over time, you can see exactly which concepts are solid and which need more work.
                </p>
              </div>
              <div className="step-card step-card-steel">
                <div className="step-card-inner">
                  <img
                    src="https://framerusercontent.com/images/v6wZRssF6htlH2vkhNBcUBx8pEs.png"
                    alt="Track mastery and build your reef"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 7. Pricing Section */}
      <section className="page-section pricing-section">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="PRICING" style={{ backgroundColor: "var(--color-surface)" }} />
            <h2 className="section-heading">Study smarter, no matter how deep you go.</h2>
            <p className="section-subtitle">
              Whether you&rsquo;re testing the waters with one class or going all in across your entire course load, Reef has a plan that fits your semester.
            </p>
          </div>
          <div className="pricing-cards-row">
            <PricingCard
              title="SHORE"
              description="Dip your toes in with one course and core study tools."
              price="$0"
              background="rgb(255, 255, 255)"
              buttonLabel="Step In"
              feature1="1 course"
              feature2="5 homeworks"
              feature3="5 quizzes"
              feature4="2 hours of tutoring"
              feature5="Basic analytics"
            />
            <PricingCard
              title="Reef"
              description="Plenty of power for most students, all semester long."
              price="$9.99"
              background="rgb(255, 229, 217)"
              buttonLabel="Dive In"
              feature1="5 courses"
              feature2="50 homeworks"
              feature3="50 quizzes"
              feature4="20 hours of tutoring"
              feature5="Study analytics"
            />
            <PricingCard
              title="Abyss"
              description="No limits. For students who never want to hit a wall."
              price="$29.99"
              background="rgb(95, 168, 211)"
              buttonLabel="Go Deep"
              feature1="Unlimited courses"
              feature2="Unlimited homeworks"
              feature3="Unlimited quizzes"
              feature4="Unlimited tutoring"
              feature5="Advanced analytics"
            />
          </div>
        </div>
      </section>

      {/* 8. FAQ Section */}
      <section id="faq" className="page-section faq-section">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="FAQ" style={{ backgroundColor: "var(--color-surface)" }} />
            <h2 className="section-heading">Common questions answered clearly</h2>
            <p className="section-subtitle">Everything you need to know before diving in.</p>
          </div>
          <AccordionResponsive />
        </div>
      </section>

      {/* 9. Newsletter Section */}
      <section className="page-section cta-section">
        <div className="section-inner">
          <div className="cta-card">
            <Badge fEv2mISRr="NEWSLETTER" style={{ backgroundColor: "var(--color-surface)" }} />
            <h2 className="cta-heading">STAY IN THE LOOP</h2>
            <p className="cta-subtitle">
              Get early access, product updates, and study tips delivered straight to your inbox.
            </p>
            <div className="newsletter-input-wrapper">
              <input
                type="email"
                placeholder="example@mail.com"
                className="newsletter-input"
              />
              <button type="button" className="newsletter-btn" aria-label="Subscribe">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <line x1="5" y1="12" x2="19" y2="12" />
                  <polyline points="12 5 19 12 12 19" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* 10. Footer */}
      <FooterResponsive />
    </>
  )
}
