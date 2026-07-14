'use client';

import React from 'react';
import ResalePrintPage from '../../components/printeaadtbia';

export default function ResalePrintTestPage() {
  const testData = {
    projectNumber: '120',
    projectName: 'مشروع النزهة السكني',
    unitNumber: '5',
    floorNumber: 'الثاني',
    city: 'جدة',
    district: 'النزهة',
    direction: 'شمالية',
    notificationDate: '11-05-2025',
    clientName: 'محمد بن علي',
    clientId: '1023456789',
    companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
    companyId: '7027279632',
    currentBuyerName: 'محمد بن علي',
    currentBuyerId: '1023456789',
    secondPartyAgentName: 'أحمد محمد الغامدي',
    secondPartyAgentIdNumber: '1012345678',
    secondPartyAgencyNumber: '445566',
    secondPartyAgencyDate: '1447/01/15',
    newBuyerName: 'عبدالله أحمد السلمي',
    newBuyerId: '1098765432',
    waiverAmount: '5000',
    salePrice: '650000',
    marketingFee: '15000',
    companyServiceFee: '2500',
    lawyerFee: '2500',
    createdByName: 'masaken.user',
    createdAtDetailed: '2026-07-13 16:20:15',
  };

  return <ResalePrintPage data={testData} />;
}
