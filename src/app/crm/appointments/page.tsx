'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { BarChart3, CalendarClock, ClipboardList, Search, Users } from 'lucide-react';
import { supabase } from '../../../lib/supabaseClient';

type EmployeeRole = 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';

type EmployeeLite = {
  id: string;
  email: string | null;
  job_title: string | null;
  role: EmployeeRole;
  is_active: boolean;
};

type AppointmentRow = {
  id: string;
  created_at: string;
  client_id: string;
  unit_id: string | null;
  appointment_at: string;
  host_name: string | null;
  created_by: string | null;
  client?: { id: string; name: string; phone: string | null } | null;
};

export default function CrmAppointmentsPage() {
  const pathname = usePathname();
  const [userId, setUserId] = useState<string | null>(null);
  const [role, setRole] = useState<EmployeeRole>('viewer');
  const [isAdmin, setIsAdmin] = useState(false);
  const [employees, setEmployees] = useState<EmployeeLite[]>([]);

  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [missingTable, setMissingTable] = useState(false);
  const [rows, setRows] = useState<AppointmentRow[]>([]);

  const [statusFilter, setStatusFilter] = useState<'upcoming' | 'past' | 'all'>('upcoming');
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    const run = async () => {
      const { data } = await supabase.auth.getUser();
      const user = data.user;
      if (!user) return;
      setUserId(user.id);

      const { data: profile } = await supabase.from('employee_profiles').select('role').eq('user_id', user.id).maybeSingle();
      const nextRole = ((profile?.role as string | null) || 'admin') as EmployeeRole;
      setRole(nextRole);
      setIsAdmin(nextRole === 'admin');

      const employeesRes = await supabase.rpc('crm_list_employees');
      if (!employeesRes.error) setEmployees(((employeesRes.data as any[]) || []) as EmployeeLite[]);
    };
    run();
  }, []);

  const canSeeAll = role === 'admin' || role === 'manager';

  const employeeLabelById = useMemo(() => {
    const map = new Map<string, string>();
    for (const e of employees) {
      if (!e?.id) continue;
      const job = String(e.job_title || '').trim();
      const email = String(e.email || '').trim();
      const emailLabel = email ? email.split('@')[0] : '';
      map.set(e.id, job || emailLabel || email || String(e.id).slice(0, 8));
    }
    return map;
  }, [employees]);

  const fetchRows = async (p: { userId: string | null; role: EmployeeRole }) => {
    setLoading(true);
    setErrorText(null);
    setMissingTable(false);
    try {
      const nowIso = new Date().toISOString();
      let q = supabase
        .from('crm_appointments')
        .select('id, created_at, client_id, unit_id, appointment_at, host_name, created_by, client:clients(id, name, phone)')
        .limit(5000);

      if (statusFilter === 'upcoming') q = q.gte('appointment_at', nowIso).order('appointment_at', { ascending: true });
      if (statusFilter === 'past') q = q.lt('appointment_at', nowIso).order('appointment_at', { ascending: false });
      if (statusFilter === 'all') q = q.order('appointment_at', { ascending: false });

      if (!canSeeAll) {
        if (!p.userId) q = q.limit(0);
        else q = q.eq('created_by', p.userId);
      }

      const res = await q;
      if (res.error) {
        const msg = String(res.error.message || '').toLowerCase();
        if (msg.includes('does not exist') || msg.includes('relation') || msg.includes('not exist')) {
          setMissingTable(true);
          setRows([]);
          return;
        }
        throw res.error;
      }
      setRows(((res.data as any[]) || []) as AppointmentRow[]);
    } catch (e: any) {
      setErrorText(e?.message || 'تعذر تحميل المواعيد');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!userId) return;
    fetchRows({ userId, role });
  }, [statusFilter, userId, role]);

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter((r) => {
      const clientName = String(r.client?.name || '').toLowerCase();
      const clientPhone = String(r.client?.phone || '').toLowerCase();
      const host = String(r.host_name || '').toLowerCase();
      const by = r.created_by ? String(employeeLabelById.get(r.created_by) || r.created_by).toLowerCase() : '';
      return clientName.includes(q) || clientPhone.includes(q) || host.includes(q) || by.includes(q);
    });
  }, [employeeLabelById, rows, searchQuery]);

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto" dir="rtl">
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 bg-purple-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-purple-600/20">
          <CalendarClock size={24} />
        </div>
        <div>
          <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">CRM المواعيد</h1>
          <p className="text-gray-500 text-sm">عرض المواعيد المسجلة من CRM</p>
        </div>
      </div>

      <div className="bg-white/90 backdrop-blur rounded-2xl shadow-md border border-gray-200 p-2">
        <div className={`grid grid-cols-2 ${isAdmin ? 'md:grid-cols-5' : 'md:grid-cols-4'} gap-2`}>
          {[
            ...(isAdmin ? [{ label: 'الموظفين', href: '/crm/employees', icon: Users }] : []),
            { label: 'العملاء', href: '/crm', icon: Users },
            { label: 'المهام', href: '/crm/tasks', icon: ClipboardList },
            { label: 'المواعيد', href: '/crm/appointments', icon: CalendarClock },
            { label: 'التقارير', href: '/crm/reports', icon: BarChart3 }
          ].map((t) => {
            const isActive =
              t.href === '/crm' ? pathname === '/crm' : pathname === t.href || pathname.startsWith(t.href + '/');
            const Icon = t.icon;
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

      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 space-y-4">
        <div className="flex flex-col md:flex-row md:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
            <input
              type="text"
              placeholder="بحث باسم العميل، الجوال، صاحب الموعد، أو الموظف..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pr-10 pl-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            />
          </div>
          <div className="flex items-center gap-2">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="px-4 py-3 rounded-xl border border-gray-200 bg-white font-bold text-gray-800"
            >
              <option value="upcoming">القادمة</option>
              <option value="past">السابقة</option>
              <option value="all">الكل</option>
            </select>
          </div>
        </div>

        {missingTable ? (
          <div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-amber-900 text-sm font-bold">
            جدول المواعيد غير موجود (crm_appointments). أنشئه في قاعدة البيانات ثم أعد تحميل الصفحة.
          </div>
        ) : null}
        {errorText ? (
          <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-red-800 text-sm font-bold">{errorText}</div>
        ) : null}

        {loading ? (
          <div className="h-20 bg-gray-50 rounded-xl animate-pulse" />
        ) : filtered.length === 0 ? (
          <div className="text-gray-600 font-bold">لا توجد مواعيد حسب الفلاتر الحالية</div>
        ) : (
          <div className="overflow-auto rounded-xl border border-gray-200">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50 text-gray-700 border-b border-gray-200">
                <tr>
                  <th className="text-right px-4 py-3 font-extrabold">تاريخ الموعد</th>
                  <th className="text-right px-4 py-3 font-extrabold">العميل</th>
                  <th className="text-right px-4 py-3 font-extrabold">الجوال</th>
                  <th className="text-right px-4 py-3 font-extrabold">صاحب الموعد</th>
                  <th className="text-right px-4 py-3 font-extrabold">الموظف</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 bg-white">
                {filtered.map((r) => {
                  const by = r.created_by ? employeeLabelById.get(r.created_by) || r.created_by.slice(0, 8) : '-';
                  return (
                    <tr key={r.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3 whitespace-nowrap font-extrabold text-gray-900">
                        {new Date(r.appointment_at).toLocaleString('ar-SA')}
                      </td>
                      <td className="px-4 py-3 min-w-[240px]">
                        {r.client?.id ? (
                          <Link href={`/crm/clients/${r.client.id}`} className="font-extrabold text-emerald-700 hover:underline">
                            {r.client.name}
                          </Link>
                        ) : (
                          <span className="font-extrabold text-gray-900">{r.client?.name || '-'}</span>
                        )}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap font-bold text-gray-700" dir="ltr">
                        {r.client?.phone || '-'}
                      </td>
                      <td className="px-4 py-3 font-extrabold text-gray-900">{r.host_name || '-'}</td>
                      <td className="px-4 py-3 font-extrabold text-gray-700">{by}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

