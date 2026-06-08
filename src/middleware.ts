import { defineMiddleware } from 'astro/middleware';

const protectedPrefix = '/dashboard';
const loginPath = '/dashboard/login';

export const onRequest = defineMiddleware(
  async ({ url, request, redirect }, next) => {
    const pathname = url.pathname;

    const isDashboard = pathname.startsWith(protectedPrefix);
    const isLogin = pathname === loginPath || pathname === loginPath + '/';

    if (!isDashboard) {
      return next();
    }

    if (isLogin) {
      return next();
    }

    const cookieHeader = request.headers.get('cookie') ?? '';
    const hasAuthCookie = cookieHeader.includes('sb-') && cookieHeader.includes('auth-token');

    if (!hasAuthCookie) {
      return redirect('/dashboard/login');
    }

    return next();
  }
);
