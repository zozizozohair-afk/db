'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { BarChart3, Briefcase, ClipboardList, Plus, RefreshCw, Shield, Users } from 'lucide-react';
import { supabase } from '../../../lib/supabaseClient';

type EmployeeRow = {
  id: string;
  email: string | null;
  user_created_at: string | null;
  last_sign_in_at: string | null;
  job_title: string | null;
  role: 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';
  is_active: boolean;
};

const ROLE_OPTIONS: Array<{ value: EmployeeRow['role']; label: string }> = [
  { value: 'admin', label: 'مدير النظام' },
  { value: 'manager', label: 'مدير' },
  { value: 'marketing', label: 'مسؤول تسويق' },
  { value: 'customer_service', label: 'خدمة عملاء' },
  { value: 'staff', label: 'موظف' },
  { value: 'viewer', label: 'مشاهد' }
];

const roleLabel = (role: EmployeeRow['role']) => ROLE_OPTIONS.find((r) => r.value === role)?.label || role;

export default function CrmEmployeesPage() {
  const pathname = usePathname();
  const router = useRouter();
  const [access, setAccess] = useState<'checking' | 'allowed' | 'denied'>('checking');
  const [rows, setRows] = useState<EmployeeRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [search, setSearch] = useState('');

  const [modalOpen, setModalOpen] = useState(false);
  const [mode, setMode] = useState<'create' | 'edit'>('create');
  const [editing, setEditing] = useState<EmployeeRow | null>(null);
  const [formEmail, setFormEmail] = useState('');
  const [formJobTitle, setFormJobTitle] = useState('');
  const [formRole, setFormRole] = useState<EmployeeRow['role']>('admin');
  const [formActive, setFormActive] = useState(true);

  const humanizeError = (message: string) => {
    const m = (message || '').toLowerCase();
    if (m.includes('user_not_found')) return 'لا يوجد مستخدم بهذا البريد داخل النظام.';
    if (m.includes('email_required')) return 'الرجاء إدخال البريد الإلكتروني.';
    if (m.includes('permission') || m.includes('not allowed')) return 'ليس لديك صلاحية لتنفيذ العملية.';
    return message;
  };

  const loadEmployees = async () => {
    setLoading(true);
    setError(null);
    setNotice(null);
    const { data, error: err } = await supabase.rpc('crm_list_employees');
    if (err) {
      setError(humanizeError(err.message));
      setRows([]);
      setLoading(false);
      return;
    }
    setRows((data as EmployeeRow[]) || []);
    setLoading(false);
  };

  useEffect(() => {
    const run = async () => {
      const { data } = await supabase.auth.getUser();
      const user = data.user;
      if (!user) {
        router.replace('/login');
        return;
      }

      const { data: profile, error: profileError } = await supabase
        .from('employee_profiles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();

      if (profileError) {
        setAccess('denied');
        setError(humanizeError(profileError.message));
        return;
      }

      const role = (profile?.role as EmployeeRow['role'] | null) || 'admin';
      if (role !== 'admin') {
        setAccess('denied');
        return;
      }

      setAccess('allowed');
      await loadEmployees();
    };

    run();
  }, []);

  const openCreate = () => {
    setMode('create');
    setEditing(null);
    setFormEmail('');
    setFormJobTitle('');
    setFormRole('admin');
    setFormActive(true);
    setModalOpen(true);
  };

  const openEdit = (row: EmployeeRow) => {
    setMode('edit');
    setEditing(row);
    setFormEmail(row.email || '');
    setFormJobTitle(row.job_title || '');
    setFormRole(row.role);
    setFormActive(row.is_active);
    setModalOpen(true);
  };

  const save = async () => {
    setError(null);
    setNotice(null);
    if (mode === 'create') {
      const { error: err } = await supabase.rpc('crm_upsert_employee_by_email', {
        p_email: formEmail,
        p_job_title: formJobTitle,
        p_role: formRole
      });
      if (err) {
        setError(humanizeError(err.message));
        return;
      }
      setModalOpen(false);
      await loadEmployees();
      setNotice('تمت إضافة الموظف بنجاح.');
      return;
    }

    if (!editing) return;
    const { error: err } = await supabase.rpc('crm_update_employee_profile', {
      p_user_id: editing.id,
      p_job_title: formJobTitle,
      p_role: formRole,
      p_is_active: formActive
    });
    if (err) {
      setError(humanizeError(err.message));
      return;
    }
    setModalOpen(false);
    await loadEmployees();
    setNotice('تم حفظ بيانات الموظف.');
  };

  const filteredRows = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter((r) => (r.email || '').toLowerCase().includes(q) || (r.job_title || '').toLowerCase().includes(q));
  }, [rows, search]);

  if (access === 'checking') {
    return (
      <div className="p-4 md:p-8 min-h-screen max-w-7xl mx-auto" dir="rtl">
        <div className="bg-white/95 backdrop-blur rounded-2xl shadow-md border border-gray-200 p-6 text-gray-700">
          جاري التحقق من الصلاحيات...
        </div>
      </div>
    );
  }

  if (access === 'denied') {
    return (
      <div className="p-4 md:p-8 min-h-screen max-w-7xl mx-auto" dir="rtl">
        <div className="bg-white/95 backdrop-blur rounded-2xl shadow-md border border-gray-200 p-6 space-y-3">
          <div className="font-bold text-gray-900">غير مصرح</div>
          <div className="text-sm text-gray-600">هذه الصفحة متاحة فقط لمدير النظام.</div>
          {error ? <div className="text-sm text-red-700">{error}</div> : null}
          <div className="flex items-center gap-2">
            <Link
              href="/crm"
              className="inline-flex items-center px-4 py-2 rounded-xl bg-gradient-to-l from-emerald-600 to-emerald-700 text-white font-bold"
            >
              العودة إلى CRM
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto" dir="rtl">
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 bg-slate-700 rounded-xl flex items-center justify-center text-white shadow-lg shadow-slate-700/20">
          <Users size={24} />
        </div>
        <div>
          <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">الموظفين</h1>
          <p className="text-gray-500 text-sm">تحديد المسمى الوظيفي ودور المستخدم داخل النظام</p>
        </div>
      </div>

      <div className="bg-white/90 backdrop-blur rounded-2xl shadow-md border border-gray-200 p-2">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
          {[
            { label: 'الموظفين', href: '/crm/employees', icon: Users },
            { label: 'العملاء', href: '/crm', icon: Users },
            { label: 'المهام', href: '/crm/tasks', icon: ClipboardList },
            { label: 'التقارير', href: '/crm/reports', icon: BarChart3 }
          ].map((t) => {
            const isActive =
              t.href === '/crm' ? pathname === '/crm' : pathname === t.href || pathname.startsWith(t.href + '/');
            const Icon = (t as any).icon;
            return (
              <Link
                key={t.href}
                href={t.href}
                className={`group px-4 py-3 rounded-xl text-sm font-bold transition-all text-center border ${
                  isActive
                    ? 'bg-gradient-to-l from-emerald-600 to-emerald-700 text-white border-emerald-600 shadow-sm'
                    : 'bg-white text-gray-800 border-gray-200 hover:bg-gray-50 hover:shadow-sm'
                }`}
              >
                <span className="inline-flex items-center gap-2">
                  <Icon size={18} className={isActive ? 'text-white' : 'text-gray-500 group-hover:text-gray-700'} />
                  {t.label}
                </span>
              </Link>
            );
          })}
        </div>
      </div>

      <div className="bg-white/95 backdrop-blur rounded-2xl shadow-md border border-gray-200 p-4 md:p-6 space-y-4">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-xl bg-gradient-to-l from-slate-900 to-slate-700 text-white flex items-center justify-center shadow-sm">
              <Shield size={20} />
            </div>
            <div>
              <div className="font-bold text-gray-900">المستخدمين</div>
              <div className="text-sm text-gray-500">اختر مستخدمًا ثم حدّد المسمى والدور</div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={loadEmployees}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border border-gray-200 bg-white hover:bg-gray-50 text-gray-700 font-bold"
              disabled={loading}
            >
              <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
              تحديث
            </button>
            <button
              onClick={openCreate}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-l from-emerald-600 to-emerald-700 text-white font-bold shadow-sm"
            >
              <Plus size={16} />
              إضافة موظف
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div className="md:col-span-2">
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="بحث بالبريد أو المسمى الوظيفي"
              className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none"
            />
          </div>
          <div className="text-sm text-gray-500 flex items-center justify-between md:justify-end gap-2">
            <span>الإجمالي: {filteredRows.length}</span>
          </div>
        </div>

        {error ? (
          <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
        ) : null}
        {notice ? (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
            {notice}
          </div>
        ) : null}

        <div className="overflow-auto rounded-2xl border border-gray-200">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-700">
              <tr>
                <th className="text-right px-4 py-3 font-bold">المستخدم</th>
                <th className="text-right px-4 py-3 font-bold">المسمى الوظيفي</th>
                <th className="text-right px-4 py-3 font-bold">الدور</th>
                <th className="text-right px-4 py-3 font-bold">الحالة</th>
                <th className="text-right px-4 py-3 font-bold"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 bg-white">
              {loading ? (
                <tr>
                  <td className="px-4 py-8 text-gray-500" colSpan={5}>
                    جاري التحميل...
                  </td>
                </tr>
              ) : filteredRows.length === 0 ? (
                <tr>
                  <td className="px-4 py-8 text-gray-500" colSpan={5}>
                    لا يوجد مستخدمين
                  </td>
                </tr>
              ) : (
                filteredRows.map((r) => (
                  <tr key={r.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <div className="font-bold text-gray-900">{r.email || '-'}</div>
                      <div className="text-xs text-gray-500">{r.last_sign_in_at ? 'آخر دخول: ' + new Date(r.last_sign_in_at).toLocaleString('ar') : 'لم يسجل دخول بعد'}</div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="inline-flex items-center gap-2 text-gray-800">
                        <Briefcase size={14} className="text-gray-400" />
                        {r.job_title || '-'}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span className="inline-flex items-center px-3 py-1 rounded-lg bg-gray-100 text-gray-800 font-bold">
                        {roleLabel(r.role)}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center px-3 py-1 rounded-lg font-bold ${
                          r.is_active ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-gray-100 text-gray-600 border border-gray-200'
                        }`}
                      >
                        {r.is_active ? 'مفعّل' : 'غير مفعّل'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-left">
                      <button
                        onClick={() => openEdit(r)}
                        className="px-4 py-2 rounded-xl bg-white border border-gray-200 hover:bg-gray-50 text-gray-800 font-bold"
                      >
                        تعديل
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {modalOpen ? (
        <div className="fixed inset-0 z-50">
          <div className="absolute inset-0 bg-black/40" onClick={() => setModalOpen(false)} />
          <div className="absolute inset-0 flex items-center justify-center p-4">
            <div className="w-full max-w-lg bg-white rounded-2xl shadow-xl border border-gray-200 overflow-hidden">
              <div className="p-5 border-b border-gray-100 flex items-center justify-between">
                <div className="font-bold text-gray-900">{mode === 'create' ? 'إضافة موظف' : 'تعديل الموظف'}</div>
                <button
                  onClick={() => setModalOpen(false)}
                  className="px-3 py-1 rounded-lg border border-gray-200 bg-white hover:bg-gray-50 text-gray-700 font-bold"
                >
                  إغلاق
                </button>
              </div>
              <div className="p-5 space-y-4">
                {mode === 'create' ? (
                  <div className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">بريد المستخدم (مسجّل مسبقًا في النظام)</div>
                    <input
                      value={formEmail}
                      onChange={(e) => setFormEmail(e.target.value)}
                      placeholder="example@domain.com"
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none"
                    />
                    <div className="text-xs text-gray-500">سيتم تعيين المستخدم كموظف إذا كان موجودًا ضمن المستخدمين.</div>
                  </div>
                ) : (
                  <div className="space-y-1">
                    <div className="text-sm font-bold text-gray-700">المستخدم</div>
                    <div className="px-4 py-3 rounded-xl border border-gray-200 bg-gray-50 text-gray-800">{formEmail || '-'}</div>
                  </div>
                )}

                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">المسمى الوظيفي</div>
                    <input
                      value={formJobTitle}
                      onChange={(e) => setFormJobTitle(e.target.value)}
                      placeholder="مثال: مسؤول مبيعات"
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none"
                    />
                  </div>
                  <div className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">الدور</div>
                    <select
                      value={formRole}
                      onChange={(e) => setFormRole(e.target.value as EmployeeRow['role'])}
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none bg-white"
                    >
                      {ROLE_OPTIONS.map((r) => (
                        <option key={r.value} value={r.value}>
                          {r.label}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                {mode === 'edit' ? (
                  <div className="flex items-center justify-between rounded-xl border border-gray-200 px-4 py-3">
                    <div className="text-sm font-bold text-gray-800">تفعيل الموظف</div>
                    <button
                      onClick={() => setFormActive((v) => !v)}
                      className={`px-4 py-2 rounded-xl font-bold border ${
                        formActive ? 'bg-emerald-600 text-white border-emerald-600' : 'bg-white text-gray-700 border-gray-200'
                      }`}
                    >
                      {formActive ? 'مفعّل' : 'غير مفعّل'}
                    </button>
                  </div>
                ) : null}

                {error ? (
                  <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
                ) : null}
              </div>
              <div className="p-5 border-t border-gray-100 flex items-center justify-end gap-2">
                <button
                  onClick={() => setModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-gray-200 bg-white hover:bg-gray-50 text-gray-700 font-bold"
                >
                  إلغاء
                </button>
                <button
                  onClick={save}
                  className="px-4 py-2 rounded-xl bg-gradient-to-l from-emerald-600 to-emerald-700 text-white font-bold shadow-sm"
                >
                  حفظ
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
