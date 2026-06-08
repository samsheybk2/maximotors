import { defineMiddleware } from 'astro/middleware';
import { createClient } from './lib/supabase';
import { createServerClient } from '@supabase/ssr';

const protectedRoutes = ['/dashboard'];
const publicOnlyRoutes = ['/dashboard/login'];

export const onRequest = defineMiddleware(
  async ({ url, cookies, redirect, locals }, next) => {
    const pathname = url.pathname;

    const isProtected = protectedRoutes.some((r) => pathname.startsWith(r));
    const isPublicOnly = publicOnlyRoutes.some((r) => pathname.startsWith(r));

    if (!isProtected && !isPublicOnly) {
      return next();
    }

    try {
      const supabase = createServerClient(
        import.meta.env.PUBLIC_SUPABASE_URL,
        import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
        {
          cookies: {
            getAll() {
              return cookies.getAll();
            },
            setAll(cookiesToSet) {
              cookiesToSet.forEach(({ name, value, options }) =>
                cookies.set(name, value, options)
              );
            },
          },
        }
      );

      const {
        data: { session },
      } = await supabase.auth.getSession();

      locals.session = session;

      if (isPublicOnly && session) {
        return redirect('/dashboard');
      }

      if (isProtected && !session) {
        return redirect('/dashboard/login');
      }
    } catch (e) {
      console.error('Auth middleware error:', e);
      if (isProtected) {
        return redirect('/dashboard/login');
      }
    }

    return next();
  }
);
