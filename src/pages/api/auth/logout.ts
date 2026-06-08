import { createServerClient, parseCookieHeader } from '@supabase/ssr';

export async function POST({ request, cookies }: { request: Request; cookies: any }) {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(request.headers.get('cookie') ?? '');
        },
        setAll(cookiesToSet: Array<{ name: string; value: string; options: any }>) {
          cookiesToSet.forEach(({ name, value, options }) => cookies.set(name, value, options));
        },
      },
    }
  );

  // Ask Supabase to sign out (this will produce cookie instructions via setAll)
  await supabase.auth.signOut();

  // Additionally, force-clear any known auth cookies by setting them expired
  // Use the request host as domain so the Set-Cookie matches production domain
  const host = (request.headers.get('host') ?? '').split(':')[0];

  const existing = parseCookieHeader(request.headers.get('cookie') ?? '');
  const names = new Set(existing.map(c => c.name));

  // Include common Supabase cookie names as a fallback
  ['sb-access-token', 'sb-refresh-token', 'sb-session', 'auth-token'].forEach(n => names.add(n));

  names.forEach((name) => {
    try {
      cookies.set(name, '', {
        path: '/',
        domain: host || undefined,
        httpOnly: true,
        sameSite: 'lax',
        expires: new Date(0),
      });
    } catch (e) {
      // best-effort: ignore if setting a cookie fails
    }
  });

  return new Response(null, { status: 204 });
}
