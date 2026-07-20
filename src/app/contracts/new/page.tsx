'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  ArrowRight,
  ArrowLeft,
  CheckCircle2,
  Home,
  Building2,
  Calendar,
  DollarSign,
  Clock,
  Save,
  X,
  Users,
  UserPlus,
  Loader2,
  AlertCircle,
  Check,
  Plus
} from 'lucide-react';
import { supabase } from '../../../lib/supabaseClient';
import { Project, Unit, NewContract, ContractPayment, ContractObligation, PAYMENT_METHODS, CONTRACT_TYPES } from '../../../types';
import CustomSelect from '../../../components/CustomSelect';
import CustomCalendar from '../../../components/CustomCalendar';
import CustomProjectPicker from '../../../components/CustomProjectPicker';
import CustomUnitPicker from '../../../components/CustomUnitPicker';

interface Client {
  id: string;
  name: string;
  id_number?: string | null;
  phone?: string | null;
  email?: string | null;
}

// Toast component for notifications
const Toast = ({ message, type, onClose }: { message: string; type: 'success' | 'error' | 'info'; onClose: () => void }) => {
  useEffect(() => {
    const timer = setTimeout(onClose, 4000);
    return () => clearTimeout(timer);
  }, [onClose]);

  const bgColor = type === 'success' ? 'bg-green-500' : type === 'error' ? 'bg-red-500' : 'bg-blue-500';

  return (
    <div className={`fixed top-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-3 ${bgColor} text-white px-6 py-3 rounded-xl shadow-2xl animate-slide-in`}>
      {type === 'success' && <Check size={20} />}
      {type === 'error' && <AlertCircle size={20} />}
      {type === 'info' && <Loader2 size={20} className="animate-spin" />}
      <span className="font-medium">{message}</span>
      <button onClick={onClose} className="hover:opacity-80 transition-opacity">
        <X size={18} />
      </button>
    </div>
  );
};

export default function NewContractPage() {
  const router = useRouter();
  const getContractTypeLabel = (type: string | null | undefined) => {
    if (!type) return null;
    return (CONTRACT_TYPES as Record<string, string>)[type] || type;
  };
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);

  // State for data
  const [projects, setProjects] = useState<Project[]>([]);
  const [units, setUnits] = useState<Unit[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [contracts, setContracts] = useState<{ id: string; unit_id: string }[]>([]);
  const [filteredUnits, setFilteredUnits] = useState<Unit[]>([]);

  // Form state
  const [contractData, setContractData] = useState<NewContract>({
    project_id: '',
    unit_id: '',
    client_id: null,
    contract_date: new Date().toISOString().split('T')[0],
    total_amount: 0,
    paid_amount: 0,
    completion_period_months: 12,
    payment_grace_period_months: 60, // 60 يوم افتراضي
    status: 'draft',
    type: 'under_construction',
    agent_name: null,
    agent_id_number: null,
    agency_number: null,
    agency_date: null,
    is_legacy: false
  });

  const [baseAmount, setBaseAmount] = useState(0); // Base contract amount (without obligations)

  const [selectedClientId, setSelectedClientId] = useState<string>('');
  const [searchIdNumber, setSearchIdNumber] = useState<string>('');
  const [showAddClient, setShowAddClient] = useState(false);
  const [newClient, setNewClient] = useState({
    name: '',
    id_number: '',
    phone: '',
    email: ''
  });

  // Filter clients based on search
  const filteredClients = clients.filter(client => 
    !searchIdNumber || 
    (client.id_number && client.id_number.toLowerCase().includes(searchIdNumber.toLowerCase()))
  );

  const clientNotFound = searchIdNumber && filteredClients.length === 0;

  const [payments, setPayments] = useState<ContractPayment[]>([]);
  const [obligations, setObligations] = useState<ContractObligation[]>([]);
  const [newPayment, setNewPayment] = useState<Omit<ContractPayment, 'id' | 'created_at' | 'contract_id'>>({
    amount: 0,
    payment_date: new Date().toISOString().split('T')[0],
    notes: '',
    payment_method: null,
    transaction_number: '',
    statement: ''
  });
  const [newObligation, setNewObligation] = useState({ amount: 0, description: '', due_date: '' });

  // Show toast notification
  const showToast = (message: string, type: 'success' | 'error' | 'info') => {
    setToast({ message, type });
  };

  // Load initial data
  useEffect(() => {
    async function loadData() {
      setLoading(true);
      try {
        const [projectsRes, unitsRes, clientsRes, contractsRes] = await Promise.all([
          supabase.from('projects').select('*'),
          supabase.from('units').select('*'),
          supabase.from('clients').select('*'),
          supabase.from('contracts').select('id, unit_id, is_archived')
        ]);
        
        if (projectsRes.data) setProjects(projectsRes.data);
        if (unitsRes.data) setUnits(unitsRes.data);
        if (clientsRes.data) setClients(clientsRes.data);
        if (contractsRes.data) setContracts(contractsRes.data);
      } catch (error) {
        console.error('Error loading data:', error);
        showToast('حدث خطأ أثناء تحميل البيانات', 'error');
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  // Filter units when project changes
  useEffect(() => {
    if (contractData.project_id) {
      const unitIdsWithActiveContracts = new Set(
        contracts
          .filter((c: any) => !Boolean(c.is_archived))
          .map((c: any) => c.unit_id)
      );
      setFilteredUnits(
        units.filter(u => 
          u.project_id === contractData.project_id &&
          (
            contractData.is_legacy
              ? true
              : !unitIdsWithActiveContracts.has(u.id) && u.status === 'available'
          )
        )
      );
    } else {
      setFilteredUnits([]);
    }
  }, [contractData.project_id, contractData.is_legacy, units, contracts]);

  // Calculate total_amount automatically: base + obligations
  useEffect(() => {
    const obligationsTotal = obligations.reduce((sum, o) => sum + Number(o.amount), 0);
    const total = baseAmount + obligationsTotal;
    setContractData(prev => ({ ...prev, total_amount: total }));
  }, [baseAmount, obligations]);

  // Calculate paid_amount automatically: sum of payments
  useEffect(() => {
    const paid = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    setContractData(prev => ({ ...prev, paid_amount: paid }));
  }, [payments]);

  // Handlers
  const handleNext = () => {
    if (step === 1 && (!contractData.project_id || !contractData.unit_id)) {
      showToast('يرجى اختيار المشروع والوحدة', 'error');
      return;
    }
    if (step === 2 && !selectedClientId && !showAddClient) {
      showToast('يرجى اختيار العميل أو إضافة عميل جديد', 'error');
      return;
    }
    if (step < 5) setStep(step + 1);
  };

  const handlePrev = () => {
    if (step > 1) setStep(step - 1);
  };

  const addPayment = () => {
    if (newPayment.amount > 0) {
      setPayments([...payments, {
        id: Date.now().toString(),
        created_at: new Date().toISOString(),
        contract_id: '',
        ...newPayment
      }]);
      setNewPayment({
        amount: 0,
        payment_date: new Date().toISOString().split('T')[0],
        notes: '',
        payment_method: null,
        transaction_number: '',
        statement: ''
      });
      showToast('تم إضافة الدفعة بنجاح', 'success');
    } else {
      showToast('يرجى إدخال مبلغ الدفعة', 'error');
    }
  };

  const removePayment = (id: string) => {
    setPayments(payments.filter(p => p.id !== id));
    showToast('تم حذف الدفعة', 'info');
  };

  const addObligation = () => {
    if (newObligation.amount > 0 && newObligation.description) {
      setObligations([...obligations, {
        id: Date.now().toString(),
        created_at: new Date().toISOString(),
        contract_id: '',
        paid: false,
        ...newObligation
      }]);
      setNewObligation({ amount: 0, description: '', due_date: '' });
      showToast('تم إضافة التزام بنجاح', 'success');
    } else {
      showToast('يرجى إدخال وصف والمبلغ للالتزام', 'error');
    }
  };

  const removeObligation = (id: string) => {
    setObligations(obligations.filter(o => o.id !== id));
    showToast('تم حذف التزام', 'info');
  };

  const handleAddClient = async () => {
    const name = newClient.name.trim();
    const effectiveIdNumber = (newClient.id_number || searchIdNumber || '').trim();
    const phone = newClient.phone.trim();

    if (!name) {
      showToast('يرجى إدخال اسم العميل', 'error');
      return;
    }
    try {
      const insertPayload = {
        name,
        id_number: effectiveIdNumber || null,
        phone: phone || null
      };

      const { data: newClientData, error } = await supabase
        .from('clients')
        .insert([insertPayload])
        .select()
        .single();
      
      if (error) throw error;

      if (newClientData) {
        setClients((prev) => [newClientData, ...prev]);
        setSelectedClientId(newClientData.id);
        setContractData({
          ...contractData,
          client_id: newClientData.id,
          client_name: newClientData.name,
          client_id_number: newClientData.id_number,
          client_phone: newClientData.phone
        });
        setShowAddClient(false);
        setNewClient({ name: '', id_number: '', phone: '', email: '' });
        setSearchIdNumber('');
        showToast('تم إضافة العميل بنجاح!', 'success');
      }
    } catch (error) {
      console.error('Error adding client:', error);
      showToast('حدث خطأ أثناء إضافة العميل', 'error');
    }
  };

  const handleSelectClient = (clientId: string) => {
    const client = clients.find(c => c.id === clientId);
    setSelectedClientId(clientId);
    if (client) {
      setContractData({
        ...contractData,
        client_id: client.id,
        client_name: client.name,
        client_id_number: client.id_number,
        client_phone: client.phone
      });
    }
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      
      const selectedProject = projects.find(p => p.id === contractData.project_id);
      const selectedUnit = units.find(u => u.id === contractData.unit_id);
      
      if (!selectedProject || !selectedUnit) {
        throw new Error('لم يتم العثور على المشروع أو الوحدة المحددة');
      }

      const {
        data: { user },
      } = await supabase.auth.getUser();
      const createdById = user?.id || null;
      const normalizeUsername = (value: string | null | undefined) => {
        if (!value) return null;
        return value.split('@')[0] || value;
      };
      let createdByName = normalizeUsername(user?.email);

      if (createdById) {
        const employeesRes = await supabase.rpc('crm_list_employees');
        const employeesData = (employeesRes.data as Array<{ id: string; email: string | null }> | null) || [];
        const currentEmployee = employeesData.find(
          (employee) => employee.id === createdById
        );
        createdByName = normalizeUsername(currentEmployee?.email) || createdByName;
      }

      const { data: contract, error: contractError } = await supabase
        .from('contracts')
        .insert([{
          ...contractData,
          status: 'active',
          created_by_id: createdById,
          created_by_name: createdByName
        }])
        .select()
        .single();

      if (contractError) {
        console.error('Contract error:', contractError);
        throw new Error(`خطأ في حفظ العقد: ${contractError.message}`);
      }

      if (obligations.length > 0) {
        const obligationsToInsert = obligations.map(({ id, created_at, ...rest }) => ({
          ...rest,
          contract_id: contract.id
        }));
        const { error: obligationsError } = await supabase
          .from('contract_obligations')
          .insert(obligationsToInsert);
        if (obligationsError) {
          throw new Error(`خطأ في حفظ الالتزامات: ${obligationsError.message}`);
        }
      }

      if (payments.length > 0) {
        const paymentsToInsert = payments.map(({ id, created_at, ...rest }) => ({
          ...rest,
          contract_id: contract.id
        }));
        const { error: paymentsError } = await supabase
          .from('contract_payments')
          .insert(paymentsToInsert);
        if (paymentsError) {
          throw new Error(`خطأ في حفظ الدفعات: ${paymentsError.message}`);
        }
      }

      const remainingValue = Math.max(contractData.total_amount - contractData.paid_amount, 0);
      if (!contractData.is_legacy) {
        const { error: unitError } = await supabase
          .from('units')
          .update({
            status: 'pending_sale',
            client_name: contractData.client_name || selectedUnit.client_name || null,
            client_id_number: contractData.client_id_number || selectedUnit.client_id_number || null,
            client_phone: contractData.client_phone || selectedUnit.client_phone || null
          })
          .eq('id', contractData.unit_id);
        
        if (unitError) {
          throw new Error(`خطأ في تحديث حالة الوحدة: ${unitError.message}`);
        }

        const debtPayload: any = {
          unit_id: contractData.unit_id,
          project_id: contractData.project_id,
          project_number: selectedProject.project_number,
          project_name: selectedProject.name,
          unit_number: selectedUnit.unit_number,
          deed_number: selectedUnit.deed_number || null,
          original_client_name: contractData.client_name || selectedUnit.client_name || null,
          original_client_phone: contractData.client_phone || selectedUnit.client_phone || null,
          original_client_id: contractData.client_id_number || selectedUnit.client_id_number || null,
          current_owner_name: selectedUnit.title_deed_owner || null,
          current_owner_phone: selectedUnit.title_deed_owner_phone || null,
          contract_value: contractData.total_amount,
          paid_value: contractData.paid_amount,
          remaining_value: remainingValue,
          saved_at: new Date().toISOString(),
        };

        const { error: debtError } = await supabase
          .from('debts')
          .upsert([debtPayload], { onConflict: 'unit_id' });
        
        if (debtError) {
          throw new Error(`خطأ في حفظ المديونية: ${debtError.message}`);
        }
      }

      try {
        await supabase.from('contract_logs').insert({
          contract_id: contract.id,
          actor_id: createdById,
          actor_name: createdByName || null,
          action: 'contract_created',
          entity_type: 'contract',
          entity_id: contract.id,
          metadata: {
            operation_at: new Date().toISOString(),
            operation_source: 'contracts_new_page',
            contract_type: 'under_construction',
            contract_type_label: getContractTypeLabel('under_construction'),
            contract_status: contractData.status || 'active',
            is_legacy: Boolean(contractData.is_legacy),
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
            remaining_amount: remainingValue,
            payments_count: payments.length,
            obligations_count: obligations.length,
            unit_update_skipped: Boolean(contractData.is_legacy),
            debt_update_skipped: Boolean(contractData.is_legacy),
          }
        });
      } catch (e) {
        console.error('Error logging contract create:', e);
      }

      showToast('تم حفظ العقد بنجاح!', 'success');
      setTimeout(() => {
        router.push('/contracts');
      }, 1500);
    } catch (error: any) {
      console.error('Full error:', error);
      showToast(error.message || 'حدث خطأ غير معروف أثناء حفظ العقد', 'error');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-br from-gray-50 to-blue-50" dir="rtl">
        <div className="relative">
          <Loader2 size={64} className="animate-spin text-blue-600" />
          <div className="absolute inset-0 bg-blue-500/20 blur-xl rounded-full"></div>
        </div>
        <h2 className="mt-6 text-2xl font-bold text-gray-800">جاري تحميل البيانات...</h2>
        <p className="mt-2 text-gray-600">يرجى الانتظار قليلاً</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen pb-32" dir="rtl" style={{ background: 'var(--background)' }}>
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center gap-4 mb-8">
          <button
            onClick={() => router.back()}
            className="p-3 bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-300 hover:-translate-y-0.5"
          >
            <ArrowRight size={24} className="text-gray-700" />
          </button>
          <div>
            <h1 className="text-3xl font-extrabold text-gray-900">إضافة عقد جديد</h1>
            <p className="text-gray-600 mt-1">خطوات بسيطة لإكمال العقد</p>
          </div>
        </div>

        <div className="mb-8 rounded-2xl border border-amber-200 bg-amber-50/80 p-5">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <div className="text-lg font-extrabold text-amber-900">وضع العقد السابق</div>
              <p className="mt-1 text-sm font-medium text-amber-800">
                عند تفعيل هذا الخيار سيتم حفظ العقد كسجل تاريخي فقط دون تغيير حالة الوحدة أو بيانات العميل الحالية أو المديونية.
              </p>
            </div>
            <label className="inline-flex items-center gap-3 rounded-xl border border-amber-300 bg-white px-4 py-3 text-sm font-bold text-amber-900 shadow-sm">
              <input
                type="checkbox"
                checked={Boolean(contractData.is_legacy)}
                onChange={(e) =>
                  setContractData((prev) => ({
                    ...prev,
                    is_legacy: e.target.checked,
                  }))
                }
                className="h-4 w-4 rounded border-amber-300 text-amber-600 focus:ring-amber-500"
              />
              عقد سابق
            </label>
          </div>
          {contractData.is_legacy && (
            <div className="mt-4 rounded-xl border border-amber-200 bg-white px-4 py-3 text-sm font-semibold text-amber-900">
              سيتم عرض كل الوحدات داخل المشروع مهما كانت حالتها، ولن يتم تحديث أي بيانات تشغيلية عند الحفظ.
            </div>
          )}
        </div>

        {/* Steps Indicator */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-4">
            {[
              { step: 1, title: 'تفاصيل العقد', icon: Building2 },
              { step: 2, title: 'العميل', icon: Users },
              { step: 3, title: 'المالية', icon: DollarSign },
              { step: 4, title: 'المهل', icon: Clock },
              { step: 5, title: 'مراجعة', icon: CheckCircle2 }
            ].map((item, index, arr) => {
              const Icon = item.icon;
              const isActive = step >= item.step;
              const isCurrent = step === item.step;
              
              return (
                <React.Fragment key={item.step}>
                  <button
                    onClick={() => item.step <= step && setStep(item.step)}
                    disabled={item.step > step}
                    className={`flex flex-col items-center gap-2 transition-all duration-300 ${item.step <= step ? 'cursor-pointer hover:scale-105' : 'cursor-not-allowed opacity-50'}`}
                  >
                    <div className={`w-14 h-14 rounded-full flex items-center justify-center transition-all duration-300 ${isActive ? (isCurrent ? 'bg-gradient-to-br from-blue-500 to-blue-700 shadow-lg scale-110' : 'bg-gradient-to-br from-green-500 to-green-700') : 'bg-gray-200'}`}>
                      {step > item.step ? (
                        <Check size={28} className="text-white" />
                      ) : (
                        <Icon size={28} className="text-white" />
                      )}
                    </div>
                    <span className={`text-sm font-semibold ${isActive ? 'text-gray-900' : 'text-gray-400'}`}>
                      {item.title}
                    </span>
                  </button>

                  {index < arr.length - 1 && (
                    <div className={`flex-1 h-1 mx-4 rounded-full transition-all duration-300 ${step > item.step ? 'bg-gradient-to-l from-green-500 to-blue-500' : 'bg-gray-200'}`}></div>
                  )}
                </React.Fragment>
              );
            })}
          </div>
        </div>

        {/* Step 1: Project & Unit */}
        {step === 1 && (
          <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
            <div className="flex items-center gap-3 mb-8 pb-4 border-b border-gray-100">
              <Building2 size={32} className="text-blue-600" />
              <h2 className="text-2xl font-extrabold text-gray-900">الخطوة 1: اختيار المشروع والوحدة</h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <CustomProjectPicker
                label="اختر المشروع"
                placeholder="اختر المشروع..."
                projects={projects}
                value={contractData.project_id}
                onChange={(val) => setContractData({ ...contractData, project_id: val, unit_id: '' })}
              />

              <CustomCalendar
                label="تاريخ العقد"
                value={contractData.contract_date}
                onChange={(val) => setContractData({ ...contractData, contract_date: val })}
              />
            </div>

            <CustomUnitPicker
              label="اختر الوحدة"
              placeholder={!contractData.project_id ? "يرجى اختيار المشروع أولاً..." : "اختر الوحدة..."}
              units={filteredUnits}
              value={contractData.unit_id}
              onChange={(val) => {
                const unit = units.find(u => u.id === val);
                setContractData({
                  ...contractData,
                  unit_id: val,
                  client_name: unit?.client_name || null,
                  client_id_number: unit?.client_id_number || null,
                  client_phone: unit?.client_phone || null
                });
              }}
              disabled={!contractData.project_id}
            />
          </div>
        )}

        {/* Step 2: Client */}
        {step === 2 && (
          <>
            <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
              <div className="flex items-center gap-3 mb-8 pb-4 border-b border-gray-100">
                <Users size={32} className="text-purple-600" />
                <h2 className="text-2xl font-extrabold text-gray-900">الخطوة 2: اختيار العميل</h2>
              </div>

              <div className="space-y-6">
                {/* Search by ID Number */}
                <div className="space-y-3">
                  <label className="block text-base font-semibold text-gray-700">ابحث برقم هوية العميل</label>
                  <input
                    type="text"
                    value={searchIdNumber}
                    onChange={(e) => setSearchIdNumber(e.target.value)}
                    className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-purple-500 focus:ring-4 focus:ring-purple-100 outline-none transition-all text-lg"
                    placeholder="أدخل رقم هوية العميل..."
                  />
                </div>

                {/* Client Not Found - Add New */}
                {clientNotFound && (
                  <div className="bg-gradient-to-r from-amber-50 to-orange-50 p-8 rounded-2xl border-2 border-amber-200 space-y-6">
                    <div className="flex items-center gap-3 text-amber-800">
                      <Users size={24} />
                      <span className="text-xl font-bold">لم يتم العثور على العميل</span>
                    </div>
                    <p className="text-amber-700 text-lg">
                      لا يوجد عميل بهذا الرقم، يمكنك إضافة عميل جديد بالبيانات التالية:
                    </p>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div className="space-y-3">
                        <label className="block text-sm font-semibold text-gray-700">الاسم</label>
                        <input
                          type="text"
                          value={newClient.name}
                          onChange={(e) => setNewClient({ ...newClient, name: e.target.value })}
                          className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-amber-500 focus:ring-2 focus:ring-amber-100 outline-none transition-all"
                          placeholder="اسم العميل"
                        />
                      </div>
                      <div className="space-y-3">
                        <label className="block text-sm font-semibold text-gray-700">رقم الهوية</label>
                        <input
                          type="text"
                          value={newClient.id_number || searchIdNumber}
                          onChange={(e) => setNewClient({ ...newClient, id_number: e.target.value })}
                          className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-amber-500 focus:ring-2 focus:ring-amber-100 outline-none transition-all"
                          placeholder="رقم الهوية"
                        />
                      </div>
                      <div className="space-y-3">
                        <label className="block text-sm font-semibold text-gray-700">رقم الجوال</label>
                        <input
                          type="tel"
                          value={newClient.phone}
                          onChange={(e) => setNewClient({ ...newClient, phone: e.target.value })}
                          className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-amber-500 focus:ring-2 focus:ring-amber-100 outline-none transition-all"
                          placeholder="رقم الجوال"
                        />
                      </div>
                      <div className="space-y-3">
                        <label className="block text-sm font-semibold text-gray-700">البريد الإلكتروني</label>
                        <input
                          type="email"
                          value={newClient.email}
                          onChange={(e) => setNewClient({ ...newClient, email: e.target.value })}
                          className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-amber-500 focus:ring-2 focus:ring-amber-100 outline-none transition-all"
                          placeholder="البريد الإلكتروني"
                        />
                      </div>
                    </div>
                    <div className="flex gap-4">
                      <button
                        onClick={() => {
                          setNewClient((prev) => ({ ...prev, id_number: searchIdNumber }));
                          handleAddClient();
                        }}
                        className="px-8 py-3 bg-gradient-to-r from-amber-600 to-orange-600 text-white rounded-xl hover:shadow-lg hover:-translate-y-0.5 transition-all font-bold"
                      >
                        إضافة هذا العميل
                      </button>
                      <button
                        onClick={() => setSearchIdNumber('')}
                        className="px-8 py-3 border-2 border-gray-300 text-gray-700 rounded-xl hover:bg-gray-50 transition-all font-bold"
                      >
                        إلغاء البحث
                      </button>
                    </div>
                  </div>
                )}

                {/* Show Search Results or All Clients */}
                {!clientNotFound && (
                  <>
                    <div className="flex items-center justify-between">
                      <label className="block text-base font-semibold text-gray-700">
                        {searchIdNumber ? 'نتائج البحث' : 'اختر عميلًا من القائمة'}
                      </label>
                      {!searchIdNumber && (
                        <button
                          onClick={() => {
                            setShowAddClient(!showAddClient);
                          }}
                          className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-xl hover:shadow-lg hover:-translate-y-0.5 transition-all font-bold"
                        >
                          <UserPlus size={20} />
                          إضافة عميل جديد
                        </button>
                      )}
                    </div>

                    {/* Add Client Form (shown when not searching) */}
                    {!searchIdNumber && showAddClient && (
                      <div className="bg-gradient-to-r from-purple-50 to-indigo-50 p-8 rounded-2xl border-2 border-purple-200 space-y-6">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                          <div className="space-y-3">
                            <label className="block text-sm font-semibold text-gray-700">الاسم</label>
                            <input
                              type="text"
                              value={newClient.name}
                              onChange={(e) => setNewClient({ ...newClient, name: e.target.value })}
                              className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-purple-500 focus:ring-2 focus:ring-purple-100 outline-none transition-all"
                              placeholder="اسم العميل"
                            />
                          </div>
                          <div className="space-y-3">
                            <label className="block text-sm font-semibold text-gray-700">رقم الهوية</label>
                            <input
                              type="text"
                              value={newClient.id_number}
                              onChange={(e) => setNewClient({ ...newClient, id_number: e.target.value })}
                              className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-purple-500 focus:ring-2 focus:ring-purple-100 outline-none transition-all"
                              placeholder="رقم الهوية"
                            />
                          </div>
                          <div className="space-y-3">
                            <label className="block text-sm font-semibold text-gray-700">رقم الجوال</label>
                            <input
                              type="tel"
                              value={newClient.phone}
                              onChange={(e) => setNewClient({ ...newClient, phone: e.target.value })}
                              className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-purple-500 focus:ring-2 focus:ring-purple-100 outline-none transition-all"
                              placeholder="رقم الجوال"
                            />
                          </div>
                          <div className="space-y-3">
                            <label className="block text-sm font-semibold text-gray-700">البريد الإلكتروني</label>
                            <input
                              type="email"
                              value={newClient.email}
                              onChange={(e) => setNewClient({ ...newClient, email: e.target.value })}
                              className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-purple-500 focus:ring-2 focus:ring-purple-100 outline-none transition-all"
                              placeholder="البريد الإلكتروني"
                            />
                          </div>
                        </div>
                        <div className="flex gap-4">
                          <button
                            onClick={handleAddClient}
                            className="px-8 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-xl hover:shadow-lg hover:-translate-y-0.5 transition-all font-bold"
                          >
                            حفظ العميل
                          </button>
                          <button
                            onClick={() => setShowAddClient(false)}
                            className="px-8 py-3 border-2 border-gray-300 text-gray-700 rounded-xl hover:bg-gray-50 transition-all font-bold"
                          >
                            إلغاء
                          </button>
                        </div>
                      </div>
                    )}

                    {/* Client List */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-h-96 overflow-y-auto p-2">
                      {filteredClients.map((client) => (
                        <div
                          key={client.id}
                          onClick={() => handleSelectClient(client.id)}
                          className={`p-6 rounded-2xl border-3 cursor-pointer transition-all duration-300 hover:scale-[1.02] ${
                            selectedClientId === client.id 
                              ? 'border-purple-500 bg-gradient-to-r from-purple-50 to-indigo-50 shadow-lg' 
                              : 'border-gray-200 hover:border-purple-300 hover:bg-gray-50'
                          }`}
                        >
                          <div className="text-xl font-bold text-gray-900">{client.name}</div>
                          <div className="flex flex-wrap gap-2 mt-2">
                            {client.phone && <div className="text-sm text-gray-600 bg-white px-3 py-1 rounded-full">📱 {client.phone}</div>}
                            {client.id_number && <div className="text-sm text-gray-600 bg-white px-3 py-1 rounded-full">🆔 {client.id_number}</div>}
                          </div>
                        </div>
                      ))}
                    </div>

                    {filteredClients.length === 0 && !searchIdNumber && (
                      <div className="text-center py-12 bg-gray-50 rounded-2xl">
                        <div className="text-4xl mb-4">👤</div>
                        <p className="text-gray-500 text-lg">لا يوجد عملاء في القائمة. اضغط على "إضافة عميل جديد" لإضافة أول عميل.</p>
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Agent Information (optional) */}
            <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-6 mt-6">
              <h2 className="text-2xl font-extrabold text-gray-900 mb-6 flex items-center gap-3">
                <Users size={28} className="text-indigo-600" />
                معلومات الوكيل (اختياري)
              </h2>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <label className="block text-sm font-semibold text-gray-700">اسم الوكيل</label>
                  <input
                    type="text"
                    value={contractData.agent_name || ''}
                    onChange={(e) => setContractData({ ...contractData, agent_name: e.target.value || null })}
                    className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 outline-none transition-all"
                    placeholder="اسم الوكيل"
                  />
                </div>

                <div className="space-y-3">
                  <label className="block text-sm font-semibold text-gray-700">رقم هوية الوكيل</label>
                  <input
                    type="text"
                    value={contractData.agent_id_number || ''}
                    onChange={(e) => setContractData({ ...contractData, agent_id_number: e.target.value || null })}
                    className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 outline-none transition-all"
                    placeholder="رقم هوية الوكيل"
                  />
                </div>

                <div className="space-y-3">
                  <label className="block text-sm font-semibold text-gray-700">رقم الوكالة</label>
                  <input
                    type="text"
                    value={contractData.agency_number || ''}
                    onChange={(e) => setContractData({ ...contractData, agency_number: e.target.value || null })}
                    className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 outline-none transition-all"
                    placeholder="رقم الوكالة"
                  />
                </div>

                <div className="space-y-3">
                  <label className="block text-sm font-semibold text-gray-700">تاريخ الوكالة</label>
                  <input
                    type="date"
                    value={contractData.agency_date || ''}
                    onChange={(e) => setContractData({ ...contractData, agency_date: e.target.value || null })}
                    className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 outline-none transition-all"
                  />
                </div>
              </div>
            </div>
          </>
        )}

        {/* Step 3: Financial */}
        {step === 3 && (
          <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
            <div className="flex items-center gap-3 mb-8 pb-4 border-b border-gray-100">
              <DollarSign size={32} className="text-green-600" />
              <h2 className="text-2xl font-extrabold text-gray-900">الخطوة 3: التفاصيل المالية</h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
              <div className="space-y-3">
                <label className="block text-base font-semibold text-gray-700">قيمة العقد الأساسية</label>
                <input
                  type="number"
                  value={baseAmount}
                  onChange={(e) => setBaseAmount(Number(e.target.value))}
                  className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-green-500 focus:ring-4 focus:ring-green-100 outline-none transition-all text-2xl font-mono"
                  placeholder="0"
                />
              </div>
              <div className="space-y-3">
                <label className="block text-base font-semibold text-gray-700">المبلغ المتبقي</label>
                <div className="w-full px-5 py-4 rounded-2xl border-2 border-blue-200 bg-gradient-to-r from-blue-50 to-indigo-50 text-2xl font-mono font-extrabold text-blue-700">
                  {(contractData.total_amount - contractData.paid_amount).toLocaleString()} ر.س
                </div>
              </div>
            </div>

            {/* Obligations */}
            <div className="pt-6 border-t border-gray-100">
              <h3 className="text-xl font-extrabold text-gray-900 mb-6 flex items-center gap-2">
                📋 المبالغ المطلوبة (الالتزامات)
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                <input
                  type="text"
                  placeholder="الوصف"
                  value={newObligation.description}
                  onChange={(e) => setNewObligation({ ...newObligation, description: e.target.value })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                />
                <input
                  type="number"
                  placeholder="المبلغ"
                  value={newObligation.amount || ''}
                  onChange={(e) => setNewObligation({ ...newObligation, amount: Number(e.target.value) })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                />
                <input
                  type="date"
                  value={newObligation.due_date}
                  onChange={(e) => setNewObligation({ ...newObligation, due_date: e.target.value })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                />
              </div>
              <button
                onClick={addObligation}
                className="w-full md:w-auto px-8 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl hover:shadow-lg hover:-translate-y-0.5 transition-all font-bold flex items-center gap-2"
              >
                <Plus size={20} />
                إضافة التزام
              </button>

              {obligations.length > 0 && (
                <div className="mt-6 space-y-3">
                  {obligations.map((o) => (
                    <div key={o.id} className="flex items-center justify-between p-5 bg-gradient-to-r from-gray-50 to-slate-50 rounded-2xl border border-gray-200">
                      <div className="flex items-center gap-3">
                        <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
                        <span className="font-bold text-gray-900 text-lg">{o.description}</span>
                        <span className="text-gray-500">-</span>
                        <span className="text-gray-700 font-mono font-bold text-xl">{o.amount.toLocaleString()} ر.س</span>
                      </div>
                      <button
                        onClick={() => removeObligation(o.id)}
                        className="p-2 text-red-500 hover:bg-red-100 rounded-xl transition-all"
                      >
                        <X size={24} />
                      </button>
                    </div>
                  ))}
                  <div className="flex items-center justify-between p-5 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-2xl border border-blue-200 mt-2">
                    <span className="font-extrabold text-blue-900 text-xl">إجمالي الالتزامات:</span>
                    <span className="font-extrabold text-blue-700 font-mono text-2xl">
                      {obligations.reduce((sum, o) => sum + Number(o.amount), 0).toLocaleString()} ر.س
                    </span>
                  </div>
                  <div className="flex items-center justify-between p-5 bg-gradient-to-r from-green-50 to-emerald-50 rounded-2xl border border-green-200">
                    <span className="font-extrabold text-green-900 text-xl">قيمة العقد الكلية (أساسي + التزامات):</span>
                    <span className="font-extrabold text-green-700 font-mono text-2xl">
                      {contractData.total_amount.toLocaleString()} ر.س
                    </span>
                  </div>
                </div>
              )}
            </div>

            {/* Payments */}
            <div className="pt-6 border-t border-gray-100">
              <h3 className="text-xl font-extrabold text-gray-900 mb-6 flex items-center gap-2">
                💰 الدفعات
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
                <input
                  type="number"
                  placeholder="المبلغ"
                  value={newPayment.amount || ''}
                  onChange={(e) => setNewPayment({ ...newPayment, amount: Number(e.target.value) })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-100 outline-none transition-all"
                />
                <input
                  type="date"
                  value={newPayment.payment_date}
                  onChange={(e) => setNewPayment({ ...newPayment, payment_date: e.target.value })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-100 outline-none transition-all"
                />
                <select
                  value={newPayment.payment_method || ''}
                  onChange={(e) => setNewPayment({ ...newPayment, payment_method: e.target.value as keyof typeof PAYMENT_METHODS || null })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-100 outline-none transition-all"
                >
                  <option value="">اختر نوع العملية</option>
                  {Object.entries(PAYMENT_METHODS).map(([key, label]) => (
                    <option key={key} value={key}>{label}</option>
                  ))}
                </select>
                <input
                  type="text"
                  placeholder="رقم العملية"
                  value={newPayment.transaction_number || ''}
                  onChange={(e) => setNewPayment({ ...newPayment, transaction_number: e.target.value })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-100 outline-none transition-all"
                />
                <input
                  type="text"
                  placeholder="البيان"
                  value={newPayment.statement || ''}
                  onChange={(e) => setNewPayment({ ...newPayment, statement: e.target.value })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-100 outline-none transition-all"
                />
                <input
                  type="text"
                  placeholder="ملاحظات"
                  value={newPayment.notes || ''}
                  onChange={(e) => setNewPayment({ ...newPayment, notes: e.target.value })}
                  className="px-4 py-3 rounded-xl border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-100 outline-none transition-all"
                />
              </div>
              <button
                onClick={addPayment}
                className="w-full md:w-auto px-8 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white rounded-xl hover:shadow-lg hover:-translate-y-0.5 transition-all font-bold flex items-center gap-2"
              >
                <Plus size={20} />
                إضافة دفعة
              </button>

              {payments.length > 0 && (
                <div className="mt-6 space-y-3">
                  {payments.map((p) => (
                    <div key={p.id} className="p-5 bg-gradient-to-r from-green-50 to-teal-50 rounded-2xl border border-green-200">
                      <div className="flex items-center gap-3 w-full">
                        <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                        <span className="font-bold text-green-900 font-mono text-xl">{p.amount.toLocaleString()} ر.س</span>
                        <span className="text-gray-400">•</span>
                        <span className="text-gray-700 font-medium">{p.payment_date}</span>
                        {p.payment_method && <span className="text-green-700 font-bold bg-white px-3 py-1 rounded-full">{PAYMENT_METHODS[p.payment_method]}</span>}
                        <div className="flex-1"></div>
                        <button
                          onClick={() => removePayment(p.id)}
                          className="p-2 text-red-500 hover:bg-red-100 rounded-xl transition-all"
                        >
                          <X size={24} />
                        </button>
                      </div>
                      <div className="flex flex-wrap gap-2 mt-3 text-sm text-gray-600">
                        {p.transaction_number && <span className="bg-white px-3 py-1 rounded-full">رقم العملية: {p.transaction_number}</span>}
                        {p.statement && <span className="bg-white px-3 py-1 rounded-full">البيان: {p.statement}</span>}
                        {p.notes && <span className="bg-white px-3 py-1 rounded-full">ملاحظات: {p.notes}</span>}
                      </div>
                    </div>
                  ))}
                  <div className="flex items-center justify-between p-5 bg-gradient-to-r from-green-100 to-emerald-100 rounded-2xl border border-green-300 mt-2">
                    <span className="font-extrabold text-green-900 text-xl">إجمالي المدفوعات:</span>
                    <span className="font-extrabold text-green-700 font-mono text-2xl">
                      {contractData.paid_amount.toLocaleString()} ر.س
                    </span>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Step 4: Timing */}
        {step === 4 && (
          <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
            <div className="flex items-center gap-3 mb-8 pb-4 border-b border-gray-100">
              <Clock size={32} className="text-yellow-600" />
              <h2 className="text-2xl font-extrabold text-gray-900">الخطوة 4: المهل والزمن</h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="space-y-3">
                <label className="block text-base font-semibold text-gray-700">مهلة الإنجاز (بالشهور)</label>
                <input
                  type="number"
                  value={contractData.completion_period_months}
                  onChange={(e) => setContractData({ ...contractData, completion_period_months: Number(e.target.value) })}
                  className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100 outline-none transition-all text-lg"
                />
              </div>

              <div className="space-y-3">
                <label className="block text-base font-semibold text-gray-700">مهلة السداد (بالأيام)</label>
                <input
                  type="number"
                  value={contractData.payment_grace_period_months || ''}
                  onChange={(e) => setContractData({ ...contractData, payment_grace_period_months: Number(e.target.value) || null })}
                  className="w-full px-5 py-4 rounded-2xl border-2 border-gray-200 focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100 outline-none transition-all text-lg"
                  placeholder="اختياري"
                />
              </div>
            </div>
          </div>
        )}

        {/* Step 5: Review */}
        {step === 5 && (
          <div className="bg-white rounded-3xl shadow-xl border border-gray-100 p-8 space-y-8">
            <div className="flex items-center gap-3 mb-8 pb-4 border-b border-gray-100">
              <CheckCircle2 size={32} className="text-emerald-600" />
              <h2 className="text-2xl font-extrabold text-gray-900">الخطوة 5: مراجعة العقد</h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="space-y-5">
                <h3 className="text-xl font-extrabold text-gray-800 border-b pb-4 border-gray-100">تفاصيل أساسية</h3>
                <div className="space-y-4">
                  <div className="flex justify-between p-3 bg-gray-50 rounded-xl">
                    <span className="text-gray-600 font-medium">المشروع:</span>
                    <span className="font-bold text-gray-900">{projects.find(p => p.id === contractData.project_id)?.name}</span>
                  </div>
                  <div className="flex justify-between p-3 bg-gray-50 rounded-xl">
                    <span className="text-gray-600 font-medium">الوحدة:</span>
                    <span className="font-bold text-gray-900">{units.find(u => u.id === contractData.unit_id)?.unit_number}</span>
                  </div>
                  <div className="flex justify-between p-3 bg-gray-50 rounded-xl">
                    <span className="text-gray-600 font-medium">تاريخ العقد:</span>
                    <span className="font-bold text-gray-900">{contractData.contract_date}</span>
                  </div>
                  {contractData.client_name && (
                    <div className="flex justify-between p-3 bg-gray-50 rounded-xl">
                      <span className="text-gray-600 font-medium">اسم العميل:</span>
                      <span className="font-bold text-gray-900">{contractData.client_name}</span>
                    </div>
                  )}
                </div>
              </div>

              <div className="space-y-5">
                <h3 className="text-xl font-extrabold text-gray-800 border-b pb-4 border-gray-100">المالية</h3>
                <div className="space-y-4">
                  <div className="flex justify-between p-3 bg-blue-50 rounded-xl border border-blue-100">
                    <span className="text-blue-700 font-bold">قيمة العقد:</span>
                    <span className="font-mono font-extrabold text-blue-800 text-xl">{contractData.total_amount.toLocaleString()} ر.س</span>
                  </div>
                  <div className="flex justify-between p-3 bg-green-50 rounded-xl border border-green-100">
                    <span className="text-green-700 font-bold">المدفوع:</span>
                    <span className="font-mono font-extrabold text-green-800 text-xl">{contractData.paid_amount.toLocaleString()} ر.س</span>
                  </div>
                  <div className="flex justify-between p-3 bg-red-50 rounded-xl border border-red-100 pt-4 border-t border-gray-200 mt-4">
                    <span className="text-red-700 font-bold text-lg">المتبقي:</span>
                    <span className="font-mono font-extrabold text-red-800 text-2xl">
                      {(contractData.total_amount - contractData.paid_amount).toLocaleString()} ر.س
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {obligations.length > 0 && (
              <div className="pt-6 border-t border-gray-100">
                <h3 className="text-xl font-extrabold text-gray-800 mb-6">الالتزامات المالية</h3>
                <div className="space-y-3">
                  {obligations.map(o => (
                    <div key={o.id} className="flex justify-between p-4 bg-gray-50 rounded-xl">
                      <span className="font-medium text-gray-900">{o.description}</span>
                      <span className="font-mono font-bold text-gray-700">{o.amount.toLocaleString()} ر.س</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {payments.length > 0 && (
              <div className="pt-6 border-t border-gray-100">
                <h3 className="text-xl font-extrabold text-gray-800 mb-6">الدفعات</h3>
                <div className="space-y-3">
                  {payments.map(p => (
                    <div key={p.id} className="flex justify-between p-4 bg-green-50 rounded-xl border border-green-100">
                      <span className="font-medium text-gray-900">{p.payment_date}</span>
                      <span className="font-mono font-extrabold text-green-700">{p.amount.toLocaleString()} ر.س</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="pt-6 border-t border-gray-100">
              <h3 className="text-xl font-extrabold text-gray-800 mb-6">الزمن والمهل</h3>
              <div className="space-y-3">
                <div className="flex justify-between p-4 bg-yellow-50 rounded-xl border border-yellow-100">
                  <span className="text-yellow-700 font-bold">مهلة الإنجاز:</span>
                  <span className="font-bold text-yellow-800">{contractData.completion_period_months} شهر</span>
                </div>
                {contractData.payment_grace_period_months && (
                  <div className="flex justify-between p-4 bg-orange-50 rounded-xl border border-orange-100">
                    <span className="text-orange-700 font-bold">مهلة السداد:</span>
                    <span className="font-bold text-orange-800">{contractData.payment_grace_period_months} يوم</span>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Navigation */}
      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 p-6 shadow-[0_-8px_30px_rgba(0,0,0,0.1)] z-40">
        <div className="max-w-5xl mx-auto flex gap-4">
          {step > 1 && (
            <button
              onClick={handlePrev}
              className="px-8 py-4 rounded-2xl border-2 border-gray-300 text-gray-700 font-extrabold hover:bg-gray-50 hover:border-gray-400 transition-all flex items-center gap-3 text-lg"
            >
              <ArrowRight size={24} />
              السابق
            </button>
          )}
          <div className="flex-1"></div>
          {step < 5 ? (
            <button
              onClick={handleNext}
              className="px-10 py-4 rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-extrabold hover:shadow-xl hover:-translate-y-0.5 transition-all flex items-center gap-3 text-lg"
            >
              التالي
              <ArrowLeft size={24} />
            </button>
          ) : (
            <button
              onClick={handleSave}
              disabled={saving}
              className="px-10 py-4 rounded-2xl bg-gradient-to-r from-emerald-600 to-green-600 text-white font-extrabold hover:shadow-xl hover:-translate-y-0.5 disabled:opacity-60 disabled:cursor-not-allowed disabled:hover:translate-y-0 transition-all flex items-center gap-3 text-lg"
            >
              {saving ? (
                <>
                  <Loader2 size={24} className="animate-spin" />
                  جاري الحفظ...
                </>
              ) : (
                <>
                  <Save size={24} />
                  حفظ العقد
                </>
              )}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
