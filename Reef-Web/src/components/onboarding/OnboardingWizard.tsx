"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { AnimatePresence, motion } from "framer-motion"
import { upsertProfile } from "../../lib/profiles"
import ProgressBar from "./ProgressBar"
import StepName from "./StepName"
import StepGrade from "./StepGrade"
import StepSubjects from "./StepSubjects"
import StepReferral from "./StepReferral"
import { colors } from "../../lib/colors"

const slideVariants = {
  enter: (direction: number) => ({
    x: direction > 0 ? 80 : -80,
    opacity: 0,
  }),
  center: { x: 0, opacity: 1 },
  exit: (direction: number) => ({
    x: direction > 0 ? -80 : 80,
    opacity: 0,
  }),
}

export default function OnboardingWizard({ user }: { user: { id: string; email: string } }) {
  const router = useRouter()
  const [step, setStep] = useState(0)
  const [direction, setDirection] = useState(1)
  const [submitting, setSubmitting] = useState(false)
  const [formData, setFormData] = useState({
    name: "",
    grade: "",
    subjects: [],
    referral_source: "",
  })

  function goNext() {
    setDirection(1)
    setStep((s) => s + 1)
  }

  function goBack() {
    setDirection(-1)
    setStep((s) => s - 1)
  }

  async function handleSubmit() {
    setSubmitting(true)
    try {
      await upsertProfile({
        display_name: formData.name,
        email: user.email,
        grade: formData.grade,
        subjects: formData.subjects,
        referral_source: formData.referral_source,
        onboarding_completed: true,
      })
      document.cookie = "reef_onboarded=true; path=/; max-age=31536000"
      router.push("/dashboard")
    } catch {
      setSubmitting(false)
    }
  }

  return (
    <div
      style={{
        width: "100%",
        minHeight: "100vh",
        backgroundColor: colors.surface,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "40px 24px",
        boxSizing: "border-box",
      }}
    >
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.15 }}
        style={{
          width: 440,
          maxWidth: "100%",
          backgroundColor: colors.white,
          border: `2px solid ${colors.black}`,
          borderRadius: 12,
          boxShadow: `6px 6px 0px 0px ${colors.black}`,
          padding: "48px 36px",
          boxSizing: "border-box",
          overflow: "hidden",
        }}
      >
        <ProgressBar step={step} total={4} />

        <AnimatePresence mode="wait" custom={direction}>
          {step === 0 && (
            <motion.div
              key="name"
              custom={direction}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.25, ease: "easeInOut" }}
            >
              <StepName
                value={formData.name}
                onChange={(name) => setFormData((d) => ({ ...d, name }))}
                onNext={goNext}
              />
            </motion.div>
          )}

          {step === 1 && (
            <motion.div
              key="grade"
              custom={direction}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.25, ease: "easeInOut" }}
            >
              <StepGrade
                value={formData.grade}
                onChange={(grade) => setFormData((d) => ({ ...d, grade }))}
                onNext={goNext}
                onBack={goBack}
              />
            </motion.div>
          )}

          {step === 2 && (
            <motion.div
              key="subjects"
              custom={direction}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.25, ease: "easeInOut" }}
            >
              <StepSubjects
                value={formData.subjects}
                onChange={(subjects) => setFormData((d) => ({ ...d, subjects }))}
                onNext={goNext}
                onBack={goBack}
              />
            </motion.div>
          )}

          {step === 3 && (
            <motion.div
              key="referral"
              custom={direction}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ duration: 0.25, ease: "easeInOut" }}
            >
              <StepReferral
                value={formData.referral_source}
                onChange={(referral_source) => setFormData((d) => ({ ...d, referral_source }))}
                onSubmit={handleSubmit}
                onBack={goBack}
                submitting={submitting}
              />
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  )
}
