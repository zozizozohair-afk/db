'use client';

import React from 'react';
import { PDFDocument } from 'pdf-lib';
import { toPng } from 'html-to-image';
import { QRCodeSVG } from 'qrcode.react';

type SettlementPrintData = {
  date: string;
  projectNumber: string;
  companyName: string;
  companyUnifiedNumber: string;
  secondPartyName: string;
  secondPartyId: string;
  secondPartyPhone: string;
  secondPartyAgentName?: string;
  secondPartyAgentIdNumber?: string;
  secondPartyAgencyNumber?: string;
  secondPartyAgencyDate?: string;
  previousContractDate: string;
  unitNumber: string | number;
  unitDirectionDescription: string;
  plotNumber: string;
  salePrice: string | number;
  saleDate: string;
  newOwnerName?: string;
  newOwnerId?: string;
  createdByName?: string;
  createdAtDetailed?: string;
};

const defaultData: SettlementPrintData = {
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
  createdAtDetailed: '2026-07-13 16:20:15',
};

function formatDetailedDate(date: Date) {
  const pad = (value: number) => value.toString().padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}-${pad(date.getHours())}-${pad(date.getMinutes())}-${pad(date.getSeconds())}`;
}

function Header() {
  return (
    <>
      <div style={{ textAlign: 'center', width: '100%' }}>
        <img src="/m.png" alt="شعار الشركة" style={{ width: '100%', height: 'auto', display: 'block' }} />
      </div>
      <hr style={{ borderColor: '#000', marginTop: '10px' }} />
    </>
  );
}

function Page({
  children,
  pageNumber,
  totalPages,
}: {
  children: React.ReactNode;
  pageNumber?: number;
  totalPages?: number;
}) {
  return (
    <div
      className="resale-page"
      style={{
        width: '210mm',
        minHeight: '297mm',
        margin: '20px auto',
        background: 'white',
        padding: '20px',
        boxSizing: 'border-box',
        pageBreakAfter: 'always'
      }}
    >
      <div
        className="resale-sheet-frame"
        style={{
          minHeight: 'calc(297mm - 40px)',
          border: '2px solid #000',
          padding: '15px',
          paddingBottom: '24px',
          boxSizing: 'border-box',
          position: 'relative',
          overflow: 'hidden'
        }}
      >
        <img
          src="/4.png"
          alt=""
          aria-hidden="true"
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block',
            pointerEvents: 'none',
            zIndex: 0
          }}
        />
        <div
          style={{
            position: 'absolute',
            inset: 0,
            backgroundColor: 'rgba(255, 255, 255, 0.52)',
            pointerEvents: 'none',
            zIndex: 0
          }}
        />
        <div style={{ position: 'relative', zIndex: 1 }}>{children}</div>
        {typeof pageNumber === 'number' && typeof totalPages === 'number' && (
          <div
            style={{
              position: 'absolute',
              left: '15px',
              right: '15px',
              bottom: '12px',
              borderTop: '1px solid #9ca3af',
              paddingTop: '6px',
              fontSize: '12px',
              fontWeight: 700,
              color: '#4b5563',
              textAlign: 'center',
              zIndex: 2,
              pointerEvents: 'none'
            }}
          >
            صفحة {pageNumber} من {totalPages}
          </div>
        )}
      </div>
    </div>
  );
}

function PartyBlockHeader({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        borderBottom: '1px solid #000',
        padding: '2px 2.5px',
        background: 'rgba(141, 228, 246, 0.42)',
        fontSize: '14.5px',
        fontWeight: 700,
        color: '#0b1114ff',
        textAlign: 'center',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        lineHeight: 1.4
      }}
    >
      {children}
    </div>
  );
}

function PartyRow({
  label,
  value,
  isFirst,
}: {
  label: string;
  value: React.ReactNode;
  isFirst?: boolean;
}) {
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: '95px minmax(0, 1fr)',
        direction: 'rtl',
        borderTop: isFirst ? 'none' : '1px solid #000'
      }}
    >
      <div
        style={{
          borderLeft: '1px solid #000',
          padding: '2px 2.5px',
          background: 'rgba(141, 228, 246, 0.42)',
          fontSize: '12.5px',
          fontWeight: 700,
          textAlign: 'center',
          lineHeight: 1.4,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}
      >
        {label}
      </div>
      <div
        style={{
          padding: '2px 2.5px',
          background: 'transparent',
          fontSize: '13.5px',
          fontWeight: 700,
          lineHeight: 1.4,
          display: 'flex',
          alignItems: 'center'
        }}
      >
        {value || '—'}
      </div>
    </div>
  );
}

export default function SettlementPrintPage({
  data = defaultData,
  autoPrint = false,
  onClose,
}: {
  data?: SettlementPrintData;
  autoPrint?: boolean;
  onClose?: () => void;
}) {
  const settlement = data;
  const hasSecondPartyAgent = Boolean(
    settlement.secondPartyAgentName ||
    settlement.secondPartyAgentIdNumber ||
    settlement.secondPartyAgencyNumber ||
    settlement.secondPartyAgencyDate
  );
  const containerRef = React.useRef<HTMLDivElement | null>(null);
  const [isDownloadingPdf, setIsDownloadingPdf] = React.useState(false);
  const qrDetailedDate = React.useMemo(
    () => settlement.createdAtDetailed || formatDetailedDate(new Date()),
    [settlement.createdAtDetailed]
  );
  const qrUserName = settlement.createdByName || 'user';
  const qrValue = [
    `${settlement.unitNumber}-${settlement.projectNumber}-${settlement.secondPartyId}`,
    `${qrDetailedDate}-${qrUserName}`
  ].join('\n');
  const hasNewOwnerData = Boolean(
    String(settlement.newOwnerName || '').trim() && String(settlement.newOwnerId || '').trim()
  );

  const triggerPrint = React.useCallback(async () => {
    window.scrollTo(0, 0);
    const waitForImage = (src: string) =>
      new Promise<void>((resolve) => {
        const img = new window.Image();
        const done = () => resolve();
        img.onload = done;
        img.onerror = done;
        img.src = src;
        if (img.complete) resolve();
      });
    await waitForImage('/4.png');
    await new Promise((resolve) => setTimeout(resolve, 200));
    window.print();
  }, []);

  const downloadPdf = React.useCallback(async () => {
    if (!containerRef.current) return;

    try {
      setIsDownloadingPdf(true);
      window.scrollTo(0, 0);

      const fontsReady = 'fonts' in document ? (document as Document & { fonts: FontFaceSet }).fonts.ready : Promise.resolve();
      await fontsReady;

      const images = Array.from(containerRef.current.querySelectorAll('img')) as HTMLImageElement[];
      await Promise.all(
        images.map(async (img) => {
          try {
            await img.decode();
          } catch {
            return;
          }
        })
      );

      const pageElements = Array.from(containerRef.current.querySelectorAll('.resale-sheet-frame')) as HTMLElement[];
      if (pageElements.length === 0) {
        throw new Error('لم يتم العثور على صفحات التسوية المالية');
      }

      const pdf = await PDFDocument.create();
      for (const pageElement of pageElements) {
        const dataUrl = await toPng(pageElement, {
          cacheBust: true,
          pixelRatio: 2,
          backgroundColor: '#ffffff',
        });

        const imageBytes = await fetch(dataUrl).then((res) => res.arrayBuffer());
        const embeddedImage = await pdf.embedPng(imageBytes);
        const pagePadding = 10;
        const pdfWidth = 595.28;
        const imageWidth = pdfWidth - (pagePadding * 2);
        const imageHeight = imageWidth * (embeddedImage.height / embeddedImage.width);
        const pdfHeight = imageHeight + (pagePadding * 2);
        const page = pdf.addPage([pdfWidth, pdfHeight]);
        page.drawImage(embeddedImage, {
          x: pagePadding,
          y: pagePadding,
          width: imageWidth,
          height: imageHeight,
        });
      }

      const pdfBytes = await pdf.save();
      const pdfBuffer = new Uint8Array(pdfBytes).buffer as ArrayBuffer;
      const blob = new Blob([pdfBuffer], { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `settlement-${settlement.date}.pdf`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Error downloading resale PDF:', error);
      alert('حدث خطأ أثناء إنشاء ملف PDF');
    } finally {
      setIsDownloadingPdf(false);
    }
  }, [settlement.date]);

  React.useEffect(() => {
    if (autoPrint) {
      const timer = window.setTimeout(() => {
        triggerPrint();
      }, 300);
      return () => window.clearTimeout(timer);
    }
  }, [autoPrint, triggerPrint]);

  return (
    <div ref={containerRef} dir="rtl" className="contract-print-container" style={{ fontFamily: "'AmiriLocal', serif", fontSize: '17.5px', overflow: 'visible', height: 'auto' }}>
      <div className="print-buttons-container" style={{ padding: '20px', textAlign: 'center', background: 'white' }}>
        {onClose && (
          <button
            onClick={onClose}
            style={{
              background: '#dc2626',
              color: 'white',
              border: 'none',
              padding: '12px 28px',
              borderRadius: '999px',
              fontSize: '18px',
              cursor: 'pointer',
              marginLeft: '10px'
            }}
          >
            إغلاق
          </button>
        )}
        <button
          onClick={downloadPdf}
          disabled={isDownloadingPdf}
          style={{
            background: isDownloadingPdf ? '#9ca3af' : '#059669',
            color: 'white',
            border: 'none',
            padding: '12px 28px',
            borderRadius: '999px',
            fontSize: '18px',
            cursor: isDownloadingPdf ? 'not-allowed' : 'pointer',
            marginLeft: '10px'
          }}
        >
          {isDownloadingPdf ? 'جارٍ التحميل...' : 'تحميل PDF'}
        </button>
        <button
          onClick={triggerPrint}
          style={{
            background: '#0f3f7a',
            color: 'white',
            border: 'none',
            padding: '12px 28px',
            borderRadius: '999px',
            fontSize: '18px',
            cursor: 'pointer'
          }}
        >
          طباعة التسوية المالية
        </button>
      </div>

      <Page pageNumber={1} totalPages={1}>
        <Header />

        <div style={{ marginTop: '18px', marginBottom: '14px', textAlign: 'center' }}>
          <h1 style={{ fontSize: '30px', color: '#0086bf', margin: 0, fontWeight: 700 }}>تسوية مالية</h1>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '18px' }}>
          <span style={{ fontSize: '17.5px', color: '#0f3f7a', fontWeight: 700 }}>التاريخ: {settlement.date}</span>
        </div>

        <div style={{ fontSize: '16.5px', lineHeight: 1.7, fontWeight: 700, marginBottom: '8px' }}>بين كلٍّ من:</div>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            border: '1px solid #000',
            marginBottom: '14px',
            direction: 'rtl'
          }}
        >
          <div style={{ borderLeft: '1px solid #000' }}>
            <PartyBlockHeader>الطرف الأول</PartyBlockHeader>
            <PartyRow label="الاسم" value={settlement.companyName} isFirst />
            <PartyRow label="الرقم الموحد" value={settlement.companyUnifiedNumber} />
          </div>
          <div>
            <PartyBlockHeader>الطرف الثاني</PartyBlockHeader>
            <PartyRow label="الاسم" value={settlement.secondPartyName} isFirst />
            <PartyRow label="حامل الهوية" value={settlement.secondPartyId} />
            <PartyRow label="جوال" value={settlement.secondPartyPhone} />
            {hasSecondPartyAgent && (
              <>
                <PartyRow label="اسم الوكيل" value={settlement.secondPartyAgentName} />
                <PartyRow label="هوية الوكيل" value={settlement.secondPartyAgentIdNumber} />
                <PartyRow label="رقم الوكالة" value={settlement.secondPartyAgencyNumber} />
                <PartyRow label="تاريخ الوكالة" value={settlement.secondPartyAgencyDate} />
              </>
            )}
          </div>
        </div>

        <p style={{ fontSize: '17.5px', lineHeight: 1.82, marginBottom: '8px' }}>
          بناءً على عقد الشراء للشقة تحت الإنشاء السابق المؤرخ في {settlement.previousContractDate}، على الشقة رقم {settlement.unitNumber}،
          وهي شقة {settlement.unitDirectionDescription} من القطعة رقم {settlement.plotNumber}، الذي قام بشرائها الطرف الثاني من الطرف الأول،
          يقر الطرف الثاني {settlement.secondPartyName} بأنه وافق على بيع الشقة بسعر {settlement.salePrice}  ريال سعودي بتاريخ {settlement.saleDate}.
        </p>

        <p style={{ fontSize: '17.5px', lineHeight: 1.82, marginBottom: '8px' }}>
          {hasNewOwnerData
            ? `سيتم بيع الشقة للمالك الجديد: ${settlement.newOwnerName}، حامل الهوية رقم ${settlement.newOwnerId}.`
            : 'سيتم بيع الشقة للعميل الجديد .'}
        </p>

        <p style={{ fontSize: '17.5px', lineHeight: 1.82, marginBottom: '8px' }}>
          وتحويل مبلغ {settlement.salePrice} ريال سعودي إلى رصيد السيد/ة {settlement.secondPartyName} لدى الشركة، وله الحق في استرداده أو شراء شقة أخرى به.
        </p>

        {hasSecondPartyAgent && (
          <p style={{ fontSize: '16.5px', lineHeight: 1.76, marginBottom: '8px', fontWeight: 700 }}>
            وقد حضر نيابةً عن الطرف الثاني وكيله {settlement.secondPartyAgentName || '—'}، حامل الهوية رقم {settlement.secondPartyAgentIdNumber || '—'}،
            بموجب الوكالة رقم {settlement.secondPartyAgencyNumber || '—'} وتاريخ {settlement.secondPartyAgencyDate || '—'}.
          </p>
        )}

        <p style={{ fontSize: '17.5px', lineHeight: 1.82, marginBottom: '14px' }}>
          ويؤكد الطرف الثاني بتوقيعه وبصمته على هذه الورقة أنه لا يطالب {settlement.companyName} أو ممثليها بأي مبالغ أخرى غير المذكور أو الشقة المذكورة أعلاه بعد تاريخه،
          وأنه قام بالتوقيع والموافقة وهو بكامل أهليته المعتبرة شرعًا دون أي إكراه من أي طرف.
        </p>

        <div
          style={{
            marginTop: '18px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
            gap: '24px',
            direction: 'ltr'
          }}
        >
          <div style={{ width: '132px', textAlign: 'center' }}>
            <QRCodeSVG value={qrValue} size={96} />
            <div style={{ fontSize: '12px', fontWeight: 700, marginTop: '8px', lineHeight: 1.5, wordBreak: 'break-word' }}>
              <div>{qrDetailedDate}</div>
              <div>{qrUserName}</div>
            </div>
          </div>
          <div style={{ flex: 1, textAlign: 'right' }}>
            <div style={{ fontSize: '18.5px', fontWeight: 700, marginBottom: '10px' }}>
              {hasSecondPartyAgent ? 'توقيع الطرف الثاني / وكيله' : 'توقيع الطرف الثاني'}
            </div>
            <div style={{ fontSize: '17.5px', marginBottom: '8px' }}>
              <span style={{ fontWeight: 700 }}>الاسم:</span> {hasSecondPartyAgent ? settlement.secondPartyAgentName : settlement.secondPartyName}
            </div>
            <div style={{ fontSize: '17.5px', marginBottom: '16px' }}>
              <span style={{ fontWeight: 700 }}>البصمة:</span> ______________________
            </div>
          </div>
        </div>
      </Page>

      <style jsx global>{`
        @font-face {
          font-family: 'AmiriLocal';
          src: url('/fonts/Amiri-Regular.ttf') format('truetype');
          font-weight: 400;
        }

        @font-face {
          font-family: 'AmiriLocal';
          src: url('/fonts/Amiri-Bold.ttf') format('truetype');
          font-weight: 700;
        }

        html,
        body {
          margin: 0;
          padding: 0;
          background: #e5e7eb;
          font-family: 'AmiriLocal', serif;
        }

        .contract-print-container {
          font-family: 'AmiriLocal', serif;
        }
      `}</style>
    </div>
  );
}
