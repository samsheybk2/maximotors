import { defineMiddleware } from 'astro/middleware';

const protectedRoutes = ['/dashboard'];
const publicOnlyRoutes = ['/dashboard/login'];

export const onRequest = defineMiddleware(
  async ({ url, request, redirect }, next) => {
    const pathname = url.pathname;

    const isProtected = protectedRoutes.some((r) => pathname.startsWith(r));
    const isPublicOnly = publicOnlyRoutes.some((r) => pathname.startsWith(r));

    if (!isProtected && !isPublicOnly) {
      return next();
    }

    const cookieHeader = request.headers.get('cookie') ?? '';
    const hasSession = cookieHeader.includes('sb-');

    if (isPublicOnly && hasSession) {
      return redirect('/dashboard');
    }

    if (isProtected && !hasSession) {
      return redirect('/dashboard/login');
    }

    return next();
  }
);
