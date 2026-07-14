'use client';

import React from 'react';
import TnazolPrintPage from '../../components/print_tnazol';

export default function TnazolPrintTestPage() {
  const testData = {
    projectNumber: '119',
    projectName: 'مشروع رقم 119',
    unitNumber: '19',
    date: '25 - 04 - 2026',
    clientName: 'نوره بنت علي بن مشهف الاحلاف الزهراني',
    clientId: '1056214065',
    clientPhone: '0549272290',
    city: 'جدة',
    district: 'النزهة',
    floorNumber: '4',
    direction: 'جنوبية غربية خلفية',
    companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
    companyId: '7027279632',
    contractDate: '2026-01-12',
    transfereeName: 'اثيربنت خالد بن حشرالدعجاني العتيبي',
    transfereeId: '1112747181',
    createdByName: 'masaken.user',
    createdAtDetailed: '2026-07-13 14:35:22',
  };

  return <TnazolPrintPage data={testData} />;
}
