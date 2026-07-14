'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { ArrowLeft, Search, Clock, User as UserIcon, Building2, Home, Users } from 'lucide-react';
import * as supabaseClient from '../../../lib/supabaseClient';
import { ContractLog, CONTRACT_LOG_ACTIONS, CONTRACT_TYPES, PAYMENT_METHODS } from '../../../types';

type Employee = { id: string; email: string | null };
type ContractSnapshot = {
  id: string;
  project: { project_number: string; name?: string | null } | null;
  unit: { unit_number: number | null } | null;
  client: { name: string | null } | null;
  client_name?: string | null;
};

const normalizeUsername = (value: string | null | undefined) => {
  if (!value) return '';
  return value.split('@')[0] || value;
};

const getContractTypeLabel = (type: string | null | undefined) => {
  if (!type) return null;
  return (CONTRACT_TYPES as Record<string, string>)[type] || type;
};

const getErrorMessage = (error: unknown) => {
  if (!error) return 'خطأ غير معروف';
  if (typeof error === 'string') return error;
  if (typeof error === 'object') {
    const maybeError = error as { message?: string; details?: string; hint?: string; code?: string };
    return (
      maybeError.message ||
      maybeError.details ||
      maybeError.hint ||
      maybeError.code ||
      JSON.stringify(error)
    );
  }
  return String(error);
};

export default function ContractLogsPage() {
  const [loading, setLoading] = useState(true);
  const [logs, setLogs] = useState<ContractLog[]>([]);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [contractsMap, setContractsMap] = useState<Record<string, ContractSnapshot>>({});
  const [query, setQuery] = useState('');
  const [selectedDate, setSelectedDate] = useState('');

  useEffect(() => {
    loadLogs();
  }, []);

  const loadLogs = async () => {
    try {
      setLoading(true);

      const logsRes = await supabaseClient.supabase
        .from('contract_logs')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(500);

      if (logsRes.error) throw logsRes.error;

      const nextLogs = (((logsRes.data as any[]) || []) as ContractLog[]);
      setLogs(nextLogs);

      try {
        const employeesRes = await supabaseClient.supabase.rpc('crm_list_employees');
        if (employeesRes.error) throw employeesRes.error;
        setEmployees((((employeesRes.data as any[]) || []) as Employee[]));
      } catch (employeesError) {
        console.warn('Error loading employees for logs:', getErrorMessage(employeesError));
        setEmployees([]);
      }

      const contractIds = Array.from(
        new Set(nextLogs.map(l => l.contract_id).filter(Boolean) as string[])
      );

      if (contractIds.length > 0) {
        try {
          const { data: contractsData, error: contractsError } = await supabaseClient.supabase
            .from('contracts')
            .select(`
              id,
              client_name,
              project:projects(project_number,name),
              unit:units(unit_number),
              client:clients(name)
            `)
            .in('id', contractIds);

          if (contractsError) throw contractsError;

          const map: Record<string, ContractSnapshot> = {};
          ((contractsData as any[]) || []).forEach((c: any) => {
            map[c.id] = c as ContractSnapshot;
          });
          setContractsMap(map);
        } catch (contractsError) {
          console.warn('Error loading related contracts for logs:', getErrorMessage(contractsError));
          setContractsMap({});
        }
      } else {
        setContractsMap({});
      }
    } catch (error) {
      const message = getErrorMessage(error);
      console.error('Error loading logs:', message, error);
      alert(`حدث خطأ أثناء تحميل سجل الأحداث: ${message}`);
    } finally {
      setLoading(false);
    }
  };

  const getActorName = (log: ContractLog) => {
    if (log.actor_name) return log.actor_name;
    if (!log.actor_id) return '—';
    const email = employees.find(e => e.id === log.actor_id)?.email || '';
    return normalizeUsername(email) || '—';
  };

  const getActionLabel = (action: string) =>
    (CONTRACT_LOG_ACTIONS as any)[action] || action || '—';

  const getContractInfo = (log: ContractLog) => {
    const snap = log.contract_id ? contractsMap[log.contract_id] : undefined;
    const meta = (log.metadata || {}) as any;

    const projectNumber = snap?.project?.project_number || meta.project_number || null;
    const unitNumber =
      (snap?.unit?.unit_number ?? null) !== null && (snap?.unit?.unit_number ?? null) !== undefined
        ? snap?.unit?.unit_number
        : (meta.unit_number ?? null);
    const clientName = snap?.client?.name || snap?.client_name || meta.client_name || null;

    const amount = meta.amount ?? null;
    const paymentMethod = meta.payment_method ?? null;
    const contractType = meta.contract_type || meta.type || null;
    const contractTypeLabel = meta.contract_type_label || getContractTypeLabel(contractType);
    const operationAt = meta.operation_at || log.created_at;

    return { projectNumber, unitNumber, clientName, amount, paymentMethod, contractTypeLabel, operationAt };
  };

  const filtered = useMemo(() => {
    const raw = query.trim();
    const q = raw.toLowerCase();
    if (!q && !selectedDate) return logs;

    const dashMatch = raw.match(/^\s*([^\-]+?)\s*-\s*([^\-]+?)\s*$/);
    const projectPart = dashMatch ? dashMatch[1].trim().toLowerCase() : null;
    const unitPart = dashMatch ? dashMatch[2].trim().toLowerCase() : null;

    return logs.filter(l => {
      const info = getContractInfo(l);
      const operationDate = String(info.operationAt || l.created_at || '').slice(0, 10);

      if (selectedDate && operationDate !== selectedDate) {
        return false;
      }

      const actor = getActorName(l).toLowerCase();
      const action = getActionLabel(l.action).toLowerCase();
      const projectNumber = String(info.projectNumber || '').toLowerCase();
      const unitNumber = String(info.unitNumber ?? '').toLowerCase();
      const clientName = String(info.clientName || '').toLowerCase();
      const contractTypeLabel = String(info.contractTypeLabel || '').toLowerCase();

      if (!q) return true;

      if (projectPart && unitPart) {
        return projectNumber.includes(projectPart) && unitNumber.includes(unitPart);
      }

      return (
        actor.includes(q) ||
        action.includes(q) ||
        contractTypeLabel.includes(q) ||
        projectNumber.includes(q) ||
        unitNumber.includes(q) ||
        clientName.includes(q)
      );
    });
  }, [logs, query, selectedDate, employees, contractsMap]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" dir="rtl" style={{ background: 'var(--background)' }}>
        <div className="animate-spin rounded-full h-16 w-16 border-b-4 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen pb-20" dir="rtl" style={{ background: 'var(--background)' }}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <div className="flex items-center gap-4">
          <Link href="/contracts" className="p-3 bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-300">
            <ArrowLeft size={20} className="text-gray-700" />
          </Link>
          <h1 className="text-3xl font-extrabold text-gray-900 flex-1">سجل الأحداث</h1>
          <button
            onClick={loadLogs}
            className="px-6 py-3 bg-white border border-gray-200 rounded-xl hover:bg-gray-50 transition-all font-semibold"
          >
            تحديث
          </button>
        </div>

        <div className="bg-white rounded-3xl shadow-lg border border-gray-100 p-6">
          <div className="flex flex-col md:flex-row gap-4 md:items-center md:justify-between">
            <div className="flex flex-col md:flex-row gap-3 w-full md:max-w-4xl">
              <div className="flex items-center gap-3 w-full md:max-w-xl">
                <div className="p-3 rounded-xl bg-gray-50 border border-gray-200">
                  <Search size={18} className="text-gray-600" />
                </div>
                <input
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="ابحث بالمستخدم أو نوع الحدث أو رقم المشروع أو رقم الوحدة أو اسم العميل..."
                  className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                />
              </div>
              <div className="p-3 rounded-xl bg-gray-50 border border-gray-200">
                <Clock size={18} className="text-gray-600" />
              </div>
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="w-full md:w-52 px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
              />
              {selectedDate && (
                <button
                  type="button"
                  onClick={() => setSelectedDate('')}
                  className="px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl hover:bg-gray-100 transition-all font-semibold text-gray-700"
                >
                  مسح التاريخ
                </button>
              )}
            </div>
            <div className="text-sm text-gray-600 font-semibold">
              عدد النتائج: {filtered.length}
            </div>
          </div>
        </div>

        {filtered.length === 0 ? (
          <div className="bg-white rounded-3xl shadow-lg border border-gray-100 p-16 text-center">
            <h3 className="text-2xl font-extrabold text-gray-900 mb-3">لا توجد أحداث</h3>
            <p className="text-lg text-gray-500">بعد ما تبدأ التعديلات/الإضافات راح تظهر هنا</p>
          </div>
        ) : (
          <div className="grid gap-4">
            {filtered.map((l) => (
              <div key={l.id} className="bg-white rounded-3xl shadow-lg border border-gray-100 p-6">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                  <div className="space-y-2">
                    <div className="text-xl font-extrabold text-gray-900">{getActionLabel(l.action)}</div>
                    <div className="flex flex-wrap gap-2 text-sm">
                      <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-gray-50 border border-gray-200 text-gray-700 font-semibold">
                        <UserIcon size={16} />
                        {getActorName(l)}
                      </span>
                      <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-gray-50 border border-gray-200 text-gray-700 font-semibold">
                        <Clock size={16} />
                        {new Date(l.created_at).toLocaleString('ar-SA')}
                      </span>
                      {(() => {
                        const info = getContractInfo(l);
                        return (
                          <>
                            {info.projectNumber && (
                              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-blue-50 border border-blue-200 text-blue-700 font-semibold">
                                <Building2 size={16} />
                                مشروع: {info.projectNumber}
                              </span>
                            )}
                            {(info.unitNumber ?? null) !== null && info.unitNumber !== undefined && (
                              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 font-semibold">
                                <Home size={16} />
                                وحدة: {info.unitNumber}
                              </span>
                            )}
                            {info.clientName && (
                              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-purple-50 border border-purple-200 text-purple-800 font-semibold">
                                <Users size={16} />
                                عميل: {info.clientName}
                              </span>
                            )}
                            {info.contractTypeLabel && (
                              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 font-semibold">
                                نوع العقد: {info.contractTypeLabel}
                              </span>
                            )}
                            {(info.amount ?? null) !== null && info.amount !== undefined && (
                              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-gray-50 border border-gray-200 text-gray-700 font-semibold">
                                المبلغ: {Number(info.amount || 0).toLocaleString()} ر.س
                              </span>
                            )}
                            {info.paymentMethod && (
                              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-gray-50 border border-gray-200 text-gray-700 font-semibold">
                                الطريقة: {(PAYMENT_METHODS as any)[info.paymentMethod] || String(info.paymentMethod)}
                              </span>
                            )}
                            {info.operationAt && (
                              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-gray-50 border border-gray-200 text-gray-700 font-semibold">
                                وقت العملية: {new Date(info.operationAt).toLocaleString('ar-SA')}
                              </span>
                            )}
                          </>
                        );
                      })()}
                    </div>
                  </div>

                  {l.contract_id && (
                    <Link
                      href="/contracts"
                      className="inline-flex items-center justify-center px-5 py-2.5 rounded-xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors"
                    >
                      فتح صفحة العقود
                    </Link>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
