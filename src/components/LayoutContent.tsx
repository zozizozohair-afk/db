'use client';
import React from 'react';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import Sidebar from './Sidebar';
import logo from '../app/public/logo.png';

export default function LayoutContent({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const pathname = usePathname();
  const isAddContractPage = pathname === '/contracts/new';

  return (
    <div className="min-h-screen flex flex-col">
      <div className="flex flex-1">
        <Sidebar />
        <main className="flex-1 w-full transition-all duration-300">
          {children}
        </main>
      </div>
      {!isAddContractPage && (
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
      )}
    </div>
  );
}
