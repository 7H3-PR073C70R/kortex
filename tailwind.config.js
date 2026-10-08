/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./web_landing/**/*.html",
    "./web_landing/**/*.js",
  ],
  darkMode: ['class', '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        brand: {
          sage: '#788C7E',
          ochre: '#D4A373',
          moss: '#4A6B5D',
          terracotta: '#D97757',
          dark: '#0D0D0F',
          card: '#141417',
        }
      }
    }
  },
  plugins: [],
}
