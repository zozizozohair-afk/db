import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";


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

export const metadata: Metadata = {
  title: "نظام مساكن لإدارة الصكوك والمشاريع",
  description: "نظام شامل لإدارة الوحدات والمشاريع العقارية",
};

import Sidebar from "../components/Sidebar";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl">
      <body
        className={`${agcRegular.variable} ${arabicUI.variable} antialiased bg-[#f9f8f4] font-sans`}
      >
        <div className="flex min-h-screen">
          <Sidebar />
          <main className="flex-1 w-full transition-all duration-300">
            {children}
          </main>
        </div>
      </body>
    </html>
  );
}
