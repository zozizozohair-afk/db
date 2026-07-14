'use client';

import React, { Suspense, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { ArrowLeft, CheckCircle2, FileSignature, Loader2, Save, Search, UserPlus } from 'lucide-react';
import { supabase } from '../../../../lib/supabaseClient';
import { CONTRACT_TYPES, FullContract } from '../../../../types';

type WaiverClient = {
  id: string;
  name: string;
  id_number: string | null;
  phone: string | null;
};

const getContractTypeLabel = (type: string | null | undefined) => {
  if (!type) return null;
  return (CONTRACT_TYPES as Record<string, string>)[type] || type;
};

function NewWaiverPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const editingWaiverId = searchParams.get('edit');
  const [isAdmin, setIsAdmin] = useState(false);
  const [accessReady, setAccessReady] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [contracts, setContracts] = useState<FullContract[]>([]);
  const [editingWaiverContract, setEditingWaiverContract] = useState<FullContract | null>(null);
  const [editingSourceContractId, setEditingSourceContractId] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [selectedContractId, setSelectedContractId] = useState<string | null>(null);

  const [waiverDate, setWaiverDate] = useState(() => new Date().toISOString().slice(0, 10));

  const [newOwnerIdNumber, setNewOwnerIdNumber] = useState('');
  const [newOwnerName, setNewOwnerName] = useState('');
  const [newOwnerPhone, setNewOwnerPhone] = useState('');
  const [clientSuggestions, setClientSuggestions] = useState<WaiverClient[]>([]);
  const [selectedNewOwnerClient, setSelectedNewOwnerClient] = useState<WaiverClient | null>(null);
  const [searchingClients, setSearchingClients] = useState(false);

  const normalizeUsername = (value: string | null | undefined) => {
    if (!value) return '';
    return value.split('@')[0] || value;
  };

  const getActorInfo = async () => {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    const actorId = user?.id || null;
    const actorName = normalizeUsername(user?.email);
    return { actorId, actorName };
  };

  const logContractEvent = async (payload: {
    contract_id: string | null;
    action: string;
    entity_type?: string;
    entity_id?: string | null;
    metadata?: Record<string, any> | null;
  }) => {
    try {
      const { actorId, actorName } = await getActorInfo();
      const nextMetadata = { ...(payload.metadata || {}) } as Record<string, any>;
      const contractType = String(nextMetadata.contract_type || nextMetadata.type || '').trim();
      nextMetadata.operation_at ??= new Date().toISOString();
      nextMetadata.operation_source ??= 'contracts_waiver_page';
      nextMetadata.contract_id ??= payload.contract_id;
      nextMetadata.entity_type ??= payload.entity_type || 'contract';
      nextMetadata.entity_id ??= payload.entity_id || null;
      if (contractType) {
        nextMetadata.contract_type = contractType;
        nextMetadata.contract_type_label ??= getContractTypeLabel(contractType);
      }
      await supabase.from('contract_logs').insert({
        contract_id: payload.contract_id,
        actor_id: actorId,
        actor_name: actorName || null,
        action: payload.action,
        entity_type: payload.entity_type || 'contract',
        entity_id: payload.entity_id || null,
        metadata: nextMetadata,
      });
    } catch {}
  };

  useEffect(() => {
    const checkAccess = async () => {
      if (!editingWaiverId) {
        setAccessReady(true);
        return;
      }

      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!user) {
        alert('غير مصرح');
        router.replace('/contracts');
        setAccessReady(true);
        return;
      }

      const { data: profile, error } = await supabase
        .from('employee_profiles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();

      if (error) {
        alert('غير مصرح');
        router.replace('/contracts');
        setAccessReady(true);
        return;
      }

      const nextIsAdmin = String(profile?.role || 'viewer') === 'admin';
      setIsAdmin(nextIsAdmin);
      setAccessReady(true);

      if (!nextIsAdmin) {
        alert('التعديل متاح للأدمن فقط');
        router.replace('/contracts');
      }
    };

    checkAccess();
  }, [editingWaiverId, router]);

  useEffect(() => {
    if (!accessReady) return;
    if (editingWaiverId && !isAdmin) return;

    const load = async () => {
      try {
        setLoading(true);
        const res = await supabase
          .from('contracts')
          .select(
            `
            id,
            created_at,
            project_id,
            unit_id,
            client_id,
            contract_date,
            total_amount,
            paid_amount,
            completion_period_months,
            payment_grace_period_months,
            status,
            type,
            resale_contract_id,
            is_archived,
            is_waived,
            project:projects(*),
            unit:units(*),
            client:clients!contracts_client_id_fkey(id,name,id_number,phone)
          `
          )
          .eq('type', 'under_construction')
          .order('created_at', { ascending: false });

        if (res.error) throw res.error;
        setContracts((res.data as any[]) as any);

        if (editingWaiverId) {
          const waiverRes = await supabase
            .from('contracts')
            .select('*')
            .eq('id', editingWaiverId)
            .eq('type', 'waiver')
            .single();
          if (waiverRes.error) throw waiverRes.error;
          const waiverData = (waiverRes.data || null) as any;
          setEditingWaiverContract(waiverData);
          const sourceId = String(waiverData?.source_contract_id || '').trim() || null;
          setEditingSourceContractId(sourceId);
          setSelectedContractId(sourceId);
          setWaiverDate(String(waiverData?.contract_date || '').trim() || new Date().toISOString().slice(0, 10));
          setNewOwnerIdNumber(String(waiverData?.waived_to_client_id_number || '').trim());
          setNewOwnerName(String(waiverData?.waived_to_client_name || '').trim());
          setNewOwnerPhone(String(waiverData?.waived_to_client_phone || '').trim());
          if (waiverData?.waived_to_client_id || waiverData?.waived_to_client_name) {
            setSelectedNewOwnerClient({
              id: String(waiverData?.waived_to_client_id || ''),
              name: String(waiverData?.waived_to_client_name || ''),
              id_number: waiverData?.waived_to_client_id_number || null,
              phone: waiverData?.waived_to_client_phone || null,
            });
          }
        } else {
          setEditingWaiverContract(null);
          setEditingSourceContractId(null);
        }
      } catch (error: any) {
        alert('حدث خطأ أثناء تحميل العقود: ' + (error?.message || ''));
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [editingWaiverId, accessReady, isAdmin]);

  useEffect(() => {
    const run = async () => {
      const q = String(newOwnerIdNumber || '').trim();
      setSelectedNewOwnerClient(null);
      setClientSuggestions([]);
      if (!q || q.length < 3) return;

      try {
        setSearchingClients(true);
        const res = await supabase
          .from('clients')
          .select('id,name,id_number,phone')
          .ilike('id_number', `${q}%`)
          .limit(6);
        if (res.error) throw res.error;
        setClientSuggestions(((res.data as any[]) || []) as any);
      } catch {
        setClientSuggestions([]);
      } finally {
        setSearchingClients(false);
      }
    };
    run();
  }, [newOwnerIdNumber]);

  const eligibleContracts = useMemo(() => {
    const base = contracts.filter((c) => {
      if (Boolean((c as any).is_archived)) return false;
      if (Boolean((c as any).is_waived) && c.id !== editingSourceContractId) return false;
      if (Boolean((c as any).resale_contract_id)) return false;
      const total = Number(c.total_amount || 0);
      const paid = Number(c.paid_amount || 0);
      if (!total) return false;
      return paid / total >= 0.7;
    });

    const q = search.trim();
    if (!q) return base;

    return base.filter((c) => {
      const projectNo = c.project?.project_number || '';
      const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '';
      const code = `${projectNo}-${unitNo}`;
      const clientName = c.client?.name || c.client_name || '';
      return code.includes(q) || projectNo.includes(q) || unitNo.includes(q) || clientName.includes(q);
    });
  }, [contracts, search, editingSourceContractId]);

  const selectedContract = useMemo(
    () => (selectedContractId ? contracts.find((c) => c.id === selectedContractId) || null : null),
    [contracts, selectedContractId]
  );

  const canCreateNewClient = useMemo(() => {
    const q = String(newOwnerIdNumber || '').trim();
    if (!q) return false;
    if (selectedNewOwnerClient) return false;
    return Boolean(newOwnerName.trim());
  }, [newOwnerIdNumber, newOwnerName, selectedNewOwnerClient]);

  const ensureNewOwnerClient = async () => {
    if (selectedNewOwnerClient) return selectedNewOwnerClient;

    const idNumber = String(newOwnerIdNumber || '').trim();
    if (!idNumber) throw new Error('يرجى إدخال هوية المتنازل له');

    const existing = await supabase.from('clients').select('id,name,id_number,phone').eq('id_number', idNumber).maybeSingle();
    if (existing.error) throw existing.error;
    if (existing.data?.id) return existing.data as any;

    const name = String(newOwnerName || '').trim();
    if (!name) throw new Error('لا يوجد عميل بهذه الهوية. أدخل اسم المتنازل له لإضافته.');

    const { data: created, error: createError } = await supabase
      .from('clients')
      .insert({
        name,
        id_number: idNumber,
        phone: String(newOwnerPhone || '').trim() || null,
      })
      .select('id,name,id_number,phone')
      .single();
    if (createError) throw createError;
    if (!created?.id) throw new Error('تعذر إنشاء العميل');
    return created as any;
  };

  const saveWaiver = async () => {
    if (editingWaiverId && !isAdmin) {
      alert('غير مصرح');
      return;
    }
    if (!selectedContract) {
      alert('يرجى اختيار عقد تحت الإنشاء المطابق للشروط أولاً');
      return;
    }
    if (editingWaiverId && editingSourceContractId && selectedContract.id !== editingSourceContractId) {
      alert('لا يمكن تغيير العقد المصدر أثناء تعديل التنازل');
      return;
    }
    const idNumber = String(newOwnerIdNumber || '').trim();
    if (!idNumber) {
      alert('يرجى إدخال هوية المتنازل له');
      return;
    }
    if (!waiverDate) {
      alert('يرجى اختيار تاريخ التنازل');
      return;
    }

    const total = Number(selectedContract.total_amount || 0);
    const paid = Number(selectedContract.paid_amount || 0);
    if (!total || paid / total < 0.7) {
      alert('لا يمكن إنشاء التنازل إلا إذا كان العقد مسددًا بنسبة 70% على الأقل');
      return;
    }
    if (Boolean((selectedContract as any).resale_contract_id)) {
      alert('لا يمكن إنشاء تنازل لعقد عليه إعادة بيع');
      return;
    }
    if (Boolean((selectedContract as any).is_archived)) {
      alert('لا يمكن إنشاء تنازل لعقد مؤرشف');
      return;
    }

    const ok = window.confirm('هل تريد حفظ التنازل وتحديث العميل داخل العقد الأصلي؟');
    if (!ok) return;

    try {
      setSaving(true);
      const { actorId, actorName } = await getActorInfo();
      const newOwner = await ensureNewOwnerClient();
      const waivedAtIso = new Date(`${waiverDate}T00:00:00`).toISOString();

      const prevClientId = editingWaiverContract
        ? ((editingWaiverContract as any).waived_previous_client_id || null)
        : (selectedContract.client_id || null);
      const prevClientName = editingWaiverContract
        ? ((editingWaiverContract as any).waived_previous_client_name || null)
        : (selectedContract.client?.name || selectedContract.client_name || null);
      const prevClientIdNumber = editingWaiverContract
        ? ((editingWaiverContract as any).waived_previous_client_id_number || null)
        : (selectedContract.client?.id_number || selectedContract.client_id_number || null);
      const prevClientPhone = editingWaiverContract
        ? ((editingWaiverContract as any).waived_previous_client_phone || null)
        : (selectedContract.client?.phone || selectedContract.client_phone || null);

      const waiverContractPayload: any = {
        project_id: selectedContract.project_id,
        unit_id: selectedContract.unit_id,
        client_id: prevClientId,
        contract_date: waiverDate,
        status: 'active',
        type: 'waiver',
        total_amount: 0,
        paid_amount: 0,
        completion_period_months: selectedContract.completion_period_months || 12,
        payment_grace_period_months: selectedContract.payment_grace_period_months ?? null,
        client_name: prevClientName,
        client_id_number: prevClientIdNumber,
        client_phone: prevClientPhone,
        source_contract_id: selectedContract.id,
        waived_previous_client_id: prevClientId,
        waived_previous_client_name: prevClientName,
        waived_previous_client_id_number: prevClientIdNumber,
        waived_previous_client_phone: prevClientPhone,
        waived_to_client_id: newOwner.id,
        waived_to_client_name: newOwner.name,
        waived_to_client_id_number: newOwner.id_number,
        waived_to_client_phone: newOwner.phone,
        created_by_id: actorId,
        created_by_name: actorName || null,
      };

      let waiverContractId = editingWaiverId;
      if (editingWaiverId) {
        const { error: waiverUpdateError } = await supabase
          .from('contracts')
          .update(waiverContractPayload)
          .eq('id', editingWaiverId);
        if (waiverUpdateError) throw waiverUpdateError;
      } else {
        const { data: waiverContract, error: waiverInsertError } = await supabase
          .from('contracts')
          .insert(waiverContractPayload)
          .select('id')
          .single();
        if (waiverInsertError) throw waiverInsertError;
        if (!waiverContract?.id) throw new Error('تعذر إنشاء عقد التنازل');
        waiverContractId = waiverContract.id;
      }

      const baseUpdatePayload: any = {
        is_waived: true,
        waived_at: waivedAtIso,
        waived_previous_client_id: prevClientId,
        waived_previous_client_name: prevClientName,
        waived_previous_client_id_number: prevClientIdNumber,
        waived_previous_client_phone: prevClientPhone,
        waived_to_client_id: newOwner.id,
        waived_to_client_name: newOwner.name,
        waived_to_client_id_number: newOwner.id_number,
        waived_to_client_phone: newOwner.phone,
        client_id: newOwner.id,
        client_name: newOwner.name,
        client_id_number: newOwner.id_number,
        client_phone: newOwner.phone,
      };

      const { error: baseUpdateError } = await supabase
        .from('contracts')
        .update(baseUpdatePayload)
        .eq('id', selectedContract.id);
      if (baseUpdateError) throw baseUpdateError;

      const { error: unitUpdateError } = await supabase
        .from('units')
        .update({
          client_name: newOwner.name,
          client_id_number: newOwner.id_number,
          client_phone: newOwner.phone,
        })
        .eq('id', selectedContract.unit_id);
      if (unitUpdateError) throw unitUpdateError;

      const { error: debtUpdateError } = await supabase
        .from('debts')
        .update({
          original_client_name: newOwner.name,
          original_client_phone: newOwner.phone,
          original_client_id: newOwner.id_number,
        })
        .eq('unit_id', selectedContract.unit_id);
      if (debtUpdateError) throw debtUpdateError;

      await logContractEvent({
        contract_id: waiverContractId,
        action: editingWaiverId ? 'contract_updated' : 'contract_created',
        entity_type: 'contract',
        entity_id: waiverContractId,
        metadata: {
          contract_type: 'waiver',
          mode: editingWaiverId ? 'edit' : 'create',
          contract_date: waivedAtIso.split('T')[0] || null,
          source_contract_id: selectedContract.id,
          source_contract_type: selectedContract.type,
          source_contract_type_label: getContractTypeLabel(selectedContract.type),
          project_id: selectedContract.project_id,
          project_number: selectedContract.project?.project_number || null,
          project_name: selectedContract.project?.name || null,
          unit_id: selectedContract.unit_id,
          unit_number: selectedContract.unit?.unit_number ?? null,
          waived_previous_client_id: prevClientId,
          waived_previous_client_name: prevClientName,
          waived_previous_client_phone: prevClientPhone,
          waived_previous_client_id_number: prevClientIdNumber,
          waived_to_client_id: newOwner.id,
          waived_to_client_name: newOwner.name,
          waived_to_client_phone: newOwner.phone,
          waived_to_client_id_number: newOwner.id_number,
          waived_at: waivedAtIso,
        },
      });

      await logContractEvent({
        contract_id: selectedContract.id,
        action: 'contract_updated',
        entity_type: 'contract',
        entity_id: selectedContract.id,
        metadata: {
          contract_type: selectedContract.type,
          is_waived: true,
          waiver_contract_id: waiverContractId,
          waived_previous_client_id: prevClientId,
          waived_previous_client_name: prevClientName,
          waived_to_client_id: newOwner.id,
          waived_to_client_name: newOwner.name,
          waived_at: waivedAtIso,
        },
      });

      alert(editingWaiverId ? 'تم تعديل التنازل وتحديث بياناته' : 'تم حفظ التنازل وتحديث العميل داخل العقد الأصلي');
      router.push('/contracts');
    } catch (error: any) {
      alert('حدث خطأ أثناء حفظ التنازل: ' + (error?.message || ''));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <div className="flex items-center justify-between gap-4 mb-8">
          <div className="flex items-center gap-3">
            <Link
              href="/contracts"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white border border-gray-200 text-gray-700 font-bold hover:bg-gray-50"
            >
              <ArrowLeft size={18} />
              رجوع
            </Link>
            <div className="h-12 w-12 rounded-2xl bg-gradient-to-br from-rose-600 to-pink-600 text-white flex items-center justify-center shadow-md">
              <FileSignature size={24} />
            </div>
            <div>
              <h1 className="text-2xl font-extrabold text-gray-900">{editingWaiverId ? 'تعديل تنازل' : 'إضافة تنازل'}</h1>
              <p className="text-sm text-gray-600 mt-1">يشترط: عقد تحت الإنشاء بدون إعادة بيع + مدفوع 70% فأكثر</p>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-10 flex items-center justify-center gap-3 text-gray-700 font-bold">
            <Loader2 className="animate-spin" size={20} />
            جارٍ تحميل البيانات...
          </div>
        ) : (
          <div className="grid grid-cols-1 xl:grid-cols-[1.3fr_0.7fr] gap-6">
            <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
              <div className="flex items-center justify-between gap-4 mb-5">
                <div>
                  <h2 className="text-lg font-extrabold text-gray-900">1) اختر عقد تحت الإنشاء</h2>
                  <p className="text-sm text-gray-500 mt-1">العقود المعروضة هنا مطابقة للشروط تلقائيًا</p>
                </div>
                <div className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-gray-50 border border-gray-200">
                  <Search size={18} className="text-gray-500" />
                  <input
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="بحث بالكود (المشروع-الوحدة) أو اسم العميل..."
                    className="bg-transparent outline-none text-sm font-bold text-gray-800 w-72 max-w-full"
                  />
                </div>
              </div>

              {eligibleContracts.length === 0 ? (
                <div className="p-10 rounded-3xl bg-gray-50 border border-gray-100 text-center">
                  <div className="text-gray-900 font-extrabold mb-2">لا توجد عقود مطابقة للشروط</div>
                  <div className="text-sm text-gray-600">تأكد أن العقد تحت الإنشاء غير مرتبط بإعادة بيع وأن المدفوع ≥ 70%.</div>
                </div>
              ) : (
                <div className="space-y-3 max-h-[560px] overflow-y-auto pr-1">
                  {eligibleContracts.map((c) => {
                    const projectNo = c.project?.project_number || '—';
                    const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '—';
                    const code = `${projectNo}-${unitNo}`;
                    const clientName = c.client?.name || c.client_name || '—';
                    const total = Number(c.total_amount || 0);
                    const paid = Number(c.paid_amount || 0);
                    const pct = total ? Math.round((paid / total) * 100) : 0;
                    const active = selectedContractId === c.id;

                    return (
                      <button
                        key={c.id}
                        type="button"
                        onClick={() => setSelectedContractId(c.id)}
                        className={`w-full text-right p-4 rounded-3xl border transition-all ${
                          active ? 'border-rose-300 bg-rose-50 shadow-sm' : 'border-gray-100 bg-white hover:bg-gray-50'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-4">
                          <div>
                            <div className="text-sm font-extrabold text-gray-900">{clientName}</div>
                            <div className="text-xs text-gray-600 mt-1">
                              الكود: {code} • تاريخ العقد: {c.contract_date || '—'}
                            </div>
                          </div>
                          <div className="text-left">
                            <div className="text-xs text-gray-600 font-bold">نسبة السداد</div>
                            <div className="text-lg font-extrabold text-rose-700">{pct}%</div>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            <div className="space-y-6">
              <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
                <h2 className="text-lg font-extrabold text-gray-900 mb-4">2) بيانات المتنازل له</h2>

                <div className="space-y-2">
                  <div className="text-sm font-bold text-gray-700">هوية المتنازل له</div>
                  <input
                    value={newOwnerIdNumber}
                    onChange={(e) => {
                      setNewOwnerIdNumber(e.target.value);
                      setSelectedNewOwnerClient(null);
                    }}
                    className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold focus:ring-2 focus:ring-rose-500"
                  />
                  {searchingClients && (
                    <div className="text-xs font-bold text-gray-500">جارٍ البحث...</div>
                  )}
                  {clientSuggestions.length > 0 && (
                    <div className="bg-white border border-gray-200 rounded-2xl overflow-hidden">
                      {clientSuggestions.map((c) => (
                        <button
                          key={c.id}
                          type="button"
                          onClick={() => {
                            setSelectedNewOwnerClient(c);
                            setNewOwnerIdNumber(c.id_number || '');
                            setNewOwnerName(c.name || '');
                            setNewOwnerPhone(c.phone || '');
                            setClientSuggestions([]);
                          }}
                          className="w-full text-right px-4 py-3 hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-b-0"
                        >
                          <div className="font-extrabold text-gray-900">{c.name || '—'}</div>
                          <div className="text-xs text-gray-600 mt-1">
                            هوية: {c.id_number || '—'} • جوال: {c.phone || '—'}
                          </div>
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                <div className="grid grid-cols-1 gap-4 mt-4">
                  <label className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">اسم المتنازل له</div>
                    <input
                      value={newOwnerName}
                      onChange={(e) => setNewOwnerName(e.target.value)}
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold focus:ring-2 focus:ring-rose-500"
                    />
                  </label>
                  <label className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">جوال المتنازل له (اختياري)</div>
                    <input
                      value={newOwnerPhone}
                      onChange={(e) => setNewOwnerPhone(e.target.value)}
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold focus:ring-2 focus:ring-rose-500"
                    />
                  </label>
                </div>

                <div className="mt-4 p-4 rounded-2xl bg-gray-50 border border-gray-200">
                  <div className="text-xs font-extrabold text-gray-700 mb-2">ملاحظة</div>
                  <div className="text-sm text-gray-700 font-semibold leading-7">
                    {selectedNewOwnerClient
                      ? 'تم اختيار عميل موجود وسيصبح هو العميل الأساسي للعقد.'
                      : canCreateNewClient
                        ? 'لا يوجد عميل مطابق (حسب الهوية). سيتم إنشاء عميل جديد عند حفظ التنازل.'
                        : 'إذا لم يوجد العميل، أدخل الاسم ليتم إنشاء عميل جديد.'}
                  </div>
                </div>
              </div>

              <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
                <h2 className="text-lg font-extrabold text-gray-900 mb-4">3) تاريخ التنازل</h2>
                <input
                  type="date"
                  value={waiverDate}
                  onChange={(e) => setWaiverDate(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                />
              </div>

              <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
                <button
                  type="button"
                  onClick={saveWaiver}
                  disabled={saving}
                  className="w-full flex items-center justify-center gap-3 px-5 py-3 rounded-2xl bg-rose-600 text-white font-extrabold hover:bg-rose-700 transition-colors disabled:opacity-60"
                >
                  {saving ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
                    {saving ? 'جارٍ الحفظ...' : editingWaiverId ? 'حفظ التعديل' : 'حفظ التنازل'}
                </button>

                {selectedContract && (
                  <div className="mt-4 flex items-start gap-3 bg-emerald-50 border border-emerald-200 rounded-2xl p-4">
                    <CheckCircle2 className="text-emerald-700 mt-0.5" size={18} />
                    <div>
                      <div className="text-sm font-extrabold text-emerald-900">العقد المختار جاهز للتنازل</div>
                      <div className="text-xs text-emerald-800 mt-1">
                        سيتم تحديث العميل داخل العقد الأصلي، وحفظ العميل السابق في حقول التنازل، وإنشاء عقد تنازل منفصل للطباعة لاحقًا.
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-sm font-extrabold text-gray-900">معاينة قالب التنازل</div>
                    <div className="text-xs text-gray-500 mt-1">صفحة المعاينة التجريبية ما زالت متاحة</div>
                  </div>
                  <Link
                    href="/test-tnazol"
                    className="inline-flex items-center gap-2 px-4 py-2 rounded-2xl bg-gray-50 border border-gray-200 text-gray-700 font-extrabold hover:bg-gray-100"
                  >
                    <UserPlus size={18} />
                    فتح المعاينة
                  </Link>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function NewWaiverPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-gray-50" dir="rtl">
          <div className="flex items-center gap-3 text-lg font-bold text-gray-700">
            <Loader2 size={24} className="animate-spin text-rose-600" />
            جاري تحميل صفحة التنازل...
          </div>
        </div>
      }
    >
      <NewWaiverPageContent />
    </Suspense>
  );
}
