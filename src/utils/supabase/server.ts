import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            const rememberMe = cookieStore.get('remember-me')?.value === 'true'

            cookiesToSet.forEach(({ name, value, options }) => {
              if (!rememberMe && options.maxAge) {
                const { maxAge, ...sessionOptions } = options
                cookieStore.set(name, value, sessionOptions)
              } else {
                cookieStore.set(name, value, options)
              }
            })
          } catch {
            // The `setAll` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        },
      },
    }
  )
}
