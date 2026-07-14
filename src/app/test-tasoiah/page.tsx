'use client';

import React from 'react';
import SettlementPrintPage from '../../components/printtasoiah';

export default function SettlementPrintTestPage() {
  const testData = {
    date: '07-07-2026',
    projectNumber: '119',
    companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
    companyUnifiedNumber: '920007936',
    secondPartyName: 'فؤاد بن حسن بن عبد القادر أشقر',
    secondPartyId: '1007133596',
    secondPartyPhone: '0506615572',
    secondPartyAgentName: 'لارا أحمد الغامدي',
    secondPartyAgentIdNumber: '1012345678',
    secondPartyAgencyNumber: '445566',
    secondPartyAgencyDate: '1447/01/15',
    previousContractDate: '2025-07-09',
    unitNumber: 1,
    unitDirectionDescription: 'جنوبية غربية أمامية',
    plotNumber: '85 / ب',
    salePrice: 620000,
    saleDate: '07-07-2026',
    newOwnerName: 'فؤاد بن حسن بن عبد القادر أشقر',
    newOwnerId: '1007133596',
    createdByName: 'masaken.user',
    createdAtDetailed: '2026-07-13-16-20-15',
  };

  return <SettlementPrintPage data={testData} />;
}
