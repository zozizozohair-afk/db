'use client';

import React from 'react';
import { PDFDocument } from 'pdf-lib';
import { QRCodeSVG } from 'qrcode.react';
import { toPng } from 'html-to-image';

type Payment = {
  transactionType?: string;
  date?: string;
  cod?: string;
  amount?: number;
  description?: string;
};

type Agent = {
  name?: string;
  id?: string;
  agencyNumber?: string;
  agencyDate?: string;
};

type ContractPrintAttachment = {
  id?: string;
  category?: string;
  file_name: string;
  file_type: 'pdf' | 'image';
  mime_type?: string | null;
  file_url: string;
  file_path?: string;
};

type ContractPrintData = {
  contractId?: string;
  projectNumber: string;
  unitNumber: string;
  clientName: string;
  clientId: string;
  clientPhone: string;
  createdByName?: string;
  createdAt?: string;
  totalAmount: string | number;
  deliveryMonths: string | number;
  deliveryDays: string | number;
  gregorianDate: string;
  hijriDate: string;
  city: string;
  district: string;
  floor: string | number;
  deedNumber: string;
  planNumber: string;
  direction: string;
  description: string;
  regionNumber: string;
  area: string | number;
  payments: Payment[];
  attachments?: ContractPrintAttachment[];
  agent?: Agent;
};

const defaultData: ContractPrintData = {
  projectNumber: '120',
  unitNumber: '5',
  clientName: 'اسم العميل',
  clientId: '0000000000',
  clientPhone: '05xxxxxxxx',
  totalAmount: '500000',
  deliveryMonths: '18',
  deliveryDays: '30',
  gregorianDate: new Date().toISOString().split('T')[0],
  hijriDate: '09 محرم 1448 هـ',
  city: 'جدة',
  district: 'النزهة',
  floor: 'الثاني',
  deedNumber: '____',
  planNumber: '____',
  direction: '____',
  description: '____',
  regionNumber: '____',
  area: '160',
  payments: [],
  attachments: [],
};

function money(value: number | string | undefined) {
  const n = Number(value ?? 0);
  return `${n.toLocaleString('en-US')} ر.س`;
}

function getPaidTotal(payments: Payment[]) {
  return payments.reduce((sum, p) => sum + Number(p.amount ?? 0), 0);
}

function getPaymentStatusDescription(contract: ContractPrintData) {
  const total = Number(contract.totalAmount ?? 0);
  const paid = getPaidTotal(contract.payments);

  if (paid >= total) {
    return 'يتم الدفع الفورى للمبلغ الاجمالي';
  }

  const remaining = total - paid;

  return `دفع مبلغ وقدره ${money(paid)} يتم دفعة فورا، ويتم دفع المتبقي خلال مدة ${contract.deliveryDays} يوما تبدأ من تاريخه، والمتبقي هو ${money(remaining)}.`;
}

const PDF_PAGE_WIDTH = 595.28;
const PDF_PAGE_HEIGHT = 841.89;
const PDF_PAGE_PADDING = 18;
const ATTACHMENT_PAGE_MARGIN = 28;

function blobToDataUrl(blob: Blob) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(new Error('تعذر قراءة الملف'));
    reader.readAsDataURL(blob);
  });
}

function loadImageElement(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new window.Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('تعذر تحميل الصورة'));
    img.src = src;
  });
}

async function imageBlobToPngBytes(blob: Blob) {
  const dataUrl = await blobToDataUrl(blob);
  const img = await loadImageElement(dataUrl);
  const canvas = document.createElement('canvas');
  canvas.width = img.naturalWidth || img.width;
  canvas.height = img.naturalHeight || img.height;
  const ctx = canvas.getContext('2d');
  if (!ctx) {
    throw new Error('تعذر تجهيز الصورة');
  }
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(img, 0, 0);
  const pngDataUrl = canvas.toDataURL('image/png');
  return fetch(pngDataUrl).then((res) => res.arrayBuffer());
}

function getContainedSize(p: { width: number; height: number; maxWidth: number; maxHeight: number }) {
  const safeWidth = Math.max(p.width, 1);
  const safeHeight = Math.max(p.height, 1);
  const scale = Math.min(p.maxWidth / safeWidth, p.maxHeight / safeHeight);
  return {
    width: safeWidth * scale,
    height: safeHeight * scale,
  };
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

function Page({ children, pageNumber, totalPages }: { children: React.ReactNode; pageNumber?: number; totalPages?: number }) {
  return (
    <div className="contract-page" style={{
      width: '210mm',
      minHeight: '297mm',
      margin: '20px auto',
      background: 'white',
      padding: '20px',
      boxSizing: 'border-box',
      pageBreakAfter: 'always'
    }}>
      <div className="contract-sheet-frame" style={{
        minHeight: 'calc(297mm - 40px)',
        border: '2px solid #000',
        padding: '15px',
        paddingBottom: '42px',
        boxSizing: 'border-box',
        position: 'relative',
        overflow: 'hidden'
      }}>
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
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(255, 255, 255, 0.5)',
          pointerEvents: 'none',
          zIndex: 0
        }} />
        <div style={{ position: 'relative', zIndex: 1 }}>
          {children}
        </div>
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

function PaymentsTable({ payments }: { payments: Payment[] }) {
  const total = getPaidTotal(payments);

  return (
    <table style={{
      width: '100%',
      borderCollapse: 'collapse',
      margin: '8px 0',
      fontSize: '13px'
    }}>
      <thead>
        <tr>
          <th style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>طريقة الدفع</th>
          <th style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>التاريخ</th>
          <th style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>رقم المرجع</th>
          <th style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>المبلغ</th>
          <th style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>البيان</th>
          <th style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>م</th>
        </tr>
      </thead>
      <tbody>
        {payments.length === 0 ? (
          <tr>
            <td colSpan={6} style={{ border: '1px solid #000', padding: '6px', textAlign: 'center', fontSize: '13px' }}>
              لا توجد دفعات مسجلة
            </td>
          </tr>
        ) : (
          payments.map((payment, index) => (
            <tr key={index}>
              <td style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>{payment.transactionType ?? ''}</td>
              <td style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>{payment.date ?? ''}</td>
              <td style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>{payment.cod ?? '541848711'}</td>
              <td style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>{money(payment.amount)}</td>
              <td style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>{payment.description ?? ''}</td>
              <td style={{ border: '1px solid #000', padding: '3px 5px', textAlign: 'center', verticalAlign: 'middle', fontSize: '13px' }}>{index + 1}</td>
            </tr>
          ))
        )}
        <tr>
          <td style={{ border: '1px solid #000', padding: '3px 5px' }}></td>
          <td style={{ border: '1px solid #000', padding: '3px 5px' }}></td>
          <td style={{ border: '1px solid #000', padding: '3px 5px' }}></td>
          <td style={{ border: '1px solid #000', padding: '3px 5px' }}></td>
          <td style={{ border: '1px solid #000', padding: '3px 5px', fontWeight: 'bold', textAlign: 'center', fontSize: '13px' }}>{money(total)}</td>
          <td style={{ border: '1px solid #000', padding: '3px 5px', fontWeight: 'bold', textAlign: 'center', fontSize: '13px' }}>الإجمالي</td>
        </tr>
      </tbody>
    </table>
  );
}

export default function ContractPrintPage({ data = defaultData, autoPrint = false, onClose }: { data?: ContractPrintData, autoPrint?: boolean, onClose?: () => void }) {
  const contract = data;
  const containerRef = React.useRef<HTMLDivElement | null>(null);
  const [isDownloadingPdf, setIsDownloadingPdf] = React.useState(false);

  const triggerPrint = React.useCallback(async () => {
    window.scrollTo(0, 0);

    const waitForImage = (src: string) =>
      new Promise<void>((resolve) => {
        const img = new window.Image();
        const done = () => resolve();
        img.onload = done;
        img.onerror = done;
        img.src = src;
        if (img.complete) {
          resolve();
        }
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

      const pageElements = Array.from(containerRef.current.querySelectorAll('.contract-sheet-frame')) as HTMLElement[];
      if (pageElements.length === 0) {
        throw new Error('لم يتم العثور على صفحات العقد');
      }

      const pdf = await PDFDocument.create();
      const skippedAttachments: string[] = [];

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

      for (const attachment of contract.attachments || []) {
        try {
          const response = await fetch(attachment.file_url);
          if (!response.ok) {
            throw new Error(`فشل تحميل ${attachment.file_name}`);
          }

          const blob = await response.blob();
          if (attachment.file_type === 'pdf') {
            const attachmentPdfBytes = await blob.arrayBuffer();
            const attachmentPdf = await PDFDocument.load(attachmentPdfBytes);
            for (const sourcePage of attachmentPdf.getPages()) {
              const embeddedPage = await pdf.embedPage(sourcePage);
              const page = pdf.addPage([PDF_PAGE_WIDTH, PDF_PAGE_HEIGHT]);
              const maxWidth = PDF_PAGE_WIDTH - (ATTACHMENT_PAGE_MARGIN * 2);
              const maxHeight = PDF_PAGE_HEIGHT - (ATTACHMENT_PAGE_MARGIN * 2);
              const contained = getContainedSize({
                width: embeddedPage.width,
                height: embeddedPage.height,
                maxWidth,
                maxHeight,
              });
              page.drawPage(embeddedPage, {
                x: (PDF_PAGE_WIDTH - contained.width) / 2,
                y: (PDF_PAGE_HEIGHT - contained.height) / 2,
                width: contained.width,
                height: contained.height,
              });
            }
            continue;
          }

          const imageBytes = await imageBlobToPngBytes(blob);
          const embeddedImage = await pdf.embedPng(imageBytes);
          const page = pdf.addPage([PDF_PAGE_WIDTH, PDF_PAGE_HEIGHT]);
          const maxWidth = PDF_PAGE_WIDTH - (ATTACHMENT_PAGE_MARGIN * 2);
          const maxHeight = PDF_PAGE_HEIGHT - (ATTACHMENT_PAGE_MARGIN * 2);
          const contained = getContainedSize({
            width: embeddedImage.width,
            height: embeddedImage.height,
            maxWidth,
            maxHeight,
          });
          page.drawImage(embeddedImage, {
            x: (PDF_PAGE_WIDTH - contained.width) / 2,
            y: (PDF_PAGE_HEIGHT - contained.height) / 2,
            width: contained.width,
            height: contained.height,
          });
        } catch (error) {
          console.error('Error appending attachment to contract PDF:', attachment.file_name, error);
          skippedAttachments.push(attachment.file_name);
        }
      }

      const pdfBytes = await pdf.save();
      const pdfBuffer = new Uint8Array(pdfBytes).buffer as ArrayBuffer;
      const blob = new Blob([pdfBuffer], { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `contract-${contract.projectNumber || 'project'}-${contract.unitNumber || 'unit'}.pdf`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
      if (skippedAttachments.length > 0) {
        alert(`تم تحميل العقد، لكن تعذر إرفاق بعض الملفات: ${skippedAttachments.join('، ')}`);
      }
    } catch (error) {
      console.error('Error downloading PDF:', error);
      alert('حدث خطأ أثناء إنشاء ملف PDF');
    } finally {
      setIsDownloadingPdf(false);
    }
  }, [contract.attachments, contract.projectNumber, contract.unitNumber]);

  React.useEffect(() => {
    if (autoPrint) {
      const timer = setTimeout(() => {
        triggerPrint();
      }, 300);
      return () => clearTimeout(timer);
    }
  }, [autoPrint, triggerPrint]);

  const agentText =
    contract.agent?.name && contract.agent?.id && contract.agent?.agencyNumber
      ? (
        <>
          ووكيلاً عنه: {contract.agent.name}
          <br />
          حامل الهوية: {contract.agent.id}
          <br />
          برقم وكالة: {contract.agent.agencyNumber}
          {contract.agent.agencyDate && (
            <>
              <br />
              تاريخ الوكالة: {contract.agent.agencyDate}
            </>
          )}
        </>
      )
      : null;

  const formatQrTimestamp = (value?: string) => {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  };

  const qrValue = [
    `${contract.unitNumber}-${contract.projectNumber}-${contract.clientId}`,
    `${contract.createdByName || ''}-${formatQrTimestamp(contract.createdAt)}`
  ].join('\n');

  return (
    <div ref={containerRef} dir="rtl" className="contract-print-container" style={{ fontFamily: "'AmiriLocal', serif", fontSize: '18px', overflow: 'visible', height: 'auto' }}>
      {onClose && (
        <div className="print-buttons-container" style={{ padding: '20px', textAlign: 'center', position: 'sticky', top: 0, background: 'white', zIndex: 1000, borderBottom: '1px solid #e5e7eb' }}>
          <button onClick={onClose} style={{
            background: '#dc2626',
            color: 'white',
            border: 'none',
            padding: '12px 28px',
            borderRadius: '8px',
            fontSize: '18px',
            cursor: 'pointer',
            marginLeft: '10px'
          }}>
            إغلاق
          </button>
          <button onClick={downloadPdf} disabled={isDownloadingPdf} style={{
            background: isDownloadingPdf ? '#9ca3af' : '#059669',
            color: 'white',
            border: 'none',
            padding: '12px 28px',
            borderRadius: '8px',
            fontSize: '18px',
            cursor: isDownloadingPdf ? 'not-allowed' : 'pointer',
            marginLeft: '10px'
          }}>
            {isDownloadingPdf ? 'جارٍ التحميل...' : 'تحميل PDF'}
          </button>
          <button onClick={triggerPrint} style={{
            background: '#0f3f7a',
            color: 'white',
            border: 'none',
            padding: '12px 28px',
            borderRadius: '8px',
            fontSize: '18px',
            cursor: 'pointer'
          }}>
            طباعة العقد
          </button>
        </div>
      )}
      {!onClose && (
        <div className="print-buttons-container" style={{ padding: '20px', textAlign: 'center' }}>
          <button onClick={downloadPdf} disabled={isDownloadingPdf} style={{
            background: isDownloadingPdf ? '#9ca3af' : '#059669',
            color: 'white',
            border: 'none',
            padding: '12px 30px',
            borderRadius: '999px',
            fontSize: '18px',
            cursor: isDownloadingPdf ? 'not-allowed' : 'pointer',
            marginLeft: '10px'
          }}>
            {isDownloadingPdf ? 'جارٍ التحميل...' : 'تحميل PDF'}
          </button>
          <button onClick={triggerPrint} style={{
            background: '#0f3f7a',
            color: 'white',
            border: 'none',
            padding: '12px 30px',
            borderRadius: '999px',
            fontSize: '18px',
            cursor: 'pointer'
          }}>
            طباعة العقد
          </button>
        </div>
      )}

      {/* الصفحة الأولى */}
      <Page pageNumber={1} totalPages={5}>
        <Header />
        <h1 style={{
          textAlign: 'center',
          color: '#0086bf',
          fontSize: '28px',
          fontWeight: 'bold',
          marginTop: '25px'
        }}>
          عقد بيع شقة - مشروع رقم: ({contract.projectNumber})
        </h1>
        <div style={{ textAlign: 'center', marginTop: '30px' }}>
          <h2 style={{ fontSize: '20px', fontWeight: 'bold' }}>بسم الله الرحمن الرحيم</h2>
          <h2 style={{ fontSize: '20px', fontWeight: 'bold', marginTop: '15px' }}>الحمد لله والصلاة والسلام على رسول الله</h2>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '25px' }}>
          <span style={{ fontSize: '18px', color: '#0086bf' }}>تاريخ العقد : {contract.gregorianDate} م</span>
          <span style={{ fontSize: '18px', color: '#0086bf' }}>الموافق : {contract.hijriDate}</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '25px' }}>
          <span style={{ fontSize: '20px', fontWeight: 'bold' }}>الطرف الأول: شركة مساكن الرفاهية للتطوير العقاري</span>
          <span style={{ fontSize: '18px' }}>رقم الجوال: 920007936</span>
        </div>
        <p style={{ fontSize: '24px', fontWeight: 'bold', marginTop: '15px' }}>س.ت: 7027279632</p>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '20px', gap: '20px', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '18px', fontWeight: 'bold', color: '#0086bf' }}> اسم المدينة : {contract.city}</span>
          <span style={{ fontSize: '18px', fontWeight: 'bold', color: '#0086bf' }}> الحي: {contract.district}</span>
          <span style={{ fontSize: '18px', fontWeight: 'bold', color: '#0086bf' }}> اسم المخطط: {contract.planNumber}</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '20px', gap: '20px', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '18px', fontWeight: 'bold' }}> رقم الصك: {contract.deedNumber}</span>
          <span style={{ fontSize: '18px', fontWeight: 'bold' }}> رقم القطعة: {contract.regionNumber}</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '30px', gap: '20px', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '18px', fontWeight: 'bold' }}> الطرف الثاني : {contract.clientName}</span>
          <span style={{ fontSize: '18px', fontWeight: 'bold' }}> رقم الهوية: {contract.clientId}</span>
        </div>
        <p style={{ fontSize: '18px', fontWeight: 'bold', marginTop: '15px' }}>
          رقم الجوال: {contract.clientPhone}
        </p>
        <p style={{
          fontSize: '19px',
          fontWeight: 'bold',
          color: '#0086bf',
          marginTop: '25px',
          lineHeight: 2.5
        }}>
          لقد باع الطرف الأول شقة معلومة المواصفات والمقاييس مساحتها ({contract.area}) متر مربع تقريباً سطح مع مباني واشترى الطرف الثاني
        </p>
        <p style={{ fontSize: '19px', marginTop: '20px' }}>
          وحرر بينهما هذا العقد على نسختين:
        </p>
        
        {/* رمز QR بسيط في يمين الصفحة */}
        <div style={{ 
          marginTop: '30px', 
          display: 'flex', 
          justifyContent: 'flex-end',
          alignItems: 'center'
        }}>
          <QRCodeSVG value={qrValue} size={80} />
        </div>
      </Page>

      {/* الصفحة الثانية */}
      <Page pageNumber={2} totalPages={5}>
        <Header />
        <h2 style={{ fontSize: '20px', marginTop: '9px', fontWeight: 'bold' }}>القسم الأول: شروط العقد:</h2>
        <p style={{ color: '#0086bf', fontSize: '18px', lineHeight: 2.2, marginTop: '6px' }}>
          1- تملك الطرف الثاني شقة رقم {contract.unitNumber} في الدور رقم {contract.floor}
        </p>
        <p style={{ color: '#0086bf', fontSize: '18px', lineHeight: 2.2 }}>
          2- وهي الموقع {contract.direction} بمبلغ وقدره {contract.totalAmount} ريال سعودى من القطعة رقم {contract.regionNumber}
        </p>
        <p style={{ color: '#0086bf', fontSize: '18px', lineHeight: 2.2 }}>
          شروط الدفع
          <br />
          {getPaymentStatusDescription(contract)}
        </p>
        <PaymentsTable payments={contract.payments} />
        <p style={{ color: '#0086bf', fontSize: '16px' }}>
          رقم الدور: {contract.floor} &nbsp;&nbsp;
          رقم الشقة: {contract.unitNumber} &nbsp;&nbsp;
          الوصف: {contract.description}
        </p>
        <p style={{ fontSize: '15px', marginTop: '8px', lineHeight: 2 }}>
          3- تخليص كل ما تطلبه الأوراق الرسمية والحكومية عن طريق شركة مساكن الرفاهية.
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          4- لا يحق للطرفين فسخ العقد بعد التوقيع
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          5- يتحمل الطرف الثاني رسوم المياه التي تفرضها الدولة
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          6- لا يحق للطرف الثاني المطالبة بالمبلغ بعد توقيع العقد.
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          7- بناء المشروع حسب ما هو موجود في المخطط الكروكي المرفق والمختوم من الشركة ولا تتحمل الشركة أى تعديل في قيشاني الجدران والأرضيات للشقق أو أى تعديل أخر.
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          8- سعر الشقة لا يشمل الضريبة
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          9- مدة تنفيذ المشروع وتسليمه ({contract.deliveryMonths}) شهراً من تاريخ توقيع العقد، باستثناء شهر رمضان. ومع ذلك، إذا حدث تأخير ناتج عن ظروف قاهرة خارجة عن سيطرة الشركة، مثل الكوارث الطبيعية (كالزلازل، الفيضانات، الأعاصير، وغيرها)، أو نتيجة قرارات أو إجراءات صادرة عن الجهات الحكومية أو الرسمية تؤثر على سير العمل، فإنه يتم تمديد مدة المشروع بما يعادل فترة التأخير دون أن تتحمل الشركة أى مسؤولية أو غرامات نتيجة لذلك.
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          10- يتحمل الطرف الثاني أى رسوم وضرائب حكومية تفرضها الدولة بعد إطلاق التيار الكهربائي ورسوم المياه التي تفرضها الدولة
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          11- الشركة لا تتحمل أى تعديل أو إضافات في الشقة وفي حالة التعديل يكون التعديل قبل العمل وفي حال بدأ العمل لن يتم أى تعديل نهائياً
        </p>
        <p style={{ fontSize: '16px', lineHeight: 1.5 }}>
          12- شرط جزائي في حال التأخير عن التسليم أكثر من ({contract.deliveryMonths}) شهر من تاريخ توقيع العقد عن كل شهر تأخير 1500 الف ريال فقط لا غير ويأخذ البند رقم 9 بعين الاعتبار.
        </p>
      </Page>

      {/* الصفحة الثالثة */}
      <Page pageNumber={3} totalPages={5}>
        <Header />
        <h2 style={{ fontSize: '22px', marginTop: '20px', fontWeight: 'bold' }}>القسم الثاني: مواصفات البناء:</h2>
        <h3 style={{ fontSize: '20px', fontWeight: 'bold', marginTop: '15px' }}>مرحلة البناء والعظم:</h3>
        <p style={{ fontSize: '18px', marginTop: '5px', lineHeight: 2 }}>1- عمل لبشة أو قواعد حسب ما يقرره المكتب الهندسي.</p>
        <p style={{ fontSize: '18px', marginTop: '5px', lineHeight: 2 }}>2- استخدام السمنت المقاوم للقواعد والميدات والرقاب وخزان المياه والبيارة.</p>
        <p style={{ fontSize: '18px', marginTop: '5px', lineHeight: 2 }}>3- عزل القواعد والحمامات وخزان المياه والسطح بعازل مائي بيوت مات 4 ملم.</p>
        <p style={{ fontSize: '18px', marginTop: '5px', lineHeight: 2 }}>4- المباني الداخلية بلوك أحمر، والخارجية بلوك أحمر معزول مقاس 20×40×20.</p>
        <h3 style={{ fontSize: '20px', fontWeight: 'bold', marginTop: '15px' }}>مرحلة التشطيب:</h3>
        <h4 style={{ fontSize: '19px', fontWeight: 'bold', marginTop: '12px' }}>أولاً: الأعمال المعمارية:</h4>
        <p style={{ fontSize: '18px', marginTop: '15px', lineHeight: 2 }}>1- الواجهة الرئيسية حسب ما تراه الشركة مواكب للتطور العمراني.</p>
        <p style={{ fontSize: '18px', marginTop: '5px', lineHeight: 2 }}>2- التشطيبات ليآسة إسمنتية ببطحة الشعيبة + الرياض.</p>
        <p style={{ fontSize: '18px', marginTop: '5px', lineHeight: 2 }}>3- الأرضيات الحواش والسطح مزايكو المتر 12 ريال داخل الشقة سيراميك المتر 18 ريال.</p>
        <p style={{ fontSize: '18px', marginTop: '5px', lineHeight: 2 }}>4- الجدران قيشاني المتر 13 ريال.</p>
        <h4 style={{ fontSize: '19px', fontWeight: 'bold', marginTop: '12px' }}>ثانياً: الأعمال الكهربائية:</h4>
        <p style={{ fontSize: '18px', marginTop: '10px', lineHeight: 2 }}>1- الكابلات من الشركة السعودية 35 ملم، 50 ملم.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>2- تركيب طبلون لكل شقة.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>3- تركيب قاطع كهرباء إلترا.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>4- اللمبات في الغرف كبس عادي.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>5-افياش نوع ألفا.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>6-افياش التلفون نوع ألفا.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>7-افياش التلفزيون نوع ألفا.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>8- تأسيس مراوح شفط مقاس 25*25.rest.</p>
        <p style={{ fontSize: '18px', lineHeight: 1.7 }}>9- لكل شقة عداد مستقل.</p>
      </Page>

      {/* الصفحة الرابعة */}
      <Page pageNumber={4} totalPages={5}>
        <Header />
        <h4 style={{ fontSize: '19px', fontWeight: 'bold', marginTop: '7px' }}>ثالثاً: الأعمال الصحية:</h4>
        <p style={{ fontSize: '18px', marginTop: '7px', lineHeight: 2 }}>1- أطقم الحمامات والمغاسل 500 ريال للطقم الواحد.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>2- الخلاط للكراسي 200 ريال.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>3- تمديدات للسخانات.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>4- مواسير للصرف الصحي 4 بوصة سماكة 7 مم خليجي.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>5- مواسير المياه 2 بوصة و¾ بوصة ضغط 80 حار خليجي.</p>
        <p style={{ fontSize: '16px', lineHeight: 2 }}>6- محابس الدفن المائي.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>7- الليات والشطافات إريال ستاندر المائي.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>8- محابس الزاوية المائي.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>9- صفايات ومهرب المغاسل إيطالي.</p>
        <h4 style={{ fontSize: '20px', fontWeight: 'bold', marginTop: '12px' }}>رابعاً: أعمال الجبس:</h4>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>1- نظام ساقط كامل.</p>
        <h4 style={{ fontSize: '19px', fontWeight: 'bold', marginTop: '12px' }}>خامساً: أعمال الدهان:</h4>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>نوع جوتن والجزيرة سادة.</p>
        <h4 style={{ fontSize: '19px', fontWeight: 'bold', marginTop: '12px' }}>سادساً: الأعمال الخشبية:</h4>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>1- باب الشقة الرئيسي خشب مقنو درجة أولى مع دهان الستار والكيلون والمقبض.</p>
        <p style={{ fontSize: '18px', lineHeight: 2 }}>2- الأبواب الداخلية من قشر السنديان والكيلون والمقبض 50 ريال.</p>
      </Page>

      {/* الصفحة الخامسة */}
  <Page pageNumber={5} totalPages={5}>
  <Header />

  <div
    style={{
      padding: '14px 22px 0 22px',
      color: '#111827',
    }}
  >
    {/* عنوان رسمي هادئ */}
    <div
      style={{
        textAlign: 'center',
        marginTop: '18px',
        marginBottom: '26px',
      }}
    >
      

      <div
        style={{
          width: '180px',
          height: '0.2px',
          background: '#0086bf',
          margin: '1px auto 0 auto',
        }}
      />
    </div>

    {/* أعمال الألمنيوم */}
    <div style={{ marginTop: '20px' }}>
      <h4
        style={{
          fontSize: '20px',
          fontWeight: 'bold',
          margin: '0 0 8px 0',
          color: '#0086bf',
        }}
      >
        سابعاً: أعمال الألمنيوم:
      </h4>

      <p
        style={{
          fontSize: '17px',
          margin: '0 0 4px 0',
          lineHeight: 2,
          fontWeight: 'bold',
        }}
      >
        1- لون حليبي أو أسود أو أبيض النوع البكو خليجي.
      </p>

      <p
        style={{
          fontSize: '17px',
          margin: 0,
          lineHeight: 2,
          fontWeight: 'bold',
        }}
      >
        2- الزجاج دبل جلاس الخط أبيض مانع للحرارة والصوت.
      </p>
    </div>

    {/* فاصل بسيط */}
    <div
      style={{
        height: '1px',
        background: '#d1d5db',
        margin: '22px 0 18px 0',
      }}
    />

    {/* الملاحظات */}
    <div>
      <h4
        style={{
          fontSize: '20px',
          fontWeight: 'bold',
          margin: '0 0 8px 0',
          color: '#0086bf',
        }}
      >
        ملاحظات:
      </h4>

      <p
        style={{
          fontSize: '17px',
          margin: '0 0 6px 0',
          lineHeight: 2,
          fontWeight: 'bold',
        }}
      >
        دولاب المطبخ والسخانات وشبك الحديد للشبابيك ليست ضمن قيمة العقد.
      </p>

      <p
        style={{
          fontSize: '17px',
          margin: 0,
          lineHeight: 2,
          fontWeight: 'bold',
        }}
      >
        • إبراء للذمة في حال عدم توفر نوع من إحدى مواصفات البناء الموضحة في العقد
        بالسوق يتم تغييرها بما يعادلها من الجودة.
      </p>
    </div>

    {/* نص الإقرار */}
    <div
      style={{
        marginTop: '28px',
        textAlign: 'justify',
      }}
    >
      <p
        style={{
          margin: 0,
          fontSize: '18px',
          lineHeight: 2.25,
          fontWeight: 'bold',
          color: '#111827',
        }}
      >
        وبناءً على ما تقدم، فقد تم تحرير هذا العقد من نسختين أصليتين، بيد كل طرف
        نسخة للعمل بموجبها عند اللزوم، ويعد توقيع الطرفين أدناه إقراراً صريحاً
        بقبول جميع البنود والشروط والمواصفات الواردة في هذا العقد.
      </p>
    </div>

    {/* اعتماد الأطراف */}
    <div
      style={{
        marginTop: '34px',
        textAlign: 'center',
      }}
    >
      <h3
        style={{
          margin: 0,
          fontSize: '22px',
          fontWeight: 'bold',
          color: '#0086bf',
        }}
      >
        توقيع الأطراف
      </h3>

      <div
        style={{
          width: '120px',
          height: '1px',
          background: '#111827',
          margin: '8px auto 0 auto',
        }}
      />
    </div>

    {/* التواقيع بدون جداول ولا بطاقات */}
    <div
      style={{
        marginTop: '38px',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        gap: '70px',
      }}
    >
      {/* الطرف الأول */}
      <div
        style={{
          flex: 1,
          textAlign: 'center',
        }}
      >
        <p
          style={{
            margin: 0,
            fontSize: '18px',
            fontWeight: 'bold',
            color: '#0086bf',
            lineHeight: 2,
          }}
        >
          الطرف الأول
        </p>

        <p
          style={{
            margin: '8px 0 0 0',
            fontSize: '20px',
            fontWeight: 'bold',
            color: '#111827',
            lineHeight: 2,
          }}
        >
          شركة مساكن الرفاهية
        </p>

        <div
          style={{
            height: '64px',
          }}
        />

        <div
          style={{
            width: '190px',
            height: '1px',
            background: '#111827',
            margin: '0 auto',
          }}
        />

        <p
          style={{
            margin: '8px 0 0 0',
            fontSize: '16px',
            fontWeight: 'bold',
            color: '#374151',
          }}
        >
          التوقيع / الختم
        </p>
      </div>

      {/* الطرف الثاني */}
      <div
        style={{
          flex: 1,
          textAlign: 'center',
        }}
      >
        <p
          style={{
            margin: 0,
            fontSize: '18px',
            fontWeight: 'bold',
            color: '#0086bf',
            lineHeight: 2,
          }}
        >
          الطرف الثاني
        </p>

        <p
          style={{
            margin: '8px 0 0 0',
            fontSize: '20px',
            fontWeight: 'bold',
            color: '#111827',
            lineHeight: 2,
          }}
        >
          {contract.clientName}
        </p>

        {agentText && (
          <div
            style={{
              marginTop: '6px',
              fontSize: '15px',
              fontWeight: 'bold',
              color: '#0086bf',
              lineHeight: 1.9,
            }}
          >
            {agentText}
          </div>
        )}

        <div
          style={{
            height: agentText ? '34px' : '64px',
          }}
        />

        <div
          style={{
            width: '190px',
            height: '1px',
            background: '#111827',
            margin: '0 auto',
          }}
        />

        <p
          style={{
            margin: '8px 0 0 0',
            fontSize: '16px',
            fontWeight: 'bold',
            color: '#374151',
          }}
        >
          التوقيع
        </p>
      </div>
    </div>

    {/* تذييل رسمي بسيط */}
    <div
      style={{
        marginTop: '46px',
        borderTop: '1px solid #9ca3af',
        paddingTop: '10px',
        display: 'flex',
        justifyContent: 'space-between',
        fontSize: '13px',
        fontWeight: 'bold',
        color: '#4b5563',
      }}
    >
      <span>شركة مساكن الرفاهية للتطوير العقاري</span>
      <span>نسخة معتمدة بعد التوقيع</span>
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

        @media print {
          /* نخفي كل شيء في الصفحة الأصلية */
          body * {
            visibility: hidden !important;
          }
          
          /* نضبط المودال */
          body .contract-print-modal,
          body .contract-print-modal * {
            visibility: visible !important;
          }
          
          body .contract-print-modal {
            position: absolute !important;
            top: 0 !important;
            left: 0 !important;
            right: 0 !important;
            width: 100% !important;
            margin: 0 !important;
            padding: 0 !important;
            background: white !important;
            z-index: 99999 !important;
            overflow: visible !important;
          }
          
          /* إلا المكون للطباعة ومحتواه */
          body .contract-print-container,
          body .contract-print-container * {
            visibility: visible !important;
          }
          
          /* نضبط الموقع للطباعة */
          body .contract-print-container {
            position: relative !important;
            margin: 0 !important;
            padding: 0 !important;
          }

          html,
          body {
            background: white;
            margin: 0;
            padding: 0;
            overflow: visible !important;
            height: auto !important;
          }

          /* فقط نخفي أزرار الطباعة والإغلاق في أعلى الصفحة */
          .print-buttons-container {
            display: none !important;
          }

          /* إعدادات الصفحة للطباعة */
          @page {
            size: A4;
            margin: 0;
          }

          /* تصميم صفحة العقد للطباعة */
          .contract-page {
            margin: 0 !important;
            padding: 20px !important;
            width: 210mm !important;
            height: 297mm !important;
            box-shadow: none !important;
            page-break-after: always !important;
            page-break-inside: avoid !important;
            position: relative !important;
            top: 0 !important;
            left: 0 !important;
          }
        }
      `}</style>
    </div>
  );
}
