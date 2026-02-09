/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-agc)", "sans-serif"],
        display: ["var(--font-arabic-ui)", "sans-serif"]
      }
    }
  },
  plugins: []
};
