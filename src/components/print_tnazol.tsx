'use client';

import React from 'react';
import { PDFDocument } from 'pdf-lib';
import { toPng } from 'html-to-image';
import { QRCodeSVG } from 'qrcode.react';

type ReceiptPrintData = {
  projectNumber: string;
  projectName?: string;
  unitNumber: string;
  date: string;
  clientName: string;
  clientId: string;
  clientPhone: string;
  city: string;
  district: string;
  floorNumber: string;
  direction: string;
  companyName: string;
  companyId: string;
  contractDate: string;
  transfereeName: string;
  transfereeId: string;
  createdByName?: string;
  createdAtDetailed?: string;
};

const defaultData: ReceiptPrintData = {
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
      className="receipt-page"
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
        className="receipt-sheet-frame"
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
            backgroundColor: 'rgba(255, 255, 255, 0.5)',
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

function InfoLabelCell({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        border: '1px solid #000',
        padding: '2px 2.5px',
        background: 'rgba(141, 228, 246, 0.42)',
        fontSize: '13px',
        fontWeight: 700,
        color: '#0b1114ff',
        textAlign: 'center',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}
    >
      {children}
    </div>
  );
}

function InfoValueCell({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        border: '1px solid #000',
        padding: '2px 2.5px',
        background: 'transparent',
        fontSize: '14px',
        fontWeight: 700,
        display: 'flex',
        alignItems: 'center'
      }}
    >
      {children || '—'}
    </div>
  );
}

export default function ReceiptPrintPage({
  data = defaultData,
  autoPrint = false,
  onClose,
}: {
  data?: ReceiptPrintData;
  autoPrint?: boolean;
  onClose?: () => void;
}) {
  const receipt = data;
  const containerRef = React.useRef<HTMLDivElement | null>(null);
  const [isDownloadingPdf, setIsDownloadingPdf] = React.useState(false);
  const qrValue = [
    `${receipt.unitNumber}-${receipt.projectNumber}-${receipt.clientId}`,
    `${receipt.createdByName || 'user'}-${receipt.createdAtDetailed || receipt.date}`
  ].join('\n');

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

      const pageElements = Array.from(containerRef.current.querySelectorAll('.receipt-sheet-frame')) as HTMLElement[];
      if (pageElements.length === 0) {
        throw new Error('لم يتم العثور على صفحات التنازل');
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
      link.download = `waiver-${receipt.projectNumber || 'project'}-${receipt.unitNumber || 'unit'}.pdf`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Error downloading waiver PDF:', error);
      alert('حدث خطأ أثناء إنشاء ملف PDF');
    } finally {
      setIsDownloadingPdf(false);
    }
  }, [receipt.projectNumber, receipt.unitNumber]);

  React.useEffect(() => {
    if (autoPrint) {
      const timer = window.setTimeout(() => {
        triggerPrint();
      }, 300);
      return () => window.clearTimeout(timer);
    }
  }, [autoPrint, triggerPrint]);

  return (
    <div ref={containerRef} dir="rtl" className="contract-print-container" style={{ fontFamily: "'AmiriLocal', serif", fontSize: '18px', overflow: 'visible', height: 'auto' }}>
      {autoPrint && onClose && (
        <div className="print-buttons-container" style={{ padding: '20px', textAlign: 'center', position: 'sticky', top: 0, background: 'white', zIndex: 1000, borderBottom: '1px solid #e5e7eb' }}>
          <button
            onClick={onClose}
            style={{
              background: '#dc2626',
              color: 'white',
              border: 'none',
              padding: '12px 28px',
              borderRadius: '8px',
              fontSize: '18px',
              cursor: 'pointer',
              marginLeft: '10px'
            }}
          >
            إغلاق
          </button>
          <button
            onClick={downloadPdf}
            disabled={isDownloadingPdf}
            style={{
              background: isDownloadingPdf ? '#9ca3af' : '#059669',
              color: 'white',
              border: 'none',
              padding: '12px 28px',
              borderRadius: '8px',
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
              borderRadius: '8px',
              fontSize: '18px',
              cursor: 'pointer'
            }}
          >
            طباعة التنازل
          </button>
        </div>
      )}
      {!autoPrint && (
        <div className="print-buttons-container" style={{ padding: '20px', textAlign: 'center' }}>
          {onClose && (
            <button
              onClick={onClose}
              style={{
                background: '#dc2626',
                color: 'white',
                border: 'none',
                padding: '12px 30px',
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
              padding: '12px 30px',
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
              padding: '12px 30px',
              borderRadius: '999px',
              fontSize: '18px',
              cursor: 'pointer'
            }}
          >
            طباعة التنازل
          </button>
        </div>
      )}

      <Page pageNumber={1} totalPages={1}>
        <Header />

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', marginTop: '18px', marginBottom: '22px' }}>
          <div style={{ width: '92px', display: 'flex', justifyContent: 'flex-start' }}>
            <QRCodeSVG value={qrValue} size={82} />
          </div>
          <div style={{ flex: 1, textAlign: 'center' }}>
            <h1 style={{ fontSize: '28px', color: '#0086bf', margin: 0, fontWeight: 700 }}>إقرار تنازل</h1>
          </div>
          <div style={{ width: '92px' }} />
        </div>

        <div style={{ textAlign: 'center', marginTop: '4px', marginBottom: '14px' }}>
          <p style={{ fontSize: '16px', fontWeight: 700, margin: 0 }}>بسم الله الرحمن الرحيم</p>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '8px', marginBottom: '16px', gap: '16px', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '16px', color: '#0f3f7a', fontWeight: 700 }}>تاريخ التنازل: {receipt.date}</span>
          <span style={{ fontSize: '16px', color: '#0f3f7a', fontWeight: 700 }}>
            مشروع رقم ({receipt.projectNumber}) - الشقة رقم ({receipt.unitNumber})
          </span>
        </div>

        <p style={{ fontSize: '16px', lineHeight: 1.95, textAlign: 'center', fontWeight: 700, marginTop: '4px', marginBottom: '10px' }}>
          الحمد لله والصلاة والسلام على رسول الله
        </p>

        <div style={{ fontSize: '15px', lineHeight: 1.9, fontWeight: 700 }}>
          <p style={{ margin: '0 0 6px 0' }}>
            السيد/ة {receipt.clientName} هوية رقم {receipt.clientId} جوال رقم {receipt.clientPhone} المحترم/ة،
          </p>
          <p style={{ margin: '0 0 6px 0' }}>السلام عليكم ورحمة الله وبركاته،</p>
          <p style={{ margin: '0 0 6px 0' }}>
            نحيطكم علمًا أنكم قد قمتم بشراء شقة رقم {receipt.unitNumber}. في الدور رقم {receipt.floorNumber} بمشروع رقم ({receipt.projectNumber})
            بمدينة {receipt.city}، في حي {receipt.district}، وهي شقة {receipt.direction}.
          </p>
          <p style={{ margin: '0 0 6px 0' }}>
            وفقًا للعقد المبرم بينكم وبين {receipt.companyName} والتطوير العقاري بتاريخ {receipt.contractDate}.
          </p>
          <p style={{ margin: '0 0 8px 0' }}>
            هذا إقرار منك (مالك العقد) باني لا ارغب بافراغ الصك باسمي وانا بكامل قواي العقلية وارغب بنقل ملكية العقد الى
            {` ${receipt.transfereeName} `}حامل/ة للهوية رقم {receipt.transfereeId} وافراغ الصك باسمه/باسمها وانني استلمت كامل
            مستحقاتي ولا أطالب الشركة بأي مبالغ مستقبلاً والله على ما أقول شهيد.
          </p>
          <p style={{ margin: '0 0 6px 0' }}>
            نرجومنكم التوقيع على هذا الإخطار كتأكيد لموافقتكم على الإقرار الموجود اعلاه.
          </p>
          <p style={{ margin: '0 0 6px 0' }}>شاكرين لكم تعاونكم، ونتطلع إلى إتمام هذه العملية بكل سهولة ويسر.</p>
          <p style={{ margin: '0 0 18px 0' }}>مع خالص التحية والتقدير،</p>
        </div>

        <div
          style={{
            marginTop: '16px',
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: '40px',
            alignItems: 'flex-start'
          }}
        >
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '17px', fontWeight: 700, marginBottom: '10px' }}>{receipt.clientName}</div>
            <div style={{ fontSize: '16px', fontWeight: 700, marginBottom: '28px' }}>التوقيع: ________________</div>
            <div style={{ fontSize: '16px', fontWeight: 700 }}>البصمة: ________________</div>
          </div>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '18px', fontWeight: 700, marginBottom: '18px' }}>الطرف الثاني: {receipt.transfereeName}</div>
            <div style={{ fontSize: '16px', fontWeight: 700, marginBottom: '28px' }}>التوقيع: ________________</div>
            <div style={{ fontSize: '16px', fontWeight: 700 }}>البصمة: ________________</div>
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
