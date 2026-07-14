'use client';

export const runtime = 'edge';

import React, { useEffect, useMemo, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowRight,
  Loader2,
  X,
  AlertCircle,
  CheckCircle2,
  Building2,
  Users,
  DollarSign,
  Save,
  Plus,
  Trash2
} from 'lucide-react';
import { supabase } from '../../../../lib/supabaseClient';
import {
  Client,
  ContractObligation,
  ContractPayment,
  CONTRACT_STATUSES,
  CONTRACT_TYPES,
  NewContract,
  PAYMENT_METHODS,
  Project,
  Unit
} from '../../../../types';
import CustomCalendar from '../../../../components/CustomCalendar';
import CustomProjectPicker from '../../../../components/CustomProjectPicker';
import CustomSelect from '../../../../components/CustomSelect';
import CustomUnitPicker from '../../../../components/CustomUnitPicker';

function Toast({
  message,
  type,
  onClose,
}: {
  message: string;
  type: 'success' | 'error' | 'info';
  onClose: () => void;
}) {
  const styles =
    type === 'success'
      ? 'bg-green-50 text-green-800 border-green-200'
      : type === 'error'
      ? 'bg-red-50 text-red-800 border-red-200'
      : 'bg-blue-50 text-blue-800 border-blue-200';

  return (
    <div className={`fixed top-6 left-1/2 -translate-x-1/2 z-50 px-5 py-3 rounded-2xl border shadow-lg flex items-center gap-3 ${styles}`}>
      {type === 'error' && <AlertCircle size={20} />}
      {type === 'info' && <Loader2 size={20} className="animate-spin" />}
      {type === 'success' && <CheckCircle2 size={20} />}
      <span className="font-medium">{message}</span>
      <button onClick={onClose} className="hover:opacity-80 transition-opacity">
        <X size={18} />
      </button>
    </div>
  );
}

type EditablePayment = Omit<ContractPayment, 'contract_id'>;
type EditableObligation = Omit<ContractObligation, 'contract_id'>;
type EmployeeRole = 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';

const getContractTypeLabel = (type: string | null | undefined) => {
  if (!type) return null;
  return (CONTRACT_TYPES as Record<string, string>)[type] || type;
};

export default function EditContractPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const contractId = params?.id;

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);
  const [access, setAccess] = useState<'checking' | 'allowed' | 'denied'>('checking');

  const [projects, setProjects] = useState<Project[]>([]);
  const [units, setUnits] = useState<Unit[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [contracts, setContracts] = useState<{ id: string; unit_id: string }[]>([]);
  const [filteredUnits, setFilteredUnits] = useState<Unit[]>([]);

  const [initialUnitId, setInitialUnitId] = useState<string | null>(null);

  const [contractData, setContractData] = useState<NewContract>({
    project_id: '',
    unit_id: '',
    client_id: null,
    contract_date: new Date().toISOString().split('T')[0],
    total_amount: 0,
    paid_amount: 0,
    completion_period_months: 12,
    payment_grace_period_months: 60,
    status: 'draft',
    type: 'under_construction',
    created_by_id: null,
    created_by_name: null,
    notes: null,
    client_name: null,
    client_id_number: null,
    client_phone: null,
    agent_name: null,
    agent_id_number: null,
    agency_number: null,
    agency_date: null,
  });

  const [baseAmount, setBaseAmount] = useState(0);
  const [payments, setPayments] = useState<EditablePayment[]>([]);
  const [obligations, setObligations] = useState<EditableObligation[]>([]);

  const [newPayment, setNewPayment] = useState<Omit<EditablePayment, 'id' | 'created_at'>>({
    amount: 0,
    payment_date: new Date().toISOString().split('T')[0],
    notes: '',
    payment_method: null,
    transaction_number: '',
    statement: '',
  });

  const [newObligation, setNewObligation] = useState({ amount: 0, description: '', due_date: '' });

  const showToast = (message: string, type: 'success' | 'error' | 'info') => setToast({ message, type });

  useEffect(() => {
    const run = async () => {
      const { data } = await supabase.auth.getUser();
      const user = data.user;
      if (!user) {
        setAccess('denied');
        setLoading(false);
        return;
      }

      const { data: profile, error: profileError } = await supabase
        .from('employee_profiles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();

      if (profileError) {
        setAccess('denied');
        setLoading(false);
        return;
      }

      const role = ((profile?.role as string | null) || 'viewer') as EmployeeRole;
      if (role !== 'admin') {
        setAccess('denied');
        setLoading(false);
        return;
      }

      setAccess('allowed');
    };

    run();
  }, []);

  useEffect(() => {
    if (access !== 'allowed') return;
    async function loadData() {
      setLoading(true);
      try {
        const [projectsRes, unitsRes, clientsRes, contractsRes, contractRes] = await Promise.all([
          supabase.from('projects').select('*'),
          supabase.from('units').select('*'),
          supabase.from('clients').select('*'),
          supabase.from('contracts').select('id, unit_id'),
          supabase.from('contracts').select('*').eq('id', contractId).single(),
        ]);

        if (projectsRes.data) setProjects(projectsRes.data);
        if (unitsRes.data) setUnits(unitsRes.data);
        if (clientsRes.data) setClients(clientsRes.data);
        if (contractsRes.data) setContracts(contractsRes.data);

        if (contractRes.error) throw contractRes.error;
        const c: any = contractRes.data;
        setInitialUnitId(c.unit_id);

        const [obligationsRes, paymentsRes] = await Promise.all([
          supabase.from('contract_obligations').select('*').eq('contract_id', contractId),
          supabase.from('contract_payments').select('*').eq('contract_id', contractId),
        ]);

        const existingObligations = (obligationsRes.data || []) as EditableObligation[];
        const existingPayments = (paymentsRes.data || []) as EditablePayment[];

        const obligationsTotal = existingObligations.reduce((sum, o) => sum + Number(o.amount), 0);
        const computedBase = Math.max(Number(c.total_amount || 0) - obligationsTotal, 0);

        setBaseAmount(computedBase);
        setObligations(existingObligations);
        setPayments(existingPayments);

        setContractData((prev) => ({
          ...prev,
          project_id: c.project_id || '',
          unit_id: c.unit_id || '',
          client_id: c.client_id ?? null,
          contract_date: c.contract_date || new Date().toISOString().split('T')[0],
          total_amount: Number(c.total_amount || 0),
          paid_amount: Number(c.paid_amount || 0),
          completion_period_months: Number(c.completion_period_months || 12),
          payment_grace_period_months: c.payment_grace_period_months ?? 60,
          status: (c.status || 'draft') as NewContract['status'],
          type: (c.type || 'under_construction') as NewContract['type'],
          created_by_id: c.created_by_id ?? null,
          created_by_name: c.created_by_name ?? null,
          notes: c.notes ?? null,
          client_name: c.client_name ?? null,
          client_id_number: c.client_id_number ?? null,
          client_phone: c.client_phone ?? null,
          agent_name: c.agent_name ?? null,
          agent_id_number: c.agent_id_number ?? null,
          agency_number: c.agency_number ?? null,
          agency_date: c.agency_date ?? null,
        }));
      } catch (e: any) {
        console.error('Error loading contract:', e);
        showToast('حدث خطأ أثناء تحميل بيانات العقد', 'error');
      } finally {
        setLoading(false);
      }
    }
    if (contractId) {
      loadData();
    }
  }, [contractId, access]);

  useEffect(() => {
    if (!contractData.project_id) {
      setFilteredUnits([]);
      return;
    }
    const unitIdsWithContracts = new Set(contracts.map(c => c.unit_id));
    setFilteredUnits(
      units.filter(u =>
        u.project_id === contractData.project_id &&
        (
          u.id === contractData.unit_id ||
          (!unitIdsWithContracts.has(u.id) && u.status === 'available')
        )
      )
    );
  }, [contractData.project_id, contractData.unit_id, units, contracts]);

  useEffect(() => {
    const obligationsTotal = obligations.reduce((sum, o) => sum + Number(o.amount), 0);
    const total = baseAmount + obligationsTotal;
    setContractData(prev => ({ ...prev, total_amount: total }));
  }, [baseAmount, obligations]);

  useEffect(() => {
    const paid = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    setContractData(prev => ({ ...prev, paid_amount: paid }));
  }, [payments]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (window.location.hash !== '#payments-section') return;

    const timer = window.setTimeout(() => {
      document.getElementById('payments-section')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 150);

    return () => window.clearTimeout(timer);
  }, [loading]);

  const selectedProject = useMemo(() => projects.find(p => p.id === contractData.project_id) || null, [projects, contractData.project_id]);
  const selectedUnit = useMemo(() => units.find(u => u.id === contractData.unit_id) || null, [units, contractData.unit_id]);

  const handleSelectClient = (clientId: string) => {
    const client = clients.find(c => c.id === clientId);
    if (!client) return;
    setContractData(prev => ({
      ...prev,
      client_id: client.id,
      client_name: client.name,
      client_id_number: client.id_number || null,
      client_phone: client.phone || null,
    }));
  };

  const addPayment = () => {
    if (Number(newPayment.amount) <= 0) {
      showToast('يرجى إدخال مبلغ الدفعة', 'error');
      return;
    }
    setPayments(prev => ([
      ...prev,
      {
        id: `tmp_${Date.now()}`,
        created_at: new Date().toISOString(),
        ...newPayment,
        amount: Number(newPayment.amount),
      }
    ]));
    setNewPayment({
      amount: 0,
      payment_date: new Date().toISOString().split('T')[0],
      notes: '',
      payment_method: null,
      transaction_number: '',
      statement: '',
    });
  };

  const removePayment = (id: string) => setPayments(prev => prev.filter(p => p.id !== id));

  const addObligation = () => {
    if (Number(newObligation.amount) <= 0 || !newObligation.description) {
      showToast('يرجى إدخال وصف ومبلغ الالتزام', 'error');
      return;
    }
    setObligations(prev => ([
      ...prev,
      {
        id: `tmp_${Date.now()}`,
        created_at: new Date().toISOString(),
        amount: Number(newObligation.amount),
        description: newObligation.description,
        due_date: newObligation.due_date || null,
        paid: false,
      }
    ]));
    setNewObligation({ amount: 0, description: '', due_date: '' });
  };

  const removeObligation = (id: string) => setObligations(prev => prev.filter(o => o.id !== id));

  const upsertDebtForUnit = async (unit: Unit, project: Project, payload: { unit_id: string; project_id: string }) => {
    const remainingValue = Math.max(Number(contractData.total_amount || 0) - Number(contractData.paid_amount || 0), 0);
    const debtPayload: any = {
      unit_id: payload.unit_id,
      project_id: payload.project_id,
      project_number: project.project_number,
      project_name: project.name,
      unit_number: unit.unit_number,
      deed_number: unit.deed_number || null,
      original_client_name: contractData.client_name || null,
      original_client_phone: contractData.client_phone || null,
      original_client_id: contractData.client_id_number || null,
      current_owner_name: unit.title_deed_owner || null,
      current_owner_phone: unit.title_deed_owner_phone || null,
      contract_value: contractData.total_amount,
      paid_value: contractData.paid_amount,
      remaining_value: remainingValue,
      saved_at: new Date().toISOString(),
    };

    const { error: debtError } = await supabase
      .from('debts')
      .upsert([debtPayload], { onConflict: 'unit_id' });
    if (debtError) throw debtError;
  };

  const handleSave = async () => {
    if (!selectedProject || !selectedUnit) {
      showToast('يرجى اختيار المشروع والوحدة', 'error');
      return;
    }

    try {
      setSaving(true);
      showToast('جارٍ حفظ التعديلات...', 'info');

      const { error: contractError } = await supabase
        .from('contracts')
        .update({
          ...contractData,
        })
        .eq('id', contractId);
      if (contractError) throw contractError;

      const { error: deleteOblError } = await supabase.from('contract_obligations').delete().eq('contract_id', contractId);
      if (deleteOblError) throw deleteOblError;
      const { error: deletePayError } = await supabase.from('contract_payments').delete().eq('contract_id', contractId);
      if (deletePayError) throw deletePayError;

      if (obligations.length > 0) {
        const obligationsToInsert = obligations.map(({ id, created_at, ...rest }) => ({
          ...rest,
          contract_id: contractId,
        }));
        const { error: insertOblError } = await supabase.from('contract_obligations').insert(obligationsToInsert);
        if (insertOblError) throw insertOblError;
      }

      if (payments.length > 0) {
        const paymentsToInsert = payments.map(({ id, created_at, ...rest }) => ({
          ...rest,
          contract_id: contractId,
        }));
        const { error: insertPayError } = await supabase.from('contract_payments').insert(paymentsToInsert);
        if (insertPayError) throw insertPayError;
      }

      const newUnitId = contractData.unit_id;
      const oldUnitId = initialUnitId;

      const { error: newUnitUpdateError } = await supabase
        .from('units')
        .update({
          status: 'pending_sale',
          client_name: contractData.client_name || null,
          client_id_number: contractData.client_id_number || null,
          client_phone: contractData.client_phone || null
        })
        .eq('id', newUnitId);
      if (newUnitUpdateError) throw newUnitUpdateError;

      await upsertDebtForUnit(selectedUnit, selectedProject, { unit_id: newUnitId, project_id: contractData.project_id });

      if (oldUnitId && oldUnitId !== newUnitId) {
        const { data: remainingContracts, error: remainingError } = await supabase
          .from('contracts')
          .select('id')
          .eq('unit_id', oldUnitId)
          .neq('id', contractId)
          .limit(1);
        if (remainingError) throw remainingError;

        if (!remainingContracts || remainingContracts.length === 0) {
          const { error: oldUnitUpdateError } = await supabase
            .from('units')
            .update({
              status: 'available',
              client_name: null,
              client_id_number: null,
              client_phone: null
            })
            .eq('id', oldUnitId);
          if (oldUnitUpdateError) throw oldUnitUpdateError;

          const { error: debtDeleteError } = await supabase.from('debts').delete().eq('unit_id', oldUnitId);
          if (debtDeleteError) throw debtDeleteError;
        }
        setInitialUnitId(newUnitId);
      }

      try {
        const {
          data: { user },
        } = await supabase.auth.getUser();
        const actorId = user?.id || null;
        const normalizeUsername = (value: string | null | undefined) => {
          if (!value) return null;
          return value.split('@')[0] || value;
        };
        let actorName = normalizeUsername(user?.email);

        if (actorId) {
          const employeesRes = await supabase.rpc('crm_list_employees');
          const employeesData = (employeesRes.data as Array<{ id: string; email: string | null }> | null) || [];
          const currentEmployee = employeesData.find((employee) => employee.id === actorId);
          actorName = normalizeUsername(currentEmployee?.email) || actorName;
        }

        await supabase.from('contract_logs').insert({
          contract_id: contractId,
          actor_id: actorId,
          actor_name: actorName || null,
          action: 'contract_updated',
          entity_type: 'contract',
          entity_id: contractId,
          metadata: {
            operation_at: new Date().toISOString(),
            operation_source: 'contracts_edit_page',
            contract_type: contractData.type || 'under_construction',
            contract_type_label: getContractTypeLabel(contractData.type || 'under_construction'),
            contract_status: contractData.status || null,
            contract_date: contractData.contract_date,
            project_id: contractData.project_id,
            project_number: selectedProject.project_number,
            project_name: selectedProject.name,
            unit_id: contractData.unit_id,
            unit_number: selectedUnit.unit_number,
            client_id: contractData.client_id || null,
            client_name: contractData.client_name || null,
            client_phone: contractData.client_phone || null,
            client_id_number: contractData.client_id_number || null,
            total_amount: contractData.total_amount,
            paid_amount: contractData.paid_amount,
            remaining_amount: Math.max((contractData.total_amount || 0) - (contractData.paid_amount || 0), 0),
            payments_count: payments.length,
            obligations_count: obligations.length,
          }
        });
      } catch (e) {
        console.error('Error logging contract update:', e);
      }

      showToast('تم حفظ التعديلات بنجاح', 'success');
      setTimeout(() => router.push('/contracts'), 800);
    } catch (e: any) {
      console.error('Error saving contract:', e);
      showToast(e?.message || 'حدث خطأ أثناء حفظ التعديلات', 'error');
    } finally {
      setSaving(false);
    }
  };

  if (access === 'checking') {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-br from-gray-50 to-blue-50" dir="rtl">
        <Loader2 size={56} className="animate-spin text-blue-600" />
        <div className="mt-4 text-lg font-semibold text-gray-700">جاري التحقق من الصلاحيات...</div>
      </div>
    );
  }

  if (access === 'denied') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-50 to-blue-50" dir="rtl">
        <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-10 max-w-md w-full text-center space-y-4">
          <div className="text-2xl font-extrabold text-gray-900">غير مصرح</div>
          <div className="text-gray-600 font-semibold">لا تملك صلاحية تعديل أو حذف العقود</div>
          <button
            onClick={() => router.push('/contracts')}
            className="w-full px-6 py-3 rounded-2xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors"
          >
            الرجوع لصفحة العقود
          </button>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-br from-gray-50 to-blue-50" dir="rtl">
        <Loader2 size={56} className="animate-spin text-blue-600" />
        <div className="mt-4 text-lg font-semibold text-gray-700">جاري تحميل بيانات العقد...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen pb-24" dir="rtl" style={{ background: 'var(--background)' }}>
      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}

      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.back()}
            className="p-3 bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-300 hover:-translate-y-0.5"
          >
            <ArrowRight size={24} className="text-gray-700" />
          </button>
          <div>
            <h1 className="text-3xl font-extrabold text-gray-900">تعديل العقد</h1>
            <p className="text-gray-600 mt-1">تعديل جميع بيانات العقد مع مزامنة الوحدة والمديونية عند الحاجة</p>
          </div>
        </div>

        <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
          <div className="flex items-center gap-3 pb-4 border-b border-gray-100">
            <Building2 size={28} className="text-blue-600" />
            <h2 className="text-xl font-extrabold text-gray-900">بيانات العقد</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <CustomProjectPicker
              label="اختر المشروع"
              placeholder="اختر المشروع..."
              projects={projects}
              value={contractData.project_id}
              onChange={(val) => setContractData(prev => ({ ...prev, project_id: val, unit_id: '' }))}
            />

            <CustomCalendar
              label="تاريخ العقد"
              value={contractData.contract_date}
              onChange={(val) => setContractData(prev => ({ ...prev, contract_date: val }))}
            />
          </div>

          <CustomUnitPicker
            label="اختر الوحدة"
            placeholder={!contractData.project_id ? "يرجى اختيار المشروع أولاً..." : "اختر الوحدة..."}
            units={filteredUnits}
            value={contractData.unit_id}
            onChange={(val) => setContractData(prev => ({ ...prev, unit_id: val }))}
            disabled={!contractData.project_id}
          />

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <CustomSelect
              label="نوع العقد"
              options={Object.keys(CONTRACT_TYPES).map(k => ({ value: k, label: CONTRACT_TYPES[k as keyof typeof CONTRACT_TYPES] }))}
              value={contractData.type}
              onChange={(val) => setContractData(prev => ({ ...prev, type: val as any }))}
            />
            <CustomSelect
              label="حالة العقد"
              options={Object.keys(CONTRACT_STATUSES).map(k => ({ value: k, label: CONTRACT_STATUSES[k as keyof typeof CONTRACT_STATUSES] }))}
              value={contractData.status}
              onChange={(val) => setContractData(prev => ({ ...prev, status: val as any }))}
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="block text-base font-semibold text-gray-700">مدة التنفيذ (بالأشهر)</label>
              <input
                type="number"
                value={contractData.completion_period_months}
                onChange={(e) => setContractData(prev => ({ ...prev, completion_period_months: Number(e.target.value || 0) }))}
                className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all text-lg"
              />
            </div>
            <div className="space-y-2">
              <label className="block text-base font-semibold text-gray-700">مهلة السداد (بالأيام)</label>
              <input
                type="number"
                value={contractData.payment_grace_period_months ?? 0}
                onChange={(e) => setContractData(prev => ({ ...prev, payment_grace_period_months: Number(e.target.value || 0) }))}
                className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all text-lg"
              />
            </div>
          </div>

          <div className="pt-2">
            <label className="block text-base font-semibold text-gray-700 mb-3">ملاحظات</label>
            <textarea
              value={contractData.notes || ''}
              onChange={(e) => setContractData(prev => ({ ...prev, notes: e.target.value || null }))}
              rows={3}
              className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all text-lg resize-none"
            />
          </div>
        </div>

        <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
          <div className="flex items-center gap-3 pb-4 border-b border-gray-100">
            <Users size={28} className="text-purple-600" />
            <h2 className="text-xl font-extrabold text-gray-900">بيانات العميل</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <CustomSelect
              label="اختيار عميل (اختياري)"
              placeholder="اختر العميل..."
              options={clients.map(c => ({ value: c.id, label: c.name }))}
              value={contractData.client_id || ''}
              onChange={(val) => handleSelectClient(val)}
            />

            <div className="space-y-2">
              <label className="block text-base font-semibold text-gray-700">رقم الهوية</label>
              <input
                type="text"
                value={contractData.client_id_number || ''}
                onChange={(e) => setContractData(prev => ({ ...prev, client_id_number: e.target.value || null }))}
                className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all text-lg"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="block text-base font-semibold text-gray-700">اسم العميل</label>
              <input
                type="text"
                value={contractData.client_name || ''}
                onChange={(e) => setContractData(prev => ({ ...prev, client_name: e.target.value || null }))}
                className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all text-lg"
              />
            </div>
            <div className="space-y-2">
              <label className="block text-base font-semibold text-gray-700">رقم الجوال</label>
              <input
                type="text"
                value={contractData.client_phone || ''}
                onChange={(e) => setContractData(prev => ({ ...prev, client_phone: e.target.value || null }))}
                className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all text-lg"
              />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
          <div className="flex items-center gap-3 pb-4 border-b border-gray-100">
            <DollarSign size={28} className="text-green-600" />
            <h2 className="text-xl font-extrabold text-gray-900">المالية</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="space-y-2 md:col-span-1">
              <label className="block text-base font-semibold text-gray-700">قيمة العقد الأساسية</label>
              <input
                type="number"
                value={baseAmount}
                onChange={(e) => setBaseAmount(Number(e.target.value || 0))}
                className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all text-lg"
              />
            </div>
            <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl p-6 text-white shadow-lg">
              <div className="text-sm font-semibold opacity-90">إجمالي العقد</div>
              <div className="text-3xl font-extrabold mt-2">{Number(contractData.total_amount || 0).toLocaleString()} ر.س</div>
            </div>
            <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-2xl p-6 text-white shadow-lg">
              <div className="text-sm font-semibold opacity-90">المدفوع</div>
              <div className="text-3xl font-extrabold mt-2">{Number(contractData.paid_amount || 0).toLocaleString()} ر.س</div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <div id="payments-section" className="space-y-4 scroll-mt-24">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-extrabold text-gray-900">الالتزامات</h3>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <input
                  type="text"
                  placeholder="الوصف"
                  value={newObligation.description}
                  onChange={(e) => setNewObligation(prev => ({ ...prev, description: e.target.value }))}
                  className="px-4 py-3 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all"
                />
                <input
                  type="number"
                  placeholder="المبلغ"
                  value={newObligation.amount}
                  onChange={(e) => setNewObligation(prev => ({ ...prev, amount: Number(e.target.value || 0) }))}
                  className="px-4 py-3 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all"
                />
                <button
                  onClick={addObligation}
                  className="inline-flex items-center justify-center gap-2 px-4 py-3 rounded-2xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors"
                >
                  <Plus size={18} />
                  إضافة
                </button>
              </div>

              <div className="space-y-3">
                {obligations.length === 0 ? (
                  <div className="text-gray-500">لا توجد التزامات</div>
                ) : (
                  obligations.map(o => (
                    <div key={o.id} className="flex items-center justify-between gap-3 p-4 rounded-2xl border border-gray-100 bg-gray-50">
                      <div className="min-w-0">
                        <div className="font-bold text-gray-900 truncate">{o.description}</div>
                        <div className="text-sm text-gray-600">{Number(o.amount).toLocaleString()} ر.س</div>
                      </div>
                      <button onClick={() => removeObligation(o.id)} className="p-2 rounded-xl bg-red-50 text-red-600 hover:bg-red-100 transition-colors">
                        <Trash2 size={18} />
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-extrabold text-gray-900">الدفعات</h3>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                <input
                  type="number"
                  placeholder="المبلغ"
                  value={newPayment.amount}
                  onChange={(e) => setNewPayment(prev => ({ ...prev, amount: Number(e.target.value || 0) }))}
                  className="px-4 py-3 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all"
                />
                <input
                  type="date"
                  value={newPayment.payment_date}
                  onChange={(e) => setNewPayment(prev => ({ ...prev, payment_date: e.target.value }))}
                  className="px-4 py-3 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all"
                />
                <CustomSelect
                  placeholder="طريقة الدفع"
                  options={Object.keys(PAYMENT_METHODS).map(k => ({ value: k, label: PAYMENT_METHODS[k as keyof typeof PAYMENT_METHODS] }))}
                  value={newPayment.payment_method || ''}
                  onChange={(val) => setNewPayment(prev => ({ ...prev, payment_method: (val || null) as any }))}
                />
                <button
                  onClick={addPayment}
                  className="inline-flex items-center justify-center gap-2 px-4 py-3 rounded-2xl bg-green-600 text-white font-semibold hover:bg-green-700 transition-colors"
                >
                  <Plus size={18} />
                  إضافة
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <input
                  type="text"
                  placeholder="الرقم المرجعي"
                  value={newPayment.transaction_number || ''}
                  onChange={(e) => setNewPayment(prev => ({ ...prev, transaction_number: e.target.value }))}
                  className="px-4 py-3 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all"
                />
                <input
                  type="text"
                  placeholder="البيان"
                  value={newPayment.statement || ''}
                  onChange={(e) => setNewPayment(prev => ({ ...prev, statement: e.target.value }))}
                  className="px-4 py-3 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all"
                />
              </div>

              <textarea
                placeholder="ملاحظات"
                value={newPayment.notes || ''}
                onChange={(e) => setNewPayment(prev => ({ ...prev, notes: e.target.value }))}
                className="px-4 py-3 rounded-2xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none transition-all min-h-[90px]"
              />

              <div className="space-y-3">
                {payments.length === 0 ? (
                  <div className="text-gray-500">لا توجد دفعات</div>
                ) : (
                  payments.map(p => (
                    <div key={p.id} className="flex items-center justify-between gap-3 p-4 rounded-2xl border border-gray-100 bg-gray-50">
                      <div className="min-w-0">
                        <div className="font-bold text-gray-900">{Number(p.amount).toLocaleString()} ر.س</div>
                        <div className="text-sm text-gray-600">
                          {p.payment_method ? PAYMENT_METHODS[p.payment_method as keyof typeof PAYMENT_METHODS] : '—'}
                          {p.payment_date ? ` • ${p.payment_date}` : ''}
                        </div>
                      </div>
                      <button onClick={() => removePayment(p.id)} className="p-2 rounded-xl bg-red-50 text-red-600 hover:bg-red-100 transition-colors">
                        <Trash2 size={18} />
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="flex items-center justify-end gap-3">
          <button
            onClick={() => router.push('/contracts')}
            className="px-6 py-3 rounded-2xl border border-gray-200 bg-white text-gray-700 font-semibold hover:bg-gray-50 transition-colors"
          >
            إلغاء
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className={`inline-flex items-center gap-2 px-7 py-3 rounded-2xl font-semibold transition-all ${
              saving ? 'bg-gray-200 text-gray-500 cursor-not-allowed' : 'bg-gradient-to-r from-blue-600 to-blue-700 text-white hover:shadow-lg'
            }`}
          >
            {saving ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} />}
            حفظ التعديلات
          </button>
        </div>
      </div>
    </div>
  );
}
