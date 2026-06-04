'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useParams, usePathname, useRouter } from 'next/navigation';
import { ArrowRight, Building2, CheckCircle2, ClipboardList, FileText, Loader2, Phone, Plus, RefreshCw, User, AlertCircle, Users, BarChart3 } from 'lucide-react';
import { supabase } from '../../../../lib/supabaseClient';
import type { Client, CrmActivity, CrmActivityChannel, CrmClientStage, CrmPipelineStage, CrmTask, CrmTaskPriority, Project, Unit } from '../../../../types';

type UnitWithProject = Unit & {
  project?: Project | null;
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

const CHANNELS: { value: CrmActivityChannel; label: string }[] = [
  { value: 'note', label: 'ملاحظة' },
  { value: 'call', label: 'اتصال' },
  { value: 'whatsapp', label: 'واتساب' },
  { value: 'visit', label: 'زيارة' },
  { value: 'email', label: 'بريد' }
];

const PRIORITIES: { value: CrmTaskPriority; label: string }[] = [
  { value: 'low', label: 'منخفضة' },
  { value: 'medium', label: 'متوسطة' },
  { value: 'high', label: 'عالية' }
];

export default function CrmClientPage() {
  const params = useParams();
  const pathname = usePathname();
  const router = useRouter();
  const clientId = String((params as any)?.id || '');
  const [isAdmin, setIsAdmin] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [employees, setEmployees] = useState<EmployeeLite[]>([]);


  const [client, setClient] = useState<Client | null>(null);
  const [stages, setStages] = useState<CrmPipelineStage[]>([]);
  const [clientStage, setClientStage] = useState<CrmClientStage | null>(null);

  const [units, setUnits] = useState<UnitWithProject[]>([]);
  const [activities, setActivities] = useState<CrmActivity[]>([]);
  const [tasks, setTasks] = useState<CrmTask[]>([]);

  const [loading, setLoading] = useState(true);
  const [savingStage, setSavingStage] = useState(false);
  const [savingActivity, setSavingActivity] = useState(false);
  const [savingTask, setSavingTask] = useState(false);
  const [errorText, setErrorText] = useState<string | null>(null);

  const [selectedStageId, setSelectedStageId] = useState<string>('');
  const [activityChannel, setActivityChannel] = useState<CrmActivityChannel>('note');
  const [activityContent, setActivityContent] = useState('');
  const [activityUnitId, setActivityUnitId] = useState<string>('');

  const [taskTitle, setTaskTitle] = useState('');
  const [taskDueAt, setTaskDueAt] = useState<string>('');
  const [taskPriority, setTaskPriority] = useState<CrmTaskPriority>('medium');
  const [taskUnitId, setTaskUnitId] = useState<string>('');

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
      const role = ((profile?.role as string | null) || 'admin') as EmployeeRole;
      setIsAdmin(role === 'admin');
      const employeesRes = await supabase.rpc('crm_list_employees');
      if (!employeesRes.error) setEmployees(((employeesRes.data as any[]) || []) as EmployeeLite[]);
    };
    run();
  }, []);

  const fetchAll = async () => {
    if (!clientId) return;
    setLoading(true);
    setErrorText(null);
    try {
      const [clientRes, stagesRes, clientStageRes, activitiesRes, tasksRes] = await Promise.all([
        supabase.from('clients').select('*').eq('id', clientId).single(),
        supabase.from('crm_pipeline_stages').select('*').order('sort_order', { ascending: true }),
        supabase.from('crm_client_stage').select('*').eq('client_id', clientId).maybeSingle(),
        supabase.from('crm_activities').select('*').eq('client_id', clientId).order('created_at', { ascending: false }),
        supabase.from('crm_tasks').select('*').eq('client_id', clientId).order('created_at', { ascending: false })
      ]);

      if (clientRes.error) throw clientRes.error;
      if (stagesRes.error) throw stagesRes.error;
      if (clientStageRes.error) throw clientStageRes.error;
      if (activitiesRes.error) throw activitiesRes.error;
      if (tasksRes.error) throw tasksRes.error;

      const c = clientRes.data as Client;
      setClient(c);
      setStages((stagesRes.data as CrmPipelineStage[]) || []);
      setClientStage((clientStageRes.data as CrmClientStage) || null);
      setActivities((activitiesRes.data as CrmActivity[]) || []);
      setTasks((tasksRes.data as CrmTask[]) || []);

      const stageId = (clientStageRes.data as CrmClientStage | null)?.stage_id;
      setSelectedStageId(stageId || '');

      const unitsFromUuidRes = await supabase
        .from('units')
        .select('*')
        .or(`original_client_id.eq.${clientId},current_client_id.eq.${clientId}`);

      if (unitsFromUuidRes.error) throw unitsFromUuidRes.error;
      const uuidUnits = (unitsFromUuidRes.data as Unit[]) || [];

      const legacyUnits: Unit[] = [];
      if (c.id_number) {
        const legacyRes = await supabase
          .from('units')
          .select('*')
          .or(`client_id_number.eq.${c.id_number},title_deed_owner_id.eq.${c.id_number}`);
        if (legacyRes.error) throw legacyRes.error;
        legacyUnits.push(...(((legacyRes.data as Unit[]) || []) as Unit[]));
      }

      const allUnitsMap = new Map<string, Unit>();
      for (const u of [...uuidUnits, ...legacyUnits]) allUnitsMap.set(u.id, u);
      const allUnits = Array.from(allUnitsMap.values());

      const projectIds = Array.from(new Set(allUnits.map((u) => u.project_id).filter(Boolean)));
      let projects: Project[] = [];
      if (projectIds.length > 0) {
        const projectsRes = await supabase.from('projects').select('*').in('id', projectIds);
        if (projectsRes.error) throw projectsRes.error;
        projects = (projectsRes.data as Project[]) || [];
      }

      const projectById = new Map<string, Project>();
      for (const p of projects) projectById.set(p.id, p);

      const enriched: UnitWithProject[] = allUnits
        .map((u) => {
          const rel =
            u.original_client_id === clientId
              ? 'عميل أصلي'
              : u.current_client_id === clientId
                ? 'مفرّغ له'
                : c.id_number && u.client_id_number === c.id_number
                  ? 'عميل أصلي'
                  : c.id_number && u.title_deed_owner_id === c.id_number
                    ? 'مفرّغ له'
                    : 'مرتبط';
          return {
            ...u,
            project: projectById.get(u.project_id) || null,
            relationLabel: rel
          };
        })
        .sort((a, b) => {
          const pnA = a.project?.project_number || '';
          const pnB = b.project?.project_number || '';
          if (pnA !== pnB) return pnA.localeCompare(pnB, 'ar');
          return (a.unit_number || 0) - (b.unit_number || 0);
        });

      setUnits(enriched);
    } catch (e: any) {
      setErrorText(e?.message || 'تعذر تحميل ملف العميل');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
  }, [clientId]);

  const stageNameById = useMemo(() => {
    const map = new Map<string, string>();
    for (const s of stages) map.set(s.id, s.name);
    return map;
  }, [stages]);

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

  const sortedTasks = useMemo(() => {
    const copy = [...tasks];
    copy.sort((a, b) => {
      if (a.status !== b.status) return a.status === 'open' ? -1 : 1;
      const aDue = a.due_at ? new Date(a.due_at).getTime() : Number.POSITIVE_INFINITY;
      const bDue = b.due_at ? new Date(b.due_at).getTime() : Number.POSITIVE_INFINITY;
      if (aDue !== bDue) return aDue - bDue;
      return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    });
    return copy;
  }, [tasks]);

  const saveStage = async () => {
    if (!client) return;
    setSavingStage(true);
    try {
      const payload: any = {
        client_id: client.id,
        stage_id: selectedStageId || null,
        updated_at: new Date().toISOString()
      };
      const { error, data } = await supabase
        .from('crm_client_stage')
        .upsert([payload], { onConflict: 'client_id' })
        .select('*')
        .maybeSingle();
      if (error) throw error;
      setClientStage((data as CrmClientStage) || null);
    } catch (e: any) {
      alert(e?.message || 'تعذر حفظ المرحلة');
    } finally {
      setSavingStage(false);
    }
  };

  const addActivity = async () => {
    if (!client) return;
    const content = activityContent.trim();
    if (!content) return;
    setSavingActivity(true);
    try {
      const payload: any = {
        client_id: client.id,
        unit_id: activityUnitId || null,
        channel: activityChannel,
        content,
        created_by: userId
      };
      const { error } = await supabase.from('crm_activities').insert([payload]);
      if (error) throw error;
      setActivityContent('');
      setActivityUnitId('');
      fetchAll();
    } catch (e: any) {
      alert(e?.message || 'تعذر إضافة السجل');
    } finally {
      setSavingActivity(false);
    }
  };

  const addTask = async () => {
    if (!client) return;
    const title = taskTitle.trim();
    if (!title) return;
    setSavingTask(true);
    try {
      const payload: any = {
        client_id: client.id,
        unit_id: taskUnitId || null,
        title,
        due_at: taskDueAt ? new Date(taskDueAt).toISOString() : null,
        priority: taskPriority,
        status: 'open'
      };
      const { error } = await supabase.from('crm_tasks').insert([payload]);
      if (error) throw error;
      setTaskTitle('');
      setTaskDueAt('');
      setTaskUnitId('');
      setTaskPriority('medium');
      fetchAll();
    } catch (e: any) {
      alert(e?.message || 'تعذر إضافة المهمة');
    } finally {
      setSavingTask(false);
    }
  };

  const toggleTaskDone = async (t: CrmTask) => {
    try {
      const nextStatus = t.status === 'done' ? 'open' : 'done';
      const now = new Date().toISOString();
      const updatePayload: any = {
        status: nextStatus,
        updated_at: now,
        completed_at: nextStatus === 'done' ? now : null
      };
      let res = await supabase.from('crm_tasks').update(updatePayload).eq('id', t.id);
      if (res.error && String(res.error.message || '').toLowerCase().includes('column')) {
        res = await supabase.from('crm_tasks').update({ status: nextStatus }).eq('id', t.id);
      }
      const { error } = res;
      if (error) throw error;
      setTasks((prev) =>
        prev.map((x) =>
          x.id === t.id ? { ...x, status: nextStatus as any, updated_at: now, completed_at: nextStatus === 'done' ? now : null } : x
        )
      );
    } catch (e: any) {
      alert(e?.message || 'تعذر تحديث المهمة');
    }
  };

  if (loading) {
    return (
      <div className="p-8 min-h-screen flex items-center justify-center" dir="rtl">
        <div className="flex items-center gap-2 text-gray-600">
          <Loader2 className="animate-spin" size={20} />
          جاري التحميل...
        </div>
      </div>
    );
  }

  if (!client) {
    return (
      <div className="p-8 min-h-screen max-w-5xl mx-auto" dir="rtl">
        <div className="bg-white p-6 rounded-2xl border border-gray-100">
          <div className="text-gray-700">لم يتم العثور على العميل</div>
          <button onClick={() => router.push('/crm')} className="mt-4 px-4 py-2 bg-gray-900 text-white rounded-xl">
            العودة
          </button>
        </div>
      </div>
    );
  }

  const currentStageName = clientStage?.stage_id ? stageNameById.get(clientStage.stage_id) || 'غير محدد' : 'غير محدد';

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-6xl mx-auto" dir="rtl">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link href="/crm" className="p-2 rounded-xl hover:bg-gray-100 transition-colors">
            <ArrowRight size={22} className="text-gray-600" />
          </Link>
          <div className="w-12 h-12 bg-emerald-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-emerald-600/20">
            <User size={24} />
          </div>
          <div className="min-w-0">
            <h1 className="font-display font-bold text-2xl text-gray-900 truncate">{client.name}</h1>
            <div className="text-sm text-gray-500 flex items-center gap-2">
              <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700">{currentStageName}</span>
              <span className="text-gray-300">•</span>
              <span dir="ltr">{client.phone || '-'}</span>
            </div>
          </div>
        </div>
        <button
          onClick={fetchAll}
          className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white border border-gray-200 hover:bg-gray-50 transition-colors"
        >
          <RefreshCw size={16} className="text-gray-600" />
          تحديث
        </button>
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

      {errorText && (
        <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-700 text-sm flex items-center gap-2">
          <AlertCircle size={18} />
          {errorText}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-lg text-gray-900 flex items-center gap-2">
                <ClipboardList size={18} className="text-blue-600" />
                المهام
              </h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
              <input
                value={taskTitle}
                onChange={(e) => setTaskTitle(e.target.value)}
                className="md:col-span-2 w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
                placeholder="عنوان المهمة"
              />
              <input
                type="datetime-local"
                value={taskDueAt}
                onChange={(e) => setTaskDueAt(e.target.value)}
                className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
              />
              <select
                value={taskPriority}
                onChange={(e) => setTaskPriority(e.target.value as CrmTaskPriority)}
                className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
              >
                {PRIORITIES.map((p) => (
                  <option key={p.value} value={p.value}>
                    أولوية {p.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mt-3">
              <select
                value={taskUnitId}
                onChange={(e) => setTaskUnitId(e.target.value)}
                className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
              >
                <option value="">بدون ربط بوحدة</option>
                {units.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.project?.project_number ? `${u.project.project_number}-${u.unit_number}` : `وحدة ${u.unit_number}`}
                  </option>
                ))}
              </select>
              <button
                onClick={addTask}
                disabled={savingTask || !taskTitle.trim()}
                className="md:col-span-2 flex items-center justify-center gap-2 bg-blue-600 text-white px-4 py-2.5 rounded-xl font-bold hover:bg-blue-700 transition-colors disabled:opacity-50"
              >
                <Plus size={18} />
                {savingTask ? 'جاري الإضافة...' : 'إضافة مهمة'}
              </button>
            </div>

            <div className="mt-6 space-y-3">
              {tasks.length === 0 ? (
                <div className="text-center py-8 text-gray-500">لا يوجد مهام</div>
              ) : (
                sortedTasks.map((t) => {
                  const assignee =
                    t.assigned_to === null || t.assigned_to === undefined
                      ? 'عامّة'
                      : t.assigned_to === userId
                        ? 'أنت'
                        : employeeLabelById.get(t.assigned_to) || String(t.assigned_to).slice(0, 8);
                  return (
                  <div key={t.id} className="p-4 bg-white border border-gray-200 rounded-xl flex items-start justify-between gap-4">
                    <div className="min-w-0">
                      <div className={`font-bold ${t.status === 'done' ? 'text-gray-400 line-through' : 'text-gray-900'}`}>
                        {t.title}
                      </div>
                      <div className="text-xs text-gray-500 mt-1">
                        {t.due_at ? `موعد: ${new Date(t.due_at).toLocaleString('ar-SA')}` : 'بدون موعد'}
                        <span className="text-gray-300 mx-2">•</span>
                        أولوية: {PRIORITIES.find((p) => p.value === t.priority)?.label || t.priority}
                        <span className="text-gray-300 mx-2">•</span>
                        مكلّف بها: {assignee}
                      </div>
                    </div>
                    <button
                      onClick={() => toggleTaskDone(t)}
                      className={`shrink-0 px-3 py-2 rounded-xl text-sm font-bold transition-colors ${
                        t.status === 'done' ? 'bg-gray-100 text-gray-700 hover:bg-gray-200' : 'bg-green-600 text-white hover:bg-green-700'
                      }`}
                    >
                      <CheckCircle2 size={16} className="inline-block ml-1" />
                      {t.status === 'done' ? 'إعادة فتح' : 'تمت'}
                    </button>
                  </div>
                  );
                })
              )}
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-lg text-gray-900 flex items-center gap-2">
                <FileText size={18} className="text-emerald-600" />
                سجل التواصل
              </h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <select
                value={activityChannel}
                onChange={(e) => setActivityChannel(e.target.value as CrmActivityChannel)}
                className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
              >
                {CHANNELS.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
              <select
                value={activityUnitId}
                onChange={(e) => setActivityUnitId(e.target.value)}
                className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
              >
                <option value="">بدون ربط بوحدة</option>
                {units.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.project?.project_number ? `${u.project.project_number}-${u.unit_number}` : `وحدة ${u.unit_number}`}
                  </option>
                ))}
              </select>
              <button
                onClick={addActivity}
                disabled={savingActivity || !activityContent.trim()}
                className="flex items-center justify-center gap-2 bg-emerald-600 text-white px-4 py-2.5 rounded-xl font-bold hover:bg-emerald-700 transition-colors disabled:opacity-50"
              >
                <Plus size={18} />
                {savingActivity ? 'جاري الحفظ...' : 'إضافة'}
              </button>
            </div>

            <textarea
              value={activityContent}
              onChange={(e) => setActivityContent(e.target.value)}
              className="w-full mt-3 p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none min-h-[90px]"
              placeholder="اكتب ملاحظة أو تفاصيل التواصل..."
            />

            <div className="mt-6 space-y-3">
              {activities.length === 0 ? (
                <div className="text-center py-8 text-gray-500">لا يوجد سجل تواصل</div>
              ) : (
                activities.map((a) => {
                  const by = a.created_by ? employeeLabelById.get(String(a.created_by)) || String(a.created_by).slice(0, 8) : null;
                  return (
                  <div key={a.id} className="p-4 bg-white border border-gray-200 rounded-xl">
                    <div className="flex items-center justify-between gap-3">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-xs text-gray-500">
                          {CHANNELS.find((c) => c.value === a.channel)?.label || a.channel}
                        </span>
                        {a.outcome ? (
                          <span
                            className={`px-2 py-1 rounded-md text-[11px] font-bold border ${
                              a.outcome === 'completed'
                                ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                                : a.outcome === 'no_answer'
                                  ? 'bg-amber-50 text-amber-800 border-amber-200'
                                  : 'bg-purple-50 text-purple-800 border-purple-200'
                            }`}
                          >
                            {a.outcome === 'completed' ? 'تم التواصل' : a.outcome === 'no_answer' ? 'عدم رد' : 'تم حجز موعد'}
                          </span>
                        ) : null}
                        {a.unit_id ? <span className="px-2 py-1 rounded-md text-[11px] font-bold bg-gray-50 text-gray-700 border border-gray-200">مرتبط بوحدة</span> : null}
                        {by ? (
                          <span className="px-2 py-1 rounded-md text-[11px] font-bold bg-slate-50 text-slate-700 border border-slate-200">
                            بواسطة: {by}
                          </span>
                        ) : null}
                      </div>
                      <div className="text-xs text-gray-500">{new Date(a.created_at).toLocaleString('ar-SA')}</div>
                    </div>
                    <div className="mt-2 text-gray-900 whitespace-pre-wrap">{a.content}</div>
                    <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-2 text-xs text-gray-600">
                      <div>
                        التواصل القادم: {a.next_contact_at ? new Date(a.next_contact_at).toLocaleString('ar-SA') : '-'}
                      </div>
                      {a.outcome === 'appointment' ? (
                        <div>
                          الموعد: {a.appointment_at ? new Date(a.appointment_at).toLocaleString('ar-SA') : '-'} {a.appointment_with ? `• ${a.appointment_with}` : ''}
                        </div>
                      ) : (
                        <div />
                      )}
                    </div>
                  </div>
                  );
                })
              )}
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
            <h2 className="font-bold text-lg text-gray-900 mb-4">المرحلة</h2>
            <select
              value={selectedStageId}
              onChange={(e) => setSelectedStageId(e.target.value)}
              className="w-full py-3 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="">غير محدد</option>
              {stages.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
            <button
              onClick={saveStage}
              disabled={savingStage}
              className="mt-3 w-full bg-emerald-600 text-white py-3 rounded-xl font-bold hover:bg-emerald-700 transition-colors disabled:opacity-50"
            >
              {savingStage ? 'جاري الحفظ...' : 'حفظ المرحلة'}
            </button>
          </div>

          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
            <h2 className="font-bold text-lg text-gray-900 mb-4 flex items-center gap-2">
              <Phone size={18} className="text-gray-400" />
              بيانات الاتصال
            </h2>
            <div className="space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-gray-500">الجوال</span>
                <span dir="ltr" className="font-bold text-gray-900">
                  {client.phone || '-'}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-500">الهوية</span>
                <span className="font-bold text-gray-900">{client.id_number || '-'}</span>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
            <h2 className="font-bold text-lg text-gray-900 mb-4 flex items-center gap-2">
              <Building2 size={18} className="text-purple-600" />
              الوحدات المرتبطة
            </h2>
            {units.length === 0 ? (
              <div className="text-center py-6 text-gray-500">لا يوجد وحدات مرتبطة</div>
            ) : (
              <div className="space-y-3">
                {units.map((u) => (
                  <Link key={u.id} href={`/units/${u.id}`} className="block p-4 bg-white border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors">
                    <div className="flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <div className="font-bold text-gray-900 truncate">
                          {u.project?.name || 'مشروع غير معروف'} {u.project?.project_number ? `(${u.project.project_number})` : ''}
                        </div>
                        <div className="text-sm text-gray-600">
                          وحدة {u.unit_number} <span className="text-gray-300 mx-2">•</span> {u.relationLabel}
                        </div>
                      </div>
                      <span className="px-3 py-1 rounded-full text-xs font-bold bg-purple-50 text-purple-700">{u.status}</span>
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
