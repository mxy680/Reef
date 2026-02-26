"use client"

import LoginHero from "./LoginHero"
import LoginForm from "./LoginForm"

export default function LoginPage() {
  return (
    <>
      <style>{`
        .login-layout {
          width: 100%;
          display: flex;
          flex-direction: row;
          min-height: 100vh;
          box-sizing: border-box;
          background-color: rgb(255, 255, 255);
        }

        .login-mobile-header {
          display: none;
        }

        @media (max-width: 768px) {
          .login-layout {
            flex-direction: column;
          }

          .login-hero-panel {
            display: none !important;
          }

          .login-form-panel {
            padding: 40px 24px !important;
          }

          .login-mobile-header {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 4px;
            margin-bottom: 32px;
          }
        }
      `}</style>
      <div className="login-layout">
        <LoginHero />
        <LoginForm />
      </div>
    </>
  )
}
