'use client';

import Link from 'next/link';
import React, { useEffect, useMemo, useState } from 'react';
import {
  Activity,
  BarChart3,
  CalendarClock,
  ClipboardList,
  CreditCard,
  FileCheck,
  Search,
  User,
  Users
} from 'lucide-react';
import {
  Bar,
  BarChart,
  Area,
  AreaChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis
} from 'recharts';
import { supabase } from '../../lib/supabaseClient';
import type { CrmActivity, CrmTask } from '../../types';

type EmployeeRole = 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';
type Scope = 'mine' | 'all';

type EmployeeLite = {
  id: string;
  email: string | null;
  job_title: string | null;
  role: EmployeeRole;
  is_active: boolean;
};

type ActivityRow = Pick<CrmActivity, 'id' | 'created_at' | 'client_id' | 'created_by' | 'channel' | 'outcome'> & {
  client?: { id: string; name: string; phone: string | null } | null;
};

type TaskRow = Pick<
  CrmTask,
  'id' | 'created_at' | 'client_id' | 'assigned_to' | 'title' | 'due_at' | 'status' | 'priority' | 'unit_id'
> & {
  client?: { id: string; name: string; phone: string | null } | null;
};

type AppointmentRow = {
  id: string;
  appointment_at: string;
  host_name: string | null;
  created_by: string | null;
  client?: { id: string; name: string; phone: string | null } | null;
};

const toLocalInput = (d: Date) => {
  const tz = d.getTimezoneOffset() * 60_000;
  return new Date(d.getTime() - tz).toISOString().slice(0, 16);
};

const startEndOfLocalDayIso = (localDateTime: string) => {
  const d = new Date(localDateTime);
  const start = new Date(d);
  start.setHours(0, 0, 0, 0);
  const end = new Date(d);
  end.setHours(23, 59, 59, 999);
  return { startIso: start.toISOString(), endIso: end.toISOString() };
};

const dayKey = (iso: string) => {
  const d = new Date(iso);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const dayLabel = (isoOrKey: string) => {
  const d = isoOrKey.includes('T') ? new Date(isoOrKey) : new Date(`${isoOrKey}T00:00:00`);
  return d.toLocaleDateString('ar-SA', { month: 'short', day: '2-digit' });
};

function StatCard(p: { title: string; value: string; hint?: string; icon: React.ReactNode; tone: 'blue' | 'emerald' | 'amber' | 'purple' | 'slate' }) {
  const tone = p.tone;
  const badge =
    tone === 'blue'
      ? 'bg-blue-50 text-blue-700 border-blue-200'
      : tone === 'emerald'
        ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
        : tone === 'amber'
          ? 'bg-amber-50 text-amber-800 border-amber-200'
          : tone === 'purple'
            ? 'bg-purple-50 text-purple-700 border-purple-200'
            : 'bg-slate-50 text-slate-700 border-slate-200';

  return (
    <div className="bg-white rounded-xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow p-3 md:p-5">
      <div className="flex items-start justify-between gap-3">
        <div className={`shrink-0 w-10 h-10 md:w-11 md:h-11 rounded-lg border flex items-center justify-center ${badge}`}>{p.icon}</div>
        {p.hint ? <div className="text-[11px] font-bold text-gray-500">{p.hint}</div> : null}
      </div>
      <div className="mt-3">
        <div className="text-xs font-bold text-gray-500">{p.title}</div>
        <div className="mt-1 text-2xl md:text-3xl font-extrabold text-gray-900">{p.value}</div>
      </div>
    </div>
  );
}

function Section(p: { title: string; right?: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
      <div className="p-3 md:p-5 border-b border-slate-200 bg-slate-50 flex items-center justify-between gap-3">
        <div className="font-extrabold text-gray-900">{p.title}</div>
        {p.right ? <div className="shrink-0">{p.right}</div> : null}
      </div>
      <div className="p-3 md:p-5">{p.children}</div>
    </div>
  );
}

export default function DashboardOverviewPage() {
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [role, setRole] = useState<EmployeeRole>('viewer');
  const [scope, setScope] = useState<Scope>('mine');
  const [employees, setEmployees] = useState<EmployeeLite[]>([]);
  const [searchText, setSearchText] = useState('');

  const [rangeStart, setRangeStart] = useState(() => toLocalInput(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)));
  const [rangeEnd, setRangeEnd] = useState(() => toLocalInput(new Date()));

  const [counts, setCounts] = useState({
    projects: 0,
    units: 0,
    debtsOpen: 0,
    deedsArchived: 0
  });

  const [tasks, setTasks] = useState<TaskRow[]>([]);
  const [myTasks, setMyTasks] = useState<TaskRow[]>([]);
  const [activities, setActivities] = useState<ActivityRow[]>([]);
  const [upcomingAppointments, setUpcomingAppointments] = useState<AppointmentRow[]>([]);
  const [appointmentsMissing, setAppointmentsMissing] = useState(false);

  useEffect(() => {
    const run = async () => {
      const { data } = await supabase.auth.getUser();
      const user = data.user;
      if (!user) return;
      setUserId(user.id);
      setUserEmail(user.email || null);
      const { data: profile } = await supabase.from('employee_profiles').select('role').eq('user_id', user.id).maybeSingle();
      const nextRole = ((profile?.role as string | null) || 'admin') as EmployeeRole;
      setRole(nextRole);
      setScope(nextRole === 'admin' || nextRole === 'manager' ? 'all' : 'mine');
      const employeesRes = await supabase.rpc('crm_list_employees');
      if (!employeesRes.error) setEmployees(((employeesRes.data as any[]) || []) as EmployeeLite[]);
    };
    run();
  }, []);

  const roleLabel = (r: EmployeeRole) => {
    if (r === 'admin') return 'مدير النظام';
    if (r === 'manager') return 'مدير';
    if (r === 'marketing') return 'مسؤول تسويق';
    if (r === 'customer_service') return 'خدمة عملاء';
    if (r === 'staff') return 'موظف';
    return 'مشاهد';
  };

  const employeeDisplayName = useMemo(() => {
    if (!userId) return '';
    const emp = employees.find((e) => e.id === userId);
    const job = String(emp?.job_title || '').trim();
    if (job) return job;
    const email = String(emp?.email || userEmail || '').trim();
    if (email) return email.split('@')[0];
    return String(userId).slice(0, 8);
  }, [employees, userEmail, userId]);

  const employeeLabelById = useMemo(() => {
    const map = new Map<string, string>();
    for (const e of employees) {
      if (!e?.id) continue;
      const job = String(e.job_title || '').trim();
      const email = String(e.email || '').trim();
      const emailLabel = email ? email.split('@')[0] : '';
      const label = job || emailLabel || email || String(e.id).slice(0, 8);
      map.set(e.id, label);
    }
    return map;
  }, [employees]);

  const fetchAll = async () => {
    setLoading(true);
    setErrorText(null);
    try {
      const { startIso } = startEndOfLocalDayIso(rangeStart);
      const { endIso } = startEndOfLocalDayIso(rangeEnd);
      const missingTableMsg = (m: string) => m.includes('does not exist') || m.includes('relation') || m.includes('not exist');

      const projectsQ = supabase.from('projects').select('id', { count: 'exact', head: true });
      const unitsQ = supabase.from('units').select('id', { count: 'exact', head: true });
      const debtsQ = supabase.from('debts').select('id', { count: 'exact', head: true }).gt('remaining_value', 0);
      const deedsArchivedQ = supabase.from('units').select('id', { count: 'exact', head: true }).not('deed_number', 'is', null);

      let tasksQ = supabase
        .from('crm_tasks')
        .select('id, created_at, client_id, unit_id, assigned_to, title, due_at, status, priority, client:clients(id, name, phone)')
        .gte('created_at', startIso)
        .lte('created_at', endIso)
        .order('created_at', { ascending: false })
        .limit(5000);

      let myTasksQ = supabase
        .from('crm_tasks')
        .select('id, created_at, client_id, unit_id, assigned_to, title, due_at, status, priority, client:clients(id, name, phone)')
        .eq('status', 'open')
        .eq('assigned_to', userId || '')
        .order('due_at', { ascending: true })
        .limit(25);

      let activitiesQ = supabase
        .from('crm_activities')
        .select('id, created_at, client_id, created_by, channel, outcome, client:clients(id, name, phone)')
        .gte('created_at', startIso)
        .lte('created_at', endIso)
        .order('created_at', { ascending: false })
        .limit(5000);

      const nowIso = new Date().toISOString();
      let appointmentsQ = supabase
        .from('crm_appointments')
        .select('id, appointment_at, host_name, created_by, client:clients(id, name, phone)')
        .gte('appointment_at', nowIso)
        .order('appointment_at', { ascending: true })
        .limit(3);

      if (scope === 'mine') {
        if (!userId) {
          tasksQ = tasksQ.limit(0);
          myTasksQ = myTasksQ.limit(0);
          activitiesQ = activitiesQ.limit(0);
          appointmentsQ = appointmentsQ.limit(0);
        } else {
          tasksQ = tasksQ.or(`assigned_to.is.null,assigned_to.eq.${userId}`);
          activitiesQ = activitiesQ.eq('created_by', userId);
          appointmentsQ = appointmentsQ.eq('created_by', userId);
        }
      } else {
        if (!userId) myTasksQ = myTasksQ.limit(0);
      }

      const [projectsRes, unitsRes, debtsRes, deedsRes, tasksRes, myTasksRes, actRes, apptRes] = await Promise.all([
        projectsQ,
        unitsQ,
        debtsQ,
        deedsArchivedQ,
        tasksQ,
        myTasksQ,
        activitiesQ,
        appointmentsQ
      ]);

      if (projectsRes.error) throw projectsRes.error;
      if (unitsRes.error) throw unitsRes.error;
      if (debtsRes.error) throw debtsRes.error;
      if (deedsRes.error) throw deedsRes.error;
      if (tasksRes.error) throw tasksRes.error;
      if (myTasksRes.error) throw myTasksRes.error;
      if (actRes.error) throw actRes.error;

      setCounts({
        projects: projectsRes.count || 0,
        units: unitsRes.count || 0,
        debtsOpen: debtsRes.count || 0,
        deedsArchived: deedsRes.count || 0
      });
      setTasks(((tasksRes.data as any[]) || []) as TaskRow[]);
      setMyTasks(((myTasksRes.data as any[]) || []) as TaskRow[]);
      setActivities(((actRes.data as any[]) || []) as ActivityRow[]);

      if (apptRes.error) {
        const msg = String(apptRes.error.message || '').toLowerCase();
        if (missingTableMsg(msg)) setAppointmentsMissing(true);
        else setAppointmentsMissing(false);
        setUpcomingAppointments([]);
      } else {
        setAppointmentsMissing(false);
        setUpcomingAppointments(((apptRes.data as any[]) || []) as AppointmentRow[]);
      }
    } catch (e: any) {
      setErrorText(e?.message || 'تعذر تحميل لوحة التحكم');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!userId) return;
    fetchAll();
  }, [userId, scope]);

  const kpis = useMemo(() => {
    const now = Date.now();
    const open = tasks.filter((t) => t.status === 'open');
    const done = tasks.filter((t) => t.status === 'done');
    const overdue = open.filter((t) => t.due_at && new Date(t.due_at).getTime() < now);
    const dueNext7 = open.filter((t) => {
      if (!t.due_at) return false;
      const ms = new Date(t.due_at).getTime() - now;
      return ms >= 0 && ms <= 7 * 24 * 60 * 60 * 1000;
    });
    const calls = activities.filter((a) => a.channel === 'call').length;
    const whatsapp = activities.filter((a) => a.channel === 'whatsapp').length;
    const email = activities.filter((a) => a.channel === 'email').length;
    return { open: open.length, done: done.length, overdue: overdue.length, dueNext7: dueNext7.length, calls, whatsapp, email };
  }, [activities, tasks]);

  const myTasksView = useMemo(() => {
    const now = Date.now();
    const q = searchText.trim().toLowerCase();
    const list = [...myTasks].filter((t) => {
      if (t.status !== 'open') return false;
      if (!q) return true;
      const title = String(t.title || '').toLowerCase();
      const clientName = String(t.client?.name || '').toLowerCase();
      const clientPhone = String(t.client?.phone || '').toLowerCase();
      return title.includes(q) || clientName.includes(q) || clientPhone.includes(q);
    });
    list.sort((a, b) => {
      const aDue = a.due_at ? new Date(a.due_at).getTime() : Number.POSITIVE_INFINITY;
      const bDue = b.due_at ? new Date(b.due_at).getTime() : Number.POSITIVE_INFINITY;
      if (aDue !== bDue) return aDue - bDue;
      return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    });
    return list.slice(0, 10).map((t) => {
      const dueMs = t.due_at ? new Date(t.due_at).getTime() : null;
      const overdue = dueMs != null && dueMs < now;
      const dueSoon = dueMs != null && dueMs >= now && dueMs <= now + 2 * 24 * 60 * 60 * 1000;
      return { ...t, overdue, dueSoon };
    });
  }, [myTasks, searchText]);

  const activitySeries = useMemo(() => {
    const keys = new Map<string, { key: string; total: number; call: number; whatsapp: number; email: number }>();
    for (const a of activities) {
      const k = dayKey(a.created_at);
      const row = keys.get(k) || { key: k, total: 0, call: 0, whatsapp: 0, email: 0 };
      row.total += 1;
      if (a.channel === 'call') row.call += 1;
      if (a.channel === 'whatsapp') row.whatsapp += 1;
      if (a.channel === 'email') row.email += 1;
      keys.set(k, row);
    }

    const { startIso } = startEndOfLocalDayIso(rangeStart);
    const { endIso } = startEndOfLocalDayIso(rangeEnd);
    const start = new Date(startIso);
    const end = new Date(endIso);
    const list: Array<{ day: string; total: number; call: number; whatsapp: number; email: number }> = [];
    const cursor = new Date(start);
    cursor.setHours(0, 0, 0, 0);
    const endDay = new Date(end);
    endDay.setHours(0, 0, 0, 0);

    while (cursor.getTime() <= endDay.getTime()) {
      const k = dayKey(cursor.toISOString());
      const row = keys.get(k) || { key: k, total: 0, call: 0, whatsapp: 0, email: 0 };
      list.push({ day: dayLabel(k), total: row.total, call: row.call, whatsapp: row.whatsapp, email: row.email });
      cursor.setDate(cursor.getDate() + 1);
    }

    const maxBars = 14;
    if (list.length <= maxBars) return list;
    return list.slice(list.length - maxBars);
  }, [activities, rangeEnd, rangeStart]);

  const taskPie = useMemo(() => {
    const open = tasks.filter((t) => t.status === 'open').length;
    const done = tasks.filter((t) => t.status === 'done').length;
    const arr = [
      { name: 'مفتوحة', value: open, color: '#f59e0b' },
      { name: 'تمت', value: done, color: '#10b981' }
    ];
    return arr.filter((x) => x.value > 0);
  }, [tasks]);

  const taskDonut = useMemo(() => {
    const open = tasks.filter((t) => t.status === 'open').length;
    const done = tasks.filter((t) => t.status === 'done').length;
    const total = open + done;
    const completion = total ? Math.round((done / total) * 100) : 0;
    const data = [
      { name: 'مفتوحة', value: open, color: '#f59e0b' },
      { name: 'تمت', value: done, color: '#10b981' }
    ].filter((x) => x.value > 0);
    const paddingAngle = data.length > 1 ? 2 : 0;
    return { open, done, total, completion, data, paddingAngle };
  }, [tasks]);

  const feed = useMemo(() => {
    const q = searchText.trim().toLowerCase();
    const acts = activities.slice(0, 15).map((a) => ({
      type: 'activity' as const,
      at: a.created_at,
      title: a.client?.name || 'عميل',
      meta:
        a.channel === 'call'
          ? 'اتصال'
          : a.channel === 'whatsapp'
            ? 'واتساب'
            : a.channel === 'email'
              ? 'بريد'
              : 'تواصل',
      by: a.created_by ? employeeLabelById.get(a.created_by) || a.created_by.slice(0, 8) : null
    }));
    const ts = tasks.slice(0, 15).map((t) => ({
      type: 'task' as const,
      at: t.created_at,
      title: t.title,
      meta: t.client?.name || 'عميل',
      by: t.assigned_to ? employeeLabelById.get(t.assigned_to) || t.assigned_to.slice(0, 8) : 'عامّة'
    }));
    const list = [...acts, ...ts]
      .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
      .slice(0, 12);
    if (!q) return list;
    return list.filter((x) => {
      const title = String(x.title || '').toLowerCase();
      const meta = String(x.meta || '').toLowerCase();
      const by = String(x.by || '').toLowerCase();
      return title.includes(q) || meta.includes(q) || by.includes(q);
    });
  }, [activities, employeeLabelById, searchText, tasks]);

  const scopeLabel = scope === 'all' ? 'الكل' : 'الخاص بي';
  const canAll = role === 'admin' || role === 'manager';

  return (
    <div className="min-h-screen max-w-7xl mx-auto p-4 md:p-8 space-y-6" dir="rtl">
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm px-4 py-3 md:px-5 md:py-4">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-10 h-10 rounded-xl bg-blue-50 border border-blue-200 flex items-center justify-center text-blue-700">
              <User size={18} />
            </div>
            <div className="min-w-0">
              <div className="font-extrabold text-slate-900 truncate">{employeeDisplayName}</div>
              <div className="text-[11px] font-extrabold text-slate-600">{roleLabel(role)}</div>
            </div>
          </div>
          <div className="relative w-full md:max-w-md">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
            <input
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
              placeholder="بحث سريع في المهام والأحداث..."
              className="w-full pr-10 pl-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-extrabold text-slate-900"
            />
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-blue-200 bg-gradient-to-l from-white via-blue-50 to-indigo-100 text-slate-900 overflow-hidden shadow-sm">
        <div className="p-6 md:p-8 flex flex-col md:flex-row md:items-center justify-between gap-5">
          <div className="min-w-0">
            <div className="text-xs font-extrabold text-blue-700">لوحة التحكم</div>
            <div className="mt-1 text-2xl md:text-3xl font-extrabold">ملخص أهم الأحداث والمؤشرات</div>
            <div className="mt-2 text-sm text-slate-700 font-bold">
              النطاق: <span className="font-extrabold text-slate-900">{scopeLabel}</span> • آخر تحديث:{' '}
              <span className="font-extrabold text-slate-900">{new Date().toLocaleString('ar-SA')}</span>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-2 sm:items-center">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <div className="bg-white border border-blue-200 rounded-xl p-3 shadow-sm">
                <div className="text-[11px] font-extrabold text-slate-600 mb-1">من</div>
                <input
                  type="datetime-local"
                  value={rangeStart}
                  onChange={(e) => setRangeStart(e.target.value)}
                  className="w-full bg-white border border-slate-200 rounded-xl px-3 py-2 text-sm font-extrabold text-slate-900 outline-none"
                />
              </div>
              <div className="bg-white border border-blue-200 rounded-xl p-3 shadow-sm">
                <div className="text-[11px] font-extrabold text-slate-600 mb-1">إلى</div>
                <input
                  type="datetime-local"
                  value={rangeEnd}
                  onChange={(e) => setRangeEnd(e.target.value)}
                  className="w-full bg-white border border-slate-200 rounded-xl px-3 py-2 text-sm font-extrabold text-slate-900 outline-none"
                />
              </div>
            </div>

            <div className="flex gap-2">
              {canAll ? (
                <button
                  type="button"
                  onClick={() => setScope((v) => (v === 'all' ? 'mine' : 'all'))}
                  className="px-4 py-3 rounded-xl bg-white border border-slate-200 hover:bg-slate-50 text-sm font-extrabold text-slate-900 shadow-sm"
                >
                  تبديل النطاق
                </button>
              ) : null}
              <button
                type="button"
                onClick={fetchAll}
                className="px-4 py-3 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-sm font-extrabold shadow-md"
              >
                تحديث
              </button>
            </div>
          </div>
        </div>

        <div className="px-6 md:px-8 pb-6 md:pb-8 flex gap-2 overflow-x-auto md:flex-wrap md:overflow-visible">
          <QuickLink href="/crm" label="CRM العملاء" icon={<Users size={16} />} />
          <QuickLink href="/crm/tasks" label="المهام" icon={<ClipboardList size={16} />} />
          <QuickLink href="/crm/reports" label="التقارير" icon={<BarChart3 size={16} />} />
          <QuickLink href="/debt/report" label="تقرير المديونية" icon={<CreditCard size={16} />} />
          <QuickLink href="/deeds" label="مراجعة الصكوك" icon={<FileCheck size={16} />} />
          <QuickLink href="/search" label="البحث الشامل" icon={<Search size={16} />} />
        </div>
      </div>

      {errorText ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-red-700 font-bold">{errorText}</div>
      ) : null}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4">
        <StatCard title="مهام مفتوحة" value={String(kpis.open)} hint={scopeLabel} icon={<ClipboardList size={18} />} tone="amber" />
        <StatCard title="متأخرة" value={String(kpis.overdue)} hint="حسب الموعد" icon={<CalendarClock size={18} />} tone="purple" />
        <StatCard title="تواصل" value={String(activities.length)} hint={dayLabel(rangeStart) + ' → ' + dayLabel(rangeEnd)} icon={<Activity size={18} />} tone="emerald" />
        <StatCard title="مديونيات قائمة" value={String(counts.debtsOpen)} hint="remaining_value > 0" icon={<CreditCard size={18} />} tone="blue" />
      </div>

      <Section
        title="مهام حسابك"
        right={
          <Link href="/crm/tasks" className="px-3 py-2 rounded-xl bg-white border border-slate-200 text-slate-900 text-xs font-extrabold hover:bg-slate-50">
            فتح صفحة المهام
          </Link>
        }
      >
        {loading ? (
          <div className="h-20 bg-gray-50 rounded-xl animate-pulse" />
        ) : myTasksView.length === 0 ? (
          <div className="text-gray-600 font-bold">لا توجد مهام مسندة لك حاليًا</div>
        ) : (
          <>
            <div className="md:hidden space-y-2">
              {myTasksView.map((t) => (
                <div key={t.id} className="rounded-xl border border-slate-200 bg-white p-3">
                  <div className="font-extrabold text-slate-900">{t.title}</div>
                  <div className="mt-1 text-[11px] font-extrabold text-slate-600">{t.client?.name || '-'}</div>
                  <div className="mt-2 flex items-center gap-2 flex-wrap">
                    <span
                      className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-extrabold border ${
                        (t as any).overdue
                          ? 'bg-red-50 text-red-700 border-red-200'
                          : (t as any).dueSoon
                            ? 'bg-amber-50 text-amber-800 border-amber-200'
                            : 'bg-slate-50 text-slate-700 border-slate-200'
                      }`}
                    >
                      {t.due_at ? new Date(t.due_at).toLocaleString('ar-SA') : 'بدون موعد'}
                    </span>
                    <span
                      className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-extrabold border ${
                        t.priority === 'high'
                          ? 'bg-red-50 text-red-700 border-red-200'
                          : t.priority === 'medium'
                            ? 'bg-amber-50 text-amber-800 border-amber-200'
                            : 'bg-slate-50 text-slate-700 border-slate-200'
                      }`}
                    >
                      {t.priority === 'high' ? 'عالية' : t.priority === 'medium' ? 'متوسطة' : 'منخفضة'}
                    </span>
                    <span className="inline-flex px-2.5 py-1 rounded-lg text-[11px] font-extrabold border bg-white text-slate-700 border-slate-200">
                      {new Date(t.created_at).toLocaleDateString('ar-SA')}
                    </span>
                  </div>
                </div>
              ))}
            </div>

            <div className="hidden md:block overflow-auto rounded-xl border border-slate-200">
              <table className="min-w-full text-sm">
                <thead className="bg-slate-50 text-slate-700 border-b border-slate-200">
                  <tr>
                    <th className="text-right px-4 py-3 font-extrabold">المهمة</th>
                    <th className="text-right px-4 py-3 font-extrabold">العميل</th>
                    <th className="text-right px-4 py-3 font-extrabold">الموعد</th>
                    <th className="text-right px-4 py-3 font-extrabold">الأولوية</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200 bg-white">
                  {myTasksView.map((t) => (
                    <tr key={t.id} className="hover:bg-slate-50">
                      <td className="px-4 py-3 min-w-[280px]">
                        <div className="font-extrabold text-slate-900 truncate">{t.title}</div>
                        <div className="text-[11px] text-slate-500 font-bold">تم الإنشاء: {new Date(t.created_at).toLocaleString('ar-SA')}</div>
                      </td>
                      <td className="px-4 py-3 min-w-[220px]">
                        <div className="font-extrabold text-slate-900 truncate">{t.client?.name || '-'}</div>
                        <div className="text-[11px] text-slate-500 font-bold" dir="ltr">
                          {t.client?.phone || '-'}
                        </div>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        {t.due_at ? (
                          <span
                            className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-extrabold border ${
                              (t as any).overdue
                                ? 'bg-red-50 text-red-700 border-red-200'
                                : (t as any).dueSoon
                                  ? 'bg-amber-50 text-amber-800 border-amber-200'
                                  : 'bg-slate-50 text-slate-700 border-slate-200'
                            }`}
                          >
                            {new Date(t.due_at).toLocaleString('ar-SA')}
                          </span>
                        ) : (
                          <span className="text-slate-500 font-bold">-</span>
                        )}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span
                          className={`inline-flex px-2.5 py-1 rounded-lg text-[11px] font-extrabold border ${
                            t.priority === 'high'
                              ? 'bg-red-50 text-red-700 border-red-200'
                              : t.priority === 'medium'
                                ? 'bg-amber-50 text-amber-800 border-amber-200'
                                : 'bg-slate-50 text-slate-700 border-slate-200'
                          }`}
                        >
                          {t.priority === 'high' ? 'عالية' : t.priority === 'medium' ? 'متوسطة' : 'منخفضة'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </Section>

      <Section
        title="المواعيد القادمة"
        right={
          <Link
            href="/crm/appointments"
            className="px-3 py-2 rounded-xl bg-white border border-slate-200 text-slate-900 text-xs font-extrabold hover:bg-slate-50"
          >
            فتح صفحة المواعيد
          </Link>
        }
      >
        {loading ? (
          <div className="h-20 bg-gray-50 rounded-xl animate-pulse" />
        ) : appointmentsMissing ? (
          <div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-amber-900 text-sm font-bold">
            جدول المواعيد غير موجود (crm_appointments).
          </div>
        ) : upcomingAppointments.length === 0 ? (
          <div className="text-gray-600 font-bold">لا توجد مواعيد قادمة</div>
        ) : (
          <div className="space-y-2">
            {upcomingAppointments.map((a) => {
              const host = String(a.host_name || '').trim() || '-';
              const by = a.created_by ? employeeLabelById.get(a.created_by) || a.created_by.slice(0, 8) : '-';
              return (
                <div key={a.id} className="rounded-xl border border-slate-200 bg-white p-3 flex flex-col md:flex-row md:items-center md:justify-between gap-2">
                  <div className="min-w-0">
                    <div className="font-extrabold text-slate-900">
                      {new Date(a.appointment_at).toLocaleString('ar-SA')}
                      <span className="text-slate-300 mx-2">•</span>
                      {host}
                    </div>
                    <div className="mt-1 text-[11px] font-extrabold text-slate-600 truncate">
                      {a.client?.id ? (
                        <Link href={`/crm/clients/${a.client.id}`} className="text-emerald-700 hover:underline">
                          {a.client?.name || 'عميل'}
                        </Link>
                      ) : (
                        <span>{a.client?.name || 'عميل'}</span>
                      )}
                      <span className="text-slate-300 mx-2">•</span>
                      <span dir="ltr">{a.client?.phone || '-'}</span>
                    </div>
                  </div>
                  <div className="shrink-0 inline-flex px-2.5 py-1 rounded-lg text-[11px] font-extrabold border bg-slate-50 text-slate-700 border-slate-200">
                    {by}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </Section>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
        <div className="lg:col-span-7">
          <Section title="التواصل (آخر 14 يوم)" right={<div className="text-xs font-bold text-gray-500">اتصال/واتساب/بريد</div>}>
          {loading ? (
            <div className="h-[260px] bg-gray-50 rounded-xl animate-pulse" />
          ) : (
            <div className="rounded-xl border border-slate-200 bg-gradient-to-b from-white to-slate-50 p-3 md:p-4 h-[360px] sm:h-[340px] lg:h-[330px] flex flex-col">
              {(() => {
                const totals = activitySeries.reduce(
                  (acc, x) => {
                    acc.total += x.total;
                    acc.call += x.call;
                    acc.whatsapp += x.whatsapp;
                    acc.email += x.email;
                    if (x.total > acc.max.total) acc.max = { day: x.day, total: x.total };
                    return acc;
                  },
                  { total: 0, call: 0, whatsapp: 0, email: 0, max: { day: '-', total: 0 } }
                );
                const avg = activitySeries.length ? Math.round(totals.total / activitySeries.length) : 0;
                return (
                  <div className="flex flex-col gap-3 h-full">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
                      <div className="grid grid-cols-2 gap-2 sm:flex sm:flex-wrap sm:items-center sm:gap-2">
                        <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-900 text-xs font-extrabold">
                          إجمالي: {totals.total}
                        </span>
                        <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-900 text-xs font-extrabold">
                          متوسط يومي: {avg}
                        </span>
                        <span className="col-span-2 sm:col-span-1 inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-slate-900 text-xs font-extrabold truncate">
                          أعلى يوم: {totals.max.day} ({totals.max.total})
                        </span>
                      </div>
                      <div className="grid grid-cols-2 gap-2 sm:flex sm:flex-wrap sm:items-center sm:gap-2">
                        <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-xs font-extrabold text-slate-900">
                          <span className="w-2.5 h-2.5 rounded-full bg-slate-900" />
                          اتصال: {totals.call}
                        </span>
                        <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-emerald-200 bg-emerald-50 text-xs font-extrabold text-emerald-900">
                          <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                          واتساب: {totals.whatsapp}
                        </span>
                        <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-blue-200 bg-blue-50 text-xs font-extrabold text-blue-900">
                          <span className="w-2.5 h-2.5 rounded-full bg-blue-500" />
                          بريد: {totals.email}
                        </span>
                      </div>
                    </div>

                    <div className="flex-1 min-h-0">
                      <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={activitySeries} margin={{ top: 10, right: 10, bottom: 0, left: 0 }}>
                          <defs>
                            <linearGradient id="gCall" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="0%" stopColor="#0f172a" stopOpacity={0.35} />
                              <stop offset="100%" stopColor="#0f172a" stopOpacity={0} />
                            </linearGradient>
                            <linearGradient id="gWa" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="0%" stopColor="#10b981" stopOpacity={0.35} />
                              <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
                            </linearGradient>
                            <linearGradient id="gEmail" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="0%" stopColor="#3b82f6" stopOpacity={0.35} />
                              <stop offset="100%" stopColor="#3b82f6" stopOpacity={0} />
                            </linearGradient>
                          </defs>
                          <CartesianGrid stroke="#e5e7eb" strokeDasharray="0" vertical={false} />
                          <XAxis dataKey="day" tick={{ fill: '#64748b', fontSize: 12 }} axisLine={false} tickLine={false} />
                          <YAxis tick={{ fill: '#64748b', fontSize: 12 }} allowDecimals={false} axisLine={false} tickLine={false} width={30} />
                          <Tooltip
                            cursor={{ stroke: '#cbd5e1', strokeWidth: 1 }}
                            content={({ active, payload, label }) => {
                              if (!active || !payload?.length) return null;
                              const byKey = new Map<string, number>();
                              for (const p of payload as any[]) {
                                byKey.set(String(p.dataKey), Number(p.value || 0));
                              }
                              const call = byKey.get('call') || 0;
                              const wa = byKey.get('whatsapp') || 0;
                              const email = byKey.get('email') || 0;
                              const total = call + wa + email;
                              return (
                                <div className="bg-white border border-slate-200 rounded-xl shadow-lg px-3 py-2 text-xs font-extrabold text-slate-900">
                                  <div className="text-slate-600 mb-1">{label}</div>
                                  <div className="flex items-center justify-between gap-4">
                                    <span className="text-slate-900">الإجمالي</span>
                                    <span className="text-slate-900">{total}</span>
                                  </div>
                                  <div className="mt-1 space-y-1">
                                    <div className="flex items-center justify-between gap-4">
                                      <span className="inline-flex items-center gap-2 text-slate-700">
                                        <span className="w-2 h-2 rounded-full bg-slate-900" />
                                        اتصال
                                      </span>
                                      <span>{call}</span>
                                    </div>
                                    <div className="flex items-center justify-between gap-4">
                                      <span className="inline-flex items-center gap-2 text-emerald-800">
                                        <span className="w-2 h-2 rounded-full bg-emerald-500" />
                                        واتساب
                                      </span>
                                      <span>{wa}</span>
                                    </div>
                                    <div className="flex items-center justify-between gap-4">
                                      <span className="inline-flex items-center gap-2 text-blue-800">
                                        <span className="w-2 h-2 rounded-full bg-blue-500" />
                                        بريد
                                      </span>
                                      <span>{email}</span>
                                    </div>
                                  </div>
                                </div>
                              );
                            }}
                          />
                          <Area
                            type="monotone"
                            dataKey="call"
                            name="اتصال"
                            stackId="a"
                            stroke="#0f172a"
                            strokeWidth={2.5}
                            fill="url(#gCall)"
                            activeDot={{ r: 5, strokeWidth: 2, fill: '#0f172a' }}
                          />
                          <Area
                            type="monotone"
                            dataKey="whatsapp"
                            name="واتساب"
                            stackId="a"
                            stroke="#10b981"
                            strokeWidth={2.5}
                            fill="url(#gWa)"
                            activeDot={{ r: 5, strokeWidth: 2, fill: '#10b981' }}
                          />
                          <Area
                            type="monotone"
                            dataKey="email"
                            name="بريد"
                            stackId="a"
                            stroke="#3b82f6"
                            strokeWidth={2.5}
                            fill="url(#gEmail)"
                            activeDot={{ r: 5, strokeWidth: 2, fill: '#3b82f6' }}
                          />
                        </AreaChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                );
              })()}
            </div>
          )}
          </Section>
        </div>

        <div className="lg:col-span-5">
          <Section title="توزيع المهام" right={<div className="text-xs font-bold text-gray-500">مفتوحة/تمت</div>}>
          {loading ? (
            <div className="h-[260px] bg-gray-50 rounded-xl animate-pulse" />
          ) : taskDonut.data.length === 0 ? (
            <div className="h-[260px] flex items-center justify-center text-gray-500 font-bold">لا توجد بيانات</div>
          ) : (
            <div className="rounded-xl border border-slate-200 bg-gradient-to-b from-white to-slate-50 p-3 md:p-4 h-[360px] sm:h-[340px] lg:h-[330px] flex flex-col">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="text-xs font-extrabold text-slate-600">نسبة الإغلاق</div>
                  <div className="mt-1 text-2xl font-extrabold text-slate-900">{taskDonut.completion}%</div>
                </div>
                <div className="grid grid-cols-2 gap-2 sm:flex sm:items-center sm:gap-2">
                  <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-amber-200 bg-amber-50 text-amber-900 text-xs font-extrabold">
                    <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                    مفتوحة: {taskDonut.open}
                  </span>
                  <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl border border-emerald-200 bg-emerald-50 text-emerald-900 text-xs font-extrabold">
                    <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                    تمت: {taskDonut.done}
                  </span>
                </div>
              </div>

              <div className="mt-3 flex-1 min-h-0">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Tooltip />
                    <Pie
                      data={[{ name: 'track', value: 1 }]}
                      dataKey="value"
                      innerRadius={72}
                      outerRadius={98}
                      fill="#e5e7eb"
                      stroke="none"
                      isAnimationActive={false}
                    />
                    <Pie
                      data={taskDonut.data}
                      dataKey="value"
                      nameKey="name"
                      innerRadius={72}
                      outerRadius={98}
                      paddingAngle={taskDonut.paddingAngle}
                      startAngle={90}
                      endAngle={-270}
                      cornerRadius={10}
                      stroke="rgba(255,255,255,0.95)"
                      strokeWidth={3}
                    >
                      {taskDonut.data.map((entry) => (
                        <Cell key={entry.name} fill={(entry as any).color} />
                      ))}
                    </Pie>
                    <text x="50%" y="50%" textAnchor="middle" dominantBaseline="middle">
                      <tspan x="50%" dy="-2" fontSize="22" fontWeight="800" fill="#0f172a">
                        {taskDonut.total}
                      </tspan>
                      <tspan x="50%" dy="18" fontSize="12" fontWeight="800" fill="#64748b">
                        إجمالي المهام
                      </tspan>
                    </text>
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
          </Section>
        </div>

        <div className="lg:col-span-12">
          <Section title="مؤشرات سريعة" right={<div className="text-xs font-bold text-gray-500">النظام</div>}>
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-7 gap-2">
              <MiniKpi label="مهام خلال 7 أيام" value={kpis.dueNext7} tone="emerald" />
              <MiniKpi label="مكالمات" value={kpis.calls} tone="slate" />
              <MiniKpi label="واتساب" value={kpis.whatsapp} tone="emerald" />
              <MiniKpi label="بريد" value={kpis.email} tone="blue" />
              <MiniKpi label="مشاريع" value={counts.projects} tone="purple" />
              <MiniKpi label="وحدات" value={counts.units} tone="blue" />
              <MiniKpi label="صكوك مؤرشفة" value={counts.deedsArchived} tone="slate" />
            </div>
          </Section>
        </div>
      </div>

      <Section title="آخر الأحداث" right={<div className="text-xs font-bold text-gray-500">أحدث 12 عنصر</div>}>
        {loading ? (
          <div className="space-y-2">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-14 bg-gray-50 rounded-xl animate-pulse" />
            ))}
          </div>
        ) : feed.length === 0 ? (
          <div className="text-gray-500 font-bold">لا توجد أحداث في الفترة المحددة</div>
        ) : (
          <div className="space-y-2">
            {feed.map((x, idx) => (
              <div key={idx} className="rounded-xl border border-slate-200 bg-white px-4 py-3 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 min-w-0">
                    <span
                      className={`px-2 py-1 rounded-lg text-[11px] font-extrabold border ${
                        x.type === 'activity' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-amber-50 text-amber-800 border-amber-200'
                      }`}
                    >
                      {x.type === 'activity' ? 'تواصل' : 'مهمة'}
                    </span>
                    <div className="font-extrabold text-gray-900 truncate">{x.title}</div>
                  </div>
                  <div className="mt-1 text-xs text-gray-600 truncate">{x.meta}</div>
                </div>
                <div className="shrink-0 text-left">
                  <div className="text-[11px] font-bold text-gray-500">{new Date(x.at).toLocaleString('ar-SA')}</div>
                  {x.by ? <div className="text-[11px] font-extrabold text-gray-800">بواسطة: {x.by}</div> : null}
                </div>
              </div>
            ))}
          </div>
        )}
      </Section>

      <div className="text-xs text-gray-500 font-bold">
        ملاحظة: الرسوم تعرض بيانات الفترة المختارة (والرسم يعرض آخر 14 يوم عند كِبر الفترة).
      </div>
    </div>
  );
}

function QuickLink(p: { href: string; label: string; icon: React.ReactNode }) {
  return (
    <Link
      href={p.href}
      className="shrink-0 inline-flex items-center gap-2 px-3 py-2 rounded-xl bg-white border border-blue-200 hover:bg-blue-50 text-slate-900 text-sm font-extrabold shadow-sm"
    >
      {p.icon}
      {p.label}
    </Link>
  );
}

function MiniKpi(p: { label: string; value: number; tone: 'emerald' | 'blue' | 'purple' | 'slate' }) {
  const tone =
    p.tone === 'emerald'
      ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
      : p.tone === 'blue'
        ? 'bg-blue-50 text-blue-800 border-blue-200'
        : p.tone === 'purple'
          ? 'bg-purple-50 text-purple-800 border-purple-200'
          : 'bg-slate-50 text-slate-800 border-slate-200';
  return (
    <div className="rounded-lg border border-slate-200 px-3 py-2 flex flex-col gap-1">
      <div className="font-extrabold text-[11px] text-slate-600 truncate">{p.label}</div>
      <div className={`inline-flex self-start px-2 py-0.5 rounded-lg border font-extrabold text-[12px] ${tone}`}>{p.value}</div>
    </div>
  );
}
