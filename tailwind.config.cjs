/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{astro,html,js,jsx,md,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        primary: '#1D3557',
        accent: '#E63946',
        'gr-claro': '#F1FAEE',
        'gr-oscuro': '#457B9D',
        cert: '#2A9D8F',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
