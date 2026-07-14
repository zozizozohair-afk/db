'use client';

import React from 'react';
import { PDFDocument } from 'pdf-lib';
import { QRCodeSVG } from 'qrcode.react';
import { toPng } from 'html-to-image';

type ResalePrintData = {
  projectNumber: string;
  projectName?: string;
  unitNumber: string;
  floorNumber: string;
  city: string;
  district: string;
  direction: string;
  notificationDate: string;
  clientName: string;
  clientId: string;
  companyName: string;
  companyId: string;
  currentBuyerName: string;
  currentBuyerId: string;
  secondPartyAgentName?: string;
  secondPartyAgentIdNumber?: string;
  secondPartyAgencyNumber?: string;
  secondPartyAgencyDate?: string;
  newBuyerName?: string;
  newBuyerId?: string;
  waiverAmount: string | number;
  salePrice: string | number;
  marketingFee: string | number;
  companyServiceFee: string | number;
  lawyerFee: string | number;
  createdByName?: string;
  createdAtDetailed?: string;
};

const defaultData: ResalePrintData = {
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

export default function ResalePrintPage({
  data = defaultData,
  autoPrint = false,
  onClose,
}: {
  data?: ResalePrintData;
  autoPrint?: boolean;
  onClose?: () => void;
}) {
  const resale = data;
  const hasSecondPartyAgent = Boolean(
    resale.secondPartyAgentName ||
    resale.secondPartyAgentIdNumber ||
    resale.secondPartyAgencyNumber ||
    resale.secondPartyAgencyDate
  );
  const containerRef = React.useRef<HTMLDivElement | null>(null);
  const [isDownloadingPdf, setIsDownloadingPdf] = React.useState(false);
  const qrValue = [
    `${resale.unitNumber}-${resale.projectNumber}-${resale.clientId}`,
    `${resale.createdByName || 'user'}-${resale.createdAtDetailed || resale.notificationDate}`
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

      const pageElements = Array.from(containerRef.current.querySelectorAll('.resale-sheet-frame')) as HTMLElement[];
      if (pageElements.length === 0) {
        throw new Error('لم يتم العثور على صفحات عقد إعادة البيع');
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
      link.download = `resale-${resale.projectNumber || 'project'}-${resale.unitNumber || 'unit'}.pdf`;
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
  }, [resale.projectNumber, resale.unitNumber]);

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
          طباعة عقد إعادة البيع
        </button>
      </div>

      <Page pageNumber={1} totalPages={1}>
        <Header />

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr auto 1fr',
            alignItems: 'center',
            gap: '12px',
            marginTop: '18px',
            marginBottom: '18px',
            direction: 'ltr'
          }}
        >
          <div style={{ textAlign: 'left' }}>
            <span style={{ fontSize: '17px', color: '#0f3f7a', fontWeight: 700 }}>
              مشروع رقم ({resale.projectNumber}) - الوحدة رقم ({resale.unitNumber})
            </span>
          </div>
          <div style={{ textAlign: 'center' }}>
            <h1 style={{ fontSize: '28px', color: '#0086bf', margin: 0, fontWeight: 700 }}>عقد إعادة بيع</h1>
          </div>
          <div style={{ textAlign: 'right' }}>
            <span style={{ fontSize: '17px', color: '#0f3f7a', fontWeight: 700 }}>التاريخ: {resale.notificationDate}</span>
          </div>
        </div>

        <p style={{ textAlign: 'center', fontSize: '16px', fontWeight: 700, marginTop: '5px', marginBottom: '7px' }}>
          بسم الله الرحمن الرحيم
        </p>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', gap: '12px', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '15px', fontWeight: 700 }}>الحمد لله والصلاة والسلام على رسول الله</span>
          <span style={{ fontSize: '15px', fontWeight: 700 }}>السيد/ة: {resale.clientName} (رقم الهوية: {resale.clientId})</span>
        </div>

        <p style={{ fontSize: '15px', lineHeight: 1.75, marginBottom: '2px' }}>
          تحية طيبة، نحيطكم علمًا بأنكم قد قمتم بشراء شقة رقم ({resale.unitNumber}) في الدور رقم ({resale.floorNumber})
          بمشروع رقم ({resale.projectNumber}) بمدينة {resale.city} في حي {resale.district}، وهي شقة {resale.direction}.
        </p>
        <p style={{ fontSize: '15px', lineHeight: 1.75, marginBottom: '4px' }}>
          بتاريخ {resale.notificationDate}، ووفقًا للعقد المبرم بينكم وبين شركة مساكن الرفاهية للمقاولات العامة والتطوير العقاري،
          ونظرًا لرغبتكم في التنازل عن العقد والتخلي عن ملكية الشقة المذكورة، وعدم قبولكم إفراغ الصك باسمكم وتسليم الشقة لكم،
          ورغبتكم في إعطاء الشركة حق التصرف في بيعها، فإننا نفيدكم بأننا نقبل هذا التنازل بشرط دفع مبلغ إضافي،
          ونرغب في توضيح الشروط كما يلي:
        </p>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr 1.35fr',
            gap: '0',
            marginBottom: '4px',
            border: '1px solid #000'
          }}
        >
          <div style={{ padding: '3px 5px', borderLeft: '1px solid #000', fontSize: '14px', lineHeight: 1.65, fontWeight: 700 }}>
            الطرف الأول: شركة مساكن الرفاهية.
          </div>
          <div style={{ padding: '3px 5px', borderLeft: '1px solid #000', fontSize: '14px', lineHeight: 1.65, fontWeight: 700 }}>
            الطرف الثاني: المبرم للعقد مع الشركة.
          </div>
          <div style={{ padding: '3px 5px', fontSize: '14px', lineHeight: 1.65, fontWeight: 700 }}>
            الطرف الثالث: مشتري الشقة الخاصة بالطرف الثاني، وهو الطرف الأخير في جميع التعاملات.
          </div>
        </div>
        {hasSecondPartyAgent && (
          <div
            style={{
              border: '1px solid #000',
              padding: '4px 6px',
              marginBottom: '4px',
              fontSize: '13px',
              lineHeight: 1.55,
              fontWeight: 700
            }}
          >
            <span>الطرف الثاني الأصيل: {resale.currentBuyerName}</span>
            <span> | اسم الوكيل: {resale.secondPartyAgentName || '—'}</span>
            <span> | هوية الوكيل: {resale.secondPartyAgentIdNumber || '—'}</span>
            <span> | رقم الوكالة: {resale.secondPartyAgencyNumber || '—'}</span>
            <span> | تاريخ الوكالة: {resale.secondPartyAgencyDate || '—'}</span>
          </div>
        )}
        <p style={{ fontSize: '15px', lineHeight: 1.75, marginBottom: '4px' }}>
          تم الاتفاق على أن مبلغ التنازل هو ({resale.waiverAmount}) ريال سعودي غير مسترد، وذلك نظير التكاليف التشغيلية للشقة حتى حين بيع الشقة من قبل الشركة.
        </p>

        <div style={{ marginTop: '2px', marginBottom: '10px' }}>
          <p style={{ fontSize: '14px', lineHeight: 1.65, margin: '0 0 1px 0' }}>
            1- يتم دفع هذا المبلغ قبل توقيع عقد التنازل واستلام سند القبض.
          </p>
          <p style={{ fontSize: '14px', lineHeight: 1.65, margin: '0 0 1px 0' }}>
            2- يتم تسديد المبلغ النهائي بالكامل، دون أي التزام إضافي من الطرف الأول، وسداد جميع المستحقات التي عليك قبل التوقيع.
          </p>
          <p style={{ fontSize: '14px', lineHeight: 1.65, margin: '0 0 1px 0' }}>
            3- الشركة ستقوم ببيع الشقة بالسعر الذي تم ذكره من قبلك، وهو ({resale.salePrice}) ريال سعودي، بالإضافة إلى المبلغ المذكور ادناه وبالتوقيع أدناه فإنك تقر بأنك على علم بذلك. كما أن الشركة غير مسؤولة عن عدم بيع الشقة في وقت قياسي، حيث لا يوجد أوقات معلومة لبيع الشقق، ولا تتحمل الشركة أي مسؤولية في التأخير.
          </p>
          <p style={{ fontSize: '14px', lineHeight: 1.65, margin: '0 0 1px 0' }}>
            4- السعر المتفق عليه لا يشمل دلالة المسوق، ولا مبلغ الخدمات المقدمة من الشركة، ولا رسوم المحاماة، ولا غيرها من الرسوم المتعلقة بالبيع والإفراغ.
          </p>
          <p style={{ fontSize: '14px', lineHeight: 1.65, margin: '0 0 1px 0' }}>
            5- تكلفة ورسوم أتعاب التسويق مبلغ وقدره ({resale.marketingFee}) ريال سعودي، بالإضافة إلى ({resale.companyServiceFee}) ريال سعودي أتعاب الشركة، و({resale.lawyerFee}) ريال سعودي أتعاب المحاماة، وتدفع حين بيع الشقة للطرف الثالث.
          </p>
          <p style={{ fontSize: '14px', lineHeight: 1.65, margin: '0 0 1px 0' }}>
            6- إذا كان الشيك المقدم للشركة وقت توقيع عقد بيع الشقة مسجلًا بملاحظة (شراء شقة - شراء عقار - قيمة شقة... إلخ)، فيتم احتساب ضريبة التصرف العقاري بنسبة 5% من مبلغ الشيك، وتدفع للشركة وقت الإفراغ للطرف الثالث.
          </p>
        </div>

        <p style={{ fontSize: '15px', lineHeight: 1.75, marginTop: '2px', marginBottom: '6px', fontWeight: 700 }}>
          نرجو منكم التوقيع على هذا الإخطار تأكيدًا لموافقتكم على الشروط المذكورة أعلاه.
        </p>
        <p style={{ fontSize: '15px', lineHeight: 1.75, marginBottom: '4px' }}>
          شاكرين لكم تعاونكم، ونتطلع إلى إتمام هذه العملية بكل سهولة ويسر.
        </p>
        <p style={{ fontSize: '15px', lineHeight: 1.75, marginBottom: '6px', fontWeight: 700 }}>
          وتفضلوا بقبول خالص التحية والتقدير.
        </p>

        <div
          style={{
            marginTop: '16px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
            gap: '40px'
          }}
        >
          <div style={{ flex: 1, textAlign: 'center' }}>
            <div style={{ fontSize: '16px', fontWeight: 700, marginBottom: '42px' }}>توقيع الشركة</div>
            <div style={{ borderTop: '1px solid #000', width: '70%', margin: '0 auto' }} />
          </div>
          <div style={{ flex: 1, textAlign: 'center' }}>
            <div style={{ fontSize: '16px', fontWeight: 700, marginBottom: '42px' }}>
              {hasSecondPartyAgent ? 'توقيع الطرف الثاني / وكيله' : 'توقيع الطرف الثاني'}
            </div>
            <div style={{ borderTop: '1px solid #000', width: '70%', margin: '0 auto' }} />
          </div>
        </div>
        <div style={{ marginTop: '14px', display: 'flex', justifyContent: 'center' }}>
          <div style={{ textAlign: 'center' }}>
            <QRCodeSVG value={qrValue} size={82} />
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
