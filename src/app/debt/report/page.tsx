 'use client';
 
 import React, { useEffect, useMemo, useState } from 'react';
 import { supabase } from '../../../lib/supabaseClient';
 import { FileText, Search, Copy, Check } from 'lucide-react';
 
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
 
 export default function DebtReportPage() {
   const [rows, setRows] = useState<Debt[]>([]);
   const [loading, setLoading] = useState(true);
   const [errorText, setErrorText] = useState<string | null>(null);
   const [q, setQ] = useState('');
   const [copied, setCopied] = useState(false);
 
   useEffect(() => {
     load();
   }, []);
 
   const load = async () => {
     try {
       setLoading(true);
       setErrorText(null);
       const { data, error } = await supabase
         .from('debts')
         .select('*')
         .order('saved_at', { ascending: false });
       if (error) throw error;
       setRows(data || []);
     } catch (e: any) {
       setErrorText(e?.message || 'تعذر تحميل تقرير المديونية');
     } finally {
       setLoading(false);
     }
   };
 
   const filtered = useMemo(() => {
     const term = q.trim();
     if (!term) return rows;
     return rows.filter((r) => {
       const code = `${r.project_number}-${r.unit_number}`;
       return (
         code.includes(term) ||
         (r.project_name && r.project_name.includes(term)) ||
         (r.original_client_name && r.original_client_name.includes(term)) ||
         (r.current_owner_name && r.current_owner_name.includes(term)) ||
         (r.deed_number && r.deed_number.includes(term))
       );
     });
   }, [rows, q]);
 
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
         <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
           <div className="md:col-span-2 relative">
             <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
             <input
               type="text"
               placeholder="ابحث بالكود (110-5)، المشروع، العميل أو رقم الصك"
               value={q}
               onChange={(e) => setQ(e.target.value)}
               className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
             />
           </div>
           <button
             onClick={copySummary}
             className="inline-flex items-center justify-center gap-2 px-4 py-3 bg-white border border-gray-200 rounded-xl text-sm font-bold hover:bg-gray-50 transition-colors"
           >
             {copied ? <Check size={18} className="text-green-600" /> : <Copy size={18} />}
             {copied ? 'تم النسخ' : 'نسخ الملخص'}
           </button>
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

