import { createServerClient } from "@supabase/ssr"
import { type NextRequest, NextResponse } from "next/server"

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet: { name: string; value: string; options?: Record<string, unknown> }[]) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          )
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options as any)
          )
        },
      },
    }
  )

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { pathname } = request.nextUrl
  const ADMIN_EMAIL = "markshteyn1@gmail.com"

  // Redirect unauthenticated users away from protected routes
  if (!user && (pathname.startsWith("/onboarding") || pathname.startsWith("/dashboard"))) {
    const url = request.nextUrl.clone()
    url.pathname = "/auth"
    return NextResponse.redirect(url)
  }

  // Block non-admin users from /dashboard/admin
  if (pathname.startsWith("/dashboard/admin")) {
    if (!user) {
      const url = request.nextUrl.clone()
      url.pathname = "/auth"
      return NextResponse.redirect(url)
    }
    if (user.email !== ADMIN_EMAIL) {
      const url = request.nextUrl.clone()
      url.pathname = "/dashboard"
      return NextResponse.redirect(url)
    }
  }

  // Redirect authenticated users away from auth pages
  if (user && (pathname === "/auth" || pathname === "/signup")) {
    const url = request.nextUrl.clone()
    const onboarded = request.cookies.get("reef_onboarded")?.value === "true"
    url.pathname = onboarded ? "/dashboard" : "/onboarding"
    return NextResponse.redirect(url)
  }

  return supabaseResponse
}
