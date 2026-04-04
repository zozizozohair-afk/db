import React, { useState } from 'react';
import { 
  X, 
  Printer, 
  CheckSquare, 
  Square,
  Layout,
  LayoutGrid
} from 'lucide-react';
import { EnrichedUnit } from './DeedsTable';

interface ReportPrintModalProps {
  isOpen: boolean;
  onClose: () => void;
  units: EnrichedUnit[];
  filterProject?: string;
  filterStatus?: string;
}

interface FieldOption {
  id: string;
  label: string;
  defaultChecked: boolean;
}

const PRINT_FIELD_OPTIONS: FieldOption[] = [
  { id: 'unit_number', label: 'رقم الوحدة', defaultChecked: true },
  { id: 'project_name', label: 'المشروع', defaultChecked: true },
  { id: 'floor', label: 'الدور', defaultChecked: true },
  { id: 'original_client', label: 'العميل الأصلي', defaultChecked: true },
  { id: 'client_phone', label: 'جوال العميل', defaultChecked: true },
  { id: 'current_client', label: 'المالك الحالي', defaultChecked: true },
  { id: 'owner_phone', label: 'جوال المالك', defaultChecked: false },
  { id: 'deed_number', label: 'رقم الصك', defaultChecked: true },
  { id: 'resale_amount', label: 'مبلغ إعادة البيع', defaultChecked: false },
  { id: 'status', label: 'الحالة', defaultChecked: true },
];

export default function ReportPrintModal({ isOpen, onClose, units, filterProject, filterStatus }: ReportPrintModalProps) {
  const [selectedFields, setSelectedFields] = useState<Record<string, boolean>>(
    PRINT_FIELD_OPTIONS.reduce((acc, field) => ({ ...acc, [field.id]: field.defaultChecked }), {})
  );
  const [groupByProject, setGroupByProject] = useState(true);

  if (!isOpen) return null;

  const toggleField = (fieldId: string) => {
    setSelectedFields(prev => ({
      ...prev,
      [fieldId]: !prev[fieldId]
    }));
  };

  const handlePrint = () => {
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    const activeFields = PRINT_FIELD_OPTIONS.filter(f => selectedFields[f.id]);
    
    let tableBodyHtml = '';

    if (groupByProject) {
      // Group units by project
      const groupedProjects: Record<string, EnrichedUnit[]> = {};
      units.forEach(unit => {
        const projectName = unit.project_name;
        if (!groupedProjects[projectName]) groupedProjects[projectName] = [];
        groupedProjects[projectName].push(unit);
      });

      Object.entries(groupedProjects).forEach(([projectName, projectUnits]) => {
        // Add project header row
        tableBodyHtml += `
          <tr class="project-group-header">
            <td colspan="${activeFields.length}">
              <div class="project-title-row">
                🏢 مشروع: ${projectName} (${projectUnits[0].project_number})
                <span class="unit-count-badge">${projectUnits.length} وحدة</span>
              </div>
            </td>
          </tr>
        `;
        
        // Add project units
        tableBodyHtml += projectUnits.map(unit => generateRowHtml(unit, activeFields)).join('');
      });
    } else {
      tableBodyHtml = units.map(unit => generateRowHtml(unit, activeFields)).join('');
    }

    const html = `
      <html dir="rtl" lang="ar">
        <head>
          <title>تقرير مراجعة الصكوك - ${new Date().toLocaleDateString('ar-SA')}</title>
          <style>
            @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800&display=swap');
            @page {
              size: A4 landscape;
              margin: 10mm;
            }
            body { 
              font-family: 'Cairo', sans-serif; 
              padding: 0; 
              margin: 0;
              color: #1f2937; 
              line-height: 1.5;
              background-color: #fff;
            }
            .document-container {
              padding: 10px;
              position: relative;
            }
            /* Decorative Top Border */
            .top-accent {
              height: 6px;
              background: linear-gradient(90deg, #0c4a6e 0%, #075985 50%, #0c4a6e 100%);
              margin-bottom: 20px;
              border-radius: 3px;
            }
            .header-main {
              display: grid;
              grid-template-columns: 1fr 1.5fr 1fr;
              align-items: center;
              padding: 20px;
              background: #f8fafc;
              border: 1px solid #e2e8f0;
              border-radius: 15px;
              margin-bottom: 25px;
              position: relative;
              overflow: hidden;
            }
            .header-main::after {
              content: '';
              position: absolute;
              top: 0;
              right: 0;
              width: 150px;
              height: 150px;
              background: radial-gradient(circle, rgba(12,74,110,0.03) 0%, transparent 70%);
              pointer-events: none;
            }
            .company-brand {
              text-align: right;
            }
            .brand-name {
              font-weight: 800;
              font-size: 22px;
              color: #0c4a6e;
              letter-spacing: -0.5px;
              margin: 0;
            }
            .brand-sub {
              font-size: 11px;
              color: #64748b;
              font-weight: 600;
              text-transform: uppercase;
              letter-spacing: 1px;
            }
            .report-title-box {
              text-align: center;
              border-right: 1px solid #e2e8f0;
              border-left: 1px solid #e2e8f0;
              padding: 0 20px;
            }
            .report-title {
              font-weight: 800;
              font-size: 26px;
              color: #0c4a6e;
              margin: 0;
              text-shadow: 0 1px 2px rgba(0,0,0,0.05);
            }
            .report-subtitle {
              font-size: 13px;
              color: #92400e;
              font-weight: 700;
              margin-top: 4px;
            }
            .meta-info {
              text-align: left;
              font-size: 12px;
              color: #475569;
            }
            .meta-item {
              margin-bottom: 4px;
            }
            .meta-item b { color: #0c4a6e; }

            .summary-bar {
              display: flex;
              gap: 15px;
              margin-bottom: 20px;
              padding: 0 10px;
            }
            .summary-card {
              flex: 1;
              background: white;
              border: 1px solid #e2e8f0;
              padding: 12px;
              border-radius: 10px;
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
            }
            .card-label { font-size: 10px; color: #64748b; font-weight: 700; text-transform: uppercase; margin-bottom: 3px; }
            .card-value { font-size: 14px; color: #0c4a6e; font-weight: 800; }

            table { 
              width: 100%; 
              border-collapse: separate; 
              border-spacing: 0;
              margin-top: 10px;
              border-radius: 10px;
              overflow: hidden;
              border: 1px solid #e2e8f0;
            }
            th { 
              background-color: #0c4a6e; 
              color: white; 
              font-weight: 700;
              font-size: 13px;
              padding: 15px 8px;
              text-align: center;
              border-bottom: 2px solid #075985;
            }
            td { 
              padding: 12px 8px; 
              text-align: center; 
              font-size: 12px; 
              border-bottom: 1px solid #f1f5f9;
              color: #334155;
              font-weight: 500;
            }
            tr:nth-child(even) { background-color: #f8fafc; }
            tr:last-child td { border-bottom: none; }
            
            .project-group-header td {
              background-color: #f1f5f9;
              text-align: right;
              padding: 12px 20px;
              border-bottom: 2px solid #e2e8f0;
            }
            .project-title-row {
              display: flex;
              justify-content: space-between;
              align-items: center;
              color: #0c4a6e;
              font-weight: 800;
              font-size: 14px;
            }
            .unit-count-badge {
              background: #0c4a6e;
              color: white;
              padding: 2px 10px;
              border-radius: 20px;
              font-size: 11px;
            }

            .status-tag {
              padding: 4px 10px;
              border-radius: 6px;
              font-size: 10px;
              font-weight: 700;
              background: #f1f5f9;
              border: 1px solid #e2e8f0;
            }

            .footer-legal {
              margin-top: 30px;
              padding: 20px;
              border-top: 2px solid #f1f5f9;
              display: flex;
              justify-content: space-between;
              align-items: center;
              font-size: 10px;
              color: #94a3b8;
              font-weight: 600;
            }
            .page-counter::after { content: "صفحة " counter(page); }

            @media print {
              body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
              .header-main { background-color: #f8fafc !important; border: 1px solid #e2e8f0 !important; }
              th { background-color: #0c4a6e !important; color: white !important; }
              .top-accent { background: #0c4a6e !important; }
              .project-group-header td { background-color: #f1f5f9 !important; }
              .unit-count-badge { background-color: #0c4a6e !important; color: white !important; }
            }
          </style>
        </head>
        <body>
          <div class="document-container">
            <div class="top-accent"></div>
            
            <div class="header-main">
              <div class="company-brand">
                <h2 class="brand-name">مساكن الرفاهية</h2>
                <span class="brand-sub">للتطوير العقاري | LUXURY HOUSING</span>
              </div>
              
              <div class="report-title-box">
                <h1 class="report-title">تقرير مراجعة الصكوك</h1>
                <div class="report-subtitle">كشف تفصيلي لحالة الوحدات العقارية</div>
              </div>
              
              <div class="meta-info">
                <div class="meta-item"><b>تاريخ التقرير:</b> ${new Date().toLocaleDateString('ar-SA')}</div>
                <div class="meta-item"><b>وقت الإصدار:</b> ${new Date().toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' })}</div>
                <div class="meta-item"><b>المرجع:</b> DEEDS-${Math.random().toString(36).substr(2, 6).toUpperCase()}</div>
              </div>
            </div>

            <div class="summary-bar">
              <div class="summary-card">
                <span class="card-label">المشروع المستهدف</span>
                <span class="card-value">${filterProject || 'كافة المشاريع'}</span>
              </div>
              <div class="summary-card">
                <span class="card-label">حالة الفلترة</span>
                <span class="card-value">${filterStatus || 'عرض شامل'}</span>
              </div>
              <div class="summary-card">
                <span class="card-label">إجمالي الوحدات</span>
                <span class="card-value">${units.length} وحدة</span>
              </div>
            </div>

            <table>
              <thead>
                <tr>
                  ${activeFields.map(f => `<th>${f.label}</th>`).join('')}
                </tr>
              </thead>
              <tbody>
                ${tableBodyHtml}
              </tbody>
            </table>

            <div class="footer-legal">
              <div>© شركة مساكن الرفاهية للتطوير العقاري - تقرير رسمي معتمد</div>
              <div class="page-counter"></div>
              <div>نظام الإدارة العقاري الذكي</div>
            </div>
          </div>

          <script>
            window.onload = () => {
              window.print();
              setTimeout(() => window.close(), 1000);
            };
          </script>
        </body>
      </html>
    `;

    printWindow.document.write(html);
    printWindow.document.close();
    onClose();
  };

  const generateRowHtml = (unit: EnrichedUnit, activeFields: FieldOption[]) => {
    return `
      <tr>
        ${selectedFields.unit_number ? `<td>${unit.unit_number}</td>` : ''}
        ${selectedFields.project_name ? `<td><div style="font-weight:700; color:#0c4a6e;">${unit.project_name}</div><div style="font-size:10px; color:#64748b;">${unit.project_number}</div></td>` : ''}
        ${selectedFields.floor ? `<td>${unit.floor_label || unit.floor_number || '-'}</td>` : ''}
        ${selectedFields.original_client ? `<td>${unit.client_name || '-'}</td>` : ''}
        ${selectedFields.client_phone ? `<td dir="ltr" style="font-family:monospace; font-weight:700;">${unit.client_phone || '-'}</td>` : ''}
        ${selectedFields.current_client ? `<td>${unit.title_deed_owner || '-'}</td>` : ''}
        ${selectedFields.owner_phone ? `<td dir="ltr" style="font-family:monospace; font-weight:700;">${unit.title_deed_owner_phone || '-'}</td>` : ''}
        ${selectedFields.deed_number ? `<td style="font-family:monospace; font-weight:700; color:#0c4a6e;">${unit.deed_number || '-'}</td>` : ''}
        ${selectedFields.resale_amount ? `<td style="font-weight:700; color:#92400e;">${unit.resale_agreed_amount ? unit.resale_agreed_amount.toLocaleString('ar-SA') + ' ريال' : '-'}</td>` : ''}
        ${selectedFields.status ? `<td><span class="status-tag">${unit.status}</span></td>` : ''}
      </tr>
    `;
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md max-h-[90vh] flex flex-col animate-in fade-in zoom-in duration-200">
        <div className="p-4 border-b border-gray-100 flex items-center justify-between bg-gray-50 rounded-t-2xl">
          <h3 className="font-display font-bold text-lg text-gray-900 flex items-center gap-2">
            <Printer size={20} className="text-blue-600" />
            تخصيص طباعة الكشف
          </h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-200 rounded-lg transition-colors">
            <X size={20} className="text-gray-500" />
          </button>
        </div>

        <div className="p-6 space-y-4 overflow-y-auto">
          {/* Grouping Option */}
          <div className="mb-6 p-4 bg-blue-50/50 rounded-2xl border border-blue-100">
            <label className="flex items-center justify-between cursor-pointer">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-blue-100 rounded-lg text-blue-600">
                  <LayoutGrid size={18} />
                </div>
                <div>
                  <p className="font-bold text-sm text-gray-900">ترتيب وفصل بحسب المشروع</p>
                  <p className="text-xs text-gray-500">سيتم تجميع الوحدات تحت اسم كل مشروع</p>
                </div>
              </div>
              <button
                onClick={() => setGroupByProject(!groupByProject)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${groupByProject ? 'bg-blue-600' : 'bg-gray-200'}`}
              >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${groupByProject ? 'translate-x-6' : 'translate-x-1'}`} />
              </button>
            </label>
          </div>

          <div className="flex items-center gap-3 mb-4 p-3 bg-blue-50 rounded-xl text-blue-700">
            <Layout size={20} />
            <p className="text-sm font-bold">اختر الأعمدة المراد إظهارها في الكشف:</p>
          </div>
          
          <div className="grid grid-cols-2 gap-2">
            {PRINT_FIELD_OPTIONS.map((field) => (
              <button
                key={field.id}
                onClick={() => toggleField(field.id)}
                className={`flex items-center justify-between p-3 rounded-xl border transition-all ${
                  selectedFields[field.id] 
                    ? 'border-blue-200 bg-blue-50 text-blue-700' 
                    : 'border-gray-100 bg-white text-gray-600 hover:border-gray-200'
                }`}
              >
                <span className="font-bold text-xs">{field.label}</span>
                {selectedFields[field.id] ? (
                  <CheckSquare size={16} className="text-blue-600" />
                ) : (
                  <Square size={16} className="text-gray-300" />
                )}
              </button>
            ))}
          </div>

          <div className="pt-6 border-t border-gray-100 mt-6">
            <button
              onClick={handlePrint}
              disabled={Object.values(selectedFields).every(v => !v)}
              className="w-full flex items-center justify-center gap-2 py-3 bg-gray-900 text-white rounded-xl font-bold hover:bg-gray-800 transition-all shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Printer size={20} />
              بدء الطباعة الآن
            </button>
            <p className="text-center text-[10px] text-gray-400 mt-3">
              * سيتم فتح نافذة الطباعة في لسان جديد بتنسيق عرضي (Landscape)
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
