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

  await supabase.auth.signOut();

  return new Response(null, { status: 204 });
}
