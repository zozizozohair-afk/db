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
  city: string;
  district: string;
  planNumber: string;
  deedNumber: string;
  regionNumber: string;
  floorNumber: string;
  direction: string;
  electricityMeter: string;
  companyName: string;
  companyId: string;
  ownerName?: string;
  agentName?: string;
  agentIdNumber?: string;
  agencyNumber?: string;
  agencyDate?: string;
  createdByName?: string;
  createdAtDetailed?: string;
  notes?: string;
  obligations: string[];
};

const defaultData: ReceiptPrintData = {
  projectNumber: '120',
  projectName: 'مشروع سكني',
  unitNumber: '5',
  date: new Date().toISOString().split('T')[0],
  clientName: 'اسم العميل',
  clientId: '0000000000',
  city: 'جدة',
  district: 'النزهة',
  planNumber: '000',
  deedNumber: '000',
  regionNumber: '000',
  floorNumber: '2',
  direction: 'شمالي',
  electricityMeter: '000000000',
  companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
  companyId: '7027279632',
  ownerName: 'اسم العميل',
  agentName: 'اسم الوكيل',
  agentIdNumber: '1000000000',
  agencyNumber: '445566',
  agencyDate: '1447/01/15',
  createdByName: 'masaken.user',
  createdAtDetailed: '2026-07-13 14:35:22',
  notes: 'يستخدم هذا القالب كصيغة أولية لمحضر الاستلام إلى حين ربطه ببيانات قاعدة البيانات.',
  obligations: [
    'لا يحق لي القيام بأي تعديلات على الهيكل الإنشائي أو إحداث أي تغييرات أو تشويه للواجهات.',
    'لا يحق لي التصرف في الأجزاء المشتركة بين جميع الملاك في العمارة إلا وفق الأنظمة المعتمدة.',
    'لا يحق لي المطالبة بأي جزء من الأسطح السفلية أو العلوية للعمارة أو استخدامها دون حق نظامي.',
    'ألتزم بنقل ملكية عداد الكهرباء الخاص بالشقة باسمي بعد الإفراغ مباشرة وأكون مسؤولاً عن فواتيره من تاريخ هذا المحضر.',
    'أتعهد منفرداً ومجتمعاً مع ملاك الشقق الأخرى بنقل عدادات الخدمات والمياه باسم ممثل لجنة الملاك عند الحاجة.',
    'لا يحق لي استخدام المصعد في نقل الأثاث بما يسبب تلفه أو الإضرار بمرافق المبنى.',
    'ألتزم بسداد ما تحتاجه العمارة من مصروفات الصيانة والنظافة والمياه والحراسة وفق التنظيم المعتمد.'
  ]
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
  const hasAgentData = Boolean(
    receipt.agentName ||
    receipt.agentIdNumber ||
    receipt.agencyNumber ||
    receipt.agencyDate
  );
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
        throw new Error('لم يتم العثور على صفحات المحضر');
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
      link.download = `receipt-${receipt.projectNumber || 'project'}-${receipt.unitNumber || 'unit'}.pdf`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Error downloading receipt PDF:', error);
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
            طباعة المحضر
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
            طباعة المحضر
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
            <h1 style={{ fontSize: '28px', color: '#0086bf', margin: 0, fontWeight: 700 }}>محضر استلام وحدة سكنية وضمانها</h1>
            <p style={{ fontSize: '18px', marginTop: '10px', fontWeight: 700 }}>
              مشروع رقم ({receipt.projectNumber}) - الوحدة رقم ({receipt.unitNumber})
            </p>
          </div>
          <div style={{ width: '92px' }} />
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '8px', marginBottom: '20px', gap: '16px', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '17px', color: '#0f3f7a', fontWeight: 700 }}>التاريخ: {receipt.date}</span>
          <span style={{ fontSize: '17px', color: '#0f3f7a', fontWeight: 700 }}>اسم المشروع: {receipt.projectName || '—'}</span>
        </div>

        <p style={{ fontSize: '18px', lineHeight: 2.1, fontWeight: 700, marginTop: '8px', marginBottom: '18px' }}>
          بهذا أقر بأنني استلمت الوحدة السكنية المبينة بياناتها أدناه والمشتراة من المالك ({receipt.companyName}) هوية رقم
          ({receipt.companyId})، وهي كاملة البنيان والتشطيبات حسب ما هو على الطبيعة، وألتزم بما ورد في هذا المحضر.
        </p>

        <div style={{ marginTop: '8px', marginBottom: '14px' }}>
          {receipt.obligations.map((item, index) => (
            <React.Fragment key={index}>
              <p style={{ fontSize: '14px', lineHeight: 1.65, margin: '0 0 2px 0', fontWeight: 700 }}>
                {index + 1}- {item}
              </p>
              {index === 6 && (
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: '110px 1fr 110px 1fr',
                    gap: '0',
                    marginTop: '6px',
                    marginBottom: '8px'
                  }}
                >
                  <InfoLabelCell>اتجاه الشقة</InfoLabelCell>
                  <InfoValueCell>{receipt.direction}</InfoValueCell>
                  <InfoLabelCell>رقم عداد الكهرباء</InfoLabelCell>
                  <InfoValueCell>{receipt.electricityMeter}</InfoValueCell>

                  <InfoLabelCell>رقم الشقة</InfoLabelCell>
                  <InfoValueCell>{receipt.unitNumber}</InfoValueCell>
                  <InfoLabelCell>الدور</InfoLabelCell>
                  <InfoValueCell>{receipt.floorNumber}</InfoValueCell>

                  <InfoLabelCell>الحي</InfoLabelCell>
                  <InfoValueCell>{receipt.district}</InfoValueCell>
                  <InfoLabelCell>مخطط رقم</InfoLabelCell>
                  <InfoValueCell>{receipt.planNumber}</InfoValueCell>

                  <InfoLabelCell>رقم القطعة</InfoLabelCell>
                  <InfoValueCell>{receipt.regionNumber}</InfoValueCell>
                  <InfoLabelCell>رقم صك الشقة</InfoLabelCell>
                  <InfoValueCell>{receipt.deedNumber}</InfoValueCell>
                </div>
              )}
            </React.Fragment>
          ))}
        </div>

        <p style={{ fontSize: '15px', lineHeight: 2.1, marginTop: '8px', marginBottom: '18px', textAlign: 'justify' }}>
          وبعد أن أقر بأنني عاينت الشقة المبينة بياناتها أعلاه معاينة تامة نافية للجهالة، وأني قبلت بحالتها الراهنة كما هي
          عليه، وأصبحت مسؤولاً عنها المسؤولية المدنية والجنائية، ولا يحق لي الرجوع على المالك لأي سبب يتعلق بحالتها الظاهرة
          وقت الاستلام، وهذا إقرار مني بذلك ولهذا جرى التوقيع.
        </p>

       

        <div
          style={{
            border: '1px solid #000',
            marginTop: '24px'
          }}
        >
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: '78px minmax(0, 1.9fr) 78px minmax(0, 1.9fr)',
              borderBottom: '1px solid #000',
              background: 'transparent',
              direction: 'rtl'
            }}
          >
            <div style={{ padding: '2px 2.5px', textAlign: 'center', fontWeight: 700, fontSize: '14px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985' }}>الطرف الأول</div>
            <div style={{ padding: '2px 2.5px' }} />
            <div style={{ padding: '2px 2.5px', textAlign: 'center', fontWeight: 700, fontSize: '14px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985' }}>الطرف الثاني</div>
            <div style={{ padding: '2px 2.5px' }} />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '78px minmax(0, 1.9fr) 78px minmax(0, 1.9fr)', borderBottom: '1px solid #000', direction: 'rtl' }}>
            <div style={{ padding: '2px 2.5px', textAlign: 'center', borderLeft: '1px solid #000', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '13px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985', fontWeight: 700 }}>الاسم</div>
            <div style={{ padding: '2px 2.5px', minHeight: '26px', display: 'flex', alignItems: 'center', fontWeight: 700, fontSize: '14px' }}>{receipt.companyName}</div>
            <div style={{ padding: '2px 2.5px', textAlign: 'center', borderRight: '1px solid #000', borderLeft: '1px solid #000', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '13px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985', fontWeight: 700 }}>الاسم</div>
            <div
              style={{
                padding: '2px 2.5px',
                minHeight: hasAgentData ? '86px' : '38px',
                display: 'flex',
                alignItems: hasAgentData ? 'flex-start' : 'center',
                justifyContent: 'center',
                flexDirection: 'column',
                fontWeight: 700,
                fontSize: '13px',
                lineHeight: 1.45
              }}
            >
              <div><span style={{ color: '#075985' }}>اسم الطرف الثاني:</span> {receipt.ownerName || receipt.clientName || '—'}</div>
              {hasAgentData && (
                <>
                  <div><span style={{ color: '#075985' }}>اسم الوكيل:</span> {receipt.agentName || '—'}</div>
                  <div><span style={{ color: '#075985' }}>رقم هوية الوكيل:</span> {receipt.agentIdNumber || '—'}</div>
                  <div><span style={{ color: '#075985' }}>رقم الوكالة:</span> {receipt.agencyNumber || '—'}</div>
                  <div><span style={{ color: '#075985' }}>تاريخ الوكالة:</span> {receipt.agencyDate || '—'}</div>
                </>
              )}
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '78px minmax(0, 1.9fr) 78px minmax(0, 1.9fr)', borderBottom: '1px solid #000', direction: 'rtl' }}>
            <div style={{ padding: '2px 2.5px', textAlign: 'center', borderLeft: '1px solid #000', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '13px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985', fontWeight: 700 }}>التوقيع</div>
            <div style={{ padding: '6px 2.5px', minHeight: '30px' }} />
            <div style={{ padding: '2px 2.5px', textAlign: 'center', borderRight: '1px solid #000', borderLeft: '1px solid #000', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '13px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985', fontWeight: 700 }}>التوقيع</div>
            <div style={{ padding: '6px 2.5px', minHeight: '30px' }} />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '78px minmax(0, 1.9fr) 78px minmax(0, 1.9fr)', direction: 'rtl' }}>
            <div style={{ padding: '2px 2.5px', textAlign: 'center', borderLeft: '1px solid #000', fontWeight: 700, fontSize: '13px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985' }}>رقم الهوية</div>
            <div style={{ padding: '2px 2.5px', fontWeight: 700, fontSize: '14px' }}>{receipt.companyId}</div>
            <div style={{ padding: '2px 2.5px', textAlign: 'center', borderRight: '1px solid #000', borderLeft: '1px solid #000', fontWeight: 700, fontSize: '13px', background: 'rgba(14, 165, 233, 0.12)', color: '#075985' }}>رقم الهوية</div>
            <div style={{ padding: '2px 2.5px', fontWeight: 700, fontSize: '14px' }}>{receipt.clientId}</div>
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
