 'use client';
 
 import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { FileText, Search, Copy, Check, FileSpreadsheet, Printer, ClipboardList, Users, AlertCircle } from 'lucide-react';
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
  id_number: string | null;
};

export default function DebtReportPage() {
  const [rows, setRows] = useState<Debt[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [filterProject, setFilterProject] = useState<string>('all');
  const [copied, setCopied] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [role, setRole] = useState<EmployeeRole>('viewer');
  const [employees, setEmployees] = useState<EmployeeLite[]>([]);
  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkAssignees, setBulkAssignees] = useState<string[]>([]);
  const [bulkDueMode, setBulkDueMode] = useState<'single' | 'per10'>('per10');
  const [bulkDueAt, setBulkDueAt] = useState<string>(() => {
    const d = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const tz = d.getTimezoneOffset() * 60_000;
    return new Date(d.getTime() - tz).toISOString().slice(0, 16);
  });
  const [bulkSaving, setBulkSaving] = useState(false);
  const [bulkError, setBulkError] = useState<string | null>(null);
  const [bulkResult, setBulkResult] = useState<string | null>(null);
  const [rowOpen, setRowOpen] = useState(false);
  const [rowDebt, setRowDebt] = useState<Debt | null>(null);
  const [rowDueAt, setRowDueAt] = useState<string>(() => {
    const d = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const tz = d.getTimezoneOffset() * 60_000;
    return new Date(d.getTime() - tz).toISOString().slice(0, 16);
  });
  const [rowAssignee, setRowAssignee] = useState<string | null>(null);
  const [rowSaving, setRowSaving] = useState(false);
  const [rowError, setRowError] = useState<string | null>(null);
  const [rowResult, setRowResult] = useState<string | null>(null);
  const [rowClientMissing, setRowClientMissing] = useState(false);
  const [rowClientChecking, setRowClientChecking] = useState(false);
  const assigneeStorageKey = useMemo(() => (userId ? `crm:last_assignee:${userId}` : null), [userId]);
  const readStoredAssignee = () => {
    if (!assigneeStorageKey) return null;
    try {
      const v = localStorage.getItem(assigneeStorageKey);
      return v ? v : null;
    } catch {
      return null;
    }
  };
  const writeStoredAssignee = (id: string) => {
    if (!assigneeStorageKey) return;
    try {
      localStorage.setItem(assigneeStorageKey, id);
    } catch {}
  };

  useEffect(() => {
    load();
  }, []);

  const load = async () => {
    try {
      setLoading(true);
      setErrorText(null);
      const { data: authData } = await supabase.auth.getUser();
      const user = authData.user;
      if (user) setUserId(user.id);

      const [debtsResult, projectsResult, profileRes, employeesRes] = await Promise.all([
        supabase
          .from('debts')
          .select('*')
          .order('saved_at', { ascending: false }),
        supabase
          .from('projects')
          .select('id, name, project_number')
          .order('created_at', { ascending: false })
        ,
        user
          ? supabase.from('employee_profiles').select('role').eq('user_id', user.id).maybeSingle()
          : Promise.resolve({ data: null, error: null } as any),
        supabase.rpc('crm_list_employees')
      ]);
      
      if (debtsResult.error) throw debtsResult.error;
      if (projectsResult.error) throw projectsResult.error;
      if (profileRes?.error) throw profileRes.error;
      if ((employeesRes as any)?.error) throw (employeesRes as any).error;
      
      setRows(debtsResult.data || []);
      setProjects(projectsResult.data || []);

      const nextRole = (((profileRes as any)?.data?.role as string | null) || 'admin') as EmployeeRole;
      setRole(nextRole);
      setEmployees((((employeesRes as any)?.data as any[]) || []) as EmployeeLite[]);
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

  const canBulkAssign = role === 'admin' || role === 'manager' || role === 'marketing';

  const allowedAssignees = useMemo(() => {
    const active = employees.filter((e) => e.is_active);
    const self = userId ? active.find((e) => e.id === userId) : null;

    if (!userId) return [];
    if (role === 'admin' || role === 'manager') return active;
    if (role === 'marketing') return [self || { id: userId, email: null, job_title: null, role, is_active: true }, ...active.filter((e) => (e.role === 'customer_service' || e.role === 'staff') && e.id !== userId)];
    return [self || { id: userId, email: null, job_title: null, role, is_active: true }];
  }, [employees, role, userId]);

  const groupedForBulk = useMemo(() => {
    const map = new Map<string, { idNumber: string; clientName: string; items: Debt[]; totalRemaining: number }>();
    for (const r of filtered) {
      const remaining = Number(r.remaining_value || 0);
      if (remaining <= 0) continue;
      const idNumber = String(r.original_client_id || '').trim();
      if (!idNumber) continue;
      const key = idNumber;
      const prev = map.get(key);
      if (!prev) {
        map.set(key, { idNumber, clientName: r.original_client_name || idNumber, items: [r], totalRemaining: remaining });
      } else {
        prev.items.push(r);
        prev.totalRemaining += remaining;
      }
    }
    const list = Array.from(map.values());
    list.sort((a, b) => b.totalRemaining - a.totalRemaining);
    return list;
  }, [filtered]);

  const debtGroupByIdNumber = useMemo(() => {
    const map = new Map<string, Debt[]>();
    for (const r of filtered) {
      const remaining = Number(r.remaining_value || 0);
      if (remaining <= 0) continue;
      const idNumber = String(r.original_client_id || '').trim();
      if (!idNumber) continue;
      const list = map.get(idNumber) || [];
      list.push(r);
      map.set(idNumber, list);
    }
    for (const [, list] of map.entries()) {
      list.sort((a, b) => {
        if (a.project_number !== b.project_number) return String(a.project_number).localeCompare(String(b.project_number), 'ar');
        return (a.unit_number || 0) - (b.unit_number || 0);
      });
    }
    return map;
  }, [filtered]);

  const startEndOfLocalDayIso = (localDateTime: string) => {
    const d = new Date(localDateTime);
    const start = new Date(d);
    start.setHours(0, 0, 0, 0);
    const end = new Date(d);
    end.setHours(23, 59, 59, 999);
    return { startIso: start.toISOString(), endIso: end.toISOString() };
  };

  const openRowTask = (d: Debt) => {
    setRowError(null);
    setRowResult(null);
    setRowClientMissing(false);
    setRowDebt(d);
    const stored = readStoredAssignee();
    const allowed = new Set(allowedAssignees.map((e) => e.id));
    if (stored && allowed.has(stored)) {
      setRowAssignee(stored);
    } else if (!rowAssignee) {
      const self = userId ? allowedAssignees.find((e) => e.id === userId) : null;
      setRowAssignee(self?.id || allowedAssignees[0]?.id || null);
    }
    setRowOpen(true);
  };

  useEffect(() => {
    const run = async () => {
      if (!rowOpen || !rowDebt) return;
      const idNumber = String(rowDebt.original_client_id || '').trim();
      if (!idNumber) {
        setRowClientMissing(false);
        return;
      }
      setRowClientChecking(true);
      try {
        const res = await supabase.from('clients').select('id').eq('id_number', idNumber).limit(1);
        if (res.error) throw res.error;
        setRowClientMissing(!((res.data as any[]) || [])[0]?.id);
      } catch {
        setRowClientMissing(false);
      } finally {
        setRowClientChecking(false);
      }
    };
    run();
  }, [rowDebt, rowOpen]);

  const ensureClientByIdNumber = async (p: { idNumber: string; name: string; phone: string | null }) => {
    const existingRes = await supabase.from('clients').select('id, name, id_number').eq('id_number', p.idNumber).limit(1).maybeSingle();
    if (existingRes.error) throw existingRes.error;
    if (existingRes.data?.id) return existingRes.data as any;

    const insertPayload: any = {
      name: p.name,
      id_number: p.idNumber,
      phone: p.phone || null
    };
    const insertRes = await supabase.from('clients').insert([insertPayload]).select('id, name, id_number').limit(1).maybeSingle();
    if (insertRes.error) throw insertRes.error;
    return insertRes.data as any;
  };

  const createDebtTaskCore = async (p: { clientId: string; clientName: string; unitId: string; title: string; description: string; dueIso: string }) => {
    const { startIso, endIso } = startEndOfLocalDayIso(rowDueAt);
    const dupeRes = await supabase
      .from('crm_tasks')
      .select('id', { head: true, count: 'exact' })
      .eq('client_id', p.clientId)
      .eq('unit_id', p.unitId)
      .gte('due_at', startIso)
      .lte('due_at', endIso)
      .ilike('title', 'متابعة مديونية%');

    if (dupeRes.error) throw dupeRes.error;
    if ((dupeRes.count || 0) > 0) {
      setRowError('مرفوض: توجد مهمة مديونية لنفس العميل ونفس الوحدة في نفس اليوم.');
      return { ok: false as const, reason: 'duplicate' as const };
    }

    const payload: any = {
      client_id: p.clientId,
      unit_id: p.unitId,
      title: p.title,
      description: p.description,
      due_at: p.dueIso,
      status: 'open',
      priority: 'high',
      assigned_to: rowAssignee || null
    };

    let insertRes = await supabase.from('crm_tasks').insert([payload]);
    if (insertRes.error && String(insertRes.error.message || '').toLowerCase().includes('column')) {
      const { description: _desc, ...rest } = payload;
      const titleWithDetails = `${payload.title}\n${String(p.description || '').trim()}`;
      insertRes = await supabase.from('crm_tasks').insert([{ ...rest, title: titleWithDetails }]);
    }
    if (insertRes.error) throw insertRes.error;
    return { ok: true as const };
  };

  const createDebtTaskForRow = async () => {
    setRowError(null);
    setRowResult(null);
    setRowClientMissing(false);
    if (!rowDebt) return;
    if (!userId) {
      setRowError('الرجاء تسجيل الدخول.');
      return;
    }
    if (!rowDueAt) {
      setRowError('الرجاء تحديد تاريخ الاستحقاق.');
      return;
    }

    const idNumber = String(rowDebt.original_client_id || '').trim();
    if (!idNumber) {
      setRowError('لا يمكن إنشاء مهمة لأن رقم هوية العميل غير موجود في سجل المديونية.');
      return;
    }

    const group = debtGroupByIdNumber.get(idNumber) || [rowDebt];
    const totalRemaining = group.reduce((sum, x) => sum + Number(x.remaining_value || 0), 0);
    const clientName = rowDebt.original_client_name || idNumber;
    const description = buildDescription(clientName, group, totalRemaining);

    setRowSaving(true);
    try {
      const resClient = await supabase.from('clients').select('id, name, id_number').eq('id_number', idNumber).limit(1).maybeSingle();
      if (resClient.error) throw resClient.error;
      if (!resClient.data?.id) {
        setRowError('لا يمكن الربط: العميل غير موجود في جدول العملاء (clients) بنفس رقم الهوية.');
        setRowClientMissing(true);
        setRowSaving(false);
        return;
      }

      const dueIso = new Date(rowDueAt).toISOString();
      const core = await createDebtTaskCore({
        clientId: resClient.data.id,
        clientName: resClient.data.name || clientName,
        unitId: rowDebt.unit_id,
        title: `متابعة مديونية: ${resClient.data.name || clientName} (متبقي ${totalRemaining})`,
        description,
        dueIso
      });
      if (!core.ok) {
        setRowSaving(false);
        return;
      }

      setRowResult(`تم إنشاء مهمة للعميل: ${resClient.data.name || clientName} • عدد الوحدات: ${group.length}`);
    } catch (e: any) {
      setRowError(e?.message || 'تعذر إنشاء المهمة');
    } finally {
      setRowSaving(false);
    }
  };

  const createClientThenDebtTaskForRow = async () => {
    setRowError(null);
    setRowResult(null);
    setRowClientMissing(false);
    if (!rowDebt) return;
    if (!userId) {
      setRowError('الرجاء تسجيل الدخول.');
      return;
    }
    if (!rowDueAt) {
      setRowError('الرجاء تحديد تاريخ الاستحقاق.');
      return;
    }

    const idNumber = String(rowDebt.original_client_id || '').trim();
    if (!idNumber) {
      setRowError('لا يمكن إنشاء العميل لأن رقم الهوية غير موجود.');
      return;
    }

    const rawName = String(rowDebt.original_client_name || '').trim();
    const name = rawName || `عميل ${idNumber}`;
    const phone = String(rowDebt.original_client_phone || '').trim() || null;

    const group = debtGroupByIdNumber.get(idNumber) || [rowDebt];
    const totalRemaining = group.reduce((sum, x) => sum + Number(x.remaining_value || 0), 0);
    const description = buildDescription(name, group, totalRemaining);
    const dueIso = new Date(rowDueAt).toISOString();

    setRowSaving(true);
    try {
      const client = await ensureClientByIdNumber({ idNumber, name, phone });
      if (!client?.id) {
        setRowError('تعذر إنشاء العميل.');
        setRowSaving(false);
        return;
      }

      const core = await createDebtTaskCore({
        clientId: String(client.id),
        clientName: String(client.name || name),
        unitId: rowDebt.unit_id,
        title: `متابعة مديونية: ${String(client.name || name)} (متبقي ${totalRemaining})`,
        description,
        dueIso
      });
      if (!core.ok) {
        setRowSaving(false);
        return;
      }

      setRowResult(`تم إنشاء العميل ثم المهمة: ${String(client.name || name)} • عدد الوحدات: ${group.length}`);
    } catch (e: any) {
      setRowError(e?.message || 'تعذر إنشاء العميل/المهمة');
    } finally {
      setRowSaving(false);
    }
  };

  const openBulk = () => {
    setBulkError(null);
    setBulkResult(null);
    if (bulkAssignees.length === 0) {
      const defaults = allowedAssignees.filter((e) => e.role === 'customer_service' || e.role === 'staff').map((e) => e.id);
      setBulkAssignees(defaults.length > 0 ? defaults : allowedAssignees.map((e) => e.id));
    }
    setBulkOpen(true);
  };

  const toggleAssignee = (id: string) => {
    setBulkAssignees((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  const buildDescription = (clientName: string, items: Debt[], totalRemaining: number) => {
    const sorted = [...items].sort((a, b) => {
      if (a.project_number !== b.project_number) return String(a.project_number).localeCompare(String(b.project_number), 'ar');
      return (a.unit_number || 0) - (b.unit_number || 0);
    });
    const lines: string[] = [];
    lines.push(`تفاصيل المديونية للعميل: ${clientName}`);
    lines.push('');
    for (const x of sorted) {
      const code = `${x.project_number}-${x.unit_number}`;
      const rem = Number(x.remaining_value || 0);
      lines.push(`- ${code} (${x.project_name}): المتبقي ${rem}`);
    }
    lines.push('');
    lines.push(`الإجمالي المتبقي: ${totalRemaining}`);
    return lines.join('\n');
  };

  const generateDebtTasks = async () => {
    setBulkError(null);
    setBulkResult(null);
    if (!canBulkAssign) {
      setBulkError('غير مصرح لك بإنشاء مهام جماعية.');
      return;
    }
    if (!userId) {
      setBulkError('الرجاء تسجيل الدخول.');
      return;
    }
    if (!bulkDueAt) {
      setBulkError('الرجاء تحديد تاريخ الاستحقاق.');
      return;
    }
    if (groupedForBulk.length === 0) {
      setBulkError('لا يوجد عملاء لديهم مديونية متبقية ضمن النتائج الحالية.');
      return;
    }

    const idNumbers = groupedForBulk.map((g) => g.idNumber);
    setBulkSaving(true);
    try {
      const clients: ClientLite[] = [];
      for (let i = 0; i < idNumbers.length; i += 500) {
        const chunk = idNumbers.slice(i, i + 500);
        const res = await supabase.from('clients').select('id, name, id_number').in('id_number', chunk);
        if (res.error) throw res.error;
        clients.push(...((((res.data as any[]) || []) as ClientLite[])));
      }
      const clientByIdNumber = new Map<string, ClientLite>();
      for (const c of clients) {
        const key = String(c.id_number || '').trim();
        if (!key) continue;
        if (!clientByIdNumber.has(key)) clientByIdNumber.set(key, c);
      }

      const base = new Date(bulkDueAt).getTime();
      const tasksToInsert: any[] = [];
      let skippedNoClient = 0;
      let skippedZero = 0;

      const assignees = bulkAssignees.filter(Boolean);
      const hasAssignees = assignees.length > 0;

      let idx = 0;
      for (const g of groupedForBulk) {
        if (g.totalRemaining <= 0) {
          skippedZero += 1;
          continue;
        }
        const matched = clientByIdNumber.get(g.idNumber);
        if (!matched) {
          skippedNoClient += 1;
          continue;
        }

        const dayOffset = bulkDueMode === 'per10' ? Math.floor(idx / 10) : 0;
        const dueAtIso = new Date(base + dayOffset * 24 * 60 * 60 * 1000).toISOString();
        const assignedTo = hasAssignees ? assignees[idx % assignees.length] : null;
        const description = buildDescription(matched.name || g.clientName, g.items, g.totalRemaining);
        const payload: any = {
          client_id: matched.id,
          unit_id: null,
          title: `متابعة مديونية (متبقي ${g.totalRemaining})`,
          description,
          due_at: dueAtIso,
          status: 'open',
          priority: 'high',
          assigned_to: assignedTo
        };
        tasksToInsert.push(payload);
        idx += 1;
      }

      let inserted = 0;
      let insertedFallback = 0;

      const insertBatch = async (batch: any[]) => {
        const res = await supabase.from('crm_tasks').insert(batch);
        if (!res.error) return { ok: true as const, fallback: false as const };
        if (String(res.error.message || '').toLowerCase().includes('column')) {
          const fallbackBatch = batch.map((x) => {
            const titleWithDetails = `${x.title}\n${String(x.description || '').trim()}`;
            const { description: _desc, ...rest } = x;
            return { ...rest, title: titleWithDetails };
          });
          const res2 = await supabase.from('crm_tasks').insert(fallbackBatch);
          if (res2.error) throw res2.error;
          return { ok: true as const, fallback: true as const };
        }
        throw res.error;
      };

      for (let i = 0; i < tasksToInsert.length; i += 100) {
        const batch = tasksToInsert.slice(i, i + 100);
        const r = await insertBatch(batch);
        inserted += batch.length;
        if (r.fallback) insertedFallback += batch.length;
      }

      const assigneesLabel = hasAssignees ? assignees.map((id) => employeeLabelById.get(id) || id.slice(0, 8)).join('، ') : 'مهام عامّة';
      const modeLabel = bulkDueMode === 'single' ? 'موحد' : 'كل 10 مهام في يوم';
      const fallbackNote = insertedFallback > 0 ? ` (تم حفظ التفاصيل داخل عنوان المهمة لعدد ${insertedFallback})` : '';
      setBulkResult(`تم إنشاء ${inserted} مهمة.${fallbackNote} | لم يتم الربط لعدد ${skippedNoClient} عميل (غير موجود في العملاء). | المستلمين: ${assigneesLabel} | نمط التاريخ: ${modeLabel}`);
    } catch (e: any) {
      setBulkError(e?.message || 'تعذر إنشاء المهام');
    } finally {
      setBulkSaving(false);
    }
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
            {canBulkAssign ? (
              <button
                onClick={openBulk}
                className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 bg-gray-900 text-white rounded-xl text-sm font-bold hover:bg-black transition-colors"
              >
                <ClipboardList size={18} />
                إنشاء مهام
              </button>
            ) : null}
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
                  <th className="px-4 py-3 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">إجراء</th>
               </tr>
             </thead>
             <tbody className="divide-y divide-gray-100">
               {errorText ? (
                 <tr>
                    <td colSpan={9} className="p-8 text-center text-red-600">{errorText}</td>
                 </tr>
               ) : loading ? (
                 <tr>
                    <td colSpan={9} className="p-8 text-center text-gray-500">جاري التحميل...</td>
                 </tr>
               ) : filtered.length === 0 ? (
                 <tr>
                    <td colSpan={9} className="p-8 text-center text-gray-500">لا توجد بيانات</td>
                 </tr>
               ) : (
                 filtered.map((r) => {
                   const code = `${r.project_number}-${r.unit_number}`;
                    const canRowAction = canBulkAssign && Number(r.remaining_value || 0) > 0;
                    const idNumber = String(r.original_client_id || '').trim();
                    const groupCount = idNumber ? debtGroupByIdNumber.get(idNumber)?.length || 0 : 0;
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
                        <td className="px-4 py-3">
                          <button
                            type="button"
                            onClick={() => openRowTask(r)}
                            disabled={!canRowAction}
                            className={`inline-flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-bold border transition-colors ${
                              canRowAction ? 'bg-white border-gray-200 text-gray-800 hover:bg-gray-50' : 'bg-gray-100 border-gray-200 text-gray-400'
                            }`}
                          >
                            <ClipboardList size={14} />
                            {groupCount > 1 ? `مهمة (يشمل ${groupCount})` : 'إضافة مهمة'}
                          </button>
                        </td>
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

      {bulkOpen ? (
        <div className="fixed inset-0 z-50">
          <div
            className="absolute inset-0 bg-black/60"
            onClick={() => {
              if (!bulkSaving) setBulkOpen(false);
            }}
          />
          <div className="absolute inset-0 flex items-center justify-center p-4">
            <div className="w-full max-w-4xl bg-white rounded-2xl shadow-2xl border border-gray-200 overflow-hidden">
              <div className="p-5 border-b border-gray-100 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="font-bold text-gray-900">إنشاء مهام متابعة المديونية</div>
                  <div className="text-sm text-gray-600">
                    سيتم إنشاء مهمة واحدة لكل عميل ضمن النتائج الحالية (فقط العملاء الذين لديهم متبقي &gt; 0)
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setBulkOpen(false)}
                  disabled={bulkSaving}
                  className="px-3 py-2 rounded-xl bg-gray-100 text-gray-700 font-bold disabled:opacity-60"
                >
                  إغلاق
                </button>
              </div>

              <div className="p-5 space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <div className="rounded-xl border border-gray-200 bg-gray-50 p-4">
                    <div className="text-xs font-bold text-gray-500">ملخص</div>
                    <div className="mt-2 grid grid-cols-2 gap-2 text-sm">
                      <div className="text-gray-700">صفوف ضمن الفلتر</div>
                      <div className="font-bold text-gray-900 text-left" dir="ltr">
                        {filtered.length}
                      </div>
                      <div className="text-gray-700">عدد العملاء</div>
                      <div className="font-bold text-gray-900 text-left" dir="ltr">
                        {groupedForBulk.length}
                      </div>
                    </div>
                    <div className="mt-3 text-[11px] text-gray-500">
                      الربط يتم عبر رقم الهوية المحفوظ في المديونية (original_client_id) مع clients.id_number.
                    </div>
                  </div>

                  <div className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
                    <div className="text-sm font-bold text-gray-700">تاريخ الاستحقاق</div>
                    <div className="grid grid-cols-1 gap-2">
                      <select
                        value={bulkDueMode}
                        onChange={(e) => setBulkDueMode(e.target.value as any)}
                        className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                      >
                        <option value="single">تاريخ موحد</option>
                        <option value="per10">كل 10 مهام في يوم</option>
                      </select>
                      <input
                        type="datetime-local"
                        value={bulkDueAt}
                        onChange={(e) => setBulkDueAt(e.target.value)}
                        className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                      />
                      <div className="text-[11px] text-gray-500">
                        {bulkDueMode === 'per10' ? 'سيتم زيادة يوم لكل 10 مهام (10 في اليوم).' : 'كل المهام ستكون بنفس التاريخ.'}
                      </div>
                    </div>
                  </div>

                  <div className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="text-sm font-bold text-gray-700">المستلمين</div>
                      <div className="inline-flex items-center gap-2 text-xs text-gray-500">
                        <Users size={14} />
                        {bulkAssignees.length}
                      </div>
                    </div>
                    <div className="max-h-[180px] overflow-auto border border-gray-200 rounded-xl">
                      <div className="p-2 space-y-1">
                        {allowedAssignees.length === 0 ? (
                          <div className="text-sm text-gray-500 p-2">لا يوجد موظفين</div>
                        ) : (
                          allowedAssignees.map((e) => {
                            const label = employeeLabelById.get(e.id) || e.id;
                            const checked = bulkAssignees.includes(e.id);
                            return (
                              <button
                                key={e.id}
                                type="button"
                                onClick={() => toggleAssignee(e.id)}
                                className={`w-full flex items-center justify-between gap-2 px-3 py-2 rounded-lg text-sm border ${
                                  checked ? 'bg-emerald-50 border-emerald-200 text-emerald-900' : 'bg-white border-gray-200 text-gray-800'
                                }`}
                              >
                                <span className="font-bold truncate">{label}</span>
                                <span className={`text-xs font-bold ${checked ? 'text-emerald-700' : 'text-gray-500'}`}>{checked ? 'مختار' : ''}</span>
                              </button>
                            );
                          })
                        )}
                      </div>
                    </div>
                    <div className="text-[11px] text-gray-500">سيتم توزيع المهام بالتساوي على المختارين.</div>
                  </div>
                </div>

                {bulkError ? (
                  <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-700 text-sm flex items-center gap-2">
                    <AlertCircle size={18} />
                    {bulkError}
                  </div>
                ) : null}

                {bulkResult ? (
                  <div className="p-3 bg-emerald-50 border border-emerald-100 rounded-xl text-emerald-800 text-sm">{bulkResult}</div>
                ) : null}
              </div>

              <div className="p-5 border-t border-gray-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setBulkOpen(false)}
                  disabled={bulkSaving}
                  className="px-5 py-2.5 rounded-xl bg-white border border-gray-200 text-gray-700 font-bold hover:bg-gray-50 disabled:opacity-60"
                >
                  إلغاء
                </button>
                <button
                  type="button"
                  onClick={generateDebtTasks}
                  disabled={bulkSaving || groupedForBulk.length === 0 || !bulkDueAt}
                  className="px-6 py-2.5 rounded-xl bg-gradient-to-l from-emerald-600 to-emerald-700 text-white font-bold shadow-sm disabled:opacity-60"
                >
                  {bulkSaving ? 'جاري الإنشاء...' : 'إنشاء المهام'}
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {rowOpen && rowDebt ? (
        <div className="fixed inset-0 z-50">
          <div
            className="absolute inset-0 bg-black/60"
            onClick={() => {
              if (!rowSaving) setRowOpen(false);
            }}
          />
          <div className="absolute inset-0 flex items-center justify-center p-4">
            <div className="w-full max-w-2xl bg-white rounded-2xl shadow-2xl border border-gray-200 overflow-hidden">
              <div className="p-5 border-b border-gray-100 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="font-bold text-gray-900">إضافة مهمة مديونية</div>
                  <div className="text-sm text-gray-600 truncate">
                    {rowDebt.original_client_name || '-'} • {rowDebt.project_number}-{rowDebt.unit_number}
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setRowOpen(false)}
                  disabled={rowSaving}
                  className="px-3 py-2 rounded-xl bg-gray-100 text-gray-700 font-bold disabled:opacity-60"
                >
                  إغلاق
                </button>
              </div>

              <div className="p-5 space-y-4">
                {rowClientMissing ? (
                  <div className="p-3 bg-amber-50 border border-amber-100 rounded-xl text-amber-900 text-sm font-bold">
                    العميل غير موجود في جدول العملاء — استخدم زر "إنشاء العميل ثم إضافة المهمة".
                  </div>
                ) : null}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
                    <div className="text-sm font-bold text-gray-700">تاريخ الاستحقاق</div>
                    <input
                      type="datetime-local"
                      value={rowDueAt}
                      onChange={(e) => setRowDueAt(e.target.value)}
                      className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                    />
                    <div className="text-[11px] text-gray-500">لن يتم إنشاء مهمة مكررة لنفس العميل/الوحدة في نفس اليوم.</div>
                  </div>

                  <div className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
                    <div className="text-sm font-bold text-gray-700">المكلّف بها</div>
                    <select
                      value={rowAssignee || ''}
                      onChange={(e) => {
                        const v = e.target.value || null;
                        setRowAssignee(v);
                        if (v) writeStoredAssignee(v);
                      }}
                      className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                    >
                      <option value="">عامّة</option>
                      {allowedAssignees.map((e) => (
                        <option key={e.id} value={e.id}>
                          {employeeLabelById.get(e.id) || e.id}
                        </option>
                      ))}
                    </select>
                    <div className="text-[11px] text-gray-500">إذا كان للعميل أكثر من وحدة مديونة سيتم تضمينها كلها في تفاصيل المهمة.</div>
                  </div>
                </div>

                {rowError ? (
                  <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-700 text-sm flex items-center gap-2">
                    <AlertCircle size={18} />
                    {rowError}
                  </div>
                ) : null}

                {rowResult ? <div className="p-3 bg-emerald-50 border border-emerald-100 rounded-xl text-emerald-800 text-sm">{rowResult}</div> : null}
              </div>

              <div className="p-5 border-t border-gray-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setRowOpen(false)}
                  disabled={rowSaving}
                  className="px-5 py-2.5 rounded-xl bg-white border border-gray-200 text-gray-700 font-bold hover:bg-gray-50 disabled:opacity-60"
                >
                  إلغاء
                </button>
                <button
                  type="button"
                  onClick={rowClientMissing ? createClientThenDebtTaskForRow : createDebtTaskForRow}
                  disabled={rowSaving || !rowDueAt || rowClientChecking}
                  className="px-6 py-2.5 rounded-xl bg-gradient-to-l from-emerald-600 to-emerald-700 text-white font-bold shadow-sm disabled:opacity-60"
                >
                  {rowSaving
                    ? 'جاري الإضافة...'
                    : rowClientChecking
                      ? 'جاري التحقق...'
                      : rowClientMissing
                        ? 'إنشاء العميل ثم إضافة المهمة'
                        : 'إضافة المهمة'}
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
     </div>
   );
 }
