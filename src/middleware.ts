import { defineMiddleware } from 'astro/middleware';
import { createClient } from './lib/supabase';

const protectedRoutes = ['/dashboard'];
const publicOnlyRoutes = ['/dashboard/login'];

export const onRequest = defineMiddleware(
  async ({ url, cookies, redirect, locals }, next) => {
    const pathname = url.pathname;
    const supabase = createClient(cookies);

    const {
      data: { session },
    } = await supabase.auth.getSession();

    locals.session = session;

    if (publicOnlyRoutes.some((r) => pathname.startsWith(r)) && session) {
      return redirect('/dashboard');
    }

    if (
      protectedRoutes.some((r) => pathname.startsWith(r)) &&
      !session &&
      !publicOnlyRoutes.some((r) => pathname.startsWith(r))
    ) {
      return redirect('/dashboard/login');
    }

    return next();
  }
);
