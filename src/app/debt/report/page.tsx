 'use client';
 
 import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { FileText, Search, Copy, Check, FileSpreadsheet, Printer } from 'lucide-react';
import * as XLSX from 'xlsx';
 
 type Debt = {
  id: string;
  created_at: string;
  unit_id: string;
  project_id: string;
  project_number: string;
  project_name: string;
  unit_number: number;
  deed_number: string | null;
  original_client_name: string | null;
  original_client_phone: string | null;
  original_client_id: string | null;
  current_owner_name: string | null;
  current_owner_phone: string | null;
  contract_value: number | null;
  paid_value: number | null;
  remaining_value: number | null;
  saved_at: string;
};

type Project = {
  id: string;
  name: string;
  project_number: string;
};

export default function DebtReportPage() {
  const [rows, setRows] = useState<Debt[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [filterProject, setFilterProject] = useState<string>('all');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    load();
  }, []);

  const load = async () => {
    try {
      setLoading(true);
      setErrorText(null);
      const [debtsResult, projectsResult] = await Promise.all([
        supabase
          .from('debts')
          .select('*')
          .order('saved_at', { ascending: false }),
        supabase
          .from('projects')
          .select('id, name, project_number')
          .order('created_at', { ascending: false })
      ]);
      
      if (debtsResult.error) throw debtsResult.error;
      if (projectsResult.error) throw projectsResult.error;
      
      setRows(debtsResult.data || []);
      setProjects(projectsResult.data || []);
    } catch (e: any) {
      setErrorText(e?.message || 'تعذر تحميل تقرير المديونية');
    } finally {
      setLoading(false);
    }
  };

  const filtered = useMemo(() => {
    let result = rows;
    
    if (filterProject !== 'all') {
      result = result.filter(r => r.project_id === filterProject);
    }
    
    const term = q.trim();
    if (term) {
      result = result.filter((r) => {
        const code = `${r.project_number}-${r.unit_number}`;
        return (
          code.includes(term) ||
          (r.project_name && r.project_name.includes(term)) ||
          (r.original_client_name && r.original_client_name.includes(term)) ||
          (r.current_owner_name && r.current_owner_name.includes(term)) ||
          (r.original_client_phone && r.original_client_phone.includes(term)) ||
          (r.current_owner_phone && r.current_owner_phone.includes(term)) ||
          (r.deed_number && r.deed_number.includes(term))
        );
      });
    }
    
    return result;
  }, [rows, q, filterProject]);
 
   const totals = useMemo(() => {
     let contract = 0;
     let paid = 0;
     let remaining = 0;
     for (const r of filtered) {
       contract += r.contract_value || 0;
       paid += r.paid_value || 0;
       remaining += r.remaining_value || 0;
     }
     return { contract, paid, remaining };
   }, [filtered]);
 
   const copySummary = () => {
    const lines: string[] = [];
    lines.push('تقرير المديونية:');
    lines.push('');
    for (const r of filtered) {
      const code = `${r.project_number}-${r.unit_number}`;
      lines.push(
        [
          `الوحدة ${code}`,
          `العميل: ${r.original_client_name || '-'}`,
          `قيمة العقد: ${r.contract_value ?? '-'}`,
          `المدفوع: ${r.paid_value ?? '-'}`,
          `المتبقي: ${r.remaining_value ?? '-'}`
        ].join(' | ')
      );
    }
    lines.push('');
    lines.push(
      `الإجمالي — قيمة العقود: ${totals.contract} | المدفوع: ${totals.paid} | المتبقي: ${totals.remaining}`
    );
    navigator.clipboard.writeText(lines.join('\n'));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const exportToExcel = () => {
    if (filtered.length === 0) {
      alert('لا توجد بيانات لتصديرها');
      return;
    }

    const data = filtered.map(r => ({
      'الوحدة': `${r.project_number}-${r.unit_number}`,
      'المشروع': r.project_name,
      'العميل': r.original_client_name || '-',
      'الجوال': r.original_client_phone || '-',
      'قيمة العقد': r.contract_value ?? '-',
      'المدفوع': r.paid_value ?? '-',
      'المتبقي': r.remaining_value ?? '-',
      'آخر حفظ': new Date(r.saved_at).toLocaleString('ar-SA')
    }));

    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'تقرير المديونية');
    XLSX.writeFile(wb, `تقرير_المديونية_${new Date().toLocaleDateString('ar-SA').replace(/\//g, '-')}.xlsx`);
  };

  const printToPDF = () => {
    if (filtered.length === 0) {
      alert('لا توجد بيانات لطباعتها');
      return;
    }

    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    const tableBodyHtml = filtered.map(r => {
      const code = `${r.project_number}-${r.unit_number}`;
      return `
        <tr>
          <td>${code}</td>
          <td>${r.project_name}</td>
          <td>${r.original_client_name || '-'}</td>
          <td dir="ltr">${r.original_client_phone || '-'}</td>
          <td>${r.contract_value ?? '-'}</td>
          <td>${r.paid_value ?? '-'}</td>
          <td>${r.remaining_value ?? '-'}</td>
          <td>${new Date(r.saved_at).toLocaleString('ar-SA')}</td>
        </tr>
      `;
    }).join('');

    const html = `
      <html dir="rtl" lang="ar">
        <head>
          <title>تقرير المديونية - ${new Date().toLocaleDateString('ar-SA')}</title>
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
            }
            .company-brand {
              text-align: right;
            }
            .brand-name {
              font-weight: 800;
              font-size: 22px;
              color: #0c4a6e;
              margin: 0;
            }
            .brand-sub {
              font-size: 11px;
              color: #64748b;
              font-weight: 600;
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
            @media print {
              body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
              .header-main { background-color: #f8fafc !important; border: 1px solid #e2e8f0 !important; }
              th { background-color: #0c4a6e !important; color: white !important; }
              .top-accent { background: #0c4a6e !important; }
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
                <h1 class="report-title">تقرير المديونية</h1>
                <div class="report-subtitle">كشف تفصيلي للمديونيات</div>
              </div>
              <div class="meta-info">
                <div class="meta-item"><b>تاريخ التقرير:</b> ${new Date().toLocaleDateString('ar-SA')}</div>
                <div class="meta-item"><b>وقت الإصدار:</b> ${new Date().toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' })}</div>
              </div>
            </div>
            <div class="summary-bar">
              <div class="summary-card">
                <span class="card-label">إجمالي العقود</span>
                <span class="card-value">${totals.contract.toLocaleString('ar-SA')} ريال</span>
              </div>
              <div class="summary-card">
                <span class="card-label">إجمالي المدفوع</span>
                <span class="card-value">${totals.paid.toLocaleString('ar-SA')} ريال</span>
              </div>
              <div class="summary-card">
                <span class="card-label">الإجمالي المتبقي</span>
                <span class="card-value">${totals.remaining.toLocaleString('ar-SA')} ريال</span>
              </div>
            </div>
            <table>
              <thead>
                <tr>
                  <th>الوحدة</th>
                  <th>المشروع</th>
                  <th>العميل</th>
                  <th>الجوال</th>
                  <th>قيمة العقد</th>
                  <th>المدفوع</th>
                  <th>المتبقي</th>
                  <th>آخر حفظ</th>
                </tr>
              </thead>
              <tbody>
                ${tableBodyHtml}
              </tbody>
            </table>
            <div class="footer-legal">
              <div>© شركة مساكن الرفاهية للتطوير العقاري - تقرير رسمي معتمد</div>
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
  };
 
   return (
     <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto" dir="rtl">
       <div className="flex items-center gap-3">
         <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-600/20">
           <FileText size={24} />
         </div>
         <div>
           <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">تقرير المديونية</h1>
           <p className="text-gray-500 text-sm">عرض مبسط للمديونيات المحفوظة للوحدات</p>
         </div>
       </div>
 
       <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 space-y-4">
         <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
          <div className="md:col-span-1">
            <select
              value={filterProject}
              onChange={(e) => setFilterProject(e.target.value)}
              className="w-full p-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">جميع المشاريع</option>
              {projects.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name} ({project.project_number})
                </option>
              ))}
            </select>
          </div>
          <div className="md:col-span-2 relative">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
            <input
              type="text"
              placeholder="ابحث بالعميل، الجوال، الكود أو رقم الصك"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
            />
          </div>
          <div className="md:col-span-2 flex gap-2">
            <button
              onClick={exportToExcel}
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 bg-green-600 text-white rounded-xl text-sm font-bold hover:bg-green-700 transition-colors"
            >
              <FileSpreadsheet size={18} />
              تصدير Excel
            </button>
            <button
              onClick={printToPDF}
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 bg-blue-600 text-white rounded-xl text-sm font-bold hover:bg-blue-700 transition-colors"
            >
              <Printer size={18} />
              طباعة PDF
            </button>
            <button
              onClick={copySummary}
              className="inline-flex items-center justify-center gap-2 px-4 py-3 bg-white border border-gray-200 rounded-xl text-sm font-bold hover:bg-gray-50 transition-colors"
            >
              {copied ? <Check size={18} className="text-green-600" /> : <Copy size={18} />}
              {copied ? 'تم النسخ' : 'نسخ الملخص'}
            </button>
          </div>
        </div>
 
         <div className="border rounded-xl overflow-auto">
           <table className="min-w-full divide-y divide-gray-100">
             <thead className="bg-gray-50">
               <tr>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">الوحدة</th>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">المشروع</th>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">العميل</th>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">الجوال</th>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">قيمة العقد</th>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">المدفوع</th>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">المتبقي</th>
                 <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">آخر حفظ</th>
               </tr>
             </thead>
             <tbody className="divide-y divide-gray-100">
               {errorText ? (
                 <tr>
                   <td colSpan={8} className="p-8 text-center text-red-600">{errorText}</td>
                 </tr>
               ) : loading ? (
                 <tr>
                   <td colSpan={8} className="p-8 text-center text-gray-500">جاري التحميل...</td>
                 </tr>
               ) : filtered.length === 0 ? (
                 <tr>
                   <td colSpan={8} className="p-8 text-center text-gray-500">لا توجد بيانات</td>
                 </tr>
               ) : (
                 filtered.map((r) => {
                   const code = `${r.project_number}-${r.unit_number}`;
                   return (
                     <tr key={r.id} className="hover:bg-gray-50/50 transition-colors">
                       <td className="px-4 py-3 text-sm font-medium text-gray-900">{code}</td>
                       <td className="px-4 py-3 text-sm text-gray-700">{r.project_name}</td>
                       <td className="px-4 py-3 text-sm text-gray-700">{r.original_client_name || '-'}</td>
                       <td className="px-4 py-3 text-sm text-gray-700" dir="ltr">{r.original_client_phone || '-'}</td>
                       <td className="px-4 py-3 text-sm text-gray-900">{r.contract_value ?? '-'}</td>
                       <td className="px-4 py-3 text-sm text-green-700">{r.paid_value ?? '-'}</td>
                       <td className="px-4 py-3 text-sm text-red-700">{r.remaining_value ?? '-'}</td>
                       <td className="px-4 py-3 text-xs text-gray-500">{new Date(r.saved_at).toLocaleString('ar-SA')}</td>
                     </tr>
                   );
                 })
               )}
             </tbody>
           </table>
         </div>
 
         <div className="flex items-center gap-4 bg-gray-50 border border-gray-200 rounded-xl px-4 py-3">
           <div className="text-sm text-gray-600">إجمالي العقود: <span className="font-bold text-gray-900">{totals.contract}</span></div>
           <div className="w-px h-6 bg-gray-200" />
           <div className="text-sm text-gray-600">إجمالي المدفوع: <span className="font-bold text-green-700">{totals.paid}</span></div>
           <div className="w-px h-6 bg-gray-200" />
           <div className="text-sm text-gray-600">الإجمالي المتبقي: <span className="font-bold text-red-700">{totals.remaining}</span></div>
         </div>
       </div>
     </div>
   );
 }

