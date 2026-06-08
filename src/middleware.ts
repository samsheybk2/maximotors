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

    // Parse cookies into a map for robust checks (avoid brittle substring includes)
    const cookieMap = cookieHeader
      .split(';')
      .map(s => s.trim())
      .filter(Boolean)
      .reduce((acc, pair) => {
        const idx = pair.indexOf('=');
        if (idx === -1) return acc;
        const k = pair.slice(0, idx).trim();
        const v = pair.slice(idx + 1).trim();
        acc[k] = v;
        return acc;
      }, {} as Record<string, string>);

    const hasAuthCookie = Object.keys(cookieMap).some(k => k.startsWith('sb-')) && Boolean(cookieMap['auth-token']);

    if (!hasAuthCookie) {
      return redirect('/dashboard/login');
    }

    return next();
  }
);
