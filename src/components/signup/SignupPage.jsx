"use client"

import SignupHero from "./SignupHero"
import SignupForm from "./SignupForm"

export default function SignupPage() {
  return (
    <>
      <style>{`
        .signup-layout {
          width: 100%;
          display: flex;
          flex-direction: row;
          min-height: 100vh;
          box-sizing: border-box;
          background-color: rgb(255, 255, 255);
        }

        .signup-mobile-header {
          display: none;
        }

        @media (max-width: 768px) {
          .signup-layout {
            flex-direction: column;
          }

          .signup-hero-panel {
            display: none !important;
          }

          .signup-form-panel {
            padding: 40px 24px !important;
          }

          .signup-mobile-header {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 4px;
            margin-bottom: 32px;
          }
        }
      `}</style>
      <div className="signup-layout">
        <SignupHero />
        <SignupForm />
      </div>
    </>
  )
}
