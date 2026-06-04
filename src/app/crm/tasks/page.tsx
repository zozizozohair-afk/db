'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { BarChart3, CheckCircle2, Circle, ClipboardList, Plus, Search, Users, X } from 'lucide-react';
import { supabase } from '../../../lib/supabaseClient';
import type { Client, CrmTask } from '../../../types';

type TaskRow = CrmTask & {
  client?: { id: string; name: string; phone: string | null } | null;
};

type EmployeeRole = 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';

type EmployeeLite = {
  id: string;
  email: string | null;
  job_title: string | null;
  role: EmployeeRole;
  is_active: boolean;
};

export default function CrmTasksPage() {
  const pathname = usePathname();
  const [isAdmin, setIsAdmin] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [role, setRole] = useState<EmployeeRole>('viewer');
  const [employees, setEmployees] = useState<EmployeeLite[]>([]);
  const [clients, setClients] = useState<Array<Pick<Client, 'id' | 'name' | 'phone'>>>([]);

  const [tasks, setTasks] = useState<TaskRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<'all' | 'open' | 'done'>('open');
  const [searchQuery, setSearchQuery] = useState('');

  const [isAddOpen, setIsAddOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formTitle, setFormTitle] = useState('');
  const [formDueAt, setFormDueAt] = useState('');
  const [formPriority, setFormPriority] = useState<CrmTask['priority']>('medium');
  const [formClientId, setFormClientId] = useState('');
  const [formAssigneeId, setFormAssigneeId] = useState<string | null>(null);
  const [formGeneral, setFormGeneral] = useState(false);
  const [clientSearch, setClientSearch] = useState('');

  const roleLabel = (r: EmployeeRole) => {
    if (r === 'admin') return 'مدير النظام';
    if (r === 'manager') return 'مدير';
    if (r === 'marketing') return 'مسؤول تسويق';
    if (r === 'customer_service') return 'خدمة عملاء';
    if (r === 'staff') return 'موظف';
    return 'مشاهد';
  };

  const fetchTasks = async (p: { userId: string | null; role: EmployeeRole }) => {
    setLoading(true);
    setErrorText(null);
    try {
      let q = supabase
        .from('crm_tasks')
        .select('id, created_at, client_id, unit_id, assigned_to, title, due_at, status, priority, client:clients(id, name, phone)')
        .order('created_at', { ascending: false });

      if (p.role !== 'admin' && p.role !== 'manager') {
        if (!p.userId) {
          setTasks([]);
          setLoading(false);
          return;
        }
        q = q.or(`assigned_to.is.null,assigned_to.eq.${p.userId}`);
      }

      const res = await q;
      if (res.error) throw res.error;
      setTasks(((res.data as any[]) || []) as TaskRow[]);
    } catch (e: any) {
      setErrorText(e?.message || 'تعذر تحميل المهام');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const run = async () => {
      const { data } = await supabase.auth.getUser();
      const user = data.user;
      if (!user) return;
      setUserId(user.id);

      const { data: profile } = await supabase
        .from('employee_profiles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
      const nextRole = ((profile?.role as string | null) || 'admin') as EmployeeRole;
      setRole(nextRole);
      setIsAdmin(nextRole === 'admin');

      const [employeesRes, clientsRes] = await Promise.all([
        supabase.rpc('crm_list_employees'),
        supabase.from('clients').select('id, name, phone').order('created_at', { ascending: false }).limit(500)
      ]);

      if (!employeesRes.error) setEmployees(((employeesRes.data as any[]) || []) as EmployeeLite[]);
      if (!clientsRes.error) setClients(((clientsRes.data as any[]) || []) as Array<Pick<Client, 'id' | 'name' | 'phone'>>);

      await fetchTasks({ userId: user.id, role: nextRole });
    };
    run();
  }, []);

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return tasks.filter((t) => {
      const statusOk = statusFilter === 'all' || t.status === statusFilter;
      if (!statusOk) return false;
      if (!q) return true;
      const clientName = (t.client?.name || '').toLowerCase();
      const clientPhone = (t.client?.phone || '').toLowerCase();
      const title = (t.title || '').toLowerCase();
      return title.includes(q) || clientName.includes(q) || clientPhone.includes(q);
    });
  }, [searchQuery, statusFilter, tasks]);

  const toggle = async (task: TaskRow) => {
    const nextStatus = task.status === 'done' ? 'open' : 'done';
    try {
      const now = new Date().toISOString();
      const updatePayload: any = {
        status: nextStatus,
        updated_at: now,
        completed_at: nextStatus === 'done' ? now : null
      };
      let res = await supabase.from('crm_tasks').update(updatePayload).eq('id', task.id);
      if (res.error && String(res.error.message || '').toLowerCase().includes('column')) {
        res = await supabase.from('crm_tasks').update({ status: nextStatus }).eq('id', task.id);
      }
      const { error } = res;
      if (error) throw error;
      setTasks((prev) =>
        prev.map((t) =>
          t.id === task.id ? { ...t, status: nextStatus as any, updated_at: now, completed_at: nextStatus === 'done' ? now : null } : t
        )
      );
    } catch (e: any) {
      alert(e?.message || 'تعذر تحديث المهمة');
    }
  };

  const statusBadge = (s: CrmTask['status']) => {
    return s === 'done' ? 'bg-green-100 text-green-700' : 'bg-orange-100 text-orange-700';
  };

  const priorityBadge = (p: CrmTask['priority']) => {
    if (p === 'high') return 'bg-red-50 text-red-700 border border-red-200';
    if (p === 'medium') return 'bg-amber-50 text-amber-700 border border-amber-200';
    return 'bg-gray-50 text-gray-700 border border-gray-200';
  };

  const priorityLabel = (p: CrmTask['priority']) => {
    if (p === 'high') return 'عالية';
    if (p === 'medium') return 'متوسطة';
    return 'منخفضة';
  };

  const canCreate = role !== 'viewer';
  const canAssignAny = role === 'admin' || role === 'manager';
  const isCustomerService = role === 'customer_service' || role === 'staff';
  const isMarketing = role === 'marketing';

  const allowedAssignees = useMemo(() => {
    const active = employees.filter((e) => e.is_active);
    const self = active.find((e) => e.id === userId) || { id: userId || '', email: null, job_title: null, role, is_active: true };

    if (!userId) return [];
    if (canAssignAny) return active;
    if (isMarketing) return [self, ...active.filter((e) => e.role === 'customer_service' && e.id !== userId)];
    if (isCustomerService) return [self];
    return [self];
  }, [canAssignAny, employees, isCustomerService, isMarketing, role, userId]);

  const openAdd = () => {
    setErrorText(null);
    setClientSearch('');
    setFormClientId('');
    setFormTitle('');
    setFormDueAt('');
    setFormPriority('medium');

    if (isCustomerService && userId) {
      setFormGeneral(false);
      setFormAssigneeId(userId);
    } else {
      setFormGeneral(false);
      setFormAssigneeId(userId || null);
    }

    setIsAddOpen(true);
  };

  const submit = async () => {
    if (!userId) return;
    const title = formTitle.trim();
    if (!title) {
      setErrorText('الرجاء كتابة عنوان المهمة.');
      return;
    }
    if (!formClientId) {
      setErrorText('الرجاء اختيار العميل.');
      return;
    }

    if (isCustomerService) {
      setFormGeneral(false);
      setFormAssigneeId(userId);
    }

    const finalAssignedTo = formGeneral ? null : formAssigneeId;

    if (!formGeneral && !finalAssignedTo) {
      setErrorText('الرجاء تحديد الموظف أو جعلها مهمة عامة.');
      return;
    }

    if (!formGeneral) {
      const allowed = new Set(allowedAssignees.map((e) => e.id));
      if (!allowed.has(finalAssignedTo as string)) {
        setErrorText('لا يمكنك إسناد المهمة لهذا الموظف.');
        return;
      }
    }

    setSaving(true);
    setErrorText(null);
    try {
      const dueAt = formDueAt ? new Date(formDueAt).toISOString() : null;
      const payload: any = {
        client_id: formClientId,
        unit_id: null,
        title,
        due_at: dueAt,
        status: 'open',
        priority: formPriority,
        assigned_to: finalAssignedTo
      };
      const { error } = await supabase.from('crm_tasks').insert([payload]);
      if (error) throw error;
      setIsAddOpen(false);
      await fetchTasks({ userId, role });
    } catch (e: any) {
      setErrorText(e?.message || 'تعذر إضافة المهمة');
    } finally {
      setSaving(false);
    }
  };

  const filteredClients = useMemo(() => {
    const q = clientSearch.trim().toLowerCase();
    if (!q) return clients;
    return clients.filter((c) => c.name.toLowerCase().includes(q) || (c.phone || '').includes(q));
  }, [clientSearch, clients]);

  const assigneeLabel = (task: TaskRow) => {
    if (!task.assigned_to) return 'عامّة';
    if (task.assigned_to === userId) return 'أنت';
    const emp = employees.find((e) => e.id === task.assigned_to);
    return emp?.job_title || emp?.email || 'موظف';
  };

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto" dir="rtl">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-600/20">
            <ClipboardList size={24} />
          </div>
          <div>
            <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">المهام</h1>
            <p className="text-gray-500 text-sm">
              تظهر لك المهام العامة والمهام المسندة إليك{role === 'admin' || role === 'manager' ? ' (والمدير يرى جميع المهام)' : ''}
            </p>
          </div>
        </div>
        {canCreate && (
          <button
            onClick={openAdd}
            className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-gradient-to-l from-blue-600 to-indigo-600 text-white font-bold shadow-md hover:shadow-lg"
          >
            <Plus size={18} />
            إضافة مهمة
          </button>
        )}
      </div>

      <div className="bg-white/90 backdrop-blur rounded-2xl shadow-md border border-gray-200 p-2">
        <div className={`grid grid-cols-2 ${isAdmin ? 'md:grid-cols-4' : 'md:grid-cols-3'} gap-2`}>
          {[
            ...(isAdmin ? [{ label: 'الموظفين', href: '/crm/employees', icon: Users }] : []),
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
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
          <div className="md:col-span-2 relative">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
            <input
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="ابحث بعنوان المهمة أو اسم العميل أو رقم الجوال..."
              className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as any)}
            className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
          >
            <option value="open">مفتوحة</option>
            <option value="done">تمت</option>
            <option value="all">الكل</option>
          </select>
          <div className="rounded-xl border border-gray-200 bg-gray-50 px-4 py-2.5 text-sm text-gray-700 flex items-center justify-between">
            <span className="font-bold">الإجمالي</span>
            <span className="font-extrabold">{filtered.length}</span>
          </div>
        </div>

        {errorText && (
          <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-700 text-sm flex items-center gap-2">
            {errorText}
          </div>
        )}

        {loading ? (
          <div className="py-10 text-center text-gray-500">جاري التحميل...</div>
        ) : filtered.length === 0 ? (
          <div className="py-10 text-center text-gray-500">لا يوجد مهام</div>
        ) : (
          <div className="overflow-auto rounded-2xl border border-gray-200">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50 text-gray-700">
                <tr>
                  <th className="text-right px-4 py-3 font-bold">الحالة</th>
                  <th className="text-right px-4 py-3 font-bold">المهمة</th>
                  <th className="text-right px-4 py-3 font-bold">العميل</th>
                  <th className="text-right px-4 py-3 font-bold">مكلف بها</th>
                  <th className="text-right px-4 py-3 font-bold">الموعد</th>
                  <th className="text-right px-4 py-3 font-bold">الأولوية</th>
                  <th className="text-right px-4 py-3 font-bold"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 bg-white">
                {filtered.map((t) => (
                  <tr key={t.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <span className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-bold ${statusBadge(t.status)}`}>
                        {t.status === 'done' ? 'تمت' : 'مفتوحة'}
                      </span>
                    </td>
                    <td className="px-4 py-3 min-w-[260px]">
                      <div className="font-bold text-gray-900 truncate">{t.title}</div>
                      <div className="text-xs text-gray-500 mt-1">تم الإنشاء: {new Date(t.created_at).toLocaleString('ar-SA')}</div>
                    </td>
                    <td className="px-4 py-3 min-w-[220px]">
                      <div className="font-bold text-gray-900 truncate">{t.client?.name || '-'}</div>
                      <div className="text-xs text-gray-500" dir="ltr">
                        {t.client?.phone || '-'}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-bold ${t.assigned_to ? 'bg-slate-100 text-slate-800 border border-slate-200' : 'bg-blue-50 text-blue-700 border border-blue-200'}`}>
                        {assigneeLabel(t)}
                      </span>
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-gray-700">
                      {t.due_at ? new Date(t.due_at).toLocaleString('ar-SA') : '-'}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-bold ${priorityBadge(t.priority)}`}>
                        {priorityLabel(t.priority)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-left whitespace-nowrap">
                      <button
                        onClick={() => toggle(t)}
                        className={`inline-flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-bold transition-colors ${
                          t.status === 'done' ? 'bg-gray-100 text-gray-700 hover:bg-gray-200' : 'bg-green-600 text-white hover:bg-green-700'
                        }`}
                      >
                        {t.status === 'done' ? (
                          <>
                            <Circle size={16} />
                            إعادة فتح
                          </>
                        ) : (
                          <>
                            <CheckCircle2 size={16} />
                            تمت
                          </>
                        )}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {isAddOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full overflow-hidden">
            <div className="p-5 border-b border-gray-100 flex items-center justify-between">
              <div className="font-bold text-gray-900">إضافة مهمة</div>
              <button
                onClick={() => setIsAddOpen(false)}
                className="p-2 rounded-xl border border-gray-200 bg-white hover:bg-gray-50"
              >
                <X size={18} className="text-gray-600" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="space-y-2">
                  <div className="text-sm font-bold text-gray-700">اختر العميل</div>
                  <input
                    value={clientSearch}
                    onChange={(e) => setClientSearch(e.target.value)}
                    placeholder="بحث باسم العميل أو الجوال"
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-gray-50 focus:ring-2 focus:ring-blue-500 outline-none"
                  />
                  <select
                    value={formClientId}
                    onChange={(e) => setFormClientId(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                  >
                    <option value="">اختر...</option>
                    {filteredClients.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name} {c.phone ? `- ${c.phone}` : ''}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="space-y-2">
                  <div className="text-sm font-bold text-gray-700">الأولوية</div>
                  <select
                    value={formPriority}
                    onChange={(e) => setFormPriority(e.target.value as any)}
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                  >
                    <option value="low">منخفضة</option>
                    <option value="medium">متوسطة</option>
                    <option value="high">عالية</option>
                  </select>
                  <div className="text-sm font-bold text-gray-700">الموعد</div>
                  <input
                    type="datetime-local"
                    value={formDueAt}
                    onChange={(e) => setFormDueAt(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <div className="text-sm font-bold text-gray-700">عنوان المهمة</div>
                <input
                  value={formTitle}
                  onChange={(e) => setFormTitle(e.target.value)}
                  placeholder="اكتب المهمة بشكل واضح..."
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="rounded-xl border border-gray-200 p-4 space-y-2">
                  <div className="text-sm font-bold text-gray-800">نوع الإسناد</div>
                  <div className="text-xs text-gray-500">الدور الحالي: {roleLabel(role)}</div>
                  <div className="flex items-center justify-between gap-2">
                    <div className="text-sm font-bold text-gray-700">مهمة عامة</div>
                    <button
                      onClick={() => {
                        if (isCustomerService) return;
                        setFormGeneral((v) => !v);
                      }}
                      className={`px-4 py-2 rounded-xl font-bold border ${
                        formGeneral ? 'bg-blue-600 text-white border-blue-600' : 'bg-white text-gray-700 border-gray-200'
                      } ${isCustomerService ? 'opacity-50 cursor-not-allowed' : ''}`}
                    >
                      {formGeneral ? 'نعم' : 'لا'}
                    </button>
                  </div>
                  <div className="text-xs text-gray-500">
                    {isCustomerService ? 'خدمة العملاء: يمكنك إضافة مهمة لنفسك فقط.' : 'المهمة العامة تظهر لجميع الموظفين.'}
                  </div>
                </div>

                <div className="rounded-xl border border-gray-200 p-4 space-y-2">
                  <div className="text-sm font-bold text-gray-800">إسناد إلى موظف</div>
                  <select
                    value={formAssigneeId || ''}
                    onChange={(e) => setFormAssigneeId(e.target.value || null)}
                    disabled={formGeneral || isCustomerService}
                    className={`w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none ${
                      formGeneral || isCustomerService ? 'opacity-60' : ''
                    }`}
                  >
                    <option value="">اختر...</option>
                    {allowedAssignees.map((e) => (
                      <option key={e.id} value={e.id}>
                        {e.job_title ? `${e.job_title} - ` : ''}
                        {e.email || e.id} ({roleLabel(e.role)})
                      </option>
                    ))}
                  </select>
                  {!canAssignAny && !isCustomerService && isMarketing ? (
                    <div className="text-xs text-gray-500">التسويق: يمكنك الإسناد لنفسك أو لخدمة العملاء فقط.</div>
                  ) : null}
                  {canAssignAny ? <div className="text-xs text-gray-500">المدير: يمكنك الإسناد لأي موظف.</div> : null}
                </div>
              </div>

              {errorText ? <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{errorText}</div> : null}
            </div>
            <div className="p-5 border-t border-gray-100 flex items-center justify-end gap-2">
              <button
                onClick={() => setIsAddOpen(false)}
                className="px-4 py-2 rounded-xl border border-gray-200 bg-white hover:bg-gray-50 text-gray-700 font-bold"
              >
                إلغاء
              </button>
              <button
                onClick={submit}
                disabled={saving}
                className="px-4 py-2 rounded-xl bg-gradient-to-l from-blue-600 to-indigo-600 text-white font-bold shadow-sm disabled:opacity-60"
              >
                {saving ? 'جاري الحفظ...' : 'حفظ'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
