import type { Metadata } from "next";
import localFont from "next/font/local";
import Image from "next/image";
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
import logo from "./public/logo.png";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl" suppressHydrationWarning>
      <body
        className={`${agcRegular.variable} ${arabicUI.variable} antialiased bg-[#f9f8f4] font-sans`}
      >
        <div className="min-h-screen flex flex-col">
          <div className="flex flex-1">
            <Sidebar />
            <main className="flex-1 w-full transition-all duration-300">
              {children}
            </main>
          </div>
          <footer className="border-t border-gray-200 bg-white/70 backdrop-blur">
            <div className="max-w-7xl mx-auto px-4 md:px-8 py-5 flex flex-col md:flex-row items-center justify-between gap-3">
              <div className="flex items-center gap-4">
                <div className="relative h-24 w-80">
                  <Image src={logo} alt="مساكن" fill className="object-contain object-right" />
                </div>
                <div className="text-sm text-gray-600">
                  جميع الحقوق محفوظة © {new Date().getFullYear()}
                </div>
              </div>
              <div className="flex items-center gap-4 text-sm">
                <a href="#" className="font-bold text-gray-700 hover:text-emerald-700 transition-colors">
                  انقر هنا
                </a>
                <a href="#" className="text-gray-600 hover:text-emerald-700 transition-colors">
                  تم التطوير بواسطة zohairalzohairy
                </a>
              </div>
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}
