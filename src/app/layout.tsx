import type { Metadata } from "next";
import { Cairo } from "next/font/google";
import localFont from "next/font/local";
import "./globals.css";
import LayoutContent from "../components/LayoutContent";


const agcRegular = localFont({
  src: "./fonts/AGCRegular.ttf",
  variable: "--font-agc",
  weight: "400",
});

const arabicUI = localFont({
  src: "./fonts/ArabicUIDisplayBlack.otf",
  variable: "--font-arabic-ui",
  weight: "900",
});

const cairo = Cairo({
  subsets: ["arabic", "latin"],
  variable: "--font-cairo",
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "نظام مساكن لإدارة الصكوك والمشاريع",
  description: "نظام شامل لإدارة الوحدات والمشاريع العقارية",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl" suppressHydrationWarning>
      <body
        className={`${agcRegular.variable} ${arabicUI.variable} ${cairo.variable} antialiased bg-[#f9f8f4] font-sans`}
      >
        <LayoutContent>
          {children}
        </LayoutContent>
      </body>
    </html>
  );
}
