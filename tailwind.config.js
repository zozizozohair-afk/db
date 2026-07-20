const config = {
  content: [
    "./src/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['var(--font-cairo)', 'var(--font-agc)', 'Tahoma', 'Arial', 'sans-serif'],
        display: ['var(--font-arabic-ui)', 'var(--font-agc)', 'Tahoma', 'Arial', 'sans-serif'],
      },
    },
  },
  plugins: [],
}

export default config
