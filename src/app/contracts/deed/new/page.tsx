'use client';

import React, { Suspense, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { ArrowLeft, CheckCircle2, FileSignature, Loader2, Save, Search, UserPlus } from 'lucide-react';
import { supabase } from '../../../../lib/supabaseClient';
import { CONTRACT_TYPES, FullContract } from '../../../../types';

type DeedClient = {
  id: string;
  name: string;
  id_number: string | null;
  phone: string | null;
};

type RecipientSource = 'contract' | 'settlement' | 'manual';

const getContractTypeLabel = (type: string | null | undefined) => {
  if (!type) return null;
  return (CONTRACT_TYPES as Record<string, string>)[type] || type;
};

function NewDeedPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const editDeedId = String(searchParams.get('edit') || '').trim();
  const [isAdmin, setIsAdmin] = useState(false);
  const [accessReady, setAccessReady] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [contracts, setContracts] = useState<FullContract[]>([]);
  const [search, setSearch] = useState('');
  const [selectedBaseContractId, setSelectedBaseContractId] = useState<string | null>(null);

  const [deedDate, setDeedDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [deedNumber, setDeedNumber] = useState('');
  const [meterNumber, setMeterNumber] = useState('');
  const [parkingNumber, setParkingNumber] = useState('');

  const [manualRecipientEnabled, setManualRecipientEnabled] = useState(false);
  const [manualRecipientIdNumber, setManualRecipientIdNumber] = useState('');
  const [manualRecipientName, setManualRecipientName] = useState('');
  const [manualRecipientPhone, setManualRecipientPhone] = useState('');
  const [manualRecipientSuggestions, setManualRecipientSuggestions] = useState<DeedClient[]>([]);
  const [selectedManualRecipient, setSelectedManualRecipient] = useState<DeedClient | null>(null);
  const [searchingManualRecipient, setSearchingManualRecipient] = useState(false);
  const [didInitEditForm, setDidInitEditForm] = useState(false);

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
      nextMetadata.operation_source ??= 'contracts_deed_page';
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
      if (!editDeedId) {
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
  }, [editDeedId, router]);

  useEffect(() => {
    if (!accessReady) return;
    if (editDeedId && !isAdmin) return;

    const load = async () => {
      try {
        setLoading(true);
        const { data, error } = await supabase
          .from('contracts')
          .select(`
            *,
            project:projects(*),
            unit:units(*),
            client:clients!contracts_client_id_fkey(id,name,id_number,phone)
          `)
          .order('created_at', { ascending: false });

        if (error) throw error;
        setContracts(((data as any[]) || []) as any);
      } catch (error: any) {
        alert('حدث خطأ أثناء تحميل بيانات الإفراغ: ' + (error?.message || ''));
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [accessReady, editDeedId, isAdmin]);

  useEffect(() => {
    const q = String(manualRecipientIdNumber || '').trim();
    if (!manualRecipientEnabled || !q || q.length < 3) {
      setManualRecipientSuggestions([]);
      return;
    }

    const run = async () => {
      try {
        setSearchingManualRecipient(true);
        const { data, error } = await supabase
          .from('clients')
          .select('id,name,id_number,phone')
          .ilike('id_number', `${q}%`)
          .limit(6);
        if (error) throw error;
        setManualRecipientSuggestions(((data as any[]) || []) as any);
      } catch {
        setManualRecipientSuggestions([]);
      } finally {
        setSearchingManualRecipient(false);
      }
    };

    run();
  }, [manualRecipientEnabled, manualRecipientIdNumber]);

  const deedContracts = useMemo(
    () =>
      contracts.filter((c) => c.type === 'deed' && !Boolean((c as any).is_archived)),
    [contracts]
  );

  const editingDeedContract = useMemo(() => {
    if (!editDeedId) return null;
    return contracts.find((c) => c.id === editDeedId && c.type === 'deed') || null;
  }, [contracts, editDeedId]);

  const editingSourceContractId = useMemo(() => {
    if (!editingDeedContract) return '';
    return String((editingDeedContract as any).deed_source_contract_id || editingDeedContract.source_contract_id || '').trim();
  }, [editingDeedContract]);

  const deedSourceIds = useMemo(() => {
    const ids = new Set<string>();
    for (const c of deedContracts) {
      const sourceId = String((c as any).deed_source_contract_id || c.source_contract_id || '').trim();
      if (sourceId && sourceId !== editingSourceContractId) ids.add(sourceId);
    }
    return ids;
  }, [deedContracts, editingSourceContractId]);

  const waiverBySourceId = useMemo(() => {
    const map = new Map<string, FullContract>();
    for (const c of contracts) {
      if (c.type === 'waiver') {
        const sourceId = String(c.source_contract_id || '').trim();
        if (sourceId) map.set(sourceId, c);
      }
    }
    return map;
  }, [contracts]);

  const settlementById = useMemo(() => {
    const map = new Map<string, FullContract>();
    for (const c of contracts) {
      if (c.type === 'financial_settlement') map.set(c.id, c);
    }
    return map;
  }, [contracts]);

  const eligibleBaseContracts = useMemo(() => {
    const bases = contracts.filter((c) => {
      if (c.type !== 'under_construction') return false;
      if (Boolean((c as any).is_archived)) return false;
      if (deedSourceIds.has(c.id)) return false;
      const hasSettlement = Boolean((c as any).financial_settlement_contract_id);
      const hasResale = Boolean(c.resale_contract_id);

      if (hasSettlement) return true;
      if (!hasResale) return true;
      return false;
    });

    const q = search.trim();
    if (!q) return bases;

    return bases.filter((c) => {
      const projectNo = c.project?.project_number || '';
      const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '';
      const code = `${projectNo}-${unitNo}`;
      const clientName = c.client?.name || c.client_name || '';
      return code.includes(q) || projectNo.includes(q) || unitNo.includes(q) || clientName.includes(q);
    });
  }, [contracts, deedSourceIds, search]);

  const selectedBaseContract = useMemo(
    () => (selectedBaseContractId ? eligibleBaseContracts.find((c) => c.id === selectedBaseContractId) || null : null),
    [eligibleBaseContracts, selectedBaseContractId]
  );

  const linkedWaiverContract = useMemo(() => {
    if (!selectedBaseContract) return null;
    return waiverBySourceId.get(selectedBaseContract.id) || null;
  }, [selectedBaseContract, waiverBySourceId]);

  const linkedSettlementContract = useMemo(() => {
    if (!selectedBaseContract) return null;
    const id = String((selectedBaseContract as any).financial_settlement_contract_id || '').trim();
    if (!id) return null;
    return settlementById.get(id) || null;
  }, [selectedBaseContract, settlementById]);

  useEffect(() => {
    if (!selectedBaseContract) {
      setDeedNumber('');
      setMeterNumber('');
      setParkingNumber('');
      return;
    }
    if (editDeedId && !didInitEditForm) return;
    setDeedNumber(String(selectedBaseContract.unit?.deed_number || '').trim());
    setMeterNumber(String((selectedBaseContract.unit as any)?.electricity_meter || '').trim());
    setParkingNumber('');
    setManualRecipientEnabled(false);
    setManualRecipientIdNumber('');
    setManualRecipientName('');
    setManualRecipientPhone('');
    setSelectedManualRecipient(null);
    setManualRecipientSuggestions([]);
  }, [selectedBaseContractId, selectedBaseContract, editDeedId, didInitEditForm]);

  useEffect(() => {
    if (loading || !editDeedId || didInitEditForm) return;
    if (!editingDeedContract) {
      setDidInitEditForm(true);
      return;
    }

    const sourceId = String((editingDeedContract as any).deed_source_contract_id || editingDeedContract.source_contract_id || '').trim();
    setSelectedBaseContractId(sourceId || null);
    setDeedDate(editingDeedContract.contract_date || new Date().toISOString().slice(0, 10));
    setDeedNumber(String((editingDeedContract as any).deed_unit_deed_number || '').trim());
    setMeterNumber(String((editingDeedContract as any).deed_meter_number || '').trim());
    setParkingNumber(String((editingDeedContract as any).deed_parking_number || '').trim());

    const recipientSource = String((editingDeedContract as any).deed_recipient_source || '').trim();
    if (recipientSource === 'manual') {
      setManualRecipientEnabled(true);
      setManualRecipientIdNumber(String((editingDeedContract as any).deed_recipient_id_number || '').trim());
      setManualRecipientName(String((editingDeedContract as any).deed_recipient_name || '').trim());
      setManualRecipientPhone(String((editingDeedContract as any).deed_recipient_phone || '').trim());
      const clientId = String((editingDeedContract as any).deed_recipient_client_id || editingDeedContract.client_id || '').trim();
      setSelectedManualRecipient(
        clientId || String((editingDeedContract as any).deed_recipient_name || '').trim()
          ? {
              id: clientId,
              name: String((editingDeedContract as any).deed_recipient_name || '').trim(),
              id_number: String((editingDeedContract as any).deed_recipient_id_number || '').trim() || null,
              phone: String((editingDeedContract as any).deed_recipient_phone || '').trim() || null,
            }
          : null
      );
    } else {
      setManualRecipientEnabled(false);
      setManualRecipientIdNumber('');
      setManualRecipientName('');
      setManualRecipientPhone('');
      setSelectedManualRecipient(null);
    }

    setDidInitEditForm(true);
  }, [loading, editDeedId, editingDeedContract, didInitEditForm]);

  const settlementRecipientData = useMemo(() => {
    if (!linkedSettlementContract) return null;
    const unit = selectedBaseContract?.unit as any;
    const contract = linkedSettlementContract as any;

    const clientId = String(contract.settlement_new_owner_client_id || contract.settlement_new_client_id || unit?.current_client_id || '').trim() || null;
    const name =
      String(unit?.title_deed_owner || contract.settlement_new_owner_name || '').trim() ||
      null;
    const idNumber =
      String(unit?.title_deed_owner_id || contract.settlement_new_owner_id_number || '').trim() ||
      null;
    const phone =
      String(unit?.title_deed_owner_phone || contract.settlement_new_owner_phone || '').trim() ||
      null;

    if (!name && !idNumber && !clientId) return null;

    return {
      client_id: clientId,
      name,
      id_number: idNumber,
      phone,
    };
  }, [linkedSettlementContract, selectedBaseContract]);

  const defaultRecipient = useMemo(() => {
    if (!selectedBaseContract) return null;

    if (settlementRecipientData && !manualRecipientEnabled) {
      return {
        source: 'settlement' as RecipientSource,
        client_id: settlementRecipientData.client_id,
        name: settlementRecipientData.name,
        id_number: settlementRecipientData.id_number,
        phone: settlementRecipientData.phone,
      };
    }

    if (manualRecipientEnabled) {
      return {
        source: 'manual' as RecipientSource,
        client_id: selectedManualRecipient?.id || null,
        name: String(manualRecipientName || '').trim() || null,
        id_number: String(manualRecipientIdNumber || '').trim() || null,
        phone: String(manualRecipientPhone || '').trim() || null,
      };
    }

    return {
      source: 'contract' as RecipientSource,
      client_id: selectedBaseContract.client_id || null,
      name: selectedBaseContract.client?.name || selectedBaseContract.client_name || null,
      id_number: selectedBaseContract.client?.id_number || selectedBaseContract.client_id_number || null,
      phone: selectedBaseContract.client?.phone || selectedBaseContract.client_phone || null,
    };
  }, [selectedBaseContract, settlementRecipientData, manualRecipientEnabled, selectedManualRecipient, manualRecipientName, manualRecipientIdNumber, manualRecipientPhone]);

  const canUseManualRecipient = useMemo(() => {
    return Boolean(selectedBaseContract);
  }, [selectedBaseContract]);

  const resolvedCaseLabel = useMemo(() => {
    if (!selectedBaseContract) return '—';
    if (manualRecipientEnabled) return 'حالة يدوية';
    if (settlementRecipientData) return 'حالة تسوية';
    return linkedWaiverContract ? 'عقد تحت الإنشاء مع تنازل' : 'عقد تحت الإنشاء مباشر';
  }, [selectedBaseContract, manualRecipientEnabled, settlementRecipientData, linkedWaiverContract]);

  const ensureManualRecipient = async () => {
    if (selectedManualRecipient) return selectedManualRecipient;

    const idNumber = String(manualRecipientIdNumber || '').trim();
    if (!idNumber) throw new Error('يرجى إدخال هوية العميل المستلم');

    const existing = await supabase.from('clients').select('id,name,id_number,phone').eq('id_number', idNumber).maybeSingle();
    if (existing.error) throw existing.error;
    if (existing.data?.id) return existing.data as any;

    const name = String(manualRecipientName || '').trim();
    if (!name) throw new Error('لا يوجد عميل بهذه الهوية. أدخل اسم العميل المستلم لإضافته.');

    const { data: created, error: createError } = await supabase
      .from('clients')
      .insert({
        name,
        id_number: idNumber,
        phone: String(manualRecipientPhone || '').trim() || null,
      })
      .select('id,name,id_number,phone')
      .single();
    if (createError) throw createError;
    if (!created?.id) throw new Error('تعذر إنشاء العميل المستلم');
    return created as any;
  };

  const normalizeValue = (value: string | null | undefined) => String(value || '').trim();

  const resolveUnitStatus = (
    baseContract: FullContract,
    recipient: { clientId?: string | null; idNumber?: string | null; name?: string | null }
  ): 'deed_completed' | 'transferred_to_other' => {
    const baseClientId = normalizeValue(baseContract.client_id);
    const baseIdNumber = normalizeValue(baseContract.client?.id_number || baseContract.client_id_number);
    const baseName = normalizeValue(baseContract.client?.name || baseContract.client_name);
    const recipientClientId = normalizeValue(recipient.clientId);
    const recipientIdNumber = normalizeValue(recipient.idNumber);
    const recipientName = normalizeValue(recipient.name);

    const sameByClientId = baseClientId && recipientClientId && baseClientId === recipientClientId;
    const sameByIdNumber = baseIdNumber && recipientIdNumber && baseIdNumber === recipientIdNumber;
    const sameByNameOnly = !recipientClientId && !recipientIdNumber && baseName && recipientName && baseName === recipientName;

    return sameByClientId || sameByIdNumber || sameByNameOnly ? 'deed_completed' : 'transferred_to_other';
  };

  const saveDeedContract = async () => {
    if (editDeedId && !isAdmin) {
      alert('غير مصرح');
      return;
    }
    if (!selectedBaseContract) {
      alert('يرجى اختيار عقد تحت الإنشاء أولاً');
      return;
    }
    if (!deedDate) {
      alert('يرجى اختيار تاريخ الإفراغ');
      return;
    }

    try {
      setSaving(true);
      const { actorId, actorName } = await getActorInfo();

      let recipientClientId = defaultRecipient?.client_id || null;
      let recipientName = defaultRecipient?.name || null;
      let recipientIdNumber = defaultRecipient?.id_number || null;
      let recipientPhone = defaultRecipient?.phone || null;
      let recipientSource: RecipientSource = defaultRecipient?.source || 'contract';

      if (manualRecipientEnabled) {
        const manualClient = await ensureManualRecipient();
        recipientClientId = manualClient.id;
        recipientName = manualClient.name || null;
        recipientIdNumber = manualClient.id_number || null;
        recipientPhone = manualClient.phone || null;
        recipientSource = 'manual';
      }

      if (!recipientName || !recipientIdNumber) {
        throw new Error('تعذر تحديد الطرف الثاني لعقد الإفراغ');
      }

      const nextUnitStatus = resolveUnitStatus(selectedBaseContract, {
        clientId: recipientClientId,
        idNumber: recipientIdNumber,
        name: recipientName,
      });

      if (linkedSettlementContract && settlementRecipientData && !String((selectedBaseContract.unit as any)?.current_client_id || '').trim()) {
        const { error: syncSettlementUnitError } = await supabase
          .from('units')
          .update({
            current_client_id: settlementRecipientData.client_id,
            title_deed_owner: settlementRecipientData.name,
            title_deed_owner_id: settlementRecipientData.id_number,
            title_deed_owner_phone: settlementRecipientData.phone,
          })
          .eq('id', selectedBaseContract.unit_id);
        if (syncSettlementUnitError) throw syncSettlementUnitError;
      }

      const payload: any = {
        project_id: selectedBaseContract.project_id,
        unit_id: selectedBaseContract.unit_id,
        client_id: recipientClientId,
        source_contract_id: selectedBaseContract.id,
        deed_source_contract_id: selectedBaseContract.id,
        deed_waiver_contract_id: linkedWaiverContract?.id || null,
        deed_settlement_contract_id: linkedSettlementContract?.id || null,
        deed_recipient_client_id: recipientClientId,
        deed_recipient_name: recipientName,
        deed_recipient_id_number: recipientIdNumber,
        deed_recipient_phone: recipientPhone,
        deed_recipient_source: recipientSource,
        deed_unit_deed_number: deedNumber || null,
        deed_meter_number: meterNumber || null,
        deed_parking_number: parkingNumber || null,
        contract_date: deedDate,
        status: 'active',
        type: 'deed',
        total_amount: 0,
        paid_amount: 0,
        completion_period_months: selectedBaseContract.completion_period_months || 12,
        payment_grace_period_months: selectedBaseContract.payment_grace_period_months ?? null,
        client_name: recipientName,
        client_id_number: recipientIdNumber,
        client_phone: recipientPhone,
      };

      let savedDeedId = '';
      if (editingDeedContract?.id) {
        const { data: updatedDeed, error: deedError } = await supabase
          .from('contracts')
          .update(payload)
          .eq('id', editingDeedContract.id)
          .select('id')
          .single();
        if (deedError) throw deedError;
        if (!updatedDeed?.id) throw new Error('تعذر تحديث عقد الإفراغ');
        savedDeedId = updatedDeed.id;
      } else {
        payload.created_by_id = actorId;
        payload.created_by_name = actorName || null;
        const { data: createdDeed, error: deedError } = await supabase
          .from('contracts')
          .insert(payload)
          .select('id')
          .single();
        if (deedError) throw deedError;
        if (!createdDeed?.id) throw new Error('تعذر إنشاء عقد الإفراغ');
        savedDeedId = createdDeed.id;
      }

      const { error: unitUpdateError } = await supabase
        .from('units')
        .update({
          status: nextUnitStatus,
          current_client_id: recipientClientId,
          title_deed_owner: recipientName,
          title_deed_owner_id: recipientIdNumber,
          title_deed_owner_phone: recipientPhone,
        })
        .eq('id', selectedBaseContract.unit_id);
      if (unitUpdateError) throw unitUpdateError;

      const { error: debtUpdateError } = await supabase
        .from('debts')
        .update({
          current_owner_name: recipientName,
          current_owner_phone: recipientPhone,
          deed_number: deedNumber || null,
        })
        .eq('unit_id', selectedBaseContract.unit_id);
      if (debtUpdateError) throw debtUpdateError;

      await logContractEvent({
        contract_id: savedDeedId,
        action: editingDeedContract?.id ? 'contract_updated' : 'contract_created',
        entity_type: 'contract',
        entity_id: savedDeedId,
        metadata: {
          contract_type: 'deed',
          mode: editingDeedContract?.id ? 'edit' : 'create',
          contract_date: deedDate,
          source_contract_id: selectedBaseContract.id,
          source_contract_type: selectedBaseContract.type,
          source_contract_type_label: getContractTypeLabel(selectedBaseContract.type),
          project_id: selectedBaseContract.project_id,
          project_number: selectedBaseContract.project?.project_number || null,
          project_name: selectedBaseContract.project?.name || null,
          unit_id: selectedBaseContract.unit_id,
          unit_number: selectedBaseContract.unit?.unit_number ?? null,
          client_id: recipientClientId,
          client_name: recipientName,
          client_phone: recipientPhone || null,
          client_id_number: recipientIdNumber,
          waiver_contract_id: linkedWaiverContract?.id || null,
          settlement_contract_id: linkedSettlementContract?.id || null,
          recipient_client_id: recipientClientId,
          recipient_name: recipientName,
          recipient_phone: recipientPhone || null,
          recipient_id_number: recipientIdNumber,
          recipient_source: recipientSource,
          unit_status: nextUnitStatus,
          deed_number: deedNumber || null,
          meter_number: meterNumber || null,
          parking_number: parkingNumber || null,
        },
      });

      alert(editingDeedContract?.id ? 'تم تعديل عقد الإفراغ بنجاح' : 'تم إنشاء عقد الإفراغ بنجاح');
      router.push('/contracts');
    } catch (error: any) {
      alert(`حدث خطأ أثناء ${editingDeedContract?.id ? 'تعديل' : 'إنشاء'} عقد الإفراغ: ` + (error?.message || ''));
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
            <div className="h-12 w-12 rounded-2xl bg-gradient-to-br from-purple-600 to-fuchsia-600 text-white flex items-center justify-center shadow-md">
              <FileSignature size={24} />
            </div>
            <div>
              <h1 className="text-2xl font-extrabold text-gray-900">{editingDeedContract ? 'تعديل عقد إفراغ' : 'إضافة عقد إفراغ'}</h1>
              <p className="text-sm text-gray-600 mt-1">يجلب بيانات العقد والوحدة والمشروع ويحدد الطرف الثاني حسب الحالة المناسبة</p>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-10 flex items-center justify-center gap-3 text-gray-700 font-bold">
            <Loader2 className="animate-spin" size={20} />
            جارٍ تحميل البيانات...
          </div>
        ) : (
          <div className="grid grid-cols-1 xl:grid-cols-[1.2fr_0.8fr] gap-6">
            <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
              <div className="flex items-center justify-between gap-4 mb-5">
                <div>
                  <h2 className="text-lg font-extrabold text-gray-900">1) اختر عقد تحت الإنشاء</h2>
                  <p className="text-sm text-gray-500 mt-1">يشمل الحالة المباشرة أو حالة التسوية، ويستبعد العقود المؤرشفة أو التي عليها إفراغ سابق</p>
                </div>
                <div className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-gray-50 border border-gray-200">
                  <Search size={18} className="text-gray-500" />
                  <input
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="بحث بالكود أو اسم العميل..."
                    className="bg-transparent outline-none text-sm font-bold text-gray-800 w-72 max-w-full"
                  />
                </div>
              </div>

              {eligibleBaseContracts.length === 0 ? (
                <div className="p-10 rounded-3xl bg-gray-50 border border-gray-100 text-center">
                  <div className="text-gray-900 font-extrabold mb-2">لا توجد عقود مطابقة لشروط الإفراغ</div>
                  <div className="text-sm text-gray-600">إما أنها مؤرشفة أو لديها عقد إفراغ سابق أو غير جاهزة حسب الحالة المطلوبة.</div>
                </div>
              ) : (
                <div className="space-y-3 max-h-[560px] overflow-y-auto pr-1">
                  {eligibleBaseContracts.map((c) => {
                    const projectNo = c.project?.project_number || '—';
                    const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '—';
                    const code = `${projectNo}-${unitNo}`;
                    const clientName = c.client?.name || c.client_name || '—';
                    const hasSettlement = Boolean((c as any).financial_settlement_contract_id);
                    const active = selectedBaseContractId === c.id;

                    return (
                      <button
                        key={c.id}
                        type="button"
                        onClick={() => setSelectedBaseContractId(c.id)}
                        className={`w-full text-right p-4 rounded-3xl border transition-all ${
                          active ? 'border-purple-300 bg-purple-50 shadow-sm' : 'border-gray-100 bg-white hover:bg-gray-50'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-4">
                          <div>
                            <div className="text-sm font-extrabold text-gray-900">{clientName}</div>
                            <div className="text-xs text-gray-600 mt-1">
                              الكود: {code} • تاريخ العقد: {c.contract_date || '—'}
                            </div>
                          </div>
                          <div className={`px-3 py-1 rounded-full text-xs font-extrabold ${hasSettlement ? 'bg-emerald-100 text-emerald-800' : 'bg-blue-100 text-blue-800'}`}>
                            {hasSettlement ? 'مع تسوية' : 'مباشر'}
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
                <h2 className="text-lg font-extrabold text-gray-900 mb-4">2) بيانات الإفراغ</h2>
                <div className="grid grid-cols-1 gap-4">
                  <label className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">تاريخ الإفراغ</div>
                    <input
                      type="date"
                      value={deedDate}
                      onChange={(e) => setDeedDate(e.target.value)}
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                    />
                  </label>
                  <label className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">رقم صك الشقة</div>
                    <input
                      value={deedNumber}
                      onChange={(e) => setDeedNumber(e.target.value)}
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                    />
                  </label>
                  <label className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">رقم العداد (اختياري)</div>
                    <input
                      value={meterNumber}
                      onChange={(e) => setMeterNumber(e.target.value)}
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                    />
                  </label>
                  <label className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">رقم الموقف (اختياري)</div>
                    <input
                      value={parkingNumber}
                      onChange={(e) => setParkingNumber(e.target.value)}
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                    />
                  </label>
                </div>
              </div>

              {canUseManualRecipient && (
                <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
                  <label className="flex items-center gap-3 bg-gray-50 border border-gray-200 rounded-2xl px-4 py-3">
                    <input
                      type="checkbox"
                      checked={manualRecipientEnabled}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setManualRecipientEnabled(checked);
                        setManualRecipientIdNumber('');
                        setManualRecipientName('');
                        setManualRecipientPhone('');
                        setSelectedManualRecipient(null);
                        setManualRecipientSuggestions([]);
                      }}
                    />
                    <span className="font-extrabold text-gray-800">إفراغ يدوي / تغيير العميل المستلم يدويًا</span>
                  </label>

                  {manualRecipientEnabled && (
                    <div className="grid grid-cols-1 gap-4 mt-4">
                      <label className="space-y-2">
                        <div className="text-sm font-bold text-gray-700">هوية العميل المستلم</div>
                        <input
                          value={manualRecipientIdNumber}
                          onChange={(e) => {
                            setManualRecipientIdNumber(e.target.value);
                            setSelectedManualRecipient(null);
                          }}
                          className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                        />
                        {searchingManualRecipient && <div className="text-xs font-bold text-gray-500">جارٍ البحث...</div>}
                        {manualRecipientSuggestions.length > 0 && (
                          <div className="bg-white border border-gray-200 rounded-2xl overflow-hidden">
                            {manualRecipientSuggestions.map((c) => (
                              <button
                                key={c.id}
                                type="button"
                                onClick={() => {
                                  setSelectedManualRecipient(c);
                                  setManualRecipientIdNumber(c.id_number || '');
                                  setManualRecipientName(c.name || '');
                                  setManualRecipientPhone(c.phone || '');
                                  setManualRecipientSuggestions([]);
                                }}
                                className="w-full text-right px-4 py-3 hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-b-0"
                              >
                                <div className="font-extrabold text-gray-900">{c.name || '—'}</div>
                                <div className="text-xs text-gray-600 mt-1">هوية: {c.id_number || '—'} • جوال: {c.phone || '—'}</div>
                              </button>
                            ))}
                          </div>
                        )}
                      </label>
                      <label className="space-y-2">
                        <div className="text-sm font-bold text-gray-700">اسم العميل المستلم</div>
                        <input
                          value={manualRecipientName}
                          onChange={(e) => setManualRecipientName(e.target.value)}
                          className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                        />
                      </label>
                      <label className="space-y-2">
                        <div className="text-sm font-bold text-gray-700">جوال العميل المستلم (اختياري)</div>
                        <input
                          value={manualRecipientPhone}
                          onChange={(e) => setManualRecipientPhone(e.target.value)}
                          className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white outline-none font-bold"
                        />
                      </label>
                    </div>
                  )}
                </div>
              )}

              <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
                <div className="text-sm font-extrabold text-gray-900 mb-3">ملخص الحالة</div>
                <div className="space-y-2 text-sm font-semibold text-gray-700">
                  <div>نوع الحالة: {resolvedCaseLabel}</div>
                  <div>الطرف الثاني: {defaultRecipient?.name || '—'}</div>
                  <div>هوية الطرف الثاني: {defaultRecipient?.id_number || '—'}</div>
                  <div>مصدر الطرف الثاني: {defaultRecipient?.source || '—'}</div>
                </div>

                {canUseManualRecipient && !manualRecipientEnabled && (
                  <div className="mt-4 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-semibold text-amber-900 leading-7">
                    يمكنك تفعيل خيار `إفراغ يدوي` في أي حالة، حتى لو كان العقد مرتبطًا بتسوية أو كانت بيانات الطرف الثاني موجودة تلقائيًا.
                  </div>
                )}

                {selectedBaseContract && (
                  <div className="mt-4 flex items-start gap-3 bg-emerald-50 border border-emerald-200 rounded-2xl p-4">
                    <CheckCircle2 className="text-emerald-700 mt-0.5" size={18} />
                    <div>
                      <div className="text-sm font-extrabold text-emerald-900">{editingDeedContract ? 'العقد جاهز للتعديل' : 'العقد جاهز للإفراغ'}</div>
                      <div className="text-xs text-emerald-800 mt-1">
                        سيتم {editingDeedContract ? 'تحديث' : 'إنشاء'} عقد الإفراغ وتحديد حالة الوحدة تلقائيًا: تم الإفراغ إذا كان العميل نفسه، أو مفرغة لآخر إذا كان العميل مختلفًا.
                      </div>
                    </div>
                  </div>
                )}

                <button
                  type="button"
                  onClick={saveDeedContract}
                  disabled={saving}
                  className="w-full mt-5 flex items-center justify-center gap-3 px-5 py-3 rounded-2xl bg-purple-600 text-white font-extrabold hover:bg-purple-700 transition-colors disabled:opacity-60"
                >
                  {saving ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
                  {saving ? (editingDeedContract ? 'جارٍ التعديل...' : 'جارٍ الحفظ...') : (editingDeedContract ? 'حفظ التعديلات' : 'حفظ عقد الإفراغ')}
                </button>
              </div>

              <div className="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-sm font-extrabold text-gray-900">معاينة قالب الإفراغ</div>
                    <div className="text-xs text-gray-500 mt-1">القالب الحالي جاهز للربط والطباعة</div>
                  </div>
                  <Link
                    href="/test-estlam"
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

export default function NewDeedPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-gray-50" dir="rtl">
          <div className="flex items-center gap-3 text-lg font-bold text-gray-700">
            <Loader2 size={24} className="animate-spin text-blue-600" />
            جاري تحميل صفحة الإفراغ...
          </div>
        </div>
      }
    >
      <NewDeedPageContent />
    </Suspense>
  );
}
