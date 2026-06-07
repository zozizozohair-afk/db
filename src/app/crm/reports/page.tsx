'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import { BarChart3, AlertCircle, Users, ClipboardList, FileText, Printer, RefreshCw } from 'lucide-react';
import { supabase } from '../../../lib/supabaseClient';
import logo from '../../public/logo.png';
import type { CrmActivity, CrmTask, Unit } from '../../../types';

type EmployeeRole = 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';

type EmployeeLite = {
  id: string;
  email: string | null;
  job_title: string | null;
  role: EmployeeRole;
  is_active: boolean;
};

type ClientLite = {
  id: string;
  name: string;
  phone: string | null;
  id_number: string | null;
};

type ActivityRow = CrmActivity & {
  client?: ClientLite | null;
};

type TaskRow = CrmTask & {
  client?: ClientLite | null;
};

type ReportData = {
  employeeId: string | 'all';
  employeeLabel: string;
  startIso: string;
  endIso: string;
  generatedAtIso: string;
  activities: ActivityRow[];
  tasks: TaskRow[];
  unitsById: Map<string, { id: string; project_id: string | null; unit_number: number | null; status: Unit['status'] | null }>;
  projectsById: Map<string, { id: string; name: string; project_number: string }>;
};

export default function CrmReportsPage() {
  const pathname = usePathname();
  const [role, setRole] = useState<EmployeeRole>('viewer');
  const [isAdmin, setIsAdmin] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [employees, setEmployees] = useState<EmployeeLite[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);

  const toLocalInput = (d: Date) => {
    const tz = d.getTimezoneOffset() * 60_000;
    return new Date(d.getTime() - tz).toISOString().slice(0, 16);
  };

  const [employeeId, setEmployeeId] = useState<string | 'all'>('all');
  const [startAt, setStartAt] = useState<string>(() => toLocalInput(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)));
  const [endAt, setEndAt] = useState<string>(() => toLocalInput(new Date()));
  const [reportLoading, setReportLoading] = useState(false);
  const [reportError, setReportError] = useState<string | null>(null);
  const [report, setReport] = useState<ReportData | null>(null);

  useEffect(() => {
    const run = async () => {
      setLoading(true);
      setErrorText(null);
      try {
        const { data } = await supabase.auth.getUser();
        const user = data.user;
        if (!user) {
          setErrorText('الرجاء تسجيل الدخول.');
          setLoading(false);
          return;
        }
        setUserId(user.id);

        const [{ data: profile }, employeesRes] = await Promise.all([
          supabase.from('employee_profiles').select('role').eq('user_id', user.id).maybeSingle(),
          supabase.rpc('crm_list_employees')
        ]);

        const nextRole = ((profile?.role as string | null) || 'admin') as EmployeeRole;
        setRole(nextRole);
        const adminLike = nextRole === 'admin' || nextRole === 'manager';
        setIsAdmin(adminLike);

        const list = ((employeesRes.data as any[]) || []) as EmployeeLite[];
        setEmployees(list);

        if (adminLike) {
          setEmployeeId('all');
        } else {
          setEmployeeId(user.id);
        }
      } catch (e: any) {
        setErrorText(e?.message || 'تعذر تحميل التقارير');
      } finally {
        setLoading(false);
      }
    };
    run();
  }, []);

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

  const channelLabel = (c: string) => {
    if (c === 'call') return 'اتصال';
    if (c === 'whatsapp') return 'واتساب';
    if (c === 'email') return 'بريد';
    if (c === 'visit') return 'زيارة';
    if (c === 'note') return 'ملاحظة';
    return c;
  };

  const outcomeLabel = (o: string | null | undefined) => {
    if (o === 'completed') return 'تم التواصل';
    if (o === 'no_answer') return 'عدم رد';
    if (o === 'appointment') return 'تم حجز موعد';
    return '-';
  };

  const priorityLabel = (p: string) => {
    if (p === 'high') return 'عالية';
    if (p === 'medium') return 'متوسطة';
    if (p === 'low') return 'منخفضة';
    return p;
  };

  const statusLabel = (s: string) => (s === 'done' ? 'منجزة' : s === 'open' ? 'مفتوحة' : s);

  const buildUnitKey = (u: { project_number?: string | null; unit_number?: number | null }) => {
    const pn = u.project_number || '-';
    const un = u.unit_number ?? '-';
    return `${pn}-${un}`;
  };

  const loadUnitsAndProjects = async (unitIds: string[]) => {
    const unitsById = new Map<string, { id: string; project_id: string | null; unit_number: number | null; status: Unit['status'] | null }>();
    const projectsById = new Map<string, { id: string; name: string; project_number: string }>();
    if (unitIds.length === 0) return { unitsById, projectsById };

    const unitsRes = await supabase.from('units').select('id, project_id, unit_number, status').in('id', unitIds);
    if (!unitsRes.error) {
      for (const u of (unitsRes.data as any[]) || []) {
        unitsById.set(String(u.id), {
          id: String(u.id),
          project_id: u.project_id ? String(u.project_id) : null,
          unit_number: u.unit_number ?? null,
          status: (u.status as any) ?? null
        });
      }
    }

    const projectIds = Array.from(new Set(Array.from(unitsById.values()).map((u) => u.project_id).filter(Boolean))) as string[];
    if (projectIds.length > 0) {
      const projectsRes = await supabase.from('projects').select('id, name, project_number').in('id', projectIds);
      if (!projectsRes.error) {
        for (const p of (projectsRes.data as any[]) || []) {
          projectsById.set(String(p.id), { id: String(p.id), name: String(p.name || ''), project_number: String(p.project_number || '') });
        }
      }
    }

    return { unitsById, projectsById };
  };

  const generateReport = async () => {
    setReportError(null);
    setReportLoading(true);
    try {
      if (!startAt || !endAt) {
        setReportError('الرجاء تحديد تاريخ البداية والنهاية.');
        setReportLoading(false);
        return;
      }
      const startIso = new Date(startAt).toISOString();
      const endIso = new Date(endAt).toISOString();
      if (new Date(startIso).getTime() > new Date(endIso).getTime()) {
        setReportError('تاريخ البداية يجب أن يكون قبل تاريخ النهاية.');
        setReportLoading(false);
        return;
      }

      const selectedEmployeeId = employeeId;
      const employeeLabel =
        selectedEmployeeId === 'all'
          ? 'كل الموظفين'
          : employeeLabelById.get(selectedEmployeeId) || String(selectedEmployeeId).slice(0, 8);

      let activitiesQ = supabase
        .from('crm_activities')
        .select(
          'id, created_at, client_id, unit_id, channel, content, created_by, outcome, next_contact_at, appointment_at, appointment_with, client:clients(id, name, phone, id_number)'
        )
        .gte('created_at', startIso)
        .lte('created_at', endIso)
        .order('created_at', { ascending: false });

      if (selectedEmployeeId !== 'all') activitiesQ = activitiesQ.eq('created_by', selectedEmployeeId);

      const taskRangeExpr = (col: string) => `and(${col}.gte.${startIso},${col}.lte.${endIso})`;

      const buildTasksQuery = (p: { includeUpdatedAt: boolean; includeCompletedAt: boolean }) => {
        const selectFields = [
          'id',
          'created_at',
          'client_id',
          'unit_id',
          'assigned_to',
          'title',
          'description',
          'due_at',
          'status',
          'priority',
          'client:clients(id, name, phone, id_number)',
          ...(p.includeUpdatedAt ? ['updated_at'] : []),
          ...(p.includeCompletedAt ? ['completed_at'] : [])
        ].join(', ');

        let q = supabase.from('crm_tasks').select(selectFields).order('created_at', { ascending: false });

        const parts = [taskRangeExpr('created_at'), taskRangeExpr('due_at')];
        if (p.includeUpdatedAt) parts.push(taskRangeExpr('updated_at'));
        if (p.includeCompletedAt) parts.push(taskRangeExpr('completed_at'));
        q = q.or(parts.join(','));

        if (selectedEmployeeId !== 'all') q = q.eq('assigned_to', selectedEmployeeId);
        return q;
      };

      const [activitiesRes, tasksResTry] = await Promise.all([activitiesQ, buildTasksQuery({ includeUpdatedAt: true, includeCompletedAt: true })]);

      let tasksRes = tasksResTry;
      if (tasksRes.error && String(tasksRes.error.message || '').toLowerCase().includes('column')) {
        tasksRes = await buildTasksQuery({ includeUpdatedAt: false, includeCompletedAt: false });
      }

      if (activitiesRes.error) throw activitiesRes.error;
      if (tasksRes.error) throw tasksRes.error;

      const activities = ((activitiesRes.data as any[]) || []) as ActivityRow[];
      const tasks = ((tasksRes.data as any[]) || []) as TaskRow[];

      const unitIds = Array.from(
        new Set(
          [...activities.map((a) => a.unit_id).filter(Boolean), ...tasks.map((t) => t.unit_id).filter(Boolean)].map((x) => String(x))
        )
      );

      const { unitsById, projectsById } = await loadUnitsAndProjects(unitIds);

      setReport({
        employeeId: selectedEmployeeId,
        employeeLabel,
        startIso,
        endIso,
        generatedAtIso: new Date().toISOString(),
        activities,
        tasks,
        unitsById,
        projectsById
      });
    } catch (e: any) {
      setReportError(e?.message || 'تعذر توليد التقرير');
      setReport(null);
    } finally {
      setReportLoading(false);
    }
  };

  const reportSummary = useMemo(() => {
    if (!report) return null;
    const byChannel = new Map<string, number>();
    const byOutcome = new Map<string, number>();
    for (const a of report.activities) {
      const ch = String(a.channel || 'unknown');
      byChannel.set(ch, (byChannel.get(ch) || 0) + 1);
      const oc = String((a as any).outcome || 'none');
      byOutcome.set(oc, (byOutcome.get(oc) || 0) + 1);
    }

    const now = Date.now();
    const openTasks = report.tasks.filter((t) => t.status === 'open');
    const doneTasks = report.tasks.filter((t) => t.status === 'done');
    const overdue = openTasks.filter((t) => t.due_at && new Date(t.due_at).getTime() < now);

    const clientsSet = new Set<string>();
    for (const a of report.activities) clientsSet.add(String(a.client_id));
    for (const t of report.tasks) clientsSet.add(String(t.client_id));

    return {
      totalActivities: report.activities.length,
      calls: byChannel.get('call') || 0,
      whatsapp: byChannel.get('whatsapp') || 0,
      email: byChannel.get('email') || 0,
      visits: byChannel.get('visit') || 0,
      notes: byChannel.get('note') || 0,
      completed: byOutcome.get('completed') || 0,
      noAnswer: byOutcome.get('no_answer') || 0,
      appointment: byOutcome.get('appointment') || 0,
      totalTasks: report.tasks.length,
      openTasks: openTasks.length,
      doneTasks: doneTasks.length,
      overdueTasks: overdue.length,
      touchedClients: clientsSet.size
    };
  }, [report]);

  const escapeHtml = (input: any) => {
    const s = String(input ?? '');
    return s
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  };

  const formatDate = (iso: string | null | undefined) => {
    if (!iso) return '-';
    try {
      return new Date(iso).toLocaleString('ar-SA');
    } catch {
      return '-';
    }
  };

  const printReportTables = () => {
    if (!report) return;

    const getUnitMeta = (unitId: string | null | undefined) => {
      if (!unitId) return { unitKey: '-', projectName: '' };
      const u = report.unitsById.get(String(unitId));
      if (!u) return { unitKey: '-', projectName: '' };
      const p = u.project_id ? report.projectsById.get(String(u.project_id)) : null;
      const unitKey = buildUnitKey({ project_number: p?.project_number || '-', unit_number: u.unit_number });
      return { unitKey, projectName: p?.name || '' };
    };

    const headerHtml = `
      <div class="header">
        <div class="brand">
          <div class="meta">
            <div class="title">تقرير CRM</div>
            <div class="sub">الموظف: <span class="strong">${escapeHtml(report.employeeLabel)}</span></div>
            <div class="sub">الفترة: <span class="strong">${escapeHtml(formatDate(report.startIso))}</span> إلى <span class="strong">${escapeHtml(
      formatDate(report.endIso)
    )}</span></div>
            <div class="sub">تم الإنشاء: <span class="strong">${escapeHtml(formatDate(report.generatedAtIso))}</span></div>
          </div>
        </div>
      </div>
    `;

    const summaryHtml =
      reportSummary
        ? `
      <div class="summary">
        <div class="card">
          <div class="k">العملاء الذين تم التعامل معهم</div>
          <div class="v">${escapeHtml(reportSummary.touchedClients)}</div>
        </div>
        <div class="card">
          <div class="k">سجل التواصل</div>
          <div class="v">${escapeHtml(reportSummary.totalActivities)}</div>
          <div class="s">اتصال ${escapeHtml(reportSummary.calls)} • واتساب ${escapeHtml(reportSummary.whatsapp)} • بريد ${escapeHtml(reportSummary.email)}</div>
        </div>
        <div class="card">
          <div class="k">نتائج التواصل</div>
          <div class="s">تم التواصل: ${escapeHtml(reportSummary.completed)} • عدم رد: ${escapeHtml(reportSummary.noAnswer)} • مواعيد: ${escapeHtml(
            reportSummary.appointment
          )}</div>
        </div>
        <div class="card">
          <div class="k">المهام</div>
          <div class="v">${escapeHtml(reportSummary.totalTasks)}</div>
          <div class="s">مفتوحة ${escapeHtml(reportSummary.openTasks)} • منجزة ${escapeHtml(reportSummary.doneTasks)} • متأخرة ${escapeHtml(
            reportSummary.overdueTasks
          )}</div>
        </div>
      </div>
    `
        : '';

    const activitiesRowsHtml = report.activities
      .map((a) => {
        const clientName = a.client?.name || String(a.client_id).slice(0, 8);
        const clientPhone = a.client?.phone || '-';
        const { unitKey, projectName } = getUnitMeta(String(a.unit_id || ''));
        const by = a.created_by ? employeeLabelById.get(String(a.created_by)) || String(a.created_by).slice(0, 8) : '-';
        const appointment =
          (a as any).outcome === 'appointment'
            ? `${formatDate((a as any).appointment_at)}${(a as any).appointment_with ? ` • ${(a as any).appointment_with}` : ''}`
            : '-';
        return `
          <tr>
            <td>
              <div class="strong">${escapeHtml(formatDate(a.created_at))}</div>
              <div class="muted">بواسطة: ${escapeHtml(by)}</div>
            </td>
            <td>
              <div class="strong">${escapeHtml(clientName)}</div>
              <div class="muted" dir="ltr">${escapeHtml(clientPhone)}</div>
            </td>
            <td>
              <div class="strong">${escapeHtml(unitKey)}</div>
              <div class="muted">${escapeHtml(projectName)}</div>
            </td>
            <td class="strong">${escapeHtml(channelLabel(String(a.channel)))}</td>
            <td class="strong">${escapeHtml(outcomeLabel((a as any).outcome))}</td>
            <td class="pre">${escapeHtml(String(a.content || '').trim())}</td>
            <td>${escapeHtml(formatDate((a as any).next_contact_at))}</td>
            <td>${escapeHtml(appointment)}</td>
          </tr>
        `;
      })
      .join('');

    const tasksRowsHtml = report.tasks
      .map((t) => {
        const clientName = t.client?.name || String(t.client_id).slice(0, 8);
        const clientPhone = t.client?.phone || '-';
        const { unitKey, projectName } = getUnitMeta(String(t.unit_id || ''));
        const assignee =
          t.assigned_to === null || t.assigned_to === undefined
            ? 'عامّة'
            : employeeLabelById.get(String(t.assigned_to)) || String(t.assigned_to).slice(0, 8);
        const when = (t as any).updated_at || (t as any).completed_at || t.created_at;
        return `
          <tr>
            <td>${escapeHtml(formatDate(when))}</td>
            <td>
              <div class="strong">${escapeHtml(clientName)}</div>
              <div class="muted" dir="ltr">${escapeHtml(clientPhone)}</div>
            </td>
            <td class="pre">
              <div class="strong">${escapeHtml(String(t.title || '').trim())}</div>
              ${t.description ? `<div class="muted pre">${escapeHtml(String(t.description || '').trim())}</div>` : ``}
            </td>
            <td class="strong">${escapeHtml(statusLabel(String(t.status)))}</td>
            <td class="strong">${escapeHtml(priorityLabel(String(t.priority)))}</td>
            <td>${escapeHtml(formatDate(t.due_at))}</td>
            <td>
              <div class="strong">${escapeHtml(unitKey)}</div>
              <div class="muted">${escapeHtml(projectName)}</div>
            </td>
            <td class="strong">${escapeHtml(assignee)}</td>
          </tr>
        `;
      })
      .join('');

    const html = `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>تقرير CRM</title>
  <style>
    @page { size: A4 landscape; margin: 10mm; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: Arial, "Segoe UI", Tahoma, sans-serif; color: #111827; }
    .container { padding: 8mm; }
    .header { border: 1px solid #E5E7EB; border-radius: 10px; padding: 10px 12px; }
    .brand { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
    .meta { flex: 1; min-width: 0; }
    .title { font-size: 16px; font-weight: 800; }
    .sub { font-size: 12px; color: #374151; margin-top: 2px; }
    .strong { font-weight: 800; color: #111827; }
    .muted { font-size: 11px; color: #6B7280; margin-top: 2px; }
    .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-top: 10px; }
    .card { border: 1px solid #E5E7EB; border-radius: 10px; padding: 10px 12px; background: #F9FAFB; }
    .card .k { font-size: 11px; color: #6B7280; font-weight: 800; }
    .card .v { font-size: 18px; font-weight: 900; margin-top: 6px; }
    .card .s { font-size: 11px; color: #374151; margin-top: 6px; font-weight: 700; }
    h2 { margin: 14px 0 8px; font-size: 14px; font-weight: 900; }
    table { width: 100%; border-collapse: collapse; border: 1px solid #E5E7EB; }
    thead { display: table-header-group; }
    th, td { border-bottom: 1px solid #E5E7EB; padding: 8px 10px; vertical-align: top; text-align: right; }
    th { background: #F3F4F6; color: #374151; font-size: 12px; font-weight: 900; }
    td { font-size: 12px; color: #111827; }
    tr { page-break-inside: avoid; }
    .pre { white-space: pre-wrap; }
    .section { margin-top: 14px; }
    .count { font-size: 12px; color: #6B7280; font-weight: 800; margin-right: 6px; }
    .empty { border: 1px dashed #E5E7EB; border-radius: 10px; padding: 16px; text-align: center; color: #6B7280; }
  </style>
</head>
<body>
  <div class="container">
    ${headerHtml}
    ${summaryHtml}
    <div class="section">
      <h2>سجل التواصل <span class="count">(${escapeHtml(report.activities.length)})</span></h2>
      ${
        report.activities.length === 0
          ? `<div class="empty">لا يوجد سجل تواصل ضمن الفترة</div>`
          : `
        <table>
          <thead>
            <tr>
              <th>التاريخ</th>
              <th>العميل</th>
              <th>الوحدة</th>
              <th>القناة</th>
              <th>النتيجة</th>
              <th>الملاحظة</th>
              <th>التواصل القادم</th>
              <th>الموعد</th>
            </tr>
          </thead>
          <tbody>
            ${activitiesRowsHtml}
          </tbody>
        </table>
      `
      }
    </div>
    <div class="section">
      <h2>المهام <span class="count">(${escapeHtml(report.tasks.length)})</span></h2>
      ${
        report.tasks.length === 0
          ? `<div class="empty">لا يوجد مهام ضمن الفترة</div>`
          : `
        <table>
          <thead>
            <tr>
              <th>التاريخ</th>
              <th>العميل</th>
              <th>المهمة</th>
              <th>الحالة</th>
              <th>الأولوية</th>
              <th>الموعد</th>
              <th>الوحدة</th>
              <th>مكلّف بها</th>
            </tr>
          </thead>
          <tbody>
            ${tasksRowsHtml}
          </tbody>
        </table>
      `
      }
    </div>
  </div>
  <script>
    setTimeout(() => {
      window.focus();
      window.print();
    }, 0);
  </script>
</body>
</html>`;

    const iframe = document.createElement('iframe');
    iframe.setAttribute('aria-hidden', 'true');
    iframe.style.position = 'fixed';
    iframe.style.right = '0';
    iframe.style.bottom = '0';
    iframe.style.width = '0';
    iframe.style.height = '0';
    iframe.style.border = '0';
    iframe.style.opacity = '0';
    document.body.appendChild(iframe);

    const cleanup = () => {
      try {
        iframe.remove();
      } catch {}
    };

    try {
      const doc = iframe.contentDocument;
      const win = iframe.contentWindow;
      if (!doc || !win) {
        cleanup();
        setReportError('تعذر تجهيز الطباعة. الرجاء إعادة المحاولة.');
        return;
      }

      doc.open();
      doc.write(html);
      doc.close();

      const removeAfter = () => setTimeout(cleanup, 300);
      try {
        win.addEventListener('afterprint', removeAfter, { once: true });
      } catch {}

      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          try {
            win.focus();
            win.print();
          } catch {
            setReportError('تعذر بدء الطباعة. الرجاء إعادة المحاولة.');
            cleanup();
          }
        });
      });

      setTimeout(removeAfter, 8000);
    } catch {
      cleanup();
      setReportError('تعذر تجهيز الطباعة. الرجاء إعادة المحاولة.');
    }
  };

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto" dir="rtl">
      <style jsx global>{`
        @media print {
          .no-print {
            display: none !important;
          }
          body {
            background: white !important;
          }
        }
      `}</style>
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 bg-purple-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-purple-600/20">
          <BarChart3 size={24} />
        </div>
        <div>
          <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">التقارير</h1>
          <p className="text-gray-500 text-sm">تقارير احترافية حسب المستخدم والفترة</p>
        </div>
      </div>

      <div className="bg-white/90 backdrop-blur rounded-2xl shadow-md border border-gray-200 p-2 no-print">
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

      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 no-print">
        {errorText && (
          <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-700 text-sm flex items-center gap-2 mb-4">
            <AlertCircle size={18} />
            {errorText}
          </div>
        )}

        {loading ? (
          <div className="py-10 text-center text-gray-500">جاري التحميل...</div>
        ) : (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
              <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
                <div className="text-xs text-gray-500 font-bold mb-2">الموظف</div>
                <select
                  value={employeeId}
                  onChange={(e) => setEmployeeId(e.target.value as any)}
                  className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
                  disabled={!isAdmin}
                >
                  {isAdmin ? <option value="all">كل الموظفين</option> : null}
                  {(isAdmin ? employees : employees.filter((e) => e.id === userId)).map((e) => (
                    <option key={e.id} value={e.id}>
                      {employeeLabelById.get(e.id) || e.id}
                    </option>
                  ))}
                </select>
                {!isAdmin ? <div className="text-[11px] text-gray-500 mt-2">التقرير يظهر حسب حسابك.</div> : null}
              </div>

              <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
                <div className="text-xs text-gray-500 font-bold mb-2">من</div>
                <input
                  type="datetime-local"
                  value={startAt}
                  onChange={(e) => setStartAt(e.target.value)}
                  className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
                />
              </div>

              <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
                <div className="text-xs text-gray-500 font-bold mb-2">إلى</div>
                <input
                  type="datetime-local"
                  value={endAt}
                  onChange={(e) => setEndAt(e.target.value)}
                  className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
                />
              </div>

              <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
                <div className="text-xs text-gray-500 font-bold mb-2">الإجراء</div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={generateReport}
                    disabled={reportLoading}
                    className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 text-white font-bold hover:bg-emerald-700 disabled:opacity-60"
                  >
                    <RefreshCw size={16} />
                    {reportLoading ? 'جاري توليد التقرير...' : 'توليد التقرير'}
                  </button>
                  <button
                    type="button"
                    onClick={printReportTables}
                    disabled={!report}
                    className="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-gray-900 text-white font-bold hover:bg-black disabled:opacity-60"
                  >
                    <Printer size={16} />
                    طباعة الجدول
                  </button>
                </div>
              </div>
            </div>

            {reportError ? (
              <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-700 text-sm flex items-center gap-2">
                <AlertCircle size={18} />
                {reportError}
              </div>
            ) : null}
          </div>
        )}
      </div>

      {report ? (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="p-6 border-b border-gray-100">
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0">
                <div className="flex items-center gap-3">
                  <div className="relative h-12 w-44">
                    <Image src={logo} alt="مساكن" fill className="object-contain object-right" />
                  </div>
                  <div className="min-w-0">
                    <div className="font-bold text-gray-900 text-lg">تقرير CRM</div>
                    <div className="text-sm text-gray-600">
                      الموظف: <span className="font-bold text-gray-900">{report.employeeLabel}</span>
                    </div>
                  </div>
                </div>
                <div className="mt-3 text-sm text-gray-600">
                  الفترة: <span className="font-bold text-gray-900">{new Date(report.startIso).toLocaleString('ar-SA')}</span> إلى{' '}
                  <span className="font-bold text-gray-900">{new Date(report.endIso).toLocaleString('ar-SA')}</span>
                  <span className="text-gray-300 mx-2">•</span>
                  تم الإنشاء: <span className="font-bold text-gray-900">{new Date(report.generatedAtIso).toLocaleString('ar-SA')}</span>
                </div>
              </div>
              <div className="no-print">
                <button
                  type="button"
                  onClick={printReportTables}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gray-900 text-white font-bold hover:bg-black"
                >
                  <Printer size={16} />
                  طباعة الجدول
                </button>
              </div>
            </div>
          </div>

          {reportSummary ? (
            <div className="p-6 grid grid-cols-1 md:grid-cols-4 gap-3">
              <div className="p-4 bg-gray-50 border border-gray-200 rounded-xl">
                <div className="text-xs text-gray-500 font-bold">العملاء الذين تم التعامل معهم</div>
                <div className="text-2xl font-extrabold text-gray-900 mt-2">{reportSummary.touchedClients}</div>
              </div>
              <div className="p-4 bg-gray-50 border border-gray-200 rounded-xl">
                <div className="text-xs text-gray-500 font-bold">سجل التواصل</div>
                <div className="text-2xl font-extrabold text-gray-900 mt-2">{reportSummary.totalActivities}</div>
                <div className="text-xs text-gray-600 mt-2">
                  اتصال {reportSummary.calls} • واتساب {reportSummary.whatsapp} • بريد {reportSummary.email}
                </div>
              </div>
              <div className="p-4 bg-gray-50 border border-gray-200 rounded-xl">
                <div className="text-xs text-gray-500 font-bold">نتائج التواصل</div>
                <div className="text-xs text-gray-700 mt-2 font-bold">تم التواصل: {reportSummary.completed}</div>
                <div className="text-xs text-gray-700 mt-1 font-bold">عدم رد: {reportSummary.noAnswer}</div>
                <div className="text-xs text-gray-700 mt-1 font-bold">مواعيد: {reportSummary.appointment}</div>
              </div>
              <div className="p-4 bg-gray-50 border border-gray-200 rounded-xl">
                <div className="text-xs text-gray-500 font-bold">المهام</div>
                <div className="text-2xl font-extrabold text-gray-900 mt-2">{reportSummary.totalTasks}</div>
                <div className="text-xs text-gray-600 mt-2">
                  مفتوحة {reportSummary.openTasks} • منجزة {reportSummary.doneTasks} • متأخرة {reportSummary.overdueTasks}
                </div>
              </div>
            </div>
          ) : null}

          <div className="p-6 space-y-6">
            <div className="flex items-center gap-2">
              <FileText size={18} className="text-emerald-600" />
              <div className="font-bold text-gray-900">سجل التواصل</div>
              <div className="text-sm text-gray-500">({report.activities.length})</div>
            </div>

            {report.activities.length === 0 ? (
              <div className="text-center py-10 text-gray-500 border border-dashed border-gray-200 rounded-xl">لا يوجد سجل تواصل ضمن الفترة</div>
            ) : (
              <div className="overflow-auto border border-gray-200 rounded-xl">
                <table className="min-w-[1100px] w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr className="text-right text-gray-600">
                      <th className="py-3 px-4 font-bold">التاريخ</th>
                      <th className="py-3 px-4 font-bold">العميل</th>
                      <th className="py-3 px-4 font-bold">الوحدة</th>
                      <th className="py-3 px-4 font-bold">القناة</th>
                      <th className="py-3 px-4 font-bold">النتيجة</th>
                      <th className="py-3 px-4 font-bold">الملاحظة</th>
                      <th className="py-3 px-4 font-bold">التواصل القادم</th>
                      <th className="py-3 px-4 font-bold">الموعد</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {report.activities.map((a) => {
                      const clientName = a.client?.name || String(a.client_id).slice(0, 8);
                      const u = a.unit_id ? report.unitsById.get(String(a.unit_id)) : null;
                      const p = u?.project_id ? report.projectsById.get(String(u.project_id)) : null;
                      const unitKey = u ? buildUnitKey({ project_number: p?.project_number || '-', unit_number: u.unit_number }) : '-';
                      const by = a.created_by ? employeeLabelById.get(String(a.created_by)) || String(a.created_by).slice(0, 8) : '-';
                      const appointment =
                        (a as any).outcome === 'appointment'
                          ? `${(a as any).appointment_at ? new Date((a as any).appointment_at).toLocaleString('ar-SA') : '-'}${(a as any).appointment_with ? ` • ${(a as any).appointment_with}` : ''}`
                          : '-';
                      return (
                        <tr key={a.id} className="hover:bg-gray-50">
                          <td className="py-3 px-4 text-gray-700 whitespace-nowrap">
                            <div className="font-bold text-gray-900">{new Date(a.created_at).toLocaleString('ar-SA')}</div>
                            <div className="text-[11px] text-gray-500">بواسطة: {by}</div>
                          </td>
                          <td className="py-3 px-4">
                            <div className="font-bold text-gray-900">{clientName}</div>
                            <div className="text-[11px] text-gray-500" dir="ltr">
                              {a.client?.phone || '-'}
                            </div>
                          </td>
                          <td className="py-3 px-4">
                            <div className="font-bold text-gray-900">{unitKey}</div>
                            <div className="text-[11px] text-gray-500">{p?.name || ''}</div>
                          </td>
                          <td className="py-3 px-4 font-bold text-gray-900">{channelLabel(String(a.channel))}</td>
                          <td className="py-3 px-4 font-bold text-gray-900">{outcomeLabel((a as any).outcome)}</td>
                          <td className="py-3 px-4 text-gray-900 whitespace-pre-wrap">{String(a.content || '').trim()}</td>
                          <td className="py-3 px-4 text-gray-700 whitespace-nowrap">
                            {(a as any).next_contact_at ? new Date((a as any).next_contact_at).toLocaleString('ar-SA') : '-'}
                          </td>
                          <td className="py-3 px-4 text-gray-700 whitespace-nowrap">{appointment}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}

            <div className="flex items-center gap-2 pt-2">
              <ClipboardList size={18} className="text-blue-600" />
              <div className="font-bold text-gray-900">المهام</div>
              <div className="text-sm text-gray-500">({report.tasks.length})</div>
            </div>

            {report.tasks.length === 0 ? (
              <div className="text-center py-10 text-gray-500 border border-dashed border-gray-200 rounded-xl">لا يوجد مهام ضمن الفترة</div>
            ) : (
              <div className="overflow-auto border border-gray-200 rounded-xl">
                <table className="min-w-[1100px] w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr className="text-right text-gray-600">
                      <th className="py-3 px-4 font-bold">التاريخ</th>
                      <th className="py-3 px-4 font-bold">العميل</th>
                      <th className="py-3 px-4 font-bold">المهمة</th>
                      <th className="py-3 px-4 font-bold">الحالة</th>
                      <th className="py-3 px-4 font-bold">الأولوية</th>
                      <th className="py-3 px-4 font-bold">الموعد</th>
                      <th className="py-3 px-4 font-bold">الوحدة</th>
                      <th className="py-3 px-4 font-bold">مكلّف بها</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {report.tasks.map((t) => {
                      const clientName = t.client?.name || String(t.client_id).slice(0, 8);
                      const u = t.unit_id ? report.unitsById.get(String(t.unit_id)) : null;
                      const p = u?.project_id ? report.projectsById.get(String(u.project_id)) : null;
                      const unitKey = u ? buildUnitKey({ project_number: p?.project_number || '-', unit_number: u.unit_number }) : '-';
                      const assignee =
                        t.assigned_to === null || t.assigned_to === undefined
                          ? 'عامّة'
                          : employeeLabelById.get(String(t.assigned_to)) || String(t.assigned_to).slice(0, 8);
                      const when = (t as any).updated_at || (t as any).completed_at || t.created_at;
                      return (
                        <tr key={t.id} className="hover:bg-gray-50">
                          <td className="py-3 px-4 text-gray-700 whitespace-nowrap">{new Date(when).toLocaleString('ar-SA')}</td>
                          <td className="py-3 px-4">
                            <div className="font-bold text-gray-900">{clientName}</div>
                            <div className="text-[11px] text-gray-500" dir="ltr">
                              {t.client?.phone || '-'}
                            </div>
                          </td>
                          <td className="py-3 px-4 text-gray-900 whitespace-pre-wrap">
                            <div className="font-bold">{String(t.title || '').trim()}</div>
                            {t.description ? <div className="mt-1 text-xs text-gray-600 whitespace-pre-wrap">{String(t.description || '').trim()}</div> : null}
                          </td>
                          <td className="py-3 px-4 font-bold text-gray-900">{statusLabel(String(t.status))}</td>
                          <td className="py-3 px-4 font-bold text-gray-900">{priorityLabel(String(t.priority))}</td>
                          <td className="py-3 px-4 text-gray-700 whitespace-nowrap">{t.due_at ? new Date(t.due_at).toLocaleString('ar-SA') : '-'}</td>
                          <td className="py-3 px-4">
                            <div className="font-bold text-gray-900">{unitKey}</div>
                            <div className="text-[11px] text-gray-500">{p?.name || ''}</div>
                          </td>
                          <td className="py-3 px-4 font-bold text-gray-900">{assignee}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
