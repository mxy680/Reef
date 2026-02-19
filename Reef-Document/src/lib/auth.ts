import NextAuth from "next-auth"
import { prisma } from "./db"
import { isAdminEmail } from "./admin"
import authConfig from "./auth.config"

export const { handlers, signIn, signOut, auth } = NextAuth({
  ...authConfig,
  callbacks: {
    async signIn({ profile }) {
      if (!profile?.sub || !profile?.email) return false
      await prisma.user.upsert({
        where: { googleId: profile.sub },
        update: { email: profile.email, name: profile.name ?? null, picture: profile.picture ?? null },
        create: { googleId: profile.sub, email: profile.email, name: profile.name ?? null, picture: profile.picture ?? null },
      })
      return true
    },
    async jwt({ token, profile }) {
      if (profile?.sub) {
        const user = await prisma.user.findUnique({ where: { googleId: profile.sub } })
        if (user) {
          token.userId = user.id
          token.dailyLimit = isAdminEmail(user.email) ? null : user.dailyLimit
        }
      }
      return token
    },
    async session({ session, token }) {
      if (token.userId) {
        session.user.id = token.userId as string
        ;(session as any).dailyLimit = token.dailyLimit
      }
      return session
    },
  },
})
