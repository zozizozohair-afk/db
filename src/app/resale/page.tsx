'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { Search, Banknote } from 'lucide-react';
import type { Unit, Project } from '../../types';

type ResaleRow = {
  resaleFee?: number;
  marketingFee?: number;
  companyFee?: number;
  lawyerFee?: number;
  agreedAmount?: number;
};

type EnrichedUnit = Unit & { project_name: string; project_number: string };

export default function ResalePage() {
  const [units, setUnits] = useState<EnrichedUnit[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [rows, setRows] = useState<Record<string, ResaleRow>>({});

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
      console.error('Error fetching resale data:', e);
      const msg =
        (e as any)?.message ||
        'تعذر تحميل البيانات. يرجى التحقق من الاتصال أو إعدادات Supabase';
      setErrorText(msg);
    } finally {
      setLoading(false);
    }
  };


  const filteredUnits = useMemo(() => {
    return units.filter((u) => {
      const code = `${u.project_number}-${u.unit_number}`;
      return (
        u.project_name.includes(searchQuery) ||
        code.includes(searchQuery) ||
        (u.client_name && u.client_name.includes(searchQuery))
      );
    });
  }, [units, searchQuery]);

  useEffect(() => {
    const map: Record<string, ResaleRow> = {};
    for (const u of units) {
      map[u.id] = {
        resaleFee: (u as any).resale_fee ?? undefined,
        marketingFee: (u as any).marketing_fee ?? undefined,
        companyFee: (u as any).company_fee ?? undefined,
        lawyerFee: (u as any).lawyer_fee ?? undefined,
        agreedAmount: (u as any).resale_agreed_amount ?? undefined,
      };
    }
    setRows(map);
  }, [units]);

  const updateField = (unitId: string, field: keyof ResaleRow, value: string) => {
    setRows((prev) => ({
      ...prev,
      [unitId]: {
        ...prev[unitId],
        [field]: value ? Number(value) : undefined,
      },
    }));
  };

  const formatCurrency = (v?: number) =>
    typeof v === 'number' && !Number.isNaN(v) ? v.toLocaleString('ar-SA') : '-';

  const rowTotal = (r: ResaleRow) => {
    const { resaleFee = 0, marketingFee = 0, companyFee = 0, lawyerFee = 0 } = r;
    return resaleFee + marketingFee + companyFee + lawyerFee;
  };

  const saveRow = async (u: EnrichedUnit) => {
    const r = rows[u.id] || {};
    if (r.agreedAmount == null || Number.isNaN(r.agreedAmount)) {
      alert('يرجى تعبئة مبلغ البيع المتفق قبل الحفظ');
      return;
    }
    const now = new Date().toISOString();
    const { error } = await supabase
      .from('units')
      .update({
        status: 'for_resale',
        resale_fee: r.resaleFee ?? null,
        marketing_fee: r.marketingFee ?? null,
        company_fee: r.companyFee ?? null,
        lawyer_fee: r.lawyerFee ?? null,
        resale_agreed_amount: r.agreedAmount ?? null,
        resale_saved_at: now,
      })
      .eq('id', u.id);
    if (error) {
      alert('حدث خطأ أثناء الحفظ: ' + error.message);
      return;
    }
    alert('تم الحفظ وتحديث حالة الوحدة إلى إعادة بيع');
    setUnits((prev) =>
      prev.map((it) =>
        it.id === u.id
          ? {
              ...it,
              status: 'for_resale',
              ...(it as any),
              resale_fee: r.resaleFee ?? null,
              marketing_fee: r.marketingFee ?? null,
              company_fee: r.companyFee ?? null,
              lawyer_fee: r.lawyerFee ?? null,
              resale_agreed_amount: r.agreedAmount ?? null,
              resale_saved_at: now,
            }
          : it
      )
    );
  };

  const exportClipboard = () => {
    const payload = filteredUnits.map((u) => ({
      unit_id: u.id,
      unit_number: u.unit_number,
      project: u.project_name,
      project_number: u.project_number,
      ...rows[u.id],
      totalFees: rowTotal(rows[u.id] || {}),
    }));
    navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
    alert('تم نسخ البيانات إلى الحافظة بصيغة JSON');
  };

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto">
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-600/20">
          <Banknote size={24} />
        </div>
        <div>
          <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">إعادة البيع</h1>
          <p className="text-gray-500 text-sm">إدارة رسوم إعادة البيع للوحدات</p>
        </div>
      </div>

      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 space-y-4">
        <div className="relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
          <input
            type="text"
            placeholder="ابحث برقم الوحدة، الكود (101-1) أو اسم المشروع..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
          />
        </div>
        <div className="flex justify-between items-center">
          <div className="text-sm text-gray-500">عدد النتائج: {filteredUnits.length}</div>
          <button
            onClick={exportClipboard}
            className="px-4 py-2 bg-gray-800 text-white rounded-xl text-sm font-bold hover:bg-black transition-colors"
          >
            تصدير إلى الحافظة
          </button>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[800px]">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  الوحدة
                </th>
                <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  المشروع
                </th>
                <th className="px-4 py-3 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  رسوم إعادة بيع
                </th>
                <th className="px-4 py-3 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  رسوم تسويق
                </th>
                <th className="px-4 py-3 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  رسوم شركة
                </th>
                <th className="px-4 py-3 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  رسوم محاماة
                </th>
                <th className="px-4 py-3 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  مبلغ البيع المتفق
                </th>
                <th className="px-4 py-3 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  إجمالي الرسوم
                </th>
                <th className="px-4 py-3 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
                  إجراءات
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {errorText ? (
                <tr>
                  <td colSpan={9} className="p-8 text-center text-red-600">
                    {errorText}
                  </td>
                </tr>
              ) : loading ? (
                <tr>
                  <td colSpan={9} className="p-8 text-center text-gray-500">
                    جاري التحميل...
                  </td>
                </tr>
              ) : filteredUnits.length === 0 ? (
                <tr>
                  <td colSpan={9} className="p-8 text-center text-gray-500">
                    لا توجد وحدات مطابقة
                  </td>
                </tr>
              ) : (
                filteredUnits.map((u) => {
                  const r = rows[u.id] || {};
                  return (
                    <tr key={u.id} className="hover:bg-gray-50/50 transition-colors">
                      <td className="px-4 py-3 whitespace-nowrap">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 bg-blue-50 rounded-lg flex items-center justify-center text-blue-700 font-display font-bold border border-blue-100">
                            {u.unit_number}
                          </div>
                          <span className="text-sm text-gray-500">الدور {u.floor_number}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <div className="flex flex-col">
                          <span className="font-bold text-gray-900">{u.project_name}</span>
                          <span className="text-xs text-gray-500">{u.project_number}</span>
                        </div>
                      </td>
                      <td className="px-2 py-3 text-center">
                        <input
                          type="number"
                          inputMode="numeric"
                          className="w-36 px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                          value={r.resaleFee ?? ''}
                          onChange={(e) => updateField(u.id, 'resaleFee', e.target.value)}
                        />
                      </td>
                      <td className="px-2 py-3 text-center">
                        <input
                          type="number"
                          inputMode="numeric"
                          className="w-36 px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                          value={r.marketingFee ?? ''}
                          onChange={(e) => updateField(u.id, 'marketingFee', e.target.value)}
                        />
                      </td>
                      <td className="px-2 py-3 text-center">
                        <input
                          type="number"
                          inputMode="numeric"
                          className="w-36 px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                          value={r.companyFee ?? ''}
                          onChange={(e) => updateField(u.id, 'companyFee', e.target.value)}
                        />
                      </td>
                      <td className="px-2 py-3 text-center">
                        <input
                          type="number"
                          inputMode="numeric"
                          className="w-36 px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                          value={r.lawyerFee ?? ''}
                          onChange={(e) => updateField(u.id, 'lawyerFee', e.target.value)}
                        />
                      </td>
                      <td className="px-2 py-3 text-center">
                        <input
                          type="number"
                          inputMode="numeric"
                          className="w-44 px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                          value={r.agreedAmount ?? ''}
                          onChange={(e) => updateField(u.id, 'agreedAmount', e.target.value)}
                        />
                      </td>
                      <td className="px-4 py-3 text-center font-mono text-sm text-gray-700">
                        {formatCurrency(rowTotal(r))}
                      </td>
                      <td className="px-4 py-3 text-center">
                        <button
                          onClick={() => saveRow(u)}
                          className="px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-bold"
                        >
                          حفظ
                        </button>
                        {(u as any).resale_saved_at && (
                          <div className="mt-1 text-[11px] text-gray-500">
                            محفوظ: {new Date((u as any).resale_saved_at).toLocaleString('ar-SA')}
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
