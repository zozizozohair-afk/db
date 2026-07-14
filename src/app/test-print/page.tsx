'use client';

import React from 'react';
import ContractPrintPage from '../../components/printcontrect';

export default function PrintTestPage() {
  const testData = {
    projectNumber: '120',
    unitNumber: '5',
    clientName: 'محمد بن علي',
    clientId: '1023456789',
    clientPhone: '0501234567',
    totalAmount: 500000,
    deliveryMonths: 18,
    deliveryDays: 30,
    gregorianDate: '2026-06-24',
    hijriDate: '09 محرم 1448 هـ',
    city: 'جدة',
    district: 'النزهة',
    floor: 'الثاني',
    deedNumber: '12345',
    planNumber: '67890',
    direction: 'الشمال',
    description: 'شقة رائعة',
    regionNumber: '123',
    area: 160,
    payments: [
      {
        transactionType: 'كاش',
        date: '2026-06-24',
        cod: '12345',
        amount: 100000,
        description: 'الدفعة الأولى'
      }
    ],
    agent: {
      name: 'علي بن أحمد',
      id: '9876543210',
      agencyNumber: 'WKL-001',
      agencyDate: '2026-06-01'
    }
  };

  return <ContractPrintPage data={testData} />;
}