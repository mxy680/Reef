"use client"

import "./globals.css"
import Header from "../framer/header"
import Footer from "../framer/footer"
import Badge from "../framer/badge"
import Button from "../framer/button"
import FeaturesCard from "../framer/features-card"
import Integrations from "../framer/integrations"
import PricingCard from "../framer/pricing-card"
import Accordion from "../framer/accordion"
import Pattern from "../framer/pattern"

export default function Home() {
  return (
    <>
      {/* 1. Header */}
      <Header.Responsive />

      {/* 2. Hero */}
      <section className="page-section hero-section">
        <div className="hero-pattern">
          <Pattern.Responsive style={{ width: "100%", height: "100%" }} />
        </div>
        <div className="section-inner">
          <div className="hero-content">
            <h1 className="hero-heading">Stay afloat this finals season.</h1>
            <p className="hero-subtitle">
              Stop switching apps. Stop waiting for office hours. Get real-time help the moment you need it.
            </p>
            <div className="hero-buttons">
              <Button variant="Solid" label="Get Started" link="/signup" />
              <Button variant="Alternative" label="Log In" link="/auth" />
            </div>
            <p className="hero-beta">🐟 Now in beta. Free to use.</p>
            <img
              className="hero-image"
              src="https://framerusercontent.com/images/28E4wGiqpajUZYTPMvIOS9l2XE.png"
              alt="Reef app on iPad"
            />
          </div>
        </div>
      </section>

      {/* 3. Problem Section */}
      <section className="page-section section-bg-light">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="THE PROBLEM" style={{ backgroundColor: "rgb(235, 140, 115)" }} />
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
      <section className="page-section section-bg-white">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="FEATURES" style={{ backgroundColor: "rgb(235, 140, 115)" }} />
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
                background="rgb(252, 249, 247)"
              />
            </div>
            {/* Row 2 */}
            <div className="features-cards-row">
              <FeaturesCard
                variant="Single"
                headline="ALL YOUR MATERIALS IN ONE PLACE"
                subline="Import PDFs, lecture slides, and photos. Organize by course, unit, and topic."
                background="rgb(252, 249, 247)"
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
                background="rgb(252, 249, 247)"
              />
            </div>
          </div>
        </div>
      </section>

      {/* 5. Integrations Section */}
      <section className="page-section">
        <Integrations.Responsive />
      </section>

      {/* 6. How It Works Section */}
      <section className="page-section section-bg-light">
        <div className="section-inner">
          <div className="section-header">
            <h2 className="section-heading">HOW IT WORKS</h2>
          </div>
          <div className="how-it-works-steps">
            {/* Step 1 */}
            <div className="how-it-works-step">
              <div className="step-image">
                <img
                  src="https://framerusercontent.com/images/n375GCjfb64K9jJZiBWWifyd9E.png"
                  alt="Upload course materials"
                />
              </div>
              <div className="step-text">
                <span className="step-number">Step 01</span>
                <h3 className="step-heading">UPLOAD YOUR COURSE MATERIALS</h3>
                <p className="step-body">
                  Import PDFs, lecture slides, and photos from anywhere. Organize by course, unit, and topic.
                </p>
              </div>
            </div>
            {/* Step 2 */}
            <div className="how-it-works-step reversed">
              <div className="step-image">
                <img
                  src="https://framerusercontent.com/images/poYwCEJ7PbKUEZffe5cE5tU5LK0.png"
                  alt="Solve problems with AI"
                />
              </div>
              <div className="step-text">
                <span className="step-number">Step 02</span>
                <h2 className="step-heading">SOLVE PROBLEMS WITH AI BY YOUR SIDE</h2>
                <p className="step-body">
                  Write with Apple Pencil like normal. Reef watches your work and delivers feedback the moment you pause.
                </p>
              </div>
            </div>
            {/* Step 3 */}
            <div className="how-it-works-step">
              <div className="step-text" style={{ flex: "1" }}>
                <span className="step-number">Step 03</span>
                <h2 className="step-heading">TRACK MASTERY, BUILD YOUR REEF</h2>
                <p className="step-body">
                  Pass quizzes to unlock marine species. Watch your personal reef grow as your knowledge deepens.
                </p>
              </div>
              <div style={{ flex: "1" }} />
            </div>
          </div>
        </div>
      </section>

      {/* 7. Pricing Section */}
      <section className="page-section section-bg-light">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="Pricing" />
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
              background="rgb(243, 250, 249)"
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
              background="rgb(252, 244, 240)"
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
              background="rgb(237, 243, 250)"
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
      <section className="page-section faq-section">
        <div className="section-inner">
          <div className="section-header">
            <Badge fEv2mISRr="Faq" style={{ backgroundColor: "rgb(235, 140, 115)" }} />
            <h2 className="section-heading">Common questions answered clearly</h2>
            <p className="section-subtitle">Everything you need to know before diving in.</p>
          </div>
          <Accordion.Responsive />
        </div>
      </section>

      {/* 9. CTA / Newsletter Section */}
      <section className="page-section cta-section">
        <div className="section-inner">
          <div className="cta-card">
            <h2 className="cta-heading">GET STARTED WITH REEF</h2>
            <p className="cta-subtitle">
              Create your free account and start learning smarter today. Get access to all features, early updates, and a direct line to shape what we build next.
            </p>
            <Button variant="Solid" label="Sign Up Free" link="/signup" />
          </div>
        </div>
      </section>

      {/* 10. Footer */}
      <Footer.Responsive />
    </>
  )
}
