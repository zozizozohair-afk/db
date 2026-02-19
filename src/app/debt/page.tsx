 'use client';
 
 import React, { useEffect, useMemo, useState } from 'react';
 import { supabase } from '../../lib/supabaseClient';
 import { CreditCard, Search, Copy, Check } from 'lucide-react';
 import type { Unit, Project } from '../../types';
 
 type EnrichedUnit = Unit & { project_name: string; project_number: string };
 
 type DebtRow = {
   contractValue?: number;
   paidValue?: number;
 };
 
 export default function DebtPage() {
   const [units, setUnits] = useState<EnrichedUnit[]>([]);
   const [projects, setProjects] = useState<Project[]>([]);
   const [loading, setLoading] = useState(true);
   const [errorText, setErrorText] = useState<string | null>(null);
 
   const [clientQuery, setClientQuery] = useState('');
   const [selectedClient, setSelectedClient] = useState<string | null>(null);
 
  const [rows, setRows] = useState<Record<string, DebtRow>>({});
  const [copied, setCopied] = useState(false);
  const [unitQuery, setUnitQuery] = useState('');
  const [saving, setSaving] = useState<Record<string, boolean>>({});
 
   useEffect(() => {
     fetchData();
   }, []);
 
   const fetchData = async () => {
     try {
       setLoading(true);
       setErrorText(null);
 
       const { data: projectsData, error: projectsError } = await supabase
         .from('projects')
         .select('*')
         .order('created_at', { ascending: false });
       if (projectsError) throw projectsError;
       setProjects(projectsData || []);
 
       const { data: unitsData, error: unitsError } = await supabase
         .from('units')
         .select('*')
         .order('unit_number', { ascending: true });
       if (unitsError) throw unitsError;
 
       const enriched: EnrichedUnit[] =
         unitsData?.map((u: Unit) => {
           const p = projectsData?.find((pr: Project) => pr.id === u.project_id);
           return {
             ...u,
             project_name: p?.name || 'غير معروف',
             project_number: p?.project_number || '-',
           };
         }) || [];
       setUnits(enriched);
     } catch (e) {
       const msg =
         (e as any)?.message ||
         'تعذر تحميل البيانات. يرجى التحقق من الاتصال أو إعدادات Supabase';
       setErrorText(msg);
     } finally {
       setLoading(false);
     }
   };
 
   const clients = useMemo(() => {
     const set = new Set<string>();
     for (const u of units) {
       if (u.client_name) set.add(u.client_name);
       if (u.title_deed_owner) set.add(u.title_deed_owner);
     }
     return Array.from(set).sort((a, b) => a.localeCompare(b, 'ar'));
   }, [units]);
 
   const filteredClients = useMemo(() => {
     const q = clientQuery.trim();
     if (!q) return clients;
     return clients.filter((c) => c.includes(q));
   }, [clients, clientQuery]);
 
   const clientUnits = useMemo(() => {
     if (!selectedClient) return [];
     return units.filter(
       (u) => u.client_name === selectedClient || u.title_deed_owner === selectedClient
     );
   }, [units, selectedClient]);

  const unitsBase = useMemo(() => {
    return selectedClient ? clientUnits : units;
  }, [selectedClient, clientUnits, units]);

  const filteredUnitsView = useMemo(() => {
    if (!unitQuery.trim()) return unitsBase;
    const q = unitQuery.trim();
    return unitsBase.filter((u) => {
      const code = `${u.project_number}-${u.unit_number}`;
      const byCode = code.includes(q);
      const byProject = u.project_name?.includes(q);
      const byUnitExact = !Number.isNaN(Number(q)) && u.unit_number === Number(q);
      return byCode || byProject || byUnitExact;
    });
  }, [unitsBase, unitQuery]);
 
   const updateField = (unitId: string, field: keyof DebtRow, value: string) => {
     setRows((prev) => ({
       ...prev,
       [unitId]: {
         ...prev[unitId],
         [field]: value ? Number(value) : undefined,
       },
     }));
   };
 
   const remaining = (r: DebtRow) => {
     const total = r.contractValue ?? 0;
     const paid = r.paidValue ?? 0;
     return Math.max(total - paid, 0);
   };
 
  const totals = useMemo(() => {
     let totalContract = 0;
     let totalPaid = 0;
     let totalRemaining = 0;
    for (const u of filteredUnitsView) {
       const r = rows[u.id] || {};
       totalContract += r.contractValue ?? 0;
       totalPaid += r.paidValue ?? 0;
       totalRemaining += remaining(r);
     }
    return { totalContract, totalPaid, totalRemaining };
  }, [filteredUnitsView, rows]);
 
  const copySummary = () => {
     if (!selectedClient) return;
     const lines: string[] = [];
    lines.push(selectedClient ? `ملخص المديونية للعميل: ${selectedClient}` : 'ملخص المديونية (بحث وحدة)');
     lines.push('');
    for (const u of filteredUnitsView) {
       const r = rows[u.id] || {};
       const projectCode = `${u.project_number}-${u.unit_number}`;
       lines.push(
         [
           `الوحدة ${projectCode}`,
           `قيمة العقد: ${r.contractValue ?? '-'}`,
           `المدفوع: ${r.paidValue ?? '-'}`,
           `المتبقي: ${remaining(r)}`
         ].join(' | ')
       );
     }
     lines.push('');
     lines.push(
       `الإجمالي — قيمة العقود: ${totals.totalContract} | المدفوع: ${totals.totalPaid} | المتبقي: ${totals.totalRemaining}`
     );
     navigator.clipboard.writeText(lines.join('\n'));
     setCopied(true);
     setTimeout(() => setCopied(false), 2000);
   };

  const saveDebtRow = async (u: EnrichedUnit) => {
    const r = rows[u.id] || {};
    try {
      setSaving((prev) => ({ ...prev, [u.id]: true }));
      const payload: any = {
        unit_id: u.id,
        project_id: u.project_id,
        project_number: u.project_number,
        project_name: u.project_name,
        unit_number: u.unit_number,
        deed_number: u.deed_number || null,
        original_client_name: u.client_name || null,
        original_client_phone: u.client_phone || null,
        original_client_id: u.client_id_number || null,
        current_owner_name: u.title_deed_owner || null,
        current_owner_phone: u.title_deed_owner_phone || null,
        contract_value: r.contractValue ?? null,
        paid_value: r.paidValue ?? null,
        remaining_value: remaining(r),
        saved_at: new Date().toISOString(),
      };
      const { error } = await supabase
        .from('debts')
        .upsert([payload], { onConflict: 'unit_id' });
      if (error) {
        alert('حدث خطأ أثناء الحفظ: ' + error.message);
        return;
      }
      alert('تم حفظ/تحديث سجل المديونية للوحدة');
    } finally {
      setSaving((prev) => ({ ...prev, [u.id]: false }));
    }
  };
 
   return (
     <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto" dir="rtl">
       <div className="flex items-center gap-3">
         <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-600/20">
           <CreditCard size={24} />
         </div>
         <div>
           <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">المديونية</h1>
           <p className="text-gray-500 text-sm">اختر العميل ثم أدخل قيمة العقد والمدفوع لكل وحدة</p>
         </div>
       </div>
 
       <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 space-y-4">
         {/* Client Selector */}
         <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
           <div className="md:col-span-2 relative">
             <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
             <input
               type="text"
               placeholder="ابحث باسم العميل..."
               value={clientQuery}
               onChange={(e) => setClientQuery(e.target.value)}
               className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
             />
           </div>
           <select
             value={selectedClient || ''}
             onChange={(e) => setSelectedClient(e.target.value || null)}
             className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
           >
             <option value="">اختر العميل</option>
             {filteredClients.map((c) => (
               <option key={c} value={c}>{c}</option>
             ))}
           </select>
         </div>
 
        {/* Unit Search + Units Table */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div className="md:col-span-1 relative">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
            <input
              type="text"
              placeholder="ابحث بالوحدة (مثال 110-5 أو رقم)"
              value={unitQuery}
              onChange={(e) => setUnitQuery(e.target.value)}
              className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
            />
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
                <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">إجراءات</th>
               </tr>
             </thead>
            <tbody className="divide-y divide-gray-100">
              {errorText ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-red-600">{errorText}</td>
                </tr>
              ) : loading ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-gray-500">جاري التحميل...</td>
                </tr>
              ) : (!selectedClient && unitQuery.trim() === '') ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-gray-500">اختر العميل أو اكتب بحث الوحدة</td>
                </tr>
              ) : filteredUnitsView.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-gray-500">لا توجد وحدات مطابقة</td>
                </tr>
              ) : (
                filteredUnitsView.map((u) => {
                  const r = rows[u.id] || {};
                  const code = `${u.project_number}-${u.unit_number}`;
                  return (
                    <tr key={u.id} className="hover:bg-gray-50/50 transition-colors">
                      <td className="px-4 py-3 text-sm font-medium text-gray-900">{code}</td>
                      <td className="px-4 py-3 text-sm text-gray-700">{u.project_name}</td>
                      <td className="px-4 py-3 text-sm text-gray-700">{u.client_name || '-'}</td>
                      <td className="px-4 py-3 text-sm text-gray-700" dir="ltr">{u.client_phone || '-'}</td>
                      <td className="px-4 py-2">
                        <input
                          type="number"
                          value={r.contractValue ?? ''}
                          onChange={(e) => updateField(u.id, 'contractValue', e.target.value)}
                          placeholder="0"
                          className="w-36 md:w-44 px-3 py-2 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none text-sm"
                        />
                      </td>
                      <td className="px-4 py-2">
                        <input
                          type="number"
                          value={r.paidValue ?? ''}
                          onChange={(e) => updateField(u.id, 'paidValue', e.target.value)}
                          placeholder="0"
                          className="w-36 md:w-44 px-3 py-2 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none text-sm"
                        />
                      </td>
                      <td className="px-4 py-3 text-sm font-bold text-gray-900">{remaining(r)}</td>
                      <td className="px-4 py-2">
                        <button
                          onClick={() => saveDebtRow(u)}
                          disabled={!!saving[u.id]}
                          className={`px-3 py-2 rounded-lg text-sm font-bold transition-colors ${saving[u.id] ? 'bg-gray-200 text-gray-500 cursor-not-allowed' : 'bg-blue-600 text-white hover:bg-blue-700'}`}
                        >
                          {saving[u.id] ? 'جارٍ الحفظ...' : 'حفظ'}
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
           </table>
         </div>
 
         {/* Totals and Actions */}
         <div className="flex flex-col md:flex-row items-center justify-between gap-4">
           <div className="flex items-center gap-4 bg-gray-50 border border-gray-200 rounded-xl px-4 py-3">
             <div className="text-sm text-gray-600">إجمالي العقود: <span className="font-bold text-gray-900">{totals.totalContract}</span></div>
             <div className="w-px h-6 bg-gray-200" />
             <div className="text-sm text-gray-600">إجمالي المدفوع: <span className="font-bold text-green-700">{totals.totalPaid}</span></div>
             <div className="w-px h-6 bg-gray-200" />
             <div className="text-sm text-gray-600">الإجمالي المتبقي: <span className="font-bold text-red-700">{totals.totalRemaining}</span></div>
           </div>
 
           <button
             onClick={copySummary}
             className="inline-flex items-center gap-2 px-4 py-3 bg-white border border-gray-200 rounded-xl text-sm font-bold hover:bg-gray-50 transition-colors"
           >
             {copied ? <Check size={18} className="text-green-600" /> : <Copy size={18} />}
             {copied ? 'تم النسخ' : 'نسخ الملخص'}
           </button>
         </div>
 
       </div>
     </div>
   );
 }
