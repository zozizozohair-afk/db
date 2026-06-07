'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Plus, Search, Users, ClipboardList, AlertCircle, Phone, Mail, MessageCircle, ArrowUpLeft, BarChart3, SlidersHorizontal } from 'lucide-react';
import { supabase } from '../../lib/supabaseClient';
import type { Client, CrmActivity, CrmClientStage, CrmPipelineStage, CrmTask, Project, Unit } from '../../types';

type LinkedUnit = {
  unit_id: string;
  project_id: string;
  project_name: string;
  project_number: string;
  unit_number: number;
  status: Unit['status'];
  relationLabel: string;
};

type EmployeeRole = 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';

type EmployeeLite = {
  id: string;
  email: string | null;
  job_title: string | null;
  role: EmployeeRole;
  is_active: boolean;
};

type ClientRow = Client & {
  stageId: string | null;
  stageName: string;
  openTasksCount: number;
  myTasksCount: number;
  nextDueAt: string | null;
  linkedUnits: LinkedUnit[];
  lastActivityAt: string | null;
  lastActivityBy: string | null;
  lastActivityChannel: string | null;
};

export default function CrmDashboardPage() {
  const router = useRouter();
  const pathname = usePathname();
  const [isAdmin, setIsAdmin] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [role, setRole] = useState<EmployeeRole>('viewer');
  const [employees, setEmployees] = useState<EmployeeLite[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [stages, setStages] = useState<CrmPipelineStage[]>([]);
  const [clientStages, setClientStages] = useState<CrmClientStage[]>([]);
  const [openTasks, setOpenTasks] = useState<CrmTask[]>([]);
  const [recentActivities, setRecentActivities] = useState<Array<Pick<CrmActivity, 'id' | 'client_id' | 'created_at' | 'created_by' | 'channel'>>>([]);
  const [linkedUnitsByClientId, setLinkedUnitsByClientId] = useState<Record<string, LinkedUnit[]>>({});
  const [projectsList, setProjectsList] = useState<{ id: string; name: string; project_number: string }[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('list');
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [unitStatusFilter, setUnitStatusFilter] = useState<'all' | 'no_unit' | Unit['status']>('all');
  const [clientStageFilter, setClientStageFilter] = useState<'all' | string>('all');
  const [clientTypeFilter, setClientTypeFilter] = useState<'all' | 'original' | 'current' | 'none'>('all');
  const [projectFilter, setProjectFilter] = useState<'all' | string>('all');
  const [workFilter, setWorkFilter] = useState<'all' | 'with_tasks' | 'assigned_to_me' | 'with_activity'>('all');
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [newClient, setNewClient] = useState<{ name: string; id_number: string; phone: string; notes: string }>({
    name: '',
    id_number: '',
    phone: '',
    notes: ''
  });
  const [adding, setAdding] = useState(false);

  const [contactOpen, setContactOpen] = useState(false);
  const [contactClient, setContactClient] = useState<ClientRow | null>(null);
  const [contactUnitId, setContactUnitId] = useState<string | null>(null);
  const [contactUnitIds, setContactUnitIds] = useState<string[]>([]);
  const [contactChannel, setContactChannel] = useState<'call' | 'whatsapp' | 'email'>('call');
  const [contactNote, setContactNote] = useState('');
  const [contactNextAt, setContactNextAt] = useState('');
  const [contactOutcome, setContactOutcome] = useState<'completed' | 'no_answer' | 'appointment'>('completed');
  const [appointmentAt, setAppointmentAt] = useState('');
  const [appointmentWith, setAppointmentWith] = useState('');
  const [contactSaving, setContactSaving] = useState(false);
  const [contactError, setContactError] = useState<string | null>(null);

  const [waMode, setWaMode] = useState<'template' | 'custom'>('template');
  const [waMessageType, setWaMessageType] = useState<'deed_transfer' | 'resale_contract' | 'payment_reminder' | 'meter_transfer' | null>(null);
  const [waCopied, setWaCopied] = useState(false);
  const [waCustomText, setWaCustomText] = useState('');

  const DEFAULT_APPOINTMENT_WITH_OPTIONS = useMemo(
    () => ['ابو شموخ', 'ابو سند', 'ابو لينا', 'ابو سعد', 'عصام', 'زهير', 'ندا'],
    []
  );
  const [appointmentWithOptions, setAppointmentWithOptions] = useState<string[]>(DEFAULT_APPOINTMENT_WITH_OPTIONS);
  const appointmentWithOptionsLoadedRef = useRef(false);

  const loadAppointmentWithOptions = async (force = false) => {
    if (!force && appointmentWithOptionsLoadedRef.current) return;
    appointmentWithOptionsLoadedRef.current = true;
    try {
      const res = await supabase.from('crm_appointment_hosts').select('name').order('name', { ascending: true });
      if (res.error) {
        const msg = String(res.error.message || '').toLowerCase();
        if (msg.includes('does not exist') || msg.includes('relation') || msg.includes('not exist')) return;
        return;
      }
      const names = ((res.data as any[]) || []).map((r) => String(r?.name || '').trim()).filter(Boolean);
      if (names.length > 0) setAppointmentWithOptions(names);
    } catch {}
  };

  const seedAppointmentWithOptions = async () => {
    try {
      const res = await supabase
        .from('crm_appointment_hosts')
        .upsert(
          DEFAULT_APPOINTMENT_WITH_OPTIONS.map((name) => ({ name })),
          { onConflict: 'name', ignoreDuplicates: true }
        );
      if (res.error) {
        const msg = String(res.error.message || '').toLowerCase();
        if (msg.includes('does not exist') || msg.includes('relation') || msg.includes('not exist')) return;
      }
    } catch {}
  };

  const toLocalInput = (d: Date) => {
    const tz = d.getTimezoneOffset() * 60_000;
    return new Date(d.getTime() - tz).toISOString().slice(0, 16);
  };

  const inferDefaultWorkFilter = (p: { userId: string | null; role: EmployeeRole }) => {
    if (!p.userId) return 'all' as const;
    if (p.role === 'admin' || p.role === 'manager') return 'all' as const;
    return 'assigned_to_me' as const;
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
      setWorkFilter(inferDefaultWorkFilter({ userId: user.id, role: nextRole }));
      await fetchData({ userId: user.id, role: nextRole });
      await seedAppointmentWithOptions();
      await loadAppointmentWithOptions();
    };
    run();
  }, []);

  const fetchData = async (p?: { userId: string | null; role: EmployeeRole }) => {
    setLoading(true);
    setErrorText(null);
    try {
      const nextRole = p?.role ?? role;
      const nextUserId = p?.userId ?? userId;

      let tasksQuery = supabase.from('crm_tasks').select('*').eq('status', 'open');
      if (nextRole !== 'admin' && nextRole !== 'manager') {
        if (!nextUserId) {
          tasksQuery = tasksQuery.limit(0);
        } else {
          tasksQuery = tasksQuery.or(`assigned_to.is.null,assigned_to.eq.${nextUserId}`);
        }
      }

      const [clientsRes, stagesRes, clientStagesRes, tasksRes, activitiesRes, employeesRes] = await Promise.all([
        supabase.from('clients').select('*').order('created_at', { ascending: false }),
        supabase.from('crm_pipeline_stages').select('*').order('sort_order', { ascending: true }),
        supabase.from('crm_client_stage').select('*'),
        tasksQuery,
        supabase
          .from('crm_activities')
          .select('id, client_id, created_at, created_by, channel')
          .order('created_at', { ascending: false })
          .limit(5000),
        supabase.rpc('crm_list_employees')
      ]);

      if (clientsRes.error) throw clientsRes.error;
      if (stagesRes.error) throw stagesRes.error;
      if (clientStagesRes.error) throw clientStagesRes.error;
      if (tasksRes.error) throw tasksRes.error;
      if (activitiesRes.error) throw activitiesRes.error;
      if (employeesRes.error) throw employeesRes.error;

      const clientsData = (clientsRes.data as Client[]) || [];
      setClients(clientsData);
      setStages((stagesRes.data as CrmPipelineStage[]) || []);
      setClientStages((clientStagesRes.data as CrmClientStage[]) || []);
      setOpenTasks((tasksRes.data as CrmTask[]) || []);
      setRecentActivities((((activitiesRes.data as any[]) || []) as any[]).map((a) => ({
        id: a.id,
        client_id: a.client_id,
        created_at: a.created_at,
        created_by: a.created_by ?? null,
        channel: a.channel
      })));
      setEmployees(((employeesRes.data as any[]) || []) as EmployeeLite[]);

      const clientIds = clientsData.map((c) => c.id);
      const idNumbers = Array.from(new Set(clientsData.map((c) => c.id_number).filter(Boolean) as string[]));

      const unitsById = new Map<string, any>();

      if (clientIds.length > 0) {
        const [originalRes, currentRes] = await Promise.all([
          supabase
            .from('units')
            .select('id, project_id, unit_number, status, original_client_id, current_client_id, client_id_number, title_deed_owner_id')
            .in('original_client_id', clientIds),
          supabase
            .from('units')
            .select('id, project_id, unit_number, status, original_client_id, current_client_id, client_id_number, title_deed_owner_id')
            .in('current_client_id', clientIds)
        ]);
        if (originalRes.error) throw originalRes.error;
        if (currentRes.error) throw currentRes.error;
        for (const u of (originalRes.data as any[]) || []) unitsById.set(u.id, u);
        for (const u of (currentRes.data as any[]) || []) unitsById.set(u.id, u);
      }

      if (idNumbers.length > 0) {
        const [legacyOriginalRes, legacyCurrentRes] = await Promise.all([
          supabase
            .from('units')
            .select('id, project_id, unit_number, status, original_client_id, current_client_id, client_id_number, title_deed_owner_id')
            .in('client_id_number', idNumbers),
          supabase
            .from('units')
            .select('id, project_id, unit_number, status, original_client_id, current_client_id, client_id_number, title_deed_owner_id')
            .in('title_deed_owner_id', idNumbers)
        ]);
        if (legacyOriginalRes.error) throw legacyOriginalRes.error;
        if (legacyCurrentRes.error) throw legacyCurrentRes.error;
        for (const u of (legacyOriginalRes.data as any[]) || []) unitsById.set(u.id, u);
        for (const u of (legacyCurrentRes.data as any[]) || []) unitsById.set(u.id, u);
      }

      const allUnits = Array.from(unitsById.values());
      const projectIds = Array.from(new Set(allUnits.map((u) => u.project_id).filter(Boolean)));
      const projectsById = new Map<string, Project>();

      if (projectIds.length > 0) {
        const projectsRes = await supabase.from('projects').select('id, name, project_number').in('id', projectIds);
        if (projectsRes.error) throw projectsRes.error;
        for (const p of (projectsRes.data as Project[]) || []) projectsById.set(p.id, p);
      }

      const projectsListRes = await supabase.from('projects').select('id, name, project_number').order('created_at', { ascending: false });
      if (projectsListRes.error) throw projectsListRes.error;
      setProjectsList((projectsListRes.data as any[]) || []);

      const idNumberByClientId = new Map<string, string>();
      for (const c of clientsData) {
        if (c.id_number) idNumberByClientId.set(c.id, c.id_number);
      }

      const map: Record<string, LinkedUnit[]> = {};
      for (const c of clientsData) map[c.id] = [];

      for (const u of allUnits) {
        const p = projectsById.get(u.project_id);
        const projectName = p?.name || 'غير معروف';
        const projectNumber = p?.project_number || '-';
        const addForClient = (clientId: string, relationLabel: string) => {
          const list = map[clientId] || [];
          list.push({
            unit_id: u.id,
            project_id: u.project_id,
            project_name: projectName,
            project_number: projectNumber,
            unit_number: u.unit_number,
            status: u.status,
            relationLabel
          });
          map[clientId] = list;
        };

        if (u.original_client_id) addForClient(u.original_client_id, 'عميل أصلي');
        if (u.current_client_id && u.current_client_id !== u.original_client_id) addForClient(u.current_client_id, 'عميل مفرّغ له');

        if (!u.original_client_id && !u.current_client_id) {
          for (const [clientId, idNum] of idNumberByClientId.entries()) {
            if (u.client_id_number && u.client_id_number === idNum) addForClient(clientId, 'عميل أصلي');
            if (u.title_deed_owner_id && u.title_deed_owner_id === idNum) addForClient(clientId, 'عميل مفرّغ له');
          }
        }
      }

      for (const clientId of Object.keys(map)) {
        map[clientId] = map[clientId].sort((a, b) => {
          if (a.project_number !== b.project_number) return a.project_number.localeCompare(b.project_number, 'ar');
          return (a.unit_number || 0) - (b.unit_number || 0);
        });
      }

      setLinkedUnitsByClientId(map);
    } catch (e: any) {
      setErrorText(e?.message || 'تعذر تحميل بيانات CRM');
    } finally {
      setLoading(false);
    }
  };

  const stageNameById = useMemo(() => {
    const map = new Map<string, string>();
    for (const s of stages) map.set(s.id, s.name);
    return map;
  }, [stages]);

  const stageIdByClientId = useMemo(() => {
    const map = new Map<string, string | null>();
    for (const cs of clientStages) map.set(cs.client_id, cs.stage_id);
    return map;
  }, [clientStages]);

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

  const openTasksByClientId = useMemo(() => {
    const map = new Map<string, CrmTask[]>();
    for (const t of openTasks) {
      const list = map.get(t.client_id) || [];
      list.push(t);
      map.set(t.client_id, list);
    }
    for (const [, list] of map.entries()) {
      list.sort((a, b) => {
        if (!a.due_at && !b.due_at) return 0;
        if (!a.due_at) return 1;
        if (!b.due_at) return -1;
        return new Date(a.due_at).getTime() - new Date(b.due_at).getTime();
      });
    }
    return map;
  }, [openTasks]);

  const lastActivityByClientId = useMemo(() => {
    const map = new Map<string, { at: string; by: string | null; channel: string | null }>();
    for (const a of recentActivities) {
      if (!a?.client_id) continue;
      if (map.has(a.client_id)) continue;
      map.set(a.client_id, { at: a.created_at, by: a.created_by ?? null, channel: a.channel ?? null });
    }
    return map;
  }, [recentActivities]);

  const rows: ClientRow[] = useMemo(() => {
    return clients.map((c) => {
      const stageId = stageIdByClientId.get(c.id) || null;
      const stageName = stageId ? stageNameById.get(stageId) || 'غير محدد' : 'غير محدد';
      const tasks = openTasksByClientId.get(c.id) || [];
      const nextDueAt = tasks.find((t) => t.due_at)?.due_at || null;
      const linkedUnits = linkedUnitsByClientId[c.id] || [];
      const myTasksCount = userId ? tasks.filter((t) => t.assigned_to === userId).length : 0;
      const last = lastActivityByClientId.get(c.id) || null;
      return {
        ...c,
        stageId,
        stageName,
        openTasksCount: tasks.length,
        myTasksCount,
        nextDueAt,
        linkedUnits,
        lastActivityAt: last?.at || null,
        lastActivityBy: last?.by || null,
        lastActivityChannel: last?.channel || null
      };
    });
  }, [clients, lastActivityByClientId, linkedUnitsByClientId, openTasksByClientId, stageIdByClientId, stageNameById, userId]);

  const statusBadge = (status: Unit['status']) => {
    if (status === 'available') return 'bg-green-100 text-green-700';
    if (status === 'sold') return 'bg-red-100 text-red-700';
    if (status === 'sold_to_other') return 'bg-gray-100 text-gray-700';
    if (status === 'pending_sale') return 'bg-orange-100 text-orange-700';
    if (status === 'resale' || status === 'for_resale') return 'bg-purple-100 text-purple-700';
    return 'bg-gray-100 text-gray-700';
  };

  const statusLabel = (status: Unit['status']) => {
    if (status === 'available') return 'متاحة';
    if (status === 'sold') return 'مباعة';
    if (status === 'sold_to_other') return 'مباعة لغيره';
    if (status === 'pending_sale') return 'بانتظار البيع';
    if (status === 'resale') return 'إعادة بيع';
    if (status === 'for_resale') return 'معروضة لإعادة البيع';
    if (status === 'rented') return 'مؤجرة';
    if (status === 'under_construction') return 'تحت الإنشاء';
    if (status === 'deed_completed') return 'تم الإفراغ';
    if (status === 'resold') return 'أعيد بيعها';
    if (status === 'transferred_to_other') return 'منقولة لغيره';
    return status;
  };

  const normalizeProjectUnitKey = (value: string) => {
    return value
      .trim()
      .replace(/[–—−ـ/\\\s]+/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');
  };

  const visibleUnitsForClient = (c: ClientRow) => {
    let list = c.linkedUnits;

    if (projectFilter !== 'all') {
      list = list.filter((u) => u.project_id === projectFilter);
    }

    if (unitStatusFilter === 'no_unit') {
      list = [];
    } else if (unitStatusFilter !== 'all') {
      list = list.filter((u) => u.status === unitStatusFilter);
    }

    if (clientTypeFilter === 'original') {
      list = list.filter((u) => u.relationLabel === 'عميل أصلي');
    } else if (clientTypeFilter === 'current') {
      list = list.filter((u) => u.relationLabel === 'عميل مفرّغ له');
    }

    return list;
  };

  const clientTheme = (c: ClientRow, visibleUnits: LinkedUnit[]) => {
    const hasUnits = visibleUnits.length > 0;
    const hasResale = visibleUnits.some((u) => u.status === 'resale' || u.status === 'for_resale');
    const hasSold = visibleUnits.some((u) => u.status === 'sold' || u.status === 'sold_to_other');
    const isNewStage = c.stageName === 'عميل جديد' || c.stageName === 'غير محدد';

    if (hasResale) {
      return {
        border: 'bg-gradient-to-l from-purple-500 via-fuchsia-500 to-indigo-500',
        stripe: 'bg-gradient-to-b from-purple-500 via-fuchsia-500 to-indigo-500',
        header: 'bg-gradient-to-l from-slate-900 via-purple-900 to-slate-900',
        avatar: 'bg-gradient-to-l from-purple-600 to-fuchsia-600'
      };
    }

    if (hasSold) {
      return {
        border: 'bg-gradient-to-l from-red-500 via-rose-500 to-orange-500',
        stripe: 'bg-gradient-to-b from-red-500 via-rose-500 to-orange-500',
        header: 'bg-gradient-to-l from-slate-900 via-red-900 to-slate-900',
        avatar: 'bg-gradient-to-l from-red-600 to-rose-600'
      };
    }

    if (hasUnits) {
      return {
        border: 'bg-gradient-to-l from-emerald-600 via-teal-600 to-emerald-600',
        stripe: 'bg-gradient-to-b from-emerald-600 via-teal-600 to-emerald-600',
        header: 'bg-gradient-to-l from-slate-900 via-emerald-900 to-slate-900',
        avatar: 'bg-gradient-to-l from-emerald-600 to-teal-600'
      };
    }

    if (isNewStage) {
      return {
        border: 'bg-gradient-to-l from-sky-500 via-blue-500 to-indigo-500',
        stripe: 'bg-gradient-to-b from-sky-500 via-blue-500 to-indigo-500',
        header: 'bg-gradient-to-l from-slate-900 via-blue-900 to-slate-900',
        avatar: 'bg-gradient-to-l from-blue-600 to-indigo-600'
      };
    }

    return {
      border: 'bg-gradient-to-l from-emerald-500 via-teal-500 to-sky-500',
      stripe: 'bg-gradient-to-b from-emerald-500 via-teal-500 to-sky-500',
      header: 'bg-gradient-to-l from-slate-900 via-emerald-900 to-slate-900',
      avatar: 'bg-gradient-to-l from-emerald-600 to-emerald-700'
    };
  };

  const filteredRows = useMemo(() => {
    const q = searchQuery.trim();
    const qProjectUnit = normalizeProjectUnitKey(q);
    const list = rows.filter((c) => {
      const stageOk = clientStageFilter === 'all' || c.stageId === clientStageFilter;

      const hasUnits = c.linkedUnits.length > 0;
      const unitStatusOk =
        unitStatusFilter === 'all'
          ? true
          : unitStatusFilter === 'no_unit'
            ? !hasUnits
            : c.linkedUnits.some((u) => u.status === unitStatusFilter);

      const projectOk =
        projectFilter === 'all'
          ? true
          : c.linkedUnits.some((u) => u.project_id === projectFilter);

      const hasOriginal = c.linkedUnits.some((u) => u.relationLabel === 'عميل أصلي');
      const hasCurrent = c.linkedUnits.some((u) => u.relationLabel === 'عميل مفرّغ له');
      const typeOk =
        clientTypeFilter === 'all'
          ? true
          : clientTypeFilter === 'none'
            ? !hasUnits
            : clientTypeFilter === 'original'
              ? hasOriginal
              : hasCurrent;

      const workOk =
        workFilter === 'all'
          ? true
          : workFilter === 'with_tasks'
            ? c.openTasksCount > 0
            : workFilter === 'assigned_to_me'
              ? c.myTasksCount > 0
              : Boolean(c.lastActivityAt);

      if (!stageOk || !unitStatusOk || !projectOk || !typeOk || !workOk) return false;
      if (!q) return true;

      const email = String((c as any)?.email || '').trim();
      const linkedText = c.linkedUnits
        .map((u) => {
          const key = `${u.project_number}-${u.unit_number}`;
          const keyNorm = normalizeProjectUnitKey(key);
          return `${key} ${keyNorm} ${u.project_name} ${statusLabel(u.status)} ${u.relationLabel}`;
        })
        .join(' ');

      const matchesProjectUnit = qProjectUnit.length >= 3 && linkedText.includes(qProjectUnit);

      return (
        c.name.includes(q) ||
        (c.id_number && c.id_number.includes(q)) ||
        (c.phone && c.phone.includes(q)) ||
        (email && email.includes(q)) ||
        c.stageName.includes(q) ||
        linkedText.includes(q) ||
        matchesProjectUnit
      );
    });

    list.sort((a, b) => {
      const aDue = a.nextDueAt ? new Date(a.nextDueAt).getTime() : Number.POSITIVE_INFINITY;
      const bDue = b.nextDueAt ? new Date(b.nextDueAt).getTime() : Number.POSITIVE_INFINITY;
      if (aDue !== bDue) return aDue - bDue;
      const aAct = a.lastActivityAt ? new Date(a.lastActivityAt).getTime() : 0;
      const bAct = b.lastActivityAt ? new Date(b.lastActivityAt).getTime() : 0;
      return bAct - aAct;
    });

    return list;
  }, [clientStageFilter, clientTypeFilter, projectFilter, rows, searchQuery, unitStatusFilter, workFilter]);

  const normalizePhoneForWhatsApp = (raw: string) => {
    const trimmed = raw.trim();
    const digits = trimmed.replace(/[^\d+]/g, '').replace(/^\+/, '');
    if (digits.startsWith('00')) return digits.substring(2);
    return digits;
  };

  const contactUnitContext = useMemo(() => {
    if (!contactClient) return null;
    const list = contactClient.linkedUnits || [];
    if (!list.length) return null;
    const preferred = contactUnitIds[0] || contactUnitId;
    if (preferred) {
      const found = list.find((u) => u.unit_id === preferred);
      if (found) return found;
    }
    return list[0] || null;
  }, [contactClient, contactUnitId, contactUnitIds]);

  const buildWaTemplateMessage = () => {
    if (!contactClient || !waMessageType) return '';
    const name = contactClient.name || 'عميلنا الكريم';
    const unitNum = contactUnitContext?.unit_number ?? '';
    const projectNumber = contactUnitContext?.project_number ?? '';
    const projectName = contactUnitContext?.project_name ?? '';
    const unitCode = unitNum && projectNumber ? `${unitNum}-${projectNumber}` : unitNum ? String(unitNum) : projectNumber ? String(projectNumber) : '';
    const timestamp = new Date().toLocaleString('ar-SA', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
    const stampLine = `\n\n_التاريخ والوقت: ${timestamp}_`;

    if (waMessageType === 'deed_transfer') {
      const unitLine = unitCode ? `مالك الشقة رقم (${unitCode})` : 'مالك الشقة';
      return `السلام عليكم ورحمة الله وبركاته،\n\nعزيزنا العميل/ة: ${name}\n${unitLine}\n\nتبارك لكم شركة مساكن الرفاهية للتطوير العقاري صدور صك شقتكم، ونتمنى منكم التكرم بالحضور إلى مقر الشركة لعملية إفراغ الصك خلال مدة أقصاها شهر.\n\n📍 موقع الشركة (خرائط Google):\nhttps://maps.app.goo.gl/p15cgtYnbGFR4uBZ6${stampLine}`;
    }

    if (waMessageType === 'resale_contract') {
      const unitLine = unitCode ? `وحدتكم رقم (${unitCode})` : 'وحدتكم';
      const projectLine = projectName ? ` في مشروع (${projectName})` : '';
      return `السلام عليكم ورحمة الله وبركاته،\n\nعميلنا الكريم: ${name}\n\nنفيدكم بأنه تم تجهيز عقد إعادة البيع الخاص بـ ${unitLine}${projectLine}.\n\nنأمل منكم التكرم بزيارة مقر شركة مساكن الرفاهية للتطوير العقاري لتوقيع العقد واستكمال الإجراءات اللازمة.\n\n📍 موقع الشركة (خرائط Google):\nhttps://maps.app.goo.gl/p15cgtYnbGFR4uBZ6\n\nشاكرين لكم تعاونكم، ونسعد بخدمتكم دائمًا.\n\nشركة مساكن الرفاهية للتطوير العقاري.${stampLine}`;
    }

    if (waMessageType === 'payment_reminder') {
      const unitLine = unitCode ? `على وحدتكم رقم (${unitCode})` : 'على وحدتكم';
      const projectLine = projectName ? ` ضمن مشروع (${projectName})` : '';
      return `السلام عليكم ورحمة الله وبركاته،\n\nعميلنا الكريم: ${name}\n\nنود إشعاركم بوجود دفعة مستحقة ${unitLine}${projectLine}.\n\nنأمل منكم سرعة السداد لاستكمال الإجراءات وتفادي أي تأخير.\n\nشاكرين لكم حسن تعاونكم وثقتكم.\n\nشركة مساكن الرفاهية للتطوير العقاري.${stampLine}`;
    }

    const unitLine = unitCode ? `شقتك رقم (${unitCode})` : 'شقتك';
    return `السلام عليكم ورحمة الله وبركاته،\n\nعزيزنا العميل/ة: ${name}\n\nيرجى نقل عداد ${unitLine}\n\nخطوات النقل:\n1. خش تطبيق الطاقة السعوديه سوي حساب او سجل دخول\n2. دور على شي اسمه اضافه حساب او توثيق ملكيه\n3. حط رقم الحساب سوي بحث\n4. اختر مالك مستفيد\n5. تضهر نافذه يطلب رقم الصك سوي تاكيد مو مهم تحط الصك\n6. سوي اوافق ثم ارسال الطلب\n7. بيعطيك تم ارسال الطلب\n\nملاحظة: صور الشاشه وحتفظ برقم الطلب خلال يوم يكون جاهز.${stampLine}`;
  };

  const openWhatsAppWithText = (text: string) => {
    const phone = String(contactClient?.phone || '').trim();
    if (!phone) {
      const url = `https://wa.me/?text=${encodeURIComponent(text)}`;
      window.open(url, '_blank', 'noopener,noreferrer');
      return;
    }
    const formattedPhone = normalizePhoneForWhatsApp(phone);
    const url = `https://wa.me/${formattedPhone}?text=${encodeURIComponent(text)}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  };

  const openClient = (id: string) => {
    router.push(`/crm/clients/${id}`);
  };

  const openContact = (p: { client: ClientRow; channel: 'call' | 'whatsapp' | 'email'; unitId?: string | null }) => {
    setContactError(null);
    setContactClient(p.client);
    const defaultUnitIds = (() => {
      const first = p.client.linkedUnits?.[0]?.unit_id || null;
      const initial = p.unitId || first;
      return initial ? [initial] : [];
    })();
    setContactUnitIds(defaultUnitIds);
    setContactUnitId(defaultUnitIds[0] || null);
    setContactChannel(p.channel);
    setContactNote('');
    setContactOutcome('completed');
    setAppointmentAt('');
    setAppointmentWith('');
    setContactNextAt(toLocalInput(new Date(Date.now() + 24 * 60 * 60 * 1000)));
    setWaMode('template');
    setWaMessageType(null);
    setWaCopied(false);
    setWaCustomText('');
    setContactOpen(true);
  };

  const renderContactButtons = (c: ClientRow, unitId?: string | null) => {
    const email = String((c as any)?.email || '').trim();
    return (
      <div className="flex flex-wrap items-center gap-2">
        {c.phone && (
          <>
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                openContact({ client: c, channel: 'call', unitId });
              }}
              className="inline-flex items-center gap-2 px-2.5 py-1.5 md:px-3 md:py-2 rounded-lg bg-gray-900 text-white text-xs md:text-sm font-bold hover:bg-black transition-colors"
            >
              <Phone size={14} />
              اتصال
            </button>
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                openContact({ client: c, channel: 'whatsapp', unitId });
              }}
              className="inline-flex items-center gap-2 px-2.5 py-1.5 md:px-3 md:py-2 rounded-lg bg-emerald-600 text-white text-xs md:text-sm font-bold hover:bg-emerald-700 transition-colors"
            >
              <MessageCircle size={14} />
              واتساب
            </button>
          </>
        )}
        {email && (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              openContact({ client: c, channel: 'email', unitId });
            }}
            className="inline-flex items-center gap-2 px-2.5 py-1.5 md:px-3 md:py-2 rounded-lg bg-blue-600 text-white text-xs md:text-sm font-bold hover:bg-blue-700 transition-colors"
          >
            <Mail size={14} />
            إيميل
          </button>
        )}
      </div>
    );
  };

  const saveContact = async () => {
    setContactError(null);
    if (!userId) {
      setContactError('الرجاء تسجيل الدخول.');
      return;
    }
    if (!contactClient) {
      setContactError('لم يتم تحديد العميل.');
      return;
    }
    const clientUnits = (contactClient.linkedUnits || []).map((u) => u.unit_id).filter(Boolean);
    if (clientUnits.length > 0 && contactUnitIds.length === 0) {
      setContactError('الرجاء تحديد الشقق المرتبطة بهذا التواصل.');
      return;
    }
    if (!contactNote.trim()) {
      setContactError('الرجاء كتابة ملاحظة التواصل.');
      return;
    }
    if (!contactNextAt) {
      setContactError('الرجاء تحديد تاريخ التواصل القادم.');
      return;
    }
    if (contactOutcome === 'appointment') {
      if (!appointmentAt) {
        setContactError('الرجاء تحديد تاريخ الموعد.');
        return;
      }
      if (!appointmentWith) {
        setContactError('الرجاء تحديد مع من تم حجز الموعد.');
        return;
      }
    }

    setContactSaving(true);
    try {
      let postSaveNotice: string | null = null;
      const primaryUnitId = contactUnitIds[0] || contactUnitId || null;
      const payload: any = {
        client_id: contactClient.id,
        unit_id: primaryUnitId,
        channel: contactChannel,
        content: contactNote.trim(),
        created_by: userId,
        next_contact_at: contactNextAt ? new Date(contactNextAt).toISOString() : null,
        outcome: contactOutcome
      };

      if (contactOutcome === 'appointment') {
        payload.appointment_at = new Date(appointmentAt).toISOString();
        payload.appointment_with = appointmentWith;
      }

      const { data: insertedActivity, error: actErr } = await supabase
        .from('crm_activities')
        .insert([payload])
        .select('id')
        .single();
      if (actErr) throw actErr;

      const activityId = insertedActivity?.id;
      if (activityId && contactUnitIds.length > 0) {
        const rows = Array.from(new Set(contactUnitIds)).map((unit_id) => ({
          activity_id: activityId,
          unit_id
        }));
        const { error: linkErr } = await supabase.from('crm_activity_units').insert(rows as any);
        if (linkErr) {
          const msg = String(linkErr.message || '');
          if (msg.toLowerCase().includes('crm_activity_units') || msg.toLowerCase().includes('relation')) {
            throw new Error(
              'تم حفظ التواصل لكن تعذر حفظ الشقق المرتبطة. الرجاء إضافة جدول crm_activity_units في قاعدة البيانات.'
            );
          }
          throw linkErr;
        }
      }

      if (contactOutcome === 'no_answer') {
        const dueAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
        const taskPayload: any = {
          client_id: contactClient.id,
          unit_id: primaryUnitId,
          title: `متابعة (عدم رد): ${contactClient.name}`,
          due_at: dueAt,
          status: 'open',
          priority: 'medium',
          assigned_to: userId
        };
        const { error: taskErr } = await supabase.from('crm_tasks').insert([taskPayload]);
        if (taskErr) throw taskErr;
      }

      if (contactOutcome === 'appointment') {
        const hostName = String(appointmentWith || '').trim();
        const atIso = new Date(appointmentAt).toISOString();
        const missingTableMsg = (m: string) => m.includes('does not exist') || m.includes('relation') || m.includes('not exist');

        let hostId: string | null = null;
        try {
          const ins = await supabase.from('crm_appointment_hosts').insert([{ name: hostName }]).select('id').single();
          if (ins.error) {
            const msg = String(ins.error.message || '').toLowerCase();
            if (msg.includes('duplicate') || msg.includes('unique')) {
              const sel = await supabase.from('crm_appointment_hosts').select('id').eq('name', hostName).maybeSingle();
              if (!sel.error) hostId = (sel.data as any)?.id || null;
            } else if (missingTableMsg(msg)) {
              postSaveNotice =
                'تم حفظ الموعد كسجل تواصل، لكن جدول قائمة أصحاب المواعيد غير موجود (crm_appointment_hosts).';
            } else {
              postSaveNotice = ins.error.message || 'تعذر حفظ صاحب الموعد.';
            }
          } else {
            hostId = (ins.data as any)?.id || null;
          }
        } catch (e: any) {
          postSaveNotice = e?.message || 'تعذر حفظ صاحب الموعد.';
        }

        try {
          const apptPayload: any = {
            client_id: contactClient.id,
            unit_id: primaryUnitId,
            activity_id: activityId || null,
            appointment_at: atIso,
            host_id: hostId,
            host_name: hostName,
            created_by: userId
          };
          const apptRes = await supabase.from('crm_appointments').insert([apptPayload]);
          if (apptRes.error) {
            const msg = String(apptRes.error.message || '').toLowerCase();
            if (missingTableMsg(msg)) {
              postSaveNotice = 'تم حفظ الموعد كسجل تواصل، لكن جدول المواعيد غير موجود (crm_appointments).';
            } else {
              postSaveNotice = apptRes.error.message || 'تعذر تسجيل الموعد في جدول المواعيد.';
            }
          }
        } catch (e: any) {
          postSaveNotice = e?.message || 'تعذر تسجيل الموعد في جدول المواعيد.';
        }

        await loadAppointmentWithOptions(true);
      }

      setContactOpen(false);
      setContactClient(null);
      setContactUnitId(null);
      setContactUnitIds([]);
      await fetchData();
      if (postSaveNotice) alert(postSaveNotice);
    } catch (e: any) {
      setContactError(e?.message || 'تعذر حفظ سجل التواصل');
    } finally {
      setContactSaving(false);
    }
  };

  const addClient = async () => {
    const name = newClient.name.trim();
    if (!name) return;
    setAdding(true);
    try {
      const payload: any = {
        name,
        id_number: newClient.id_number.trim() || null,
        phone: newClient.phone.trim() || null,
        notes: newClient.notes.trim() || null
      };
      const { error } = await supabase.from('clients').insert([payload]);
      if (error) throw error;
      setIsAddOpen(false);
      setNewClient({ name: '', id_number: '', phone: '', notes: '' });
      fetchData();
    } catch (e: any) {
      alert(e?.message || 'تعذر إضافة العميل');
    } finally {
      setAdding(false);
    }
  };

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto" dir="rtl">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-emerald-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-emerald-600/20">
            <Users size={24} />
          </div>
          <div>
            <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">CRM العملاء</h1>
            <p className="text-gray-500 text-sm">متابعة العملاء، المهام، وسجل التواصل</p>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setIsAddOpen(true)}
            className="flex items-center justify-center gap-2 px-6 py-2.5 bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 transition-all shadow-md hover:shadow-lg font-bold"
          >
            <Plus size={20} />
            إضافة عميل
          </button>
        </div>
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
              placeholder="ابحث باسم العميل، رقم الهوية، الجوال، الإيميل، المرحلة، أو (رقم المشروع-رقم الوحدة مثل 101-5)..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pr-10 pl-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            />
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={() => setFiltersOpen((v) => !v)}
              className={`md:hidden inline-flex items-center gap-2 px-4 py-3 rounded-xl text-sm font-bold border transition-colors ${
                filtersOpen
                  ? 'bg-emerald-600 text-white border-emerald-600'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <SlidersHorizontal size={16} />
              {filtersOpen ? 'إخفاء الفلاتر' : 'إظهار الفلاتر'}
            </button>
            <div className="hidden md:flex items-center gap-2">
              <button
                onClick={() => setViewMode('grid')}
                className={`px-4 py-2 rounded-lg text-sm font-bold border transition-colors ${
                  viewMode === 'grid'
                    ? 'bg-emerald-600 text-white border-emerald-600'
                    : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
                }`}
              >
                شبكة
              </button>
              <button
                onClick={() => setViewMode('list')}
                className={`px-4 py-2 rounded-lg text-sm font-bold border transition-colors ${
                  viewMode === 'list'
                    ? 'bg-emerald-600 text-white border-emerald-600'
                    : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
                }`}
              >
                قائمة
              </button>
            </div>
          </div>
        </div>

        <div className={`${filtersOpen ? 'grid' : 'hidden'} md:grid grid-cols-1 md:grid-cols-4 gap-3`}>
          <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
            <div className="text-xs text-gray-500 font-bold mb-2">حالة الوحدات</div>
            <select
              value={unitStatusFilter}
              onChange={(e) => setUnitStatusFilter(e.target.value as any)}
              className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">الكل</option>
              <option value="no_unit">بدون وحدة</option>
              {(
                [
                  'available',
                  'sold',
                  'deed_completed',
                  'pending_sale',
                  'resale',
                  'for_resale',
                  'under_construction',
                  'rented',
                  'sold_to_other',
                  'resold',
                  'transferred_to_other'
                ] as Unit['status'][]
              ).map((s) => (
                <option key={s} value={s}>
                  {statusLabel(s)}
                </option>
              ))}
            </select>
          </div>

          <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
            <div className="text-xs text-gray-500 font-bold mb-2">حالة العميل</div>
            <select
              value={clientStageFilter}
              onChange={(e) => setClientStageFilter(e.target.value as any)}
              className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">الكل</option>
              <option value="">غير محدد</option>
              {stages.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>

          <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
            <div className="text-xs text-gray-500 font-bold mb-2">نوع العميل</div>
            <select
              value={clientTypeFilter}
              onChange={(e) => setClientTypeFilter(e.target.value as any)}
              className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">الكل</option>
              <option value="original">عميل أصلي</option>
              <option value="current">عميل مفرّغ له</option>
              <option value="none">بدون وحدة</option>
            </select>
          </div>

          <div className="bg-gray-50 border border-gray-200 rounded-xl p-3">
            <div className="text-xs text-gray-500 font-bold mb-2">المشروع</div>
            <select
              value={projectFilter}
              onChange={(e) => setProjectFilter(e.target.value as any)}
              className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">الكل</option>
              {projectsList.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.project_number} - {p.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className={`${filtersOpen ? 'grid' : 'hidden'} md:grid grid-cols-1 md:grid-cols-4 gap-3`}>
          <div className="bg-gray-50 border border-gray-200 rounded-xl p-3 md:col-span-2">
            <div className="text-xs text-gray-500 font-bold mb-2">عرض العملاء</div>
            <select
              value={workFilter}
              onChange={(e) => setWorkFilter(e.target.value as any)}
              className="w-full py-2.5 px-3 bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">الكل</option>
              <option value="with_tasks">العملاء الذين لديهم مهام</option>
              <option value="assigned_to_me">مهام مسندة لي</option>
              <option value="with_activity">العملاء الذين لديهم سجل تواصل</option>
            </select>
          </div>
        </div>

        {errorText && (
          <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-700 text-sm flex items-center gap-2">
            <AlertCircle size={18} />
            {errorText}
          </div>
        )}

        {loading ? (
          <div className="py-10 text-center text-gray-500">جاري التحميل...</div>
        ) : filteredRows.length === 0 ? (
          <div className="py-10 text-center text-gray-500">لا يوجد عملاء</div>
        ) : (
          <div className={viewMode === 'grid' ? 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4' : 'space-y-3'}>
            {filteredRows.map((c) => {
              if (viewMode === 'list') {
                const visibleUnits = visibleUnitsForClient(c);
                const primaryUnit = visibleUnits[0] || null;
                const isCurrentOwner = visibleUnits.some((u) => u.relationLabel === 'عميل مفرّغ له');
                const theme = clientTheme(c, visibleUnits);
                const lastBy = c.lastActivityBy ? employeeLabelById.get(c.lastActivityBy) || String(c.lastActivityBy).slice(0, 8) : null;
                return (
                  <div
                    key={c.id}
                    className={`${theme.border} p-[1px] rounded-lg shadow-[0_12px_28px_rgba(15,23,42,0.10)] hover:shadow-[0_18px_40px_rgba(15,23,42,0.14)] transition-all`}
                  >
                    <div
                      onClick={() => openClient(c.id)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') openClient(c.id);
                      }}
                      role="link"
                      tabIndex={0}
                      className="bg-white rounded-lg border border-white/60 outline-none focus:ring-2 focus:ring-emerald-500 relative"
                    >
                      <div className={`absolute inset-y-0 right-0 w-1 ${theme.stripe}`} />
                      <div className="p-3 md:p-4 flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
                      <div className="min-w-0">
                        <div className="flex items-center gap-3">
                          <div className={`w-9 h-9 md:w-10 md:h-10 rounded-lg ${theme.avatar} text-white flex items-center justify-center font-bold shadow-sm`}>
                            {c.name?.trim()?.charAt(0) || 'ع'}
                          </div>
                          <div className="min-w-0">
                            <div className="flex items-center gap-2 min-w-0">
                              <div className="font-bold text-gray-900 truncate text-base md:text-lg">{c.name}</div>
                              {isCurrentOwner && (
                                <span className="shrink-0 px-2 py-0.5 md:px-2.5 md:py-1 rounded-md text-[10px] md:text-[11px] font-bold bg-teal-50 text-teal-800 border border-teal-200">
                                  مفرّغ له
                                </span>
                              )}
                              <span className="shrink-0 px-2 py-0.5 md:px-2.5 md:py-1 rounded-md text-[10px] md:text-[11px] font-bold bg-gray-50 text-gray-700 border border-gray-200">
                                {c.stageName}
                              </span>
                              {c.openTasksCount > 0 ? (
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    openClient(c.id);
                                  }}
                                  className={`shrink-0 px-2 py-0.5 md:px-2.5 md:py-1 rounded-md text-[10px] md:text-[11px] font-bold border hover:bg-blue-100 ${
                                    c.myTasksCount > 0 ? 'bg-amber-50 text-amber-900 border-amber-200 hover:bg-amber-100' : 'bg-blue-50 text-blue-800 border-blue-200'
                                  }`}
                                >
                                  {c.myTasksCount > 0 ? `مسندة لك: ${c.myTasksCount}` : `مهام: ${c.openTasksCount}`}
                                </button>
                              ) : null}
                            </div>
                            {primaryUnit ? (
                              <div className="text-xs md:text-sm text-gray-600 truncate mt-1">
                                الشقة: {primaryUnit.project_number}-{primaryUnit.unit_number}
                                <span className="text-gray-300 mx-2">•</span>
                                {primaryUnit.project_name}
                              </div>
                            ) : (
                              <div className="text-xs md:text-sm text-gray-500 mt-1">الشقة: -</div>
                            )}
                            <div className="text-[11px] md:text-xs text-gray-500 mt-1">
                              آخر تواصل:{' '}
                              {c.lastActivityAt ? new Date(c.lastActivityAt).toLocaleString('ar-SA') : '-'}
                              {lastBy ? (
                                <>
                                  <span className="text-gray-300 mx-2">•</span>
                                  بواسطة: {lastBy}
                                </>
                              ) : null}
                            </div>
                          </div>
                        </div>
                      </div>

                      <div className="flex flex-col md:flex-row md:items-center gap-3 md:gap-4">
                        <div className="flex items-center gap-2">
                          <span className="text-xs md:text-sm text-gray-500">حالة الشقة:</span>
                          {primaryUnit ? (
                            <span className={`px-2.5 py-0.5 md:px-3 md:py-1 rounded-md text-xs md:text-sm font-bold ${statusBadge(primaryUnit.status)}`}>
                              {statusLabel(primaryUnit.status)}
                            </span>
                          ) : (
                            <span className="px-2.5 py-0.5 md:px-3 md:py-1 rounded-md text-xs md:text-sm font-bold bg-gray-100 text-gray-700">-</span>
                          )}
                        </div>

                        {renderContactButtons(c, primaryUnit?.unit_id || null)}

                        <div className="flex items-center justify-end">
                          <span className="text-gray-400">
                            <ArrowUpLeft size={16} />
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                  </div>
                );
              }

              const visibleUnits = visibleUnitsForClient(c);
              const isCurrentOwner = visibleUnits.some((u) => u.relationLabel === 'عميل مفرّغ له');
              const theme = clientTheme(c, visibleUnits);
              const lastBy = c.lastActivityBy ? employeeLabelById.get(c.lastActivityBy) || String(c.lastActivityBy).slice(0, 8) : null;
              return (
                <div
                  key={c.id}
                  className={`${theme.border} p-[1px] rounded-lg shadow-[0_12px_28px_rgba(15,23,42,0.10)] hover:shadow-[0_18px_40px_rgba(15,23,42,0.14)] transition-all`}
                >
                  <div
                    onClick={() => openClient(c.id)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') openClient(c.id);
                    }}
                    role="link"
                    tabIndex={0}
                    className="bg-white rounded-lg overflow-hidden outline-none focus:ring-2 focus:ring-emerald-500"
                  >
                    <div className={`relative p-5 ${theme.header}`}>
                      <div className="absolute inset-0 opacity-70 bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.18),transparent_60%)]" />
                      <div className="relative flex items-start justify-between gap-3">
                        <div className="flex items-center gap-3 min-w-0">
                          <div className="w-12 h-12 rounded-lg bg-white/10 border border-white/15 flex items-center justify-center text-white font-bold text-lg">
                            {c.name?.trim()?.charAt(0) || 'ع'}
                          </div>
                          <div className="min-w-0">
                            <div className="flex items-center gap-2 min-w-0">
                              <div className="font-bold text-white truncate text-lg">{c.name}</div>
                              {isCurrentOwner && (
                                <span className="shrink-0 px-2.5 py-1 rounded-md text-[11px] font-bold bg-teal-400/20 text-teal-50 border border-teal-300/30">
                                  مفرّغ له
                                </span>
                              )}
                            </div>
                            <div className="text-xs text-white/70 truncate">
                              {c.id_number ? `هوية: ${c.id_number}` : 'بدون رقم هوية'}
                            </div>
                          </div>
                        </div>
                        <span className="px-3 py-1 rounded-md text-xs font-bold bg-white/10 text-white border border-white/15">
                          {c.stageName}
                        </span>
                      </div>
                      <div className="relative mt-3 flex items-center justify-between gap-3">
                        <div className="text-xs md:text-sm text-white/80 truncate" dir="ltr">
                          {c.phone || '-'}
                        </div>
                        <div className="text-xs text-white/70">
                          المتابعة القادمة: {c.nextDueAt ? new Date(c.nextDueAt).toLocaleString('ar-SA') : '-'}
                        </div>
                      </div>
                    </div>

                    <div className="p-5 space-y-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2 text-gray-800 font-bold text-xs md:text-sm">
                          <ClipboardList size={14} className="text-gray-400" />
                          <span>مهام مفتوحة</span>
                        </div>
                        <span className="text-xl font-extrabold text-gray-900">{c.openTasksCount}</span>
                      </div>

                      {c.myTasksCount > 0 ? <div className="text-xs font-bold text-amber-800">مسندة لك: {c.myTasksCount}</div> : null}

                      <div className="text-xs text-gray-600">
                        آخر تواصل: {c.lastActivityAt ? new Date(c.lastActivityAt).toLocaleString('ar-SA') : '-'}
                        {lastBy ? ` • بواسطة: ${lastBy}` : ''}
                      </div>

                      <div className="flex items-center justify-between gap-2">
                        {renderContactButtons(c, visibleUnits[0]?.unit_id || null)}
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            openClient(c.id);
                          }}
                          className="inline-flex items-center gap-2 px-2.5 py-1.5 md:px-3 md:py-2 rounded-lg bg-gray-900 text-white text-xs md:text-sm font-bold hover:bg-black transition-colors"
                        >
                          <ArrowUpLeft size={14} />
                          فتح
                        </button>
                      </div>

                      {visibleUnits.length > 0 && (
                        <div className="pt-4 border-t border-gray-100 space-y-2">
                          <div className="text-xs font-bold text-gray-700">الوحدات المرتبطة</div>
                          <div className="space-y-2">
                            {visibleUnits.slice(0, 2).map((u) => (
                              <div key={`${c.id}_${u.unit_id}_${u.relationLabel}`} className="flex items-center justify-between gap-2 bg-gray-50 border border-gray-100 rounded-lg px-3 py-2">
                                <div className="min-w-0">
                                  <div className="text-xs md:text-sm font-bold text-gray-900 truncate">
                                    {u.project_number}-{u.unit_number} <span className="text-gray-300 mx-1">•</span> {u.project_name}
                                  </div>
                                  <div className="text-xs text-gray-500">{u.relationLabel}</div>
                                </div>
                                <span className={`shrink-0 px-2 py-1 rounded-md text-[10px] md:text-[11px] font-bold ${statusBadge(u.status)}`}>
                                  {statusLabel(u.status)}
                                </span>
                              </div>
                            ))}
                            {visibleUnits.length > 2 && <div className="text-xs text-gray-500">+{visibleUnits.length - 2} وحدات أخرى</div>}
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {contactOpen && contactClient && (
        <div className="fixed inset-0 z-50">
          <div className="absolute inset-0 bg-black/60" />
          <div className="absolute inset-0 flex items-center justify-center p-4">
            <div className="w-full max-w-2xl max-h-[90vh] bg-white rounded-2xl shadow-2xl border border-gray-200 overflow-hidden flex flex-col">
              <div className="p-5 border-b border-gray-100">
                <div className="flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <div className="font-bold text-gray-900">تسجيل تواصل</div>
                    <div className="text-sm text-gray-600 truncate">{contactClient.name}</div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="px-3 py-1 rounded-lg text-xs font-bold bg-gray-100 text-gray-700 border border-gray-200">
                      {contactChannel === 'call' ? 'اتصال' : contactChannel === 'whatsapp' ? 'واتساب' : 'بريد'}
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        setContactOpen(false);
                        setContactClient(null);
                        setContactUnitId(null);
                        setContactUnitIds([]);
                      }}
                      className="w-9 h-9 rounded-xl border border-gray-200 bg-white hover:bg-gray-50 text-gray-700 font-extrabold"
                      aria-label="إغلاق"
                    >
                      ×
                    </button>
                  </div>
                </div>
              </div>

              <div className="p-5 space-y-4 overflow-y-auto flex-1">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="rounded-xl border border-gray-200 bg-gray-50 p-4">
                    <div className="text-xs font-bold text-gray-500">بيانات التواصل</div>
                    <div className="mt-2 flex items-center justify-between gap-3">
                      <div className="text-sm font-bold text-gray-900" dir="ltr">
                        {contactChannel === 'email'
                          ? String((contactClient as any)?.email || '-')
                          : contactClient.phone || '-'}
                      </div>
                      {contactChannel === 'call' && contactClient.phone ? (
                        <a
                          href={`tel:${contactClient.phone}`}
                          className="px-3 py-2 rounded-xl bg-gray-900 text-white text-xs font-bold"
                        >
                          فتح الاتصال
                        </a>
                      ) : null}
                      {contactChannel === 'whatsapp' && contactClient.phone ? (
                        <a
                          href={`https://wa.me/${normalizePhoneForWhatsApp(contactClient.phone)}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="px-3 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold"
                        >
                          فتح واتساب
                        </a>
                      ) : null}
                      {contactChannel === 'email' && String((contactClient as any)?.email || '').trim() ? (
                        <a
                          href={`mailto:${String((contactClient as any)?.email || '').trim()}`}
                          className="px-3 py-2 rounded-xl bg-blue-600 text-white text-xs font-bold"
                        >
                          فتح البريد
                        </a>
                      ) : null}
                    </div>
                    <div className="text-xs text-gray-500 mt-2">سيتم حفظ المستخدم الذي سجل التواصل تلقائيًا.</div>

                    {contactChannel === 'whatsapp' ? (
                      <div className="mt-4 pt-4 border-t border-gray-200 space-y-3">
                        <div className="flex items-center justify-between gap-3">
                          <div className="text-xs font-bold text-gray-700">رسائل جاهزة (واتساب)</div>
                          <div className="inline-flex bg-white border border-gray-200 rounded-xl overflow-hidden">
                            <button
                              type="button"
                              onClick={() => setWaMode('template')}
                              className={`px-3 py-1.5 text-xs font-bold ${waMode === 'template' ? 'bg-emerald-600 text-white' : 'text-gray-600'}`}
                            >
                              رسائل جاهزة
                            </button>
                            <button
                              type="button"
                              onClick={() => setWaMode('custom')}
                              className={`px-3 py-1.5 text-xs font-bold ${waMode === 'custom' ? 'bg-emerald-600 text-white' : 'text-gray-600'}`}
                            >
                              رسالة مخصصة
                            </button>
                          </div>
                        </div>

                        {waMode === 'template' ? (
                          <div className="space-y-3">
                            <div className="grid gap-2">
                              <button
                                type="button"
                                onClick={() => setWaMessageType('deed_transfer')}
                                className={`p-3 rounded-xl border text-right font-bold text-sm transition-all ${
                                  waMessageType === 'deed_transfer' ? 'border-emerald-600 bg-emerald-50 text-emerald-900' : 'border-gray-200 bg-white text-gray-800 hover:bg-gray-50'
                                }`}
                              >
                                طلب حضور للإفراغ
                              </button>
                              <button
                                type="button"
                                onClick={() => setWaMessageType('meter_transfer')}
                                className={`p-3 rounded-xl border text-right font-bold text-sm transition-all ${
                                  waMessageType === 'meter_transfer' ? 'border-emerald-600 bg-emerald-50 text-emerald-900' : 'border-gray-200 bg-white text-gray-800 hover:bg-gray-50'
                                }`}
                              >
                                نقل عدادات
                              </button>
                              <button
                                type="button"
                                onClick={() => setWaMessageType('payment_reminder')}
                                className={`p-3 rounded-xl border text-right font-bold text-sm transition-all ${
                                  waMessageType === 'payment_reminder' ? 'border-emerald-600 bg-emerald-50 text-emerald-900' : 'border-gray-200 bg-white text-gray-800 hover:bg-gray-50'
                                }`}
                              >
                                تذكير بالسداد
                              </button>
                              <button
                                type="button"
                                onClick={() => setWaMessageType('resale_contract')}
                                className={`p-3 rounded-xl border text-right font-bold text-sm transition-all ${
                                  waMessageType === 'resale_contract' ? 'border-emerald-600 bg-emerald-50 text-emerald-900' : 'border-gray-200 bg-white text-gray-800 hover:bg-gray-50'
                                }`}
                              >
                                توقيع عقد إعادة بيع
                              </button>
                            </div>

                            {waMessageType ? (
                              <div className="space-y-2">
                                <div className="bg-white p-3 rounded-xl border border-gray-200 text-xs leading-relaxed whitespace-pre-line text-gray-700">
                                  {buildWaTemplateMessage()}
                                </div>
                                <div className="flex items-center gap-2">
                                  <button
                                    type="button"
                                    onClick={() => openWhatsAppWithText(buildWaTemplateMessage())}
                                    disabled={!contactClient.phone || !buildWaTemplateMessage()}
                                    className="flex-1 px-3 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold disabled:opacity-60"
                                  >
                                    إرسال واتساب
                                  </button>
                                  <button
                                    type="button"
                                    onClick={async () => {
                                      const txt = buildWaTemplateMessage();
                                      await navigator.clipboard.writeText(txt);
                                      setWaCopied(true);
                                      setTimeout(() => setWaCopied(false), 1500);
                                    }}
                                    disabled={!buildWaTemplateMessage()}
                                    className="px-3 py-2 rounded-xl bg-white border border-gray-200 text-gray-700 text-xs font-bold disabled:opacity-60"
                                  >
                                    {waCopied ? 'تم النسخ' : 'نسخ'}
                                  </button>
                                </div>
                              </div>
                            ) : (
                              <div className="text-xs text-gray-500">اختر نوع الرسالة لعرض المعاينة.</div>
                            )}
                          </div>
                        ) : (
                          <div className="space-y-2">
                            <textarea
                              value={waCustomText}
                              onChange={(e) => setWaCustomText(e.target.value)}
                              className="w-full p-3 bg-white border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none min-h-[90px]"
                              placeholder="اكتب نص الرسالة..."
                            />
                            <div className="flex items-center gap-2">
                              <button
                                type="button"
                                onClick={() => openWhatsAppWithText(waCustomText.trim())}
                                disabled={!waCustomText.trim()}
                                className="flex-1 px-3 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold disabled:opacity-60"
                              >
                                إرسال واتساب
                              </button>
                              <button
                                type="button"
                                onClick={async () => {
                                  const txt = waCustomText.trim();
                                  await navigator.clipboard.writeText(txt);
                                  setWaCopied(true);
                                  setTimeout(() => setWaCopied(false), 1500);
                                }}
                                disabled={!waCustomText.trim()}
                                className="px-3 py-2 rounded-xl bg-white border border-gray-200 text-gray-700 text-xs font-bold disabled:opacity-60"
                              >
                                {waCopied ? 'تم النسخ' : 'نسخ'}
                              </button>
                            </div>
                          </div>
                        )}
                      </div>
                    ) : null}
                  </div>

                  <div className="rounded-xl border border-gray-200 bg-white p-4 space-y-3">
                    <div className="space-y-2">
                      <div className="flex items-center justify-between gap-2">
                        <div className="text-sm font-bold text-gray-700">الشقق المرتبطة بالتواصل *</div>
                        {(contactClient.linkedUnits || []).length > 0 && contactUnitIds.length > 0 ? (
                          <button
                            type="button"
                            onClick={() => {
                              setContactUnitIds([]);
                              setContactUnitId(null);
                            }}
                            className="text-xs font-bold text-gray-600 hover:text-gray-900"
                          >
                            مسح
                          </button>
                        ) : null}
                      </div>

                      {(contactClient.linkedUnits || []).length === 0 ? (
                        <div className="text-xs text-gray-500">لا توجد وحدات مرتبطة بهذا العميل.</div>
                      ) : (
                        <div className="max-h-44 overflow-auto custom-scrollbar space-y-2">
                          {(contactClient.linkedUnits || []).map((u) => {
                            const checked = contactUnitIds.includes(u.unit_id);
                            const label = `${u.project_number}-${u.unit_number}`;
                            return (
                              <label
                                key={`${u.unit_id}_${u.relationLabel}`}
                                className={`flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
                                  checked ? 'border-emerald-600 bg-emerald-50' : 'border-gray-200 bg-white hover:bg-gray-50'
                                }`}
                              >
                                <input
                                  type="checkbox"
                                  checked={checked}
                                  onChange={(e) => {
                                    const nextChecked = e.target.checked;
                                    setContactUnitIds((prev) => {
                                      const next = nextChecked
                                        ? Array.from(new Set([...prev, u.unit_id]))
                                        : prev.filter((x) => x !== u.unit_id);
                                      setContactUnitId(next[0] || null);
                                      return next;
                                    });
                                  }}
                                  className="mt-1"
                                />
                                <div className="min-w-0">
                                  <div className="text-sm font-extrabold text-gray-900 truncate">
                                    {label} <span className="text-gray-300 mx-1">•</span> {u.project_name}
                                  </div>
                                  <div className="text-xs text-gray-500 font-bold">{u.relationLabel}</div>
                                </div>
                              </label>
                            );
                          })}
                        </div>
                      )}
                    </div>

                    <div className="pt-3 border-t border-gray-100">
                    <div className="grid grid-cols-1 gap-3">
                      <div className="space-y-2">
                        <div className="text-sm font-bold text-gray-700">نتيجة التواصل *</div>
                        <select
                          value={contactOutcome}
                          onChange={(e) => setContactOutcome(e.target.value as any)}
                          className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-emerald-500 outline-none"
                        >
                          <option value="completed">تم التواصل</option>
                          <option value="no_answer">عدم رد</option>
                          <option value="appointment">تم حجز موعد</option>
                        </select>
                      </div>

                      <div className="space-y-2">
                        <div className="text-sm font-bold text-gray-700">تاريخ التواصل القادم *</div>
                        <input
                          type="datetime-local"
                          value={contactNextAt}
                          onChange={(e) => setContactNextAt(e.target.value)}
                          className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-emerald-500 outline-none"
                        />
                      </div>

                      {contactOutcome === 'no_answer' ? (
                        <div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-xs text-amber-800">
                          سيتم إنشاء مهمة متابعة تلقائيًا بعد يوم لنفس المستخدم.
                        </div>
                      ) : null}

                      {contactOutcome === 'appointment' ? (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div className="space-y-2">
                            <div className="text-sm font-bold text-gray-700">تاريخ الموعد *</div>
                            <input
                              type="datetime-local"
                              value={appointmentAt}
                              onChange={(e) => setAppointmentAt(e.target.value)}
                              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                          </div>
                          <div className="space-y-2">
                            <div className="text-sm font-bold text-gray-700">مع من *</div>
                            <select
                              value={appointmentWith}
                              onChange={(e) => setAppointmentWith(e.target.value)}
                              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-white focus:ring-2 focus:ring-emerald-500 outline-none"
                            >
                              <option value="">اختر...</option>
                              {appointmentWithOptions.map((n) => (
                                <option key={n} value={n}>
                                  {n}
                                </option>
                              ))}
                            </select>
                          </div>
                        </div>
                      ) : null}
                    </div>
                    </div>
                  </div>
                </div>

                <div className="space-y-2">
                  <div className="text-sm font-bold text-gray-700">ملاحظة التواصل *</div>
                  <textarea
                    value={contactNote}
                    onChange={(e) => setContactNote(e.target.value)}
                    className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none min-h-[110px]"
                    placeholder="اكتب ماذا حدث بالضبط..."
                  />
                </div>

                {contactError ? (
                  <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {contactError}
                  </div>
                ) : null}
              </div>

              <div className="p-5 border-t border-gray-100 flex items-center justify-end">
                <button
                  onClick={saveContact}
                  disabled={
                    contactSaving ||
                    !contactNote.trim() ||
                    !contactNextAt ||
                    (contactOutcome === 'appointment' && (!appointmentAt || !appointmentWith))
                  }
                  className="px-6 py-2.5 rounded-xl bg-gradient-to-l from-emerald-600 to-emerald-700 text-white font-bold shadow-sm disabled:opacity-60"
                >
                  {contactSaving ? 'جاري الحفظ...' : 'حفظ سجل التواصل'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {isAddOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full">
            <div className="p-6 border-b border-gray-100 flex items-center justify-between">
              <h2 className="font-bold text-xl text-gray-900">إضافة عميل</h2>
              <button onClick={() => setIsAddOpen(false)} className="p-2 hover:bg-gray-100 rounded-xl transition-colors">
                ×
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">اسم العميل *</label>
                <input
                  type="text"
                  value={newClient.name}
                  onChange={(e) => setNewClient((p) => ({ ...p, name: e.target.value }))}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none"
                  placeholder="أدخل اسم العميل"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">رقم الهوية</label>
                <input
                  type="text"
                  value={newClient.id_number}
                  onChange={(e) => setNewClient((p) => ({ ...p, id_number: e.target.value }))}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none"
                  placeholder="اختياري"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">رقم الجوال</label>
                <input
                  type="text"
                  value={newClient.phone}
                  onChange={(e) => setNewClient((p) => ({ ...p, phone: e.target.value }))}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none"
                  placeholder="اختياري"
                  dir="ltr"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">ملاحظات</label>
                <textarea
                  value={newClient.notes}
                  onChange={(e) => setNewClient((p) => ({ ...p, notes: e.target.value }))}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none min-h-[90px]"
                  placeholder="اختياري"
                />
              </div>
              <button
                onClick={addClient}
                disabled={adding || !newClient.name.trim()}
                className="w-full bg-emerald-600 text-white py-3 rounded-xl font-bold hover:bg-emerald-700 transition-colors disabled:opacity-50"
              >
                {adding ? 'جاري الإضافة...' : 'حفظ'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
