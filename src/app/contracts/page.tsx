'use client';

import React, { useState, useEffect, useMemo, useRef } from 'react';
import Link from 'next/link';
import { ArrowLeft, Plus, Trash2, Printer, Pencil, Wallet, CalendarDays, ScrollText, Layers3, Repeat2, FileSignature, FileStack, Archive, Eye, Search, Upload, FileImage, FileText, Loader2 } from 'lucide-react';
import * as supabaseClient from '../../lib/supabaseClient';
import { FullContract, Project, Unit, Client, ContractObligation, ContractPayment, CONTRACT_STATUSES, CONTRACT_TYPES, PAYMENT_METHODS, ContractAttachment, ContractAttachmentCategory } from '../../types';
import ContractPrintPage from '../../components/printcontrect';
import ResalePrintPage from '../../components/printeaadtbia';
import SettlementPrintPage from '../../components/printtasoiah';
import TnazolPrintPage from '../../components/print_tnazol';
import ReceiptPrintPage from '../../components/printestlam';

type EmployeeRole = 'admin' | 'manager' | 'marketing' | 'customer_service' | 'staff' | 'viewer';
type ContractTypeKey = keyof typeof CONTRACT_TYPES;

const CONTRACT_ATTACHMENT_LABELS: Record<ContractAttachmentCategory, string> = {
  receipt: 'إيصالات',
  identity: 'هوية',
  unit_plan: 'مخطط شقة',
};

const CONTRACT_ATTACHMENT_DESCRIPTIONS: Record<ContractAttachmentCategory, string> = {
  receipt: 'أي إيصالات سداد أو تحويل مرتبطة بالعقد.',
  identity: 'صور الهوية أو النسخ الرسمية الخاصة بالعميل.',
  unit_plan: 'مخطط الشقة أو أي ملفات توضيحية للوحدة.',
};

export default function ContractsPage() {
  const [contracts, setContracts] = useState<FullContract[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [employees, setEmployees] = useState<Array<{ id: string; email: string | null }>>([]);
  const [role, setRole] = useState<EmployeeRole>('viewer');
  const [isAdmin, setIsAdmin] = useState(false);
  const [activeContractTypeFilter, setActiveContractTypeFilter] = useState<'all' | ContractTypeKey>('all');
  const [showArchivedContracts, setShowArchivedContracts] = useState(false);
  const [contractsSearchQuery, setContractsSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedContract, setSelectedContract] = useState<FullContract | null>(null);
  const [loadingAttachments, setLoadingAttachments] = useState(false);
  const [uploadingAttachmentCategory, setUploadingAttachmentCategory] = useState<ContractAttachmentCategory | null>(null);
  const [openingAttachmentId, setOpeningAttachmentId] = useState<string | null>(null);
  const [deletingAttachmentId, setDeletingAttachmentId] = useState<string | null>(null);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [showResalePrintModal, setShowResalePrintModal] = useState(false);
  const [resalePrintData, setResalePrintData] = useState<any>(null);
  const [showSettlementPrintModal, setShowSettlementPrintModal] = useState(false);
  const [settlementPrintData, setSettlementPrintData] = useState<any>(null);
  const [showWaiverPrintModal, setShowWaiverPrintModal] = useState(false);
  const [waiverPrintData, setWaiverPrintData] = useState<any>(null);
  const [showDeedPrintModal, setShowDeedPrintModal] = useState(false);
  const [deedPrintData, setDeedPrintData] = useState<any>(null);
  const [showResaleWizard, setShowResaleWizard] = useState(false);
  const [resaleStep, setResaleStep] = useState<1 | 2 | 3>(1);
  const [resaleSearch, setResaleSearch] = useState('');
  const [resaleSourceContractId, setResaleSourceContractId] = useState<string | null>(null);
  const [resaleAgreedAmount, setResaleAgreedAmount] = useState('');
  const [resaleFee, setResaleFee] = useState('5000');
  const [resaleMarketingFee, setResaleMarketingFee] = useState('15000');
  const [resaleCompanyFee, setResaleCompanyFee] = useState('2500');
  const [resaleLawyerFee, setResaleLawyerFee] = useState('2500');
  const [savingResale, setSavingResale] = useState(false);
  const [showSettlementWizard, setShowSettlementWizard] = useState(false);
  const [settlementStep, setSettlementStep] = useState<1 | 2 | 3>(1);
  const [settlementSearch, setSettlementSearch] = useState('');
  const [settlementSourceContractId, setSettlementSourceContractId] = useState<string | null>(null);
  const [settlementSalePrice, setSettlementSalePrice] = useState('');
  const [settlementDate, setSettlementDate] = useState(new Date().toISOString().split('T')[0]);
  const [settlementIncludeNewClient, setSettlementIncludeNewClient] = useState(false);
  const [settlementNewOwnerIdNumber, setSettlementNewOwnerIdNumber] = useState('');
  const [settlementNewOwnerName, setSettlementNewOwnerName] = useState('');
  const [settlementNewOwnerPhone, setSettlementNewOwnerPhone] = useState('');
  const [settlementFoundClient, setSettlementFoundClient] = useState<Client | null>(null);
  const [settlementClientSuggestions, setSettlementClientSuggestions] = useState<Client[]>([]);
  const [settlementClientLookupStatus, setSettlementClientLookupStatus] = useState<'idle' | 'matches' | 'selected' | 'not_found' | 'duplicate'>('idle');
  const [settlementSearchingClient, setSettlementSearchingClient] = useState(false);
  const [settlementCreatingClient, setSettlementCreatingClient] = useState(false);
  const [savingSettlement, setSavingSettlement] = useState(false);
  const settlementLookupTimerRef = useRef<number | null>(null);
  const [settlementEditingContractId, setSettlementEditingContractId] = useState<string | null>(null);
  const [syncingUnit, setSyncingUnit] = useState(false);
  const [syncingDebt, setSyncingDebt] = useState(false);
  const [isEditingAgent, setIsEditingAgent] = useState(false);
  const [isPaymentEditorOpen, setIsPaymentEditorOpen] = useState(false);
  const [editingPaymentId, setEditingPaymentId] = useState<string | null>(null);
  const [savingPayment, setSavingPayment] = useState(false);
  const [paymentForm, setPaymentForm] = useState<{
    amount: number;
    payment_date: string;
    payment_method: keyof typeof PAYMENT_METHODS | null;
    transaction_number: string;
    statement: string;
    notes: string;
  }>({
    amount: 0,
    payment_date: new Date().toISOString().split('T')[0],
    payment_method: null,
    transaction_number: '',
    statement: '',
    notes: ''
  });
  const [agentForm, setAgentForm] = useState({
    agent_name: '',
    agent_id_number: '',
    agency_number: '',
    agency_date: '',
    agent_phone: ''
  });
  const [foundClient, setFoundClient] = useState<Client | null>(null);

  const normalizeUsername = (value: string | null | undefined) => {
    if (!value) return '';
    return value.split('@')[0] || value;
  };

  const getContractTypeLabel = (type: string | null | undefined) => {
    if (!type) return null;
    return (CONTRACT_TYPES as Record<string, string>)[type] || type;
  };

  const getContractSnapshot = (contractId: string | null | undefined) => {
    if (!contractId) return null;
    if (selectedContract?.id === contractId) return selectedContract;
    return contracts.find((contract) => contract.id === contractId) || null;
  };

  const getActorInfo = async () => {
    const {
      data: { user },
    } = await supabaseClient.supabase.auth.getUser();

    const actorId = user?.id || null;
    const fallbackName = normalizeUsername(user?.email);
    const employeeEmail = employees.find((e) => e.id === (actorId || ''))?.email;
    const actorName = normalizeUsername(employeeEmail) || fallbackName || '';

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
      const nextMetadata: Record<string, any> = { ...(payload.metadata || {}) };

      const operationAt = String(nextMetadata.operation_at || new Date().toISOString());
      const targetContract = getContractSnapshot(payload.contract_id);
      const contractType = String(
        nextMetadata.contract_type || nextMetadata.type || targetContract?.type || ''
      ).trim();

      nextMetadata.operation_at ??= operationAt;
      nextMetadata.operation_date ??= operationAt.split('T')[0] || operationAt;
      nextMetadata.operation_source ??= 'contracts_page';
      nextMetadata.actor_role ??= role;
      nextMetadata.entity_type ??= payload.entity_type || 'contract';
      nextMetadata.entity_id ??= payload.entity_id || null;
      nextMetadata.contract_id ??= payload.contract_id;

      if (contractType) {
        nextMetadata.contract_type = contractType;
        nextMetadata.contract_type_label ??= getContractTypeLabel(contractType);
      }

      if (targetContract) {
        nextMetadata.project_id ??= targetContract.project_id || null;
        nextMetadata.project_number ??= targetContract.project?.project_number || null;
        nextMetadata.project_name ??= targetContract.project?.name || null;
        nextMetadata.unit_id ??= targetContract.unit_id || null;
        nextMetadata.unit_number ??= targetContract.unit?.unit_number ?? null;
        nextMetadata.client_id ??= targetContract.client_id || null;
        nextMetadata.client_name ??= targetContract.client?.name || targetContract.client_name || null;
        nextMetadata.client_phone ??= targetContract.client?.phone || targetContract.client_phone || null;
        nextMetadata.client_id_number ??= targetContract.client?.id_number || targetContract.client_id_number || null;
        nextMetadata.contract_date ??= targetContract.contract_date || null;
        nextMetadata.contract_status ??= targetContract.status || null;
        nextMetadata.total_amount ??= targetContract.total_amount ?? null;
        nextMetadata.paid_amount ??= targetContract.paid_amount ?? null;
        nextMetadata.remaining_amount ??=
          Math.max((targetContract.total_amount || 0) - (targetContract.paid_amount || 0), 0);
        nextMetadata.is_archived ??= Boolean(targetContract.is_archived);
      }

      const { error } = await supabaseClient.supabase.from('contract_logs').insert({
        contract_id: payload.contract_id,
        actor_id: actorId,
        actor_name: actorName || null,
        action: payload.action,
        entity_type: payload.entity_type || 'contract',
        entity_id: payload.entity_id || null,
        metadata: Object.keys(nextMetadata).length > 0 ? nextMetadata : null,
      });
      if (error) throw error;
    } catch (error) {
      console.error('Error logging contract event:', error);
    }
  };

  const getAttachmentFileType = (file: File): 'pdf' | 'image' | null => {
    const mime = String(file.type || '').toLowerCase();
    if (mime === 'application/pdf') return 'pdf';
    if (mime.startsWith('image/')) return 'image';
    const name = String(file.name || '').toLowerCase();
    if (name.endsWith('.pdf')) return 'pdf';
    if (/\.(png|jpe?g|webp|gif|bmp)$/i.test(name)) return 'image';
    return null;
  };

  const buildAttachmentPath = (p: {
    contractId: string;
    category: ContractAttachmentCategory;
    fileName: string;
  }) => {
    const ext = p.fileName.includes('.') ? p.fileName.split('.').pop() || 'bin' : 'bin';
    const safeExt = ext.replace(/[^a-zA-Z0-9]/g, '').toLowerCase() || 'bin';
    const random = Math.random().toString(36).slice(2, 8);
    return `contracts/${p.contractId}/attachments/${p.category}/${Date.now()}-${random}.${safeExt}`;
  };

  const updateContractAttachmentsState = (contractId: string, attachments: ContractAttachment[]) => {
    setSelectedContract((prev) => (prev && prev.id === contractId ? { ...prev, attachments } : prev));
    setContracts((prev) => prev.map((contract) => (
      contract.id === contractId ? { ...contract, attachments } : contract
    )));
  };

  const loadContractAttachments = async (contractId: string) => {
    setLoadingAttachments(true);
    try {
      const { data, error } = await supabaseClient.supabase
        .from('contract_attachments')
        .select('*')
        .eq('contract_id', contractId)
        .order('created_at', { ascending: true });

      if (error) {
        const msg = String(error.message || '').toLowerCase();
        if (msg.includes('does not exist') || msg.includes('relation')) {
          updateContractAttachmentsState(contractId, []);
          return;
        }
        throw error;
      }

      updateContractAttachmentsState(contractId, ((data || []) as ContractAttachment[]));
    } catch (error) {
      console.error('Error loading contract attachments:', error);
    } finally {
      setLoadingAttachments(false);
    }
  };

  const getContractAttachmentUrl = async (attachment: ContractAttachment) => {
    if (attachment.file_path) {
      const { data, error } = await supabaseClient.supabase
        .storage
        .from('project-files')
        .createSignedUrl(attachment.file_path, 60 * 60);
      if (!error && data?.signedUrl) return data.signedUrl;
    }
    return attachment.file_url;
  };

  const uploadContractAttachment = async (category: ContractAttachmentCategory, file: File) => {
    if (!selectedContract) return;

    const fileType = getAttachmentFileType(file);
    if (!fileType) {
      alert('المسموح فقط: ملفات PDF أو الصور.');
      return;
    }

    setUploadingAttachmentCategory(category);
    let uploadedFilePath: string | null = null;
    try {
      const filePath = buildAttachmentPath({
        contractId: selectedContract.id,
        category,
        fileName: file.name,
      });

      const { error: uploadError } = await supabaseClient.supabase
        .storage
        .from('project-files')
        .upload(filePath, file, { upsert: false });
      if (uploadError) throw uploadError;
      uploadedFilePath = filePath;

      const publicUrl = supabaseClient.supabase
        .storage
        .from('project-files')
        .getPublicUrl(filePath).data.publicUrl;

      const payload = {
        contract_id: selectedContract.id,
        category,
        file_name: file.name,
        file_type: fileType,
        mime_type: file.type || null,
        file_url: publicUrl,
        file_path: filePath,
      };

      const { data, error } = await supabaseClient.supabase
        .from('contract_attachments')
        .insert([payload])
        .select('*')
        .single();
      if (error) throw error;

      const nextAttachments = [...(selectedContract.attachments || []), data as ContractAttachment];
      updateContractAttachmentsState(selectedContract.id, nextAttachments);
      await logContractEvent({
        contract_id: selectedContract.id,
        action: 'contract_updated',
        entity_type: 'contract_attachment',
        entity_id: (data as ContractAttachment).id,
        metadata: {
          contract_type: selectedContract.type,
          attachment_category: category,
          attachment_category_label: CONTRACT_ATTACHMENT_LABELS[category],
          attachment_file_name: file.name,
          attachment_file_type: fileType,
        }
      });
    } catch (error: any) {
      if (uploadedFilePath) {
        await supabaseClient.supabase.storage.from('project-files').remove([uploadedFilePath]);
      }
      console.error('Error uploading contract attachment:', error);
      alert(error?.message || 'تعذر رفع المرفق');
    } finally {
      setUploadingAttachmentCategory(null);
    }
  };

  const openContractAttachment = async (attachment: ContractAttachment) => {
    setOpeningAttachmentId(attachment.id);
    try {
      const url = await getContractAttachmentUrl(attachment);
      window.open(url, '_blank', 'noopener,noreferrer');
    } catch (error) {
      console.error('Error opening contract attachment:', error);
      alert('تعذر فتح الملف');
    } finally {
      setOpeningAttachmentId(null);
    }
  };

  const deleteContractAttachment = async (attachment: ContractAttachment) => {
    if (!selectedContract) return;
    const ok = window.confirm(`هل تريد حذف المرفق "${attachment.file_name}"؟`);
    if (!ok) return;

    setDeletingAttachmentId(attachment.id);
    try {
      if (attachment.file_path) {
        await supabaseClient.supabase.storage.from('project-files').remove([attachment.file_path]);
      }

      const { error } = await supabaseClient.supabase
        .from('contract_attachments')
        .delete()
        .eq('id', attachment.id);
      if (error) throw error;

      const nextAttachments = (selectedContract.attachments || []).filter((item) => item.id !== attachment.id);
      updateContractAttachmentsState(selectedContract.id, nextAttachments);
    } catch (error: any) {
      console.error('Error deleting contract attachment:', error);
      alert(error?.message || 'تعذر حذف المرفق');
    } finally {
      setDeletingAttachmentId(null);
    }
  };

  const mapContractToPrintData = (contract: FullContract) => {
    // تحويل التاريخ الميلادي إلى هجري بسيط (يمكن تحسينه لاحقاً)
    const getHijriDate = (dateStr: string) => {
      try {
        const date = new Date(dateStr);
        return date.toLocaleDateString('ar-SA-u-ca-islamic-umalqura');
      } catch {
        return '';
      }
    };

    // Build agent data if agent name exists
    const agent = contract.agent_name ? {
      name: contract.agent_name,
      id: contract.agent_id_number || '',
      agencyNumber: contract.agency_number || '',
      agencyDate: contract.agency_date || ''
    } : undefined;

    return {
      contractId: contract.id,
      projectNumber: contract.project?.project_number || '',
      unitNumber: contract.unit?.unit_number?.toString() || '',
      clientName: contract.client?.name || contract.client_name || '',
      clientId: contract.client?.id_number || contract.client_id_number || '',
      clientPhone: contract.client?.phone || contract.client_phone || '',
      createdByName:
        contract.created_by_name ||
        employees.find((e) => e.id === (contract.created_by_id || ''))?.email ||
        '',
      createdAt: contract.created_at || '',
      totalAmount: contract.total_amount,
      deliveryMonths: contract.completion_period_months || 18,
      deliveryDays: contract.payment_grace_period_months || 60, // الحقل يمثل الأيام مباشرة
      gregorianDate: contract.contract_date,
      hijriDate: getHijriDate(contract.contract_date),
      city: contract.project?.location_text?.split(',')[0] || 'جدة',
      district: contract.project?.location_text?.split(',')[1] || 'النزهة',
      floor: contract.unit?.floor_label || '',
      deedNumber: contract.project?.deed_number || contract.unit?.deed_number || '',
      planNumber: contract.project?.plan_number || '',
      direction: contract.unit?.direction_label || '',
      description: contract.unit?.description || '',
      regionNumber: contract.project?.plot_number || '',
      area: contract.unit?.area_sqm || 0,
      payments: (contract.payments || []).map(p => ({
        transactionType: p.payment_method ? PAYMENT_METHODS[p.payment_method] : '',
        date: p.payment_date,
        cod: p.transaction_number || '',
        amount: p.amount,
        description: p.statement || p.notes || ''
      })),
      attachments: contract.attachments || [],
      agent
    };
  };

  const handlePrintContract = (contract: FullContract) => {
    console.log('🖨️ handlePrintContract called with:', contract);
    setSelectedContract(contract);
    setShowPrintModal(true);
    console.log('✅ showPrintModal set to true');
    logContractEvent({
      contract_id: contract.id,
      action: 'contract_printed',
      entity_type: 'contract',
      entity_id: contract.id,
      metadata: {
        contract_type: contract.type,
        print_target: 'under_construction',
        print_template: 'printcontrect',
        project_id: contract.project_id,
        unit_id: contract.unit_id,
        project_number: contract.project?.project_number || null,
        unit_number: contract.unit?.unit_number ?? null,
        client_name: contract.client?.name || contract.client_name || null,
      }
    });
  };

  const saveResaleContract = async () => {
    if (!resaleSourceContract) {
      alert('يرجى اختيار عقد تحت الإنشاء أولاً');
      return;
    }
    if (resaleSourceContract.resale_contract_id && !isAdmin) {
      alert('غير مصرح');
      return;
    }
    const agreed = Number(resaleAgreedAmount);
    const resaleFeeValue = Number(resaleFee);
    const marketingFeeValue = Number(resaleMarketingFee);
    const companyFeeValue = Number(resaleCompanyFee);
    const lawyerFeeValue = Number(resaleLawyerFee);

    if (!Number.isFinite(agreed) || agreed <= 0) {
      alert('يرجى إدخال مبلغ البيع المتفق عليه بشكل صحيح');
      return;
    }
    if (![resaleFeeValue, marketingFeeValue, companyFeeValue, lawyerFeeValue].every((v) => Number.isFinite(v) && v >= 0)) {
      alert('يرجى التأكد من إدخال الرسوم بشكل صحيح');
      return;
    }
    if (!resaleSourceContract.project_id || !resaleSourceContract.unit_id) {
      alert('بيانات العقد المختار غير مكتملة (المشروع/الوحدة)');
      return;
    }

    try {
      setSavingResale(true);
      const nowIso = new Date().toISOString();
      const today = nowIso.split('T')[0];
      const { actorId, actorName } = await getActorInfo();

      const resalePayload = {
        project_id: resaleSourceContract.project_id,
        unit_id: resaleSourceContract.unit_id,
        client_id: resaleSourceContract.client_id ?? null,
        contract_date: today,
        status: 'active' as const,
        type: 'resale' as const,
        total_amount: agreed,
        paid_amount: 0,
        completion_period_months: resaleSourceContract.completion_period_months || 12,
        payment_grace_period_months: resaleSourceContract.payment_grace_period_months ?? null,
        client_name: resaleSourceContract.client?.name || resaleSourceContract.client_name || null,
        client_id_number: resaleSourceContract.client?.id_number || resaleSourceContract.client_id_number || null,
        client_phone: resaleSourceContract.client?.phone || resaleSourceContract.client_phone || null,
        created_by_id: actorId,
        created_by_name: actorName || null,
        source_contract_id: resaleSourceContract.id,
        resale_agreed_amount: agreed,
        resale_fee: resaleFeeValue,
        marketing_fee: marketingFeeValue,
        company_service_fee: companyFeeValue,
        lawyer_fee: lawyerFeeValue,
      };

      const existingResaleId = resaleSourceContract.resale_contract_id || null;
      let resaleId = existingResaleId;

      if (existingResaleId) {
        const { error: updateError } = await supabaseClient.supabase
          .from('contracts')
          .update(resalePayload)
          .eq('id', existingResaleId);
        if (updateError) throw updateError;
      } else {
        const { data: createdResale, error: createError } = await supabaseClient.supabase
          .from('contracts')
          .insert(resalePayload)
          .select('*')
          .single();
        if (createError) throw createError;
        if (!createdResale?.id) throw new Error('تعذر إنشاء عقد إعادة البيع');
        resaleId = createdResale.id;
      }

      if (!resaleId) throw new Error('تعذر حفظ عقد إعادة البيع');

      const { error: linkError } = await supabaseClient.supabase
        .from('contracts')
        .update({
          resale_contract_id: resaleId,
          resale_signed_at: nowIso,
        })
        .eq('id', resaleSourceContract.id);
      if (linkError) throw linkError;

      const { error: unitUpdateError } = await supabaseClient.supabase
        .from('units')
        .update({
          status: 'for_resale',
          resale_fee: resaleFeeValue,
          marketing_fee: marketingFeeValue,
          company_fee: companyFeeValue,
          lawyer_fee: lawyerFeeValue,
          resale_agreed_amount: agreed,
          resale_saved_at: nowIso,
        })
        .eq('id', resaleSourceContract.unit_id);
      if (unitUpdateError) throw unitUpdateError;

      await logContractEvent({
        contract_id: resaleId,
        action: existingResaleId ? 'contract_updated' : 'contract_created',
        entity_type: 'contract',
        entity_id: resaleId,
        metadata: {
          contract_type: 'resale',
          mode: existingResaleId ? 'edit' : 'create',
          source_contract_id: resaleSourceContract.id,
          source_contract_type: resaleSourceContract.type,
          project_id: resaleSourceContract.project_id,
          project_number: resaleSourceContract.project?.project_number || null,
          project_name: resaleSourceContract.project?.name || null,
          unit_id: resaleSourceContract.unit_id,
          unit_number: resaleSourceContract.unit?.unit_number ?? null,
          client_id: resaleSourceContract.client_id || null,
          client_name: resaleSourceContract.client?.name || resaleSourceContract.client_name || null,
          agreed_amount: agreed,
          resale_fee: resaleFeeValue,
          marketing_fee: marketingFeeValue,
          company_fee: companyFeeValue,
          lawyer_fee: lawyerFeeValue,
          unit_status_after: 'for_resale',
          linked_at: nowIso,
        },
      });

      await logContractEvent({
        contract_id: resaleSourceContract.id,
        action: 'contract_updated',
        entity_type: 'contract',
        entity_id: resaleSourceContract.id,
        metadata: {
          contract_type: resaleSourceContract.type,
          resale_contract_id: resaleId,
          resale_signed_at: nowIso,
          linked_contract_type: 'resale',
          linked_contract_type_label: getContractTypeLabel('resale'),
        },
      });

      await loadContracts();
      setShowResaleWizard(false);
      alert(existingResaleId ? 'تم تحديث عقد إعادة البيع وحفظ الرسوم' : 'تم إنشاء عقد إعادة البيع وتحديث الوحدة وحفظ الرسوم');
      setActiveContractTypeFilter('resale');
    } catch (error: any) {
      console.error('Error creating resale contract:', error);
      alert('حدث خطأ أثناء إنشاء عقد إعادة البيع: ' + (error?.message || ''));
    } finally {
      setSavingResale(false);
    }
  };

  const deleteResaleContract = async (baseContract: FullContract) => {
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    const resaleId = baseContract.resale_contract_id;
    if (!resaleId) {
      alert('لا يوجد عقد إعادة بيع مرتبط بهذا العقد');
      return;
    }

    const settlementExists = contracts.some(
      (c) => c.type === 'financial_settlement' && (c as any).settlement_resale_contract_id === resaleId
    );
    if (settlementExists) {
      alert('لا يمكن حذف عقد إعادة البيع لوجود عقد تسوية مالية مرتبط به');
      return;
    }
    const ok = window.confirm('هل أنت متأكد من حذف عقد إعادة البيع المرتبط؟');
    if (!ok) return;

    try {
      setLoading(true);
      const { error: deleteError } = await supabaseClient.supabase.from('contracts').delete().eq('id', resaleId);
      if (deleteError) throw deleteError;

      const { error: unlinkError } = await supabaseClient.supabase
        .from('contracts')
        .update({ resale_contract_id: null, resale_signed_at: null })
        .eq('id', baseContract.id);
      if (unlinkError) throw unlinkError;

      const { error: unitUpdateError } = await supabaseClient.supabase
        .from('units')
        .update({
          status: 'pending_sale',
          resale_fee: null,
          marketing_fee: null,
          company_fee: null,
          lawyer_fee: null,
          resale_agreed_amount: null,
          resale_saved_at: null,
        })
        .eq('id', baseContract.unit_id);
      if (unitUpdateError) throw unitUpdateError;

      await logContractEvent({
        contract_id: baseContract.id,
        action: 'contract_updated',
        entity_type: 'contract',
        entity_id: baseContract.id,
        metadata: {
          contract_type: baseContract.type,
          resale_contract_id: null,
          unlinked_resale_contract_id: resaleId,
          unit_status_after: 'pending_sale',
          resale_fees_cleared: true,
        },
      });

      await logContractEvent({
        contract_id: resaleId,
        action: 'contract_deleted',
        entity_type: 'contract',
        entity_id: resaleId,
        metadata: {
          contract_type: 'resale',
          source_contract_id: baseContract.id,
          source_contract_type: baseContract.type,
          unit_id: baseContract.unit_id,
          unit_number: baseContract.unit?.unit_number ?? null,
          deleted_reason: 'manual_delete',
          unit_status_after: 'pending_sale',
        },
      });

      await loadContracts();
      setSelectedContract(null);
      alert('تم حذف عقد إعادة البيع وفك الارتباط');
    } catch (error: any) {
      console.error('Error deleting resale contract:', error);
      alert('حدث خطأ أثناء حذف عقد إعادة البيع: ' + (error?.message || ''));
    } finally {
      setLoading(false);
    }
  };

  const deleteSettlementContract = async (baseContract: FullContract, settlementContract: FullContract) => {
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    const settlementId = settlementContract.id;
    if (!settlementId) {
      alert('لا يوجد عقد تسوية');
      return;
    }

    const ok = window.confirm('هل أنت متأكد من حذف عقد التسوية المالية؟');
    if (!ok) return;

    try {
      setLoading(true);

      const { error: deleteError } = await supabaseClient.supabase.from('contracts').delete().eq('id', settlementId);
      if (deleteError) throw deleteError;

      const { error: unlinkError } = await supabaseClient.supabase
        .from('contracts')
        .update({
          financial_settlement_contract_id: null,
          financial_settlement_signed_at: null,
          settlement_new_client_id: null,
          settlement_new_client_applied_at: null,
          settlement_new_owner_name: null,
          settlement_new_owner_id_number: null,
          settlement_new_owner_phone: null,
        })
        .eq('id', baseContract.id);
      if (unlinkError) throw unlinkError;

      const { error: unitUpdateError } = await supabaseClient.supabase
        .from('units')
        .update({
          status: 'for_resale',
          current_client_id: null,
          title_deed_owner: null,
          title_deed_owner_id: null,
          title_deed_owner_phone: null,
        })
        .eq('id', baseContract.unit_id);
      if (unitUpdateError) throw unitUpdateError;

      await logContractEvent({
        contract_id: baseContract.id,
        action: 'contract_updated',
        entity_type: 'contract',
        entity_id: baseContract.id,
        metadata: {
          contract_type: baseContract.type,
          financial_settlement_contract_id: null,
          removed_settlement_contract_id: settlementId,
          unit_status_after: 'for_resale',
          settlement_client_cleared: true,
        },
      });

      await logContractEvent({
        contract_id: settlementId,
        action: 'contract_deleted',
        entity_type: 'contract',
        entity_id: settlementId,
        metadata: {
          contract_type: 'financial_settlement',
          source_contract_id: baseContract.id,
          resale_contract_id: (settlementContract as any).settlement_resale_contract_id || null,
          unit_id: baseContract.unit_id,
          unit_number: baseContract.unit?.unit_number ?? null,
          deleted_reason: 'manual_delete',
          unit_status_after: 'for_resale',
        },
      });

      await loadContracts();
      setSelectedContract(null);
      alert('تم حذف عقد التسوية المالية وفك الارتباط');
    } catch (error: any) {
      console.error('Error deleting settlement contract:', error);
      alert('حدث خطأ أثناء حذف عقد التسوية المالية: ' + (error?.message || ''));
    } finally {
      setLoading(false);
    }
  };

  const deleteWaiverContract = async (baseContract: FullContract, waiverContract: FullContract) => {
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    const waiverId = waiverContract.id;
    if (!waiverId) {
      alert('لا يوجد عقد تنازل');
      return;
    }

    const ok = window.confirm('هل أنت متأكد من حذف عقد التنازل وإرجاع العميل السابق؟');
    if (!ok) return;

    try {
      setLoading(true);

      const normalize = (value: string | null | undefined) => String(value || '').trim();

      const { data: latestWaiver, error: waiverFetchError } = await supabaseClient.supabase
        .from('contracts')
        .select(`
          id,
          source_contract_id,
          waived_previous_client_id,
          waived_previous_client_name,
          waived_previous_client_id_number,
          waived_previous_client_phone,
          waived_to_client_id,
          waived_to_client_name,
          waived_to_client_id_number,
          waived_to_client_phone
        `)
        .eq('id', waiverId)
        .eq('type', 'waiver')
        .single();
      if (waiverFetchError) throw waiverFetchError;
      if (!latestWaiver?.id) throw new Error('تعذر قراءة أحدث بيانات عقد التنازل');

      const sourceContractId = String((latestWaiver as any).source_contract_id || '').trim();
      if (!sourceContractId || sourceContractId !== baseContract.id) {
        throw new Error('مرجع عقد التنازل لا يطابق عقد تحت الإنشاء المتوقع');
      }

      const { data: latestBase, error: baseFetchError } = await supabaseClient.supabase
        .from('contracts')
        .select(`
          id,
          unit_id,
          is_archived,
          is_waived,
          resale_contract_id,
          financial_settlement_contract_id,
          client_id,
          client_name,
          client_id_number,
          client_phone,
          waived_to_client_id,
          waived_to_client_name,
          waived_to_client_id_number,
          waived_to_client_phone
        `)
        .eq('id', sourceContractId)
        .single();
      if (baseFetchError) throw baseFetchError;
      if (!latestBase?.id) throw new Error('تعذر قراءة أحدث بيانات عقد تحت الإنشاء');

      const { data: latestUnit, error: unitFetchError } = await supabaseClient.supabase
        .from('units')
        .select('id, client_name, client_id_number, client_phone')
        .eq('id', (latestBase as any).unit_id)
        .single();
      if (unitFetchError) throw unitFetchError;

      if (Boolean((latestBase as any).is_archived)) {
        throw new Error('لا يمكن حذف التنازل لأن عقد تحت الإنشاء مؤرشف حاليًا');
      }
      if (Boolean((latestBase as any).resale_contract_id)) {
        throw new Error('لا يمكن حذف التنازل لوجود عقد إعادة بيع مرتبط بالعقد الأصلي');
      }
      if (Boolean((latestBase as any).financial_settlement_contract_id)) {
        throw new Error('لا يمكن حذف التنازل لوجود عقد تسوية مالية مرتبط بالعقد الأصلي');
      }
      if (!Boolean((latestBase as any).is_waived)) {
        throw new Error('العقد الأصلي ليس في حالة تنازل حاليًا، لذلك تم إيقاف الحذف الآمن');
      }

      const expectedCurrentClientId = normalize((latestWaiver as any).waived_to_client_id);
      const expectedCurrentIdNumber = normalize((latestWaiver as any).waived_to_client_id_number);
      const expectedCurrentName = normalize((latestWaiver as any).waived_to_client_name);

      const baseCurrentClientId = normalize((latestBase as any).client_id);
      const baseCurrentIdNumber = normalize((latestBase as any).client_id_number);
      const baseCurrentName = normalize((latestBase as any).client_name);
      const baseTrackedWaivedToClientId = normalize((latestBase as any).waived_to_client_id);
      const baseTrackedWaivedToIdNumber = normalize((latestBase as any).waived_to_client_id_number);
      const unitCurrentIdNumber = normalize((latestUnit as any).client_id_number);
      const unitCurrentName = normalize((latestUnit as any).client_name);

      if (expectedCurrentClientId && baseCurrentClientId && expectedCurrentClientId !== baseCurrentClientId) {
        throw new Error('تم تغيير العميل الحالي في العقد الأصلي بعد التنازل، لذلك تم إيقاف الحذف الآمن');
      }
      if (expectedCurrentIdNumber && baseCurrentIdNumber && expectedCurrentIdNumber !== baseCurrentIdNumber) {
        throw new Error('هوية العميل الحالية في العقد الأصلي لا تطابق المتنازل له، لذلك تم إيقاف الحذف الآمن');
      }
      if (expectedCurrentClientId && baseTrackedWaivedToClientId && expectedCurrentClientId !== baseTrackedWaivedToClientId) {
        throw new Error('بيانات التنازل المخزنة في العقد الأصلي تغيّرت، لذلك تم إيقاف الحذف الآمن');
      }
      if (expectedCurrentIdNumber && baseTrackedWaivedToIdNumber && expectedCurrentIdNumber !== baseTrackedWaivedToIdNumber) {
        throw new Error('هوية المتنازل له المخزنة في العقد الأصلي لا تطابق عقد التنازل، لذلك تم إيقاف الحذف الآمن');
      }
      if (expectedCurrentIdNumber && unitCurrentIdNumber && expectedCurrentIdNumber !== unitCurrentIdNumber) {
        throw new Error('بيانات العميل الحالية في الوحدة لا تطابق المتنازل له، لذلك تم إيقاف الحذف الآمن');
      }
      if (expectedCurrentName && baseCurrentName && expectedCurrentName !== baseCurrentName && expectedCurrentIdNumber === '') {
        throw new Error('اسم العميل الحالي في العقد الأصلي لا يطابق المتنازل له، لذلك تم إيقاف الحذف الآمن');
      }
      if (expectedCurrentName && unitCurrentName && expectedCurrentName !== unitCurrentName && expectedCurrentIdNumber === '') {
        throw new Error('اسم العميل الحالي في الوحدة لا يطابق المتنازل له، لذلك تم إيقاف الحذف الآمن');
      }

      const previousClientId = (latestWaiver as any).waived_previous_client_id || null;
      const previousClientName = (latestWaiver as any).waived_previous_client_name || null;
      const previousClientIdNumber = (latestWaiver as any).waived_previous_client_id_number || null;
      const previousClientPhone = (latestWaiver as any).waived_previous_client_phone || null;

      const { error: baseUpdateError } = await supabaseClient.supabase
        .from('contracts')
        .update({
          is_waived: false,
          waived_at: null,
          waived_previous_client_id: null,
          waived_previous_client_name: null,
          waived_previous_client_id_number: null,
          waived_previous_client_phone: null,
          waived_to_client_id: null,
          waived_to_client_name: null,
          waived_to_client_id_number: null,
          waived_to_client_phone: null,
          client_id: previousClientId,
          client_name: previousClientName,
          client_id_number: previousClientIdNumber,
          client_phone: previousClientPhone,
        })
        .eq('id', sourceContractId);
      if (baseUpdateError) throw baseUpdateError;

      const { error: unitUpdateError } = await supabaseClient.supabase
        .from('units')
        .update({
          client_name: previousClientName || '',
          client_id_number: previousClientIdNumber,
          client_phone: previousClientPhone,
        })
        .eq('id', (latestBase as any).unit_id);
      if (unitUpdateError) throw unitUpdateError;

      const { error: debtUpdateError } = await supabaseClient.supabase
        .from('debts')
        .update({
          original_client_name: previousClientName,
          original_client_phone: previousClientPhone,
          original_client_id: previousClientIdNumber,
        })
        .eq('unit_id', (latestBase as any).unit_id);
      if (debtUpdateError) throw debtUpdateError;

      const { error: deleteError } = await supabaseClient.supabase.from('contracts').delete().eq('id', waiverId);
      if (deleteError) throw deleteError;

      await logContractEvent({
        contract_id: sourceContractId,
        action: 'contract_updated',
        entity_type: 'contract',
        entity_id: sourceContractId,
        metadata: {
          contract_type: baseContract.type,
          is_waived: false,
          removed_waiver_contract_id: waiverId,
          restored_previous_client_id: previousClientId,
          restored_previous_client_name: previousClientName,
          restored_previous_client_id_number: previousClientIdNumber,
          restored_previous_client_phone: previousClientPhone,
          safety_verified: true,
          debt_restored: true,
        },
      });

      await logContractEvent({
        contract_id: waiverId,
        action: 'contract_deleted',
        entity_type: 'contract',
        entity_id: waiverId,
        metadata: {
          contract_type: 'waiver',
          source_contract_id: sourceContractId,
          restored_previous_client_id: previousClientId,
          restored_previous_client_name: previousClientName,
          deleted_reason: 'safe_delete',
          safety_verified: true,
        },
      });

      await loadContracts();
      setSelectedContract(null);
      alert('تم حذف عقد التنازل وإرجاع العميل السابق');
    } catch (error: any) {
      console.error('Error deleting waiver contract:', error);
      alert('حدث خطأ أثناء حذف عقد التنازل: ' + (error?.message || ''));
    } finally {
      setLoading(false);
    }
  };

  const mapResaleToPrintData = (baseContract: FullContract, resaleContract: FullContract) => {
    const locationText = baseContract.project?.location_text || '';
    const [cityRaw, districtRaw] = locationText.split(',').map((v) => v.trim());
    const createdAtDetailed = resaleContract.created_at ? new Date(resaleContract.created_at).toISOString().replace('T', ' ').slice(0, 19) : '';

    return {
      projectNumber: baseContract.project?.project_number || '',
      projectName: baseContract.project?.name || '',
      unitNumber: baseContract.unit?.unit_number != null ? String(baseContract.unit.unit_number) : '',
      floorNumber: baseContract.unit?.floor_label || '',
      city: cityRaw || 'جدة',
      district: districtRaw || 'النزهة',
      direction: baseContract.unit?.direction_label || '',
      notificationDate: resaleContract.contract_date || '',
      clientName: baseContract.client?.name || baseContract.client_name || '',
      clientId: baseContract.client?.id_number || baseContract.client_id_number || '',
      companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
      companyId: '7027279632',
      currentBuyerName: baseContract.client?.name || baseContract.client_name || '',
      currentBuyerId: baseContract.client?.id_number || baseContract.client_id_number || '',
      secondPartyAgentName: baseContract.agent_name || undefined,
      secondPartyAgentIdNumber: baseContract.agent_id_number || undefined,
      secondPartyAgencyNumber: baseContract.agency_number || undefined,
      secondPartyAgencyDate: baseContract.agency_date || undefined,
      waiverAmount: resaleContract.resale_fee ?? undefined,
      salePrice: resaleContract.resale_agreed_amount ?? resaleContract.total_amount ?? undefined,
      marketingFee: (resaleContract as any).marketing_fee ?? undefined,
      companyServiceFee: (resaleContract as any).company_service_fee ?? undefined,
      lawyerFee: (resaleContract as any).lawyer_fee ?? undefined,
      newBuyerName: undefined,
      newBuyerId: undefined,
      createdByName: resaleContract.created_by_name || undefined,
      createdAtDetailed: createdAtDetailed || undefined,
    };
  };

  const mapSettlementToPrintData = (baseContract: FullContract, settlementContract: FullContract) => {
    const normalizeDate = (value: string | null | undefined) => {
      const v = String(value || '').trim();
      if (!v) return '';
      const match = v.match(/^(\d{4})-(\d{2})-(\d{2})/);
      if (!match) return v;
      return `${match[3]}-${match[2]}-${match[1]}`;
    };

    const plotNumber = (() => {
      const plot = String((baseContract.project as any)?.plot_number || '').trim();
      const plan = String((baseContract.project as any)?.plan_number || '').trim();
      if (plot && plan) return `${plot} / ${plan}`;
      return plot || plan || String((baseContract.unit as any)?.deed_number || '').trim() || '—';
    })();

    const createdAtDetailed = settlementContract.created_at
      ? new Date(settlementContract.created_at).toISOString().replace('T', ' ').slice(0, 19)
      : '';

    const settlementDateValue = (settlementContract as any).settlement_date || settlementContract.contract_date || '';
    const salePriceRaw = (settlementContract as any).settlement_sale_price;
    const salePriceValue = salePriceRaw != null ? salePriceRaw : settlementContract.total_amount;

    return {
      date: normalizeDate(settlementDateValue),
      projectNumber: baseContract.project?.project_number || '',
      companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
      companyUnifiedNumber: '920007936',
      secondPartyName: baseContract.client?.name || baseContract.client_name || '',
      secondPartyId: baseContract.client?.id_number || baseContract.client_id_number || '',
      secondPartyPhone: baseContract.client?.phone || baseContract.client_phone || '',
      secondPartyAgentName: baseContract.agent_name || undefined,
      secondPartyAgentIdNumber: baseContract.agent_id_number || undefined,
      secondPartyAgencyNumber: baseContract.agency_number || undefined,
      secondPartyAgencyDate: baseContract.agency_date || undefined,
      previousContractDate: baseContract.contract_date || '',
      unitNumber: baseContract.unit?.unit_number ?? '',
      unitDirectionDescription: baseContract.unit?.direction_label || baseContract.unit?.description || '',
      plotNumber,
      salePrice: salePriceValue ?? 0,
      saleDate: normalizeDate(settlementDateValue),
      newOwnerName: String((settlementContract as any).settlement_new_owner_name || '').trim(),
      newOwnerId: String((settlementContract as any).settlement_new_owner_id_number || '').trim(),
      createdByName: settlementContract.created_by_name || undefined,
      createdAtDetailed: createdAtDetailed || undefined,
    };
  };

  const mapWaiverToPrintData = (baseContract: FullContract, waiverContract: FullContract) => {
    const locationText = baseContract.project?.location_text || '';
    const [cityRaw, districtRaw] = locationText.split(',').map((v) => v.trim());
    const createdAtDetailed = waiverContract.created_at
      ? new Date(waiverContract.created_at).toISOString().replace('T', ' ').slice(0, 19)
      : '';

    const normalizeDate = (value: string | null | undefined) => {
      const v = String(value || '').trim();
      if (!v) return '';
      const match = v.match(/^(\d{4})-(\d{2})-(\d{2})/);
      if (!match) return v;
      return `${match[3]} - ${match[2]} - ${match[1]}`;
    };

    return {
      projectNumber: baseContract.project?.project_number || '',
      projectName: baseContract.project?.name || '',
      unitNumber: baseContract.unit?.unit_number != null ? String(baseContract.unit.unit_number) : '',
      date: normalizeDate(waiverContract.contract_date),
      clientName:
        String((waiverContract as any).waived_previous_client_name || '').trim() ||
        baseContract.client?.name ||
        baseContract.client_name ||
        '',
      clientId:
        String((waiverContract as any).waived_previous_client_id_number || '').trim() ||
        baseContract.client?.id_number ||
        baseContract.client_id_number ||
        '',
      clientPhone:
        String((waiverContract as any).waived_previous_client_phone || '').trim() ||
        baseContract.client?.phone ||
        baseContract.client_phone ||
        '',
      city: cityRaw || 'جدة',
      district: districtRaw || 'النزهة',
      floorNumber: baseContract.unit?.floor_label || '',
      direction: baseContract.unit?.direction_label || baseContract.unit?.description || '',
      companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
      companyId: '7027279632',
      contractDate: baseContract.contract_date || '',
      transfereeName: String((waiverContract as any).waived_to_client_name || '').trim() || '—',
      transfereeId: String((waiverContract as any).waived_to_client_id_number || '').trim() || '—',
      createdByName: waiverContract.created_by_name || undefined,
      createdAtDetailed: createdAtDetailed || undefined,
    };
  };

  const mapDeedToPrintData = (baseContract: FullContract, deedContract: FullContract) => {
    const locationText = baseContract.project?.location_text || '';
    const [cityRaw, districtRaw] = locationText.split(',').map((v) => v.trim());
    const createdAtDetailed = deedContract.created_at
      ? new Date(deedContract.created_at).toISOString().replace('T', ' ').slice(0, 19)
      : '';

    const recipientName =
      String((deedContract as any).deed_recipient_name || '').trim() ||
      deedContract.client?.name ||
      deedContract.client_name ||
      '';
    const recipientId =
      String((deedContract as any).deed_recipient_id_number || '').trim() ||
      deedContract.client?.id_number ||
      deedContract.client_id_number ||
      '';

    return {
      projectNumber: baseContract.project?.project_number || '',
      projectName: baseContract.project?.name || '',
      unitNumber: baseContract.unit?.unit_number != null ? String(baseContract.unit.unit_number) : '',
      date: deedContract.contract_date || '',
      clientName: recipientName,
      clientId: recipientId,
      city: cityRaw || 'جدة',
      district: districtRaw || 'النزهة',
      planNumber: baseContract.project?.plan_number || '',
      deedNumber:
        String((deedContract as any).deed_unit_deed_number || '').trim() ||
        String(baseContract.unit?.deed_number || '').trim() ||
        '',
      regionNumber: baseContract.project?.plot_number || '',
      floorNumber: baseContract.unit?.floor_label || '',
      direction: baseContract.unit?.direction_label || baseContract.unit?.description || '',
      electricityMeter: String((deedContract as any).deed_meter_number || '').trim(),
      companyName: 'شركة مساكن الرفاهية للمقاولات العامة',
      companyId: '7027279632',
      ownerName: recipientName,
      agentName: baseContract.agent_name || undefined,
      agentIdNumber: baseContract.agent_id_number || undefined,
      agencyNumber: baseContract.agency_number || undefined,
      agencyDate: baseContract.agency_date || undefined,
      createdByName: deedContract.created_by_name || undefined,
      createdAtDetailed: createdAtDetailed || undefined,
      notes: String((deedContract as any).deed_parking_number || '').trim()
        ? `رقم الموقف: ${(deedContract as any).deed_parking_number}`
        : undefined,
      obligations: [
        'لا يحق لي القيام بأي تعديلات على الهيكل الإنشائي أو إحداث أي تغييرات أو تشويه للواجهات.',
        'لا يحق لي التصرف في الأجزاء المشتركة بين جميع الملاك في العمارة إلا وفق الأنظمة المعتمدة.',
        'لا يحق لي المطالبة بأي جزء من الأسطح السفلية أو العلوية للعمارة أو استخدامها دون حق نظامي.',
        'ألتزم بنقل ملكية عداد الكهرباء الخاص بالشقة باسمي بعد الإفراغ مباشرة وأكون مسؤولاً عن فواتيره من تاريخ هذا المحضر.',
        'أتعهد منفرداً ومجتمعاً مع ملاك الشقق الأخرى بنقل عدادات الخدمات والمياه باسم ممثل لجنة الملاك عند الحاجة.',
        'لا يحق لي استخدام المصعد في نقل الأثاث بما يسبب تلفه أو الإضرار بمرافق المبنى.',
        'ألتزم بسداد ما تحتاجه العمارة من مصروفات الصيانة والنظافة والمياه والحراسة وفق التنظيم المعتمد.'
      ],
    };
  };

  const saveSettlementContract = async () => {
    if (settlementEditingContractId && !isAdmin) {
      alert('غير مصرح');
      return;
    }
    if (!settlementSourceContract) {
      alert('يرجى اختيار عقد تحت الإنشاء أولاً');
      return;
    }
    if (!settlementSourceContract.resale_contract_id) {
      alert('يلزم أن يكون هناك عقد إعادة بيع مرتبط بعقد تحت الإنشاء قبل إنشاء التسوية');
      return;
    }

    const salePriceValue = Number(settlementSalePrice);
    if (!Number.isFinite(salePriceValue) || salePriceValue <= 0) {
      alert('يرجى إدخال مبلغ البيع المتفق عليه الجديد بشكل صحيح');
      return;
    }

    const newOwnerNameValue = settlementNewOwnerName.trim();
    const newOwnerIdValue = settlementNewOwnerIdNumber.trim();
    const newOwnerPhoneValue = settlementNewOwnerPhone.trim();

    if (settlementIncludeNewClient && (!newOwnerNameValue || !newOwnerIdValue)) {
      alert('يرجى تعبئة اسم وهوية العميل الجديد');
      return;
    }

    try {
      setSavingSettlement(true);
      const nowIso = new Date().toISOString();
      const { actorId, actorName } = await getActorInfo();

      let newOwnerClientId: string | null = null;
      if (settlementIncludeNewClient) {
        const existing = settlementFoundClient || (clients.find((c) => (c.id_number || '') === newOwnerIdValue) || null);
        if (existing) {
          newOwnerClientId = existing.id;
        } else {
          const { data: createdClient, error: clientError } = await supabaseClient.supabase
            .from('clients')
            .insert({
              name: newOwnerNameValue,
              id_number: newOwnerIdValue,
              phone: newOwnerPhoneValue || null,
            })
            .select()
            .single();
          if (clientError) throw clientError;
          if (!createdClient?.id) throw new Error('تعذر إنشاء العميل الجديد');
          newOwnerClientId = createdClient.id;
          setSettlementFoundClient(createdClient as any);
          setSettlementClientLookupStatus('selected');
          setClients((prev) => [createdClient as any, ...prev]);
        }
      }

      const settlementPayload: any = {
        project_id: settlementSourceContract.project_id,
        unit_id: settlementSourceContract.unit_id,
        client_id: settlementSourceContract.client_id ?? null,
        contract_date: settlementDate,
        status: 'active',
        type: 'financial_settlement',
        total_amount: salePriceValue,
        paid_amount: 0,
        completion_period_months: settlementSourceContract.completion_period_months || 12,
        payment_grace_period_months: settlementSourceContract.payment_grace_period_months ?? null,
        client_name: settlementSourceContract.client?.name || settlementSourceContract.client_name || null,
        client_id_number: settlementSourceContract.client?.id_number || settlementSourceContract.client_id_number || null,
        client_phone: settlementSourceContract.client?.phone || settlementSourceContract.client_phone || null,
        settlement_source_contract_id: settlementSourceContract.id,
        settlement_resale_contract_id: settlementSourceContract.resale_contract_id,
        settlement_date: settlementDate,
        settlement_sale_price: salePriceValue,
        settlement_new_owner_client_id: settlementIncludeNewClient ? newOwnerClientId : null,
        settlement_new_owner_name: settlementIncludeNewClient ? newOwnerNameValue : null,
        settlement_new_owner_id_number: settlementIncludeNewClient ? newOwnerIdValue : null,
        settlement_new_owner_phone: settlementIncludeNewClient ? (newOwnerPhoneValue || null) : null,
      };

      let settlementId = settlementEditingContractId;

      if (settlementEditingContractId) {
        const { error: updateError } = await supabaseClient.supabase
          .from('contracts')
          .update(settlementPayload)
          .eq('id', settlementEditingContractId);
        if (updateError) throw updateError;
      } else {
        const { data: createdSettlement, error: settlementError } = await supabaseClient.supabase
          .from('contracts')
          .insert({
            ...settlementPayload,
            created_by_id: actorId,
            created_by_name: actorName || null,
          })
          .select('*')
          .single();

        if (settlementError) throw settlementError;
        if (!createdSettlement?.id) throw new Error('تعذر إنشاء عقد التسوية المالية');
        settlementId = createdSettlement.id;
      }

      if (!settlementId) throw new Error('تعذر حفظ عقد التسوية المالية');

      const baseUpdatePayload: any = {
        financial_settlement_contract_id: settlementId,
        financial_settlement_signed_at: nowIso,
      };

      if (settlementIncludeNewClient && newOwnerClientId) {
        baseUpdatePayload.settlement_new_client_id = newOwnerClientId;
        baseUpdatePayload.settlement_new_client_applied_at = nowIso;
        baseUpdatePayload.settlement_new_owner_name = newOwnerNameValue;
        baseUpdatePayload.settlement_new_owner_id_number = newOwnerIdValue;
        baseUpdatePayload.settlement_new_owner_phone = newOwnerPhoneValue || null;
      } else {
        baseUpdatePayload.settlement_new_client_id = null;
        baseUpdatePayload.settlement_new_client_applied_at = null;
        baseUpdatePayload.settlement_new_owner_name = null;
        baseUpdatePayload.settlement_new_owner_id_number = null;
        baseUpdatePayload.settlement_new_owner_phone = null;
      }

      const { error: baseUpdateError } = await supabaseClient.supabase
        .from('contracts')
        .update(baseUpdatePayload)
        .eq('id', settlementSourceContract.id);
      if (baseUpdateError) throw baseUpdateError;

      const unitUpdatePayload: any = {
        status: 'pending_sale',
      };
      if (settlementIncludeNewClient) {
        if (newOwnerClientId) {
          unitUpdatePayload.current_client_id = newOwnerClientId;
        }
        unitUpdatePayload.title_deed_owner = newOwnerNameValue;
        unitUpdatePayload.title_deed_owner_id = newOwnerIdValue;
        unitUpdatePayload.title_deed_owner_phone = newOwnerPhoneValue || null;
      } else if (settlementEditingContractId) {
        unitUpdatePayload.current_client_id = null;
        unitUpdatePayload.title_deed_owner = null;
        unitUpdatePayload.title_deed_owner_id = null;
        unitUpdatePayload.title_deed_owner_phone = null;
      }

      const { error: unitUpdateError } = await supabaseClient.supabase
        .from('units')
        .update(unitUpdatePayload)
        .eq('id', settlementSourceContract.unit_id);
      if (unitUpdateError) throw unitUpdateError;

      await logContractEvent({
        contract_id: settlementId,
        action: settlementEditingContractId ? 'contract_updated' : 'contract_created',
        entity_type: 'contract',
        entity_id: settlementId,
        metadata: {
          contract_type: 'financial_settlement',
          mode: settlementEditingContractId ? 'edit' : 'create',
          source_contract_id: settlementSourceContract.id,
          resale_contract_id: settlementSourceContract.resale_contract_id,
          settlement_date: settlementDate,
          settlement_sale_price: salePriceValue,
          include_new_client: settlementIncludeNewClient,
          new_owner_name: settlementIncludeNewClient ? newOwnerNameValue : null,
          new_owner_id_number: settlementIncludeNewClient ? newOwnerIdValue : null,
          new_owner_phone: settlementIncludeNewClient ? (newOwnerPhoneValue || null) : null,
          new_owner_client_id: settlementIncludeNewClient ? newOwnerClientId : null,
          unit_status_after: 'pending_sale',
        },
      });

      await logContractEvent({
        contract_id: settlementSourceContract.id,
        action: 'contract_updated',
        entity_type: 'contract',
        entity_id: settlementSourceContract.id,
        metadata: {
          financial_settlement_contract_id: settlementId,
          settlement_include_new_client: settlementIncludeNewClient,
          settlement_sale_price: salePriceValue,
          settlement_date: settlementDate,
        },
      });

      await loadContracts();
      setShowSettlementWizard(false);
      alert(settlementEditingContractId ? 'تم تعديل عقد التسوية المالية' : 'تم إنشاء عقد التسوية المالية');
      setActiveContractTypeFilter('financial_settlement');
    } catch (error: any) {
      console.error('Error creating settlement contract:', error);
      alert('حدث خطأ أثناء إنشاء عقد التسوية المالية: ' + (error?.message || ''));
    } finally {
      setSavingSettlement(false);
    }
  };

  const searchSettlementClient = async () => {
    const idNumber = settlementNewOwnerIdNumber.trim();
    if (!idNumber) {
      setSettlementFoundClient(null);
      setSettlementClientLookupStatus('idle');
      return;
    }

    try {
      setSettlementSearchingClient(true);
      const { data, error } = await supabaseClient.supabase.from('clients').select('*').eq('id_number', idNumber);
      if (error) throw error;

      const list = (data as any[]) || [];
      if (list.length === 0) {
        setSettlementFoundClient(null);
        setSettlementClientLookupStatus('not_found');
        return;
      }

      if (list.length > 1) {
        setSettlementFoundClient(list[0] as any);
        setSettlementClientLookupStatus('duplicate');
      } else {
        setSettlementFoundClient(list[0] as any);
        setSettlementClientLookupStatus('selected');
      }

      const client = list[0] as any;
      setSettlementNewOwnerName(client?.name || '');
      setSettlementNewOwnerPhone(client?.phone || '');
    } catch (error: any) {
      console.error('Error searching settlement client:', error);
      alert('حدث خطأ أثناء البحث عن العميل: ' + (error?.message || ''));
    } finally {
      setSettlementSearchingClient(false);
    }
  };

  const createSettlementClient = async () => {
    const idNumber = settlementNewOwnerIdNumber.trim();
    const name = settlementNewOwnerName.trim();
    const phone = settlementNewOwnerPhone.trim();

    if (!idNumber || !name) {
      alert('يرجى تعبئة الهوية والاسم قبل إضافة العميل');
      return;
    }

    try {
      setSettlementCreatingClient(true);
      const { data: createdClient, error } = await supabaseClient.supabase
        .from('clients')
        .insert({
          name,
          id_number: idNumber,
          phone: phone || null,
        })
        .select()
        .single();
      if (error) throw error;
      if (!createdClient?.id) throw new Error('تعذر إضافة العميل');

      setSettlementFoundClient(createdClient as any);
      setSettlementClientLookupStatus('selected');
      setClients((prev) => [createdClient as any, ...prev]);
      alert('تم إضافة العميل بنجاح');
    } catch (error: any) {
      console.error('Error creating settlement client:', error);
      alert('حدث خطأ أثناء إضافة العميل: ' + (error?.message || ''));
    } finally {
      setSettlementCreatingClient(false);
    }
  };

  const searchClientByIdNumber = (idNumber: string) => {
    if (!idNumber) {
      setFoundClient(null);
      return;
    }
    const client = clients.find(c => c.id_number === idNumber);
    setFoundClient(client || null);
    if (client) {
      setAgentForm(prev => ({
        ...prev,
        agent_name: client.name,
        agent_phone: client.phone || ''
      }));
    }
  };

  const handleSaveAgent = () => {
    // إذا لم يكن العميل موجوداً و لدينا رقم جوال، نضيفه كعميل جديد أولاً
    if (!foundClient && agentForm.agent_id_number && agentForm.agent_phone && agentForm.agent_name) {
      createNewAgentClient();
    } else {
      updateAgent({
        agent_name: agentForm.agent_name,
        agent_id_number: agentForm.agent_id_number,
        agency_number: agentForm.agency_number,
        agency_date: agentForm.agency_date
      });
      setIsEditingAgent(false);
    }
  };

  const createNewAgentClient = async () => {
    try {
      const { data: newClient, error } = await supabaseClient.supabase
        .from('clients')
        .insert({
          name: agentForm.agent_name,
          id_number: agentForm.agent_id_number,
          phone: agentForm.agent_phone
        })
        .select()
        .single();
      
      if (error) throw error;
      
      setClients([...clients, newClient]);
      setFoundClient(newClient);
      updateAgent({
        agent_name: agentForm.agent_name,
        agent_id_number: agentForm.agent_id_number,
        agency_number: agentForm.agency_number,
        agency_date: agentForm.agency_date
      });
      setIsEditingAgent(false);
      alert('تم إضافة الوكيل كعميل جديد بنجاح!');
    } catch (error) {
      console.error('Error creating client:', error);
      alert('حدث خطأ أثناء إضافة العميل الجديد');
    }
  };

  const handleClearAgent = () => {
    if (confirm('هل تريد مسح بيانات الوكيل؟')) {
      updateAgent({
        agent_name: null,
        agent_id_number: null,
        agency_number: null,
        agency_date: null
      });
      setAgentForm({
        agent_name: '',
        agent_id_number: '',
        agency_number: '',
        agency_date: '',
        agent_phone: ''
      });
      setFoundClient(null);
    }
  };

  useEffect(() => {
    loadContracts();
  }, []);

  // تحديث النموذج عند اختيار عقد جديد
  useEffect(() => {
    if (selectedContract) {
      setAgentForm(prev => ({
        ...prev,
        agent_name: selectedContract.agent_name || '',
        agent_id_number: selectedContract.agent_id_number || '',
        agency_number: selectedContract.agency_number || '',
        agency_date: selectedContract.agency_date || ''
      }));
    }
  }, [selectedContract]);

  useEffect(() => {
    if (!selectedContract?.id) return;
    loadContractAttachments(selectedContract.id);
  }, [selectedContract?.id]);

  const contractTypeCards = useMemo(() => ([
    {
      key: 'under_construction' as ContractTypeKey,
      title: CONTRACT_TYPES.under_construction,
      description: 'العقد الفعلي الحالي، وتدار منه الدفعات والطباعة وتفاصيل العميل والوحدة.',
      icon: Layers3,
      accent: 'from-blue-600 to-blue-700',
      border: 'border-blue-200',
      bg: 'bg-blue-50/80',
      actionHref: '/contracts/new',
      actionLabel: 'إضافة عقد'
    },
    {
      key: 'resale' as ContractTypeKey,
      title: CONTRACT_TYPES.resale,
      description: 'يعرض هذا القسم عقود إعادة البيع داخل نفس صفحة العقود، مع إمكانية الوصول السريع إلى معاينة القالب.',
      icon: Repeat2,
      accent: 'from-amber-500 to-orange-500',
      border: 'border-amber-200',
      bg: 'bg-amber-50/80',
      actionHref: '/test-eaadtbia',
      actionLabel: 'معاينة القالب'
    },
    {
      key: 'financial_settlement' as ContractTypeKey,
      title: CONTRACT_TYPES.financial_settlement,
      description: 'يعرض هذا القسم عقود التسوية المالية داخل نفس القائمة، مع فتح قالب المعاينة مباشرة عند الحاجة.',
      icon: FileStack,
      accent: 'from-emerald-600 to-emerald-700',
      border: 'border-emerald-200',
      bg: 'bg-emerald-50/80',
      actionHref: '/test-tasoiah',
      actionLabel: 'معاينة القالب'
    },
    {
      key: 'waiver' as ContractTypeKey,
      title: CONTRACT_TYPES.waiver,
      description: 'قالب التنازل جاهز الآن للمعاينة والطباعة التجريبية قبل ربطه ببيانات العقود الفعلية.',
      icon: FileSignature,
      accent: 'from-rose-600 to-pink-600',
      border: 'border-rose-200',
      bg: 'bg-rose-50/80',
      actionHref: '/contracts/waiver/new',
      actionLabel: 'إضافة تنازل'
    },
    {
      key: 'deed' as ContractTypeKey,
      title: 'محضر استلام / محضر إفراغ',
      description: 'القالب جاهز الآن للطباعة التجريبية، وسيتم ربطه لاحقاً ببيانات العقود والوحدات.',
      icon: FileSignature,
      accent: 'from-purple-600 to-fuchsia-600',
      border: 'border-purple-200',
      bg: 'bg-purple-50/80',
      actionHref: '/contracts/deed/new',
      actionLabel: 'إضافة إفراغ'
    }
  ]), []);

  const contractsCountByType = useMemo(() => {
    const base = contracts.filter((c) => (showArchivedContracts ? Boolean((c as any).is_archived) : !Boolean((c as any).is_archived)));
    return base.reduce<Record<string, number>>((acc, contract) => {
      const key = (contract.type || 'other') as string;
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
  }, [contracts, showArchivedContracts]);

  const filteredContracts = useMemo(() => {
    const base = contracts.filter((c) => (showArchivedContracts ? Boolean((c as any).is_archived) : !Boolean((c as any).is_archived)));
    const typeFiltered =
      activeContractTypeFilter === 'all'
        ? base.filter((c) => c.type !== 'resale')
        : activeContractTypeFilter === 'resale'
          ? base.filter((c) => c.type === 'resale')
          : base.filter((contract) => contract.type === activeContractTypeFilter);

    const raw = contractsSearchQuery.trim();
    if (!raw) return typeFiltered;

    const q = raw.toLowerCase();
    const dashMatch = raw.match(/^\s*([^\-]+?)\s*-\s*([^\-]+?)\s*$/);
    const projectPart = dashMatch ? dashMatch[1].trim().toLowerCase() : null;
    const unitPart = dashMatch ? dashMatch[2].trim().toLowerCase() : null;

    return typeFiltered.filter((contract) => {
      const clientName = String(contract.client?.name || contract.client_name || '').toLowerCase();
      const projectNumber = String(contract.project?.project_number || '').toLowerCase();
      const unitNumber = String(contract.unit?.unit_number ?? '').toLowerCase();

      if (projectPart && unitPart) {
        return projectNumber.includes(projectPart) && unitNumber.includes(unitPart);
      }

      return (
        clientName.includes(q) ||
        projectNumber.includes(q) ||
        unitNumber.includes(q)
      );
    });
  }, [contracts, activeContractTypeFilter, showArchivedContracts, contractsSearchQuery]);

  const groupedContracts = useMemo(() => {
    if (activeContractTypeFilter === 'resale') {
      return { resale: filteredContracts };
    }
    return filteredContracts.reduce<Record<string, FullContract[]>>((acc, contract) => {
      const key = contract.type || 'other';
      if (!acc[key]) acc[key] = [];
      acc[key].push(contract);
      return acc;
    }, {});
  }, [filteredContracts, activeContractTypeFilter]);

  const resaleContractById = useMemo(() => {
    const map = new Map<string, FullContract>();
    for (const c of contracts) {
      if (c.type === 'resale') map.set(c.id, c);
    }
    return map;
  }, [contracts]);

  const summaryStats = useMemo(() => {
    return {
      totalContracts: filteredContracts.length,
    };
  }, [filteredContracts]);

  const getHoverOverlayColor = (type: string) => {
    if (type === 'under_construction') return 'rgba(37, 99, 235, 0.92)';
    if (type === 'resale') return 'rgba(245, 158, 11, 0.92)';
    if (type === 'financial_settlement') return 'rgba(5, 150, 105, 0.92)';
    if (type === 'waiver') return 'rgba(225, 29, 72, 0.92)';
    if (type === 'deed') return 'rgba(147, 51, 234, 0.92)';
    return 'rgba(55, 65, 81, 0.92)';
  };

  const resaleSourceContract = useMemo(() => {
    if (!resaleSourceContractId) return null;
    return contracts.find((c) => c.id === resaleSourceContractId) || null;
  }, [contracts, resaleSourceContractId]);

  const selectedResaleContract = useMemo(() => {
    if (!selectedContract) return null;
    if (selectedContract.type === 'resale') return selectedContract;
    if (selectedContract.type === 'under_construction' && selectedContract.resale_contract_id) {
      return resaleContractById.get(selectedContract.resale_contract_id) || null;
    }
    return null;
  }, [selectedContract, resaleContractById]);

  const selectedResaleBaseContract = useMemo(() => {
    if (!selectedContract) return null;
    if (selectedContract.type === 'under_construction') return selectedContract;
    if (selectedContract.type !== 'resale') return null;
    const bySource = selectedContract.source_contract_id
      ? contracts.find((c) => c.id === selectedContract.source_contract_id) || null
      : null;
    if (bySource) return bySource;
    return contracts.find((c) => c.type === 'under_construction' && c.resale_contract_id === selectedContract.id) || null;
  }, [selectedContract, contracts]);

  const selectedSettlementContract = useMemo(() => {
    if (!selectedContract) return null;
    if (selectedContract.type === 'financial_settlement') return selectedContract;
    return null;
  }, [selectedContract]);

  const selectedSettlementBaseContract = useMemo(() => {
    if (!selectedSettlementContract) return null;
    const sourceId = (selectedSettlementContract as any).settlement_source_contract_id as string | null | undefined;
    if (sourceId) {
      return contracts.find((c) => c.id === sourceId) || null;
    }
    return contracts.find((c) => c.type === 'under_construction' && c.financial_settlement_contract_id === selectedSettlementContract.id) || null;
  }, [selectedSettlementContract, contracts]);

  const selectedSettlementResaleContract = useMemo(() => {
    if (!selectedSettlementContract) return null;
    const resaleId = (selectedSettlementContract as any).settlement_resale_contract_id as string | null | undefined;
    if (!resaleId) return null;
    return resaleContractById.get(resaleId) || null;
  }, [selectedSettlementContract, resaleContractById]);

  const selectedWaiverContract = useMemo(() => {
    if (!selectedContract) return null;
    if (selectedContract.type === 'waiver') return selectedContract;
    return null;
  }, [selectedContract]);

  const selectedWaiverBaseContract = useMemo(() => {
    if (!selectedWaiverContract) return null;
    const sourceId = selectedWaiverContract.source_contract_id as string | null | undefined;
    if (sourceId) {
      return contracts.find((c) => c.id === sourceId) || null;
    }
    const waivedToClientId = (selectedWaiverContract as any).waived_to_client_id as string | null | undefined;
    return (
      contracts.find(
        (c) =>
          c.type === 'under_construction' &&
          Boolean((c as any).is_waived) &&
          (c.client_id === waivedToClientId || (c as any).waived_to_client_id === waivedToClientId)
      ) || null
    );
  }, [selectedWaiverContract, contracts]);

  const selectedDeedContract = useMemo(() => {
    if (!selectedContract) return null;
    if (selectedContract.type === 'deed') return selectedContract;
    return null;
  }, [selectedContract]);

  const selectedDeedBaseContract = useMemo(() => {
    if (!selectedDeedContract) return null;
    const sourceId =
      (selectedDeedContract as any).deed_source_contract_id ||
      selectedDeedContract.source_contract_id ||
      null;
    if (!sourceId) return null;
    return contracts.find((c) => c.id === sourceId) || null;
  }, [selectedDeedContract, contracts]);

  const selectedContractViewType = useMemo<'all' | ContractTypeKey>(() => {
    if (!selectedContract) return activeContractTypeFilter;
    if (activeContractTypeFilter === 'all') {
      return (selectedContract.type || 'other') as ContractTypeKey;
    }
    return activeContractTypeFilter;
  }, [selectedContract, activeContractTypeFilter]);

  const resaleCandidates = useMemo(() => {
    const eligible = contracts.filter(
      (c) => c.type === 'under_construction' && !Boolean((c as any).is_archived) && !c.resale_contract_id
    );
    if (!resaleSearch.trim()) return eligible;
    const q = resaleSearch.trim();
    return eligible.filter((c) => {
      const projectNo = c.project?.project_number || '';
      const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '';
      const code = `${projectNo}-${unitNo}`;
      const clientName = c.client?.name || c.client_name || '';
      return code.includes(q) || clientName.includes(q) || projectNo.includes(q) || unitNo.includes(q);
    });
  }, [contracts, resaleSearch]);

  const openResaleWizard = (baseContract?: FullContract) => {
    setResaleStep(1);
    setResaleSearch('');
    setResaleSourceContractId(baseContract?.id || null);
    const linkedResale =
      baseContract?.resale_contract_id ? resaleContractById.get(baseContract.resale_contract_id) : null;
    const agreedPref =
      linkedResale?.resale_agreed_amount ??
      linkedResale?.total_amount ??
      (baseContract?.unit ? (baseContract.unit as any).resale_agreed_amount : null);
    setResaleAgreedAmount(agreedPref != null ? String(agreedPref) : '');
    setResaleFee(String(linkedResale?.resale_fee ?? 5000));
    setResaleMarketingFee(String((linkedResale as any)?.marketing_fee ?? 15000));
    setResaleCompanyFee(String((linkedResale as any)?.company_service_fee ?? 2500));
    setResaleLawyerFee(String((linkedResale as any)?.lawyer_fee ?? 2500));
    setShowResaleWizard(true);
    if (baseContract?.id) setResaleStep(2);
  };

  const closeResaleWizard = () => {
    if (savingResale) return;
    setShowResaleWizard(false);
  };

  const settlementSourceContract = useMemo(() => {
    if (!settlementSourceContractId) return null;
    return contracts.find((c) => c.id === settlementSourceContractId) || null;
  }, [contracts, settlementSourceContractId]);

  const settlementCandidates = useMemo(() => {
    const eligible = contracts.filter(
      (c) =>
        c.type === 'under_construction' &&
        !Boolean((c as any).is_archived) &&
        Boolean(c.resale_contract_id) &&
        !c.financial_settlement_contract_id
    );
    if (!settlementSearch.trim()) return eligible;
    const q = settlementSearch.trim();
    return eligible.filter((c) => {
      const projectNo = c.project?.project_number || '';
      const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '';
      const code = `${projectNo}-${unitNo}`;
      const clientName = c.client?.name || c.client_name || '';
      return code.includes(q) || clientName.includes(q) || projectNo.includes(q) || unitNo.includes(q);
    });
  }, [contracts, settlementSearch]);

  const openSettlementWizard = (baseContract?: FullContract, settlementContract?: FullContract) => {
    setSettlementStep(1);
    setSettlementSearch('');
    setSettlementSourceContractId(baseContract?.id || null);
    setSettlementSalePrice('');
    setSettlementDate(new Date().toISOString().split('T')[0]);
    setSettlementIncludeNewClient(false);
    setSettlementNewOwnerIdNumber('');
    setSettlementNewOwnerName('');
    setSettlementNewOwnerPhone('');
    setSettlementFoundClient(null);
    setSettlementClientSuggestions([]);
    setSettlementClientLookupStatus('idle');
    setSettlementEditingContractId(settlementContract?.id || null);

    if (settlementContract) {
      const settlementDateValue = (settlementContract as any).settlement_date || settlementContract.contract_date || '';
      const salePriceRaw = (settlementContract as any).settlement_sale_price;
      const salePriceValue = salePriceRaw != null ? salePriceRaw : settlementContract.total_amount;
      setSettlementDate(String(settlementDateValue || '').slice(0, 10) || new Date().toISOString().split('T')[0]);
      setSettlementSalePrice(String(salePriceValue ?? ''));

      const ownerName = (settlementContract as any).settlement_new_owner_name || '';
      const ownerId = (settlementContract as any).settlement_new_owner_id_number || '';
      const ownerPhone = (settlementContract as any).settlement_new_owner_phone || '';
      setSettlementNewOwnerName(String(ownerName || ''));
      setSettlementNewOwnerIdNumber(String(ownerId || ''));
      setSettlementNewOwnerPhone(String(ownerPhone || ''));

      const hasNewClient = Boolean((settlementContract as any).settlement_new_owner_client_id);
      setSettlementIncludeNewClient(hasNewClient);
      const clientId = (settlementContract as any).settlement_new_owner_client_id as string | null | undefined;
      if (clientId) {
        const existingClient = clients.find((c) => c.id === clientId) || null;
        if (existingClient) setSettlementFoundClient(existingClient);
      }
      setSettlementClientLookupStatus(hasNewClient ? 'selected' : 'idle');
    }

    setShowSettlementWizard(true);
    if (baseContract?.id) setSettlementStep(settlementContract ? 3 : 2);
  };

  const closeSettlementWizard = () => {
    if (savingSettlement) return;
    setShowSettlementWizard(false);
  };

  useEffect(() => {
    if (!showSettlementWizard) return;
    if (settlementStep !== 3) return;
    if (!settlementIncludeNewClient) return;

    const idNumber = settlementNewOwnerIdNumber.trim();
    if (idNumber.length < 3) {
      setSettlementClientSuggestions([]);
      setSettlementFoundClient(null);
      setSettlementClientLookupStatus('idle');
      return;
    }

    if (settlementLookupTimerRef.current) {
      window.clearTimeout(settlementLookupTimerRef.current);
      settlementLookupTimerRef.current = null;
    }

    settlementLookupTimerRef.current = window.setTimeout(async () => {
      try {
        setSettlementSearchingClient(true);
        const { data, error } = await supabaseClient.supabase
          .from('clients')
          .select('*')
          .ilike('id_number', `${idNumber}%`)
          .limit(6);
        if (error) throw error;

        const list = ((data as any[]) || []) as Client[];
        const exactMatches = list.filter((c) => (c.id_number || '') === idNumber);

        if (list.length === 0) {
          setSettlementClientSuggestions([]);
          setSettlementFoundClient(null);
          setSettlementClientLookupStatus('not_found');
          return;
        }

        if (exactMatches.length > 1) {
          setSettlementClientSuggestions(exactMatches);
          setSettlementFoundClient(null);
          setSettlementClientLookupStatus('duplicate');
          return;
        }

        if (exactMatches.length === 1) {
          const exact = exactMatches[0];
          setSettlementClientSuggestions([]);
          setSettlementFoundClient(exact);
          setSettlementClientLookupStatus('selected');
          setSettlementNewOwnerName(exact.name || '');
          setSettlementNewOwnerPhone(exact.phone || '');
          return;
        }

        setSettlementClientSuggestions(list);
        setSettlementFoundClient(null);
        setSettlementClientLookupStatus('matches');
      } catch (error: any) {
        console.error('Error searching settlement client suggestions:', error);
        setSettlementClientSuggestions([]);
        setSettlementFoundClient(null);
        setSettlementClientLookupStatus('idle');
      } finally {
        setSettlementSearchingClient(false);
      }
    }, 250);

    return () => {
      if (settlementLookupTimerRef.current) {
        window.clearTimeout(settlementLookupTimerRef.current);
        settlementLookupTimerRef.current = null;
      }
    };
  }, [showSettlementWizard, settlementStep, settlementIncludeNewClient, settlementNewOwnerIdNumber]);

  const loadContracts = async () => {
    try {
      setLoading(true);
      const { data: authData } = await supabaseClient.supabase.auth.getUser();
      const user = authData.user;
      if (user) {
        const { data: profile } = await supabaseClient.supabase
          .from('employee_profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
        const nextRole = ((profile?.role as string | null) || 'viewer') as EmployeeRole;
        setRole(nextRole);
        setIsAdmin(nextRole === 'admin');
      } else {
        setRole('viewer');
        setIsAdmin(false);
      }

      // جلب جميع العقود مع المشروع والوحدة والعميل
      const { data: contractsData, error: contractsError } = await supabaseClient.supabase
        .from('contracts')
        .select(`
          *,
          project:projects(*),
          unit:units(*),
          client:clients!contracts_client_id_fkey(*)
        `)
        .order('created_at', { ascending: false });
      
      if (contractsError) {
        const message = (contractsError as any)?.message || JSON.stringify(contractsError || {});
        throw new Error(message);
      }

      const employeesRes = await supabaseClient.supabase.rpc('crm_list_employees');
      if (employeesRes.error) {
        setEmployees([]);
      } else {
        const employeesList = Array.isArray(employeesRes.data) ? employeesRes.data : [];
        setEmployees((employeesList as any[]) as Array<{ id: string; email: string | null }>);
      }
      
      // جلب جميع العملاء للبحث عن الوكيل
      const { data: clientsData, error: clientsError } = await supabaseClient.supabase
        .from('clients')
        .select('*')
        .order('created_at', { ascending: false });
      
      if (clientsError) {
        setClients([]);
      } else {
        setClients(clientsData || []);
      }
      
      // جلب الالتزامات والدفعات لكل عقد
      const contractsWithDetails = await Promise.all(
        (contractsData || []).map(async (contract: any) => {
          const [obligationsRes, paymentsRes] = await Promise.all([
            supabaseClient.supabase.from('contract_obligations').select('*').eq('contract_id', contract.id),
            supabaseClient.supabase.from('contract_payments').select('*').eq('contract_id', contract.id),
          ]);
          
          return {
            ...contract,
            project: contract.project,
            unit: contract.unit,
            client: contract.client,
            obligations: obligationsRes.data || [],
            payments: paymentsRes.data || [],
          };
        })
      );
      
      setContracts(contractsWithDetails);
    } catch (error) {
      console.error('Error loading contracts:', error);
      const message = (error as any)?.message || JSON.stringify(error || {});
      alert('حدث خطأ أثناء تحميل العقود: ' + message);
    } finally {
      setLoading(false);
    }
  };

  const updateAgent = async (agentData: {
    agent_name?: string | null;
    agent_id_number?: string | null;
    agency_number?: string | null;
    agency_date?: string | null;
  }) => {
    if (!selectedContract) return;
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    
    try {
      const { error } = await supabaseClient.supabase
        .from('contracts')
        .update(agentData)
        .eq('id', selectedContract.id);
      
      if (error) throw error;
      
      // تحديث الحالة المحلية
      setSelectedContract({ ...selectedContract, ...agentData });
      setContracts(contracts.map(c => 
        c.id === selectedContract.id ? { ...c, ...agentData } : c
      ));

      await logContractEvent({
        contract_id: selectedContract.id,
        action: 'agent_updated',
        entity_type: 'contract',
        entity_id: selectedContract.id,
        metadata: {
          contract_type: selectedContract.type,
          previous_agent_name: selectedContract.agent_name ?? null,
          previous_agent_id_number: selectedContract.agent_id_number ?? null,
          previous_agency_number: selectedContract.agency_number ?? null,
          previous_agency_date: selectedContract.agency_date ?? null,
          agent_name: agentData.agent_name ?? null,
          agent_id_number: agentData.agent_id_number ?? null,
          agency_number: agentData.agency_number ?? null,
          agency_date: agentData.agency_date ?? null,
        }
      });
      
      alert('تم تحديث بيانات الوكيل بنجاح');
    } catch (error) {
      console.error('Error updating agent:', error);
      alert('حدث خطأ أثناء تحديث بيانات الوكيل');
    }
  };

  const deleteContract = async (id: string) => {
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    
    try {
      const contractToDelete = contracts.find(c => c.id === id);
      if (!contractToDelete) {
        alert('لم يتم العثور على العقد');
        return;
      }

      if (contractToDelete.type === 'under_construction') {
        if (Boolean((contractToDelete as any).is_archived)) {
          const ok = window.confirm(
            'هل تريد حذف العقد المؤرشف نهائيًا؟\n\nهذا الإجراء نهائي وسيزيل العقد من النظام بالكامل.'
          );
          if (!ok) return;

          await logContractEvent({
            contract_id: id,
            action: 'contract_deleted',
            entity_type: 'contract',
            entity_id: id,
            metadata: {
              contract_type: contractToDelete.type,
              deleted_reason: 'archived_contract_cleanup',
              deleted_from_archive: true,
              archived_at: (contractToDelete as any).archived_at || null,
              archived_by_id: (contractToDelete as any).archived_by_id || null,
              archived_by_name: (contractToDelete as any).archived_by_name || null,
              project_number: contractToDelete?.project?.project_number || null,
              project_name: contractToDelete?.project?.name || null,
              unit_number: contractToDelete?.unit?.unit_number ?? null,
              client_name: contractToDelete?.client?.name || contractToDelete?.client_name || null,
              project_id: contractToDelete?.project_id || null,
              unit_id: contractToDelete?.unit_id || null,
              client_id: contractToDelete?.client_id || null,
            },
          });

          const { error } = await supabaseClient.supabase.from('contracts').delete().eq('id', id);
          if (error) throw error;

          setContracts(contracts.filter(c => c.id !== id));
          if (selectedContract?.id === id) setSelectedContract(null);
          alert('تم حذف العقد المؤرشف نهائيًا');
          return;
        }

        if (contractToDelete.resale_contract_id) {
          alert('لا يمكن حذف عقد تحت الإنشاء لوجود عقد إعادة بيع مرتبط به');
          return;
        }
        if ((contractToDelete as any).financial_settlement_contract_id) {
          alert('لا يمكن حذف عقد تحت الإنشاء لوجود عقد تسوية مالية مرتبط به');
          return;
        }

        const ok = window.confirm(
          'هل تريد أرشفة عقد تحت الإنشاء؟\n\nسيتم:\n- إرجاع حالة الوحدة إلى (متاحة)\n- إزالة بيانات العميل من الوحدة\n- الاحتفاظ بالعقد مؤرشفًا للرجوع إليه لاحقًا'
        );
        if (!ok) return;

        const { actorId, actorName } = await getActorInfo();
        const unitId = contractToDelete.unit_id || null;
        const archivedAt = new Date().toISOString();

        const { error: archiveError } = await supabaseClient.supabase
          .from('contracts')
          .update({
            is_archived: true,
            archived_at: archivedAt,
            archived_by_id: actorId,
            archived_by_name: actorName || null,
          })
          .eq('id', id);
        if (archiveError) throw archiveError;

        if (unitId) {
          const { error: unitUpdateError } = await supabaseClient.supabase
            .from('units')
            .update({
              status: 'available',
              client_name: '',
              client_id_number: null,
              client_phone: null,
              original_client_id: null,
              current_client_id: null,
              title_deed_owner: null,
              title_deed_owner_id: null,
              title_deed_owner_phone: null,
            })
            .eq('id', unitId);
          if (unitUpdateError) throw unitUpdateError;

          const { error: debtDeleteError } = await supabaseClient.supabase
            .from('debts')
            .delete()
            .eq('unit_id', unitId);
          if (debtDeleteError) throw debtDeleteError;
        }

        await logContractEvent({
          contract_id: id,
          action: 'contract_archived',
          entity_type: 'contract',
          entity_id: id,
          metadata: {
            contract_type: contractToDelete.type,
            project_number: contractToDelete?.project?.project_number || null,
            project_name: contractToDelete?.project?.name || null,
            unit_number: contractToDelete?.unit?.unit_number ?? null,
            client_name: contractToDelete?.client?.name || contractToDelete?.client_name || null,
            project_id: contractToDelete?.project_id || null,
            unit_id: unitId,
            client_id: contractToDelete?.client_id || null,
            archived_at: archivedAt,
            archived_by_id: actorId,
            archived_by_name: actorName || null,
            unit_status_after: 'available',
            debt_deleted: Boolean(unitId),
            unit_client_cleared: Boolean(unitId),
          },
        });

        await loadContracts();
        if (selectedContract?.id === id) setSelectedContract(null);
        alert('تمت أرشفة عقد تحت الإنشاء وإرجاع الوحدة إلى متاحة');
        return;
      }

      if (contractToDelete.type === 'resale') {
        const settlementExists = contracts.some(
          (c) => c.type === 'financial_settlement' && (c as any).settlement_resale_contract_id === id
        );
        if (settlementExists) {
          alert('لا يمكن حذف عقد إعادة البيع لوجود عقد تسوية مالية مرتبط به');
          return;
        }

        const baseContract = contractToDelete.source_contract_id
          ? contracts.find((c) => c.id === contractToDelete.source_contract_id) || null
          : contracts.find((c) => c.type === 'under_construction' && c.resale_contract_id === id) || null;
        if (!baseContract) {
          alert('تعذر تحديد عقد تحت الإنشاء المرتبط لإتمام الحذف');
          return;
        }

        await deleteResaleContract(baseContract);
        return;
      }

      if (contractToDelete.type === 'financial_settlement') {
        const baseId = (contractToDelete as any).settlement_source_contract_id as string | null | undefined;
        const baseContract = baseId
          ? contracts.find((c) => c.id === baseId) || null
          : contracts.find((c) => c.type === 'under_construction' && (c as any).financial_settlement_contract_id === id) || null;
        if (!baseContract) {
          alert('تعذر تحديد عقد تحت الإنشاء المرتبط لإتمام الحذف');
          return;
        }
        await deleteSettlementContract(baseContract, contractToDelete);
        return;
      }

      if (contractToDelete.type === 'waiver') {
        const baseId = contractToDelete.source_contract_id as string | null | undefined;
        const baseContract = baseId
          ? contracts.find((c) => c.id === baseId) || null
          : contracts.find((c) => c.type === 'under_construction' && (c as any).is_waived) || null;
        if (!baseContract) {
          alert('تعذر تحديد عقد تحت الإنشاء المرتبط لإتمام حذف التنازل');
          return;
        }
        await deleteWaiverContract(baseContract, contractToDelete);
        return;
      }

      if (!confirm('هل تريد حذف هذا العقد؟')) return;
      const unitId = contractToDelete?.unit_id || null;

      await logContractEvent({
        contract_id: id,
        action: 'contract_deleted',
        entity_type: 'contract',
        entity_id: id,
        metadata: {
          contract_type: contractToDelete.type,
          project_number: contractToDelete?.project?.project_number || null,
          project_name: contractToDelete?.project?.name || null,
          unit_number: contractToDelete?.unit?.unit_number ?? null,
          client_name: contractToDelete?.client?.name || contractToDelete?.client_name || null,
          project_id: contractToDelete?.project_id || null,
          unit_id: contractToDelete?.unit_id || null,
          client_id: contractToDelete?.client_id || null,
          deleted_reason: 'manual_delete',
        }
      });

      const { error } = await supabaseClient.supabase.from('contracts').delete().eq('id', id);
      if (error) throw error;

      if (unitId) {
        const { data: remainingContracts, error: remainingError } = await supabaseClient.supabase
          .from('contracts')
          .select('id')
          .eq('unit_id', unitId)
          .limit(1);

        if (remainingError) throw remainingError;

        if (!remainingContracts || remainingContracts.length === 0) {
          const { error: unitUpdateError } = await supabaseClient.supabase
            .from('units')
            .update({ status: 'available' })
            .eq('id', unitId);

          if (unitUpdateError) throw unitUpdateError;

          const { error: debtDeleteError } = await supabaseClient.supabase
            .from('debts')
            .delete()
            .eq('unit_id', unitId);

          if (debtDeleteError) throw debtDeleteError;
        }
      }

      setContracts(contracts.filter(c => c.id !== id));
      if (selectedContract?.id === id) setSelectedContract(null);
      alert('تم حذف العقد بنجاح');
    } catch (error) {
      console.error('Error deleting contract:', error);
      alert('حدث خطأ أثناء حذف العقد');
    }
  };

  const syncUnitClientFromContract = async () => {
    if (!selectedContract?.unit_id) return;
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    const clientName = selectedContract.client?.name || selectedContract.client_name || null;
    const clientId = selectedContract.client?.id_number || selectedContract.client_id_number || null;
    const clientPhone = selectedContract.client?.phone || selectedContract.client_phone || null;

    if (!clientName && !clientId && !clientPhone) {
      alert('بيانات العميل غير متوفرة في العقد');
      return;
    }

    try {
      setSyncingUnit(true);
      const { error } = await supabaseClient.supabase
        .from('units')
        .update({
          client_name: clientName,
          client_id_number: clientId,
          client_phone: clientPhone
        })
        .eq('id', selectedContract.unit_id);

      if (error) throw error;

      const { data: updatedUnit, error: unitFetchError } = await supabaseClient.supabase
        .from('units')
        .select('*')
        .eq('id', selectedContract.unit_id)
        .single();

      if (unitFetchError) throw unitFetchError;

      setSelectedContract(prev => (prev ? ({ ...prev, unit: updatedUnit as Unit }) : prev));
      await logContractEvent({
        contract_id: selectedContract.id,
        action: 'unit_client_synced',
        entity_type: 'unit',
        entity_id: selectedContract.unit_id,
        metadata: {
          contract_type: selectedContract.type,
          unit_id: selectedContract.unit_id,
          previous_unit_client_name: selectedContract.unit?.client_name || null,
          previous_unit_client_id_number: selectedContract.unit?.client_id_number || null,
          previous_unit_client_phone: selectedContract.unit?.client_phone || null,
          client_name: clientName,
          client_id_number: clientId,
          client_phone: clientPhone
        }
      });
      alert('تم تحديث بيانات العميل داخل الوحدة');
    } catch (error) {
      console.error('Error syncing unit client:', error);
      alert('حدث خطأ أثناء تحديث بيانات الوحدة');
    } finally {
      setSyncingUnit(false);
    }
  };

  const syncDebtClientFromContract = async () => {
    if (!selectedContract?.unit_id || !selectedContract.project_id) return;
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    const projectNumber = selectedContract.project?.project_number || null;
    const projectName = selectedContract.project?.name || null;
    const unitNumber = selectedContract.unit?.unit_number ?? null;
    const deedNumber = selectedContract.project?.deed_number || selectedContract.unit?.deed_number || null;
    const clientName = selectedContract.client?.name || selectedContract.client_name || null;
    const clientId = selectedContract.client?.id_number || selectedContract.client_id_number || null;
    const clientPhone = selectedContract.client?.phone || selectedContract.client_phone || null;
    const remainingValue = Math.max((selectedContract.total_amount || 0) - (selectedContract.paid_amount || 0), 0);

    try {
      setSyncingDebt(true);
      const payload: any = {
        unit_id: selectedContract.unit_id,
        project_id: selectedContract.project_id,
        project_number: projectNumber,
        project_name: projectName,
        unit_number: unitNumber,
        deed_number: deedNumber,
        original_client_name: clientName,
        original_client_phone: clientPhone,
        original_client_id: clientId,
        contract_value: selectedContract.total_amount,
        paid_value: selectedContract.paid_amount,
        remaining_value: remainingValue,
        saved_at: new Date().toISOString(),
      };

      const { error } = await supabaseClient.supabase
        .from('debts')
        .upsert([payload], { onConflict: 'unit_id' });

      if (error) throw error;
      await logContractEvent({
        contract_id: selectedContract.id,
        action: 'debt_synced',
        entity_type: 'debt',
        entity_id: selectedContract.unit_id,
        metadata: {
          contract_type: selectedContract.type,
          ...payload
        }
      });
      alert('تم تحديث بيانات المديونية من العقد');
    } catch (error) {
      console.error('Error syncing debt:', error);
      alert('حدث خطأ أثناء تحديث بيانات المديونية');
    } finally {
      setSyncingDebt(false);
    }
  };

  const openNewPaymentEditor = () => {
    setEditingPaymentId(null);
    setPaymentForm({
      amount: 0,
      payment_date: new Date().toISOString().split('T')[0],
      payment_method: null,
      transaction_number: '',
      statement: '',
      notes: ''
    });
    setIsPaymentEditorOpen(true);
  };

  const openEditPaymentEditor = (payment: ContractPayment) => {
    if (!isAdmin) return;
    setEditingPaymentId(payment.id);
    setPaymentForm({
      amount: Number(payment.amount || 0),
      payment_date: payment.payment_date || new Date().toISOString().split('T')[0],
      payment_method: (payment.payment_method as any) || null,
      transaction_number: payment.transaction_number || '',
      statement: payment.statement || '',
      notes: payment.notes || ''
    });
    setIsPaymentEditorOpen(true);
  };

  const closePaymentEditor = () => {
    setIsPaymentEditorOpen(false);
    setEditingPaymentId(null);
  };

  const upsertDebtFromContract = async (contract: FullContract) => {
    if (!contract.unit_id || !contract.project_id) return;
    try {
      const projectNumber = contract.project?.project_number || null;
      const projectName = contract.project?.name || null;
      const unitNumber = contract.unit?.unit_number ?? null;
      const deedNumber = contract.project?.deed_number || contract.unit?.deed_number || null;
      const clientName = contract.client?.name || contract.client_name || null;
      const clientId = contract.client?.id_number || contract.client_id_number || null;
      const clientPhone = contract.client?.phone || contract.client_phone || null;
      const remainingValue = Math.max((contract.total_amount || 0) - (contract.paid_amount || 0), 0);

      const payload: any = {
        unit_id: contract.unit_id,
        project_id: contract.project_id,
        project_number: projectNumber,
        project_name: projectName,
        unit_number: unitNumber,
        deed_number: deedNumber,
        original_client_name: clientName,
        original_client_phone: clientPhone,
        original_client_id: clientId,
        contract_value: contract.total_amount,
        paid_value: contract.paid_amount,
        remaining_value: remainingValue,
        saved_at: new Date().toISOString(),
      };

      const { error } = await supabaseClient.supabase
        .from('debts')
        .upsert([payload], { onConflict: 'unit_id' });
      if (error) throw error;
    } catch (error) {
      console.error('Error upserting debt after payment:', error);
    }
  };

  const persistPaymentsAndPaidAmount = async (nextPayments: ContractPayment[]) => {
    if (!selectedContract) return;
    const paid = nextPayments.reduce((sum, p) => sum + Number(p.amount || 0), 0);

    const { error } = await supabaseClient.supabase
      .from('contracts')
      .update({ paid_amount: paid })
      .eq('id', selectedContract.id);

    if (error) throw error;

    const nextContract: FullContract = {
      ...selectedContract,
      paid_amount: paid,
      payments: nextPayments,
    };

    setSelectedContract(nextContract);
    setContracts(prev =>
      prev.map(c => (c.id === selectedContract.id ? { ...c, paid_amount: paid, payments: nextPayments } : c))
    );

    await upsertDebtFromContract(nextContract);
  };

  const savePaymentFromEditor = async () => {
    if (!selectedContract) return;
    if (!isAdmin && editingPaymentId) {
      alert('غير مصرح');
      return;
    }
    if (Number(paymentForm.amount || 0) <= 0) {
      alert('يرجى إدخال مبلغ صحيح للدفعة');
      return;
    }
    if (!paymentForm.payment_date) {
      alert('يرجى اختيار تاريخ الدفعة');
      return;
    }

    try {
      setSavingPayment(true);

      const payload: any = {
        amount: Number(paymentForm.amount || 0),
        payment_date: paymentForm.payment_date,
        payment_method: paymentForm.payment_method,
        transaction_number: paymentForm.transaction_number || null,
        statement: paymentForm.statement || null,
        notes: paymentForm.notes || null,
      };

      let savedPayment: ContractPayment | null = null;
      if (editingPaymentId) {
        const { data, error } = await supabaseClient.supabase
          .from('contract_payments')
          .update(payload)
          .eq('id', editingPaymentId)
          .select('*')
          .single();
        if (error) throw error;
        savedPayment = data as ContractPayment;
      } else {
        const { data, error } = await supabaseClient.supabase
          .from('contract_payments')
          .insert({ ...payload, contract_id: selectedContract.id })
          .select('*')
          .single();
        if (error) throw error;
        savedPayment = data as ContractPayment;
      }

      if (!savedPayment) throw new Error('Payment not saved');

      const currentPayments = (selectedContract.payments || []) as ContractPayment[];
      const nextPayments = editingPaymentId
        ? currentPayments.map(p => (p.id === editingPaymentId ? savedPayment! : p))
        : [...currentPayments, savedPayment];

      nextPayments.sort((a, b) => (a.payment_date || '').localeCompare(b.payment_date || ''));

      await persistPaymentsAndPaidAmount(nextPayments);
      await logContractEvent({
        contract_id: selectedContract.id,
        action: editingPaymentId ? 'payment_updated' : 'payment_added',
        entity_type: 'payment',
        entity_id: savedPayment.id,
        metadata: {
          contract_type: selectedContract.type,
          payment_id: savedPayment.id,
          operation_mode: editingPaymentId ? 'edit' : 'create',
          payments_count_after: nextPayments.length,
          paid_amount_before: selectedContract.paid_amount || 0,
          paid_amount_after: nextPayments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0),
          amount: savedPayment.amount,
          payment_date: savedPayment.payment_date,
          payment_method: savedPayment.payment_method,
          transaction_number: savedPayment.transaction_number,
          statement: savedPayment.statement,
          notes: savedPayment.notes
        }
      });
      closePaymentEditor();
      alert('تم حفظ الدفعة');
    } catch (error) {
      console.error('Error saving payment:', error);
      alert('حدث خطأ أثناء حفظ الدفعة');
    } finally {
      setSavingPayment(false);
    }
  };

  const deletePaymentById = async (paymentId: string) => {
    if (!selectedContract) return;
    if (!isAdmin) {
      alert('غير مصرح');
      return;
    }
    if (!confirm('هل تريد حذف هذه الدفعة؟')) return;

    try {
      setSavingPayment(true);
      const { error } = await supabaseClient.supabase.from('contract_payments').delete().eq('id', paymentId);
      if (error) throw error;

      const deletedPayment = (selectedContract.payments || []).find((payment) => payment.id === paymentId) || null;
      const nextPayments = (selectedContract.payments || []).filter(p => p.id !== paymentId);
      await persistPaymentsAndPaidAmount(nextPayments);
      await logContractEvent({
        contract_id: selectedContract.id,
        action: 'payment_deleted',
        entity_type: 'payment',
        entity_id: paymentId,
        metadata: {
          contract_type: selectedContract.type,
          payment_id: paymentId,
          deleted_amount: deletedPayment?.amount ?? null,
          deleted_payment_date: deletedPayment?.payment_date || null,
          deleted_payment_method: deletedPayment?.payment_method || null,
          payments_count_after: nextPayments.length,
          paid_amount_before: selectedContract.paid_amount || 0,
          paid_amount_after: nextPayments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0),
        }
      });
      alert('تم حذف الدفعة');
    } catch (error) {
      console.error('Error deleting payment:', error);
      alert('حدث خطأ أثناء حذف الدفعة');
    } finally {
      setSavingPayment(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" dir="rtl" style={{ background: 'var(--background)' }}>
        <div className="animate-spin rounded-full h-16 w-16 border-b-4 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen pb-20" dir="rtl" style={{ background: 'var(--background)' }}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8 space-y-5">
          <div className="flex flex-wrap items-center gap-4">
            <Link href="/" className="p-3 bg-white rounded-md border border-gray-200 shadow-sm hover:shadow-md transition-all duration-300">
              <ArrowLeft size={20} className="text-gray-700" />
            </Link>
            <h1 className="text-3xl font-extrabold text-gray-900 flex-1">العقود</h1>
            <Link
              href="/contracts/logs"
              className="inline-flex items-center gap-2 px-5 py-3 bg-white border border-gray-300 text-gray-800 rounded-md shadow-sm hover:shadow-md transition-all duration-300 font-bold"
            >
              <ScrollText size={18} />
              سجل الأحداث
            </Link>
          </div>

          <div className="flex flex-wrap items-stretch gap-3 pt-1">
            <button
              type="button"
              onClick={() => openResaleWizard()}
              className="inline-flex min-h-[50px] items-center gap-2 px-5 py-3 bg-white border border-amber-300 text-amber-900 rounded-md shadow-sm hover:shadow-md transition-all duration-300 font-bold"
            >
              <Repeat2 size={18} />
              إنشاء عقد إعادة بيع
            </button>
            <button
              type="button"
              onClick={() => openSettlementWizard()}
              className="inline-flex min-h-[50px] items-center gap-2 px-5 py-3 bg-white border border-violet-300 text-violet-900 rounded-md shadow-sm hover:shadow-md transition-all duration-300 font-bold"
            >
              <FileStack size={18} />
              إنشاء عقد تسوية مالية
            </button>
            <Link
              href="/contracts/waiver/new"
              className="inline-flex min-h-[50px] items-center gap-2 px-5 py-3 bg-white border border-rose-300 text-rose-900 rounded-md shadow-sm hover:shadow-md transition-all duration-300 font-bold"
            >
              <FileSignature size={18} />
              إنشاء تنازل
            </Link>
            <Link
              href="/contracts/deed/new"
              className="inline-flex min-h-[50px] items-center gap-2 px-5 py-3 bg-white border border-purple-300 text-purple-900 rounded-md shadow-sm hover:shadow-md transition-all duration-300 font-bold"
            >
              <FileSignature size={18} />
              إنشاء عقد إفراغ
            </Link>
            <Link
              href="/contracts/new"
              className="inline-flex min-h-[50px] items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-700 to-blue-800 text-white rounded-md shadow-md hover:shadow-lg transition-all duration-300 font-bold"
            >
              <Plus size={20} />
              عقد على الخارطه
            </Link>
          </div>
        </div>

        {/* Contracts List */}
        {selectedContract ? (
          <div className="space-y-6">
            <button
              onClick={() => setSelectedContract(null)}
              className="flex items-center gap-2 text-blue-700 hover:text-blue-800 transition-colors font-semibold"
            >
              <ArrowLeft size={24} />
              العودة لقائمة العقود
            </button>
            
            {selectedContractViewType === 'financial_settlement' && selectedSettlementContract && selectedSettlementBaseContract ? (
              <div className="bg-white rounded-3xl shadow-xl border border-gray-100 overflow-hidden">
                <div className="bg-gradient-to-r from-emerald-700 to-teal-700 px-8 py-6">
                  <div className="flex justify-between items-center">
                    <div>
                      <h2 className="text-2xl font-bold text-white mb-2">تفاصيل عقد تسوية مالية</h2>
                      <div className="flex flex-wrap items-center gap-2">
                        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                          ملحق بعقد إعادة بيع وتحت الإنشاء
                        </div>
                        {selectedSettlementResaleContract && (
                          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                            إعادة بيع: #{selectedSettlementResaleContract.id.slice(0, 8)}
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {isAdmin && (
                        <button
                          type="button"
                          onClick={() => openSettlementWizard(selectedSettlementBaseContract, selectedSettlementContract)}
                          className="flex items-center gap-2 px-5 py-2.5 bg-white text-emerald-800 rounded-xl hover:bg-emerald-50 transition-all font-semibold shadow-sm"
                        >
                          <Pencil size={20} />
                          تعديل
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => {
                          setSettlementPrintData(mapSettlementToPrintData(selectedSettlementBaseContract, selectedSettlementContract));
                          setShowSettlementPrintModal(true);
                          logContractEvent({
                            contract_id: selectedSettlementContract.id,
                            action: 'contract_printed',
                            entity_type: 'contract',
                            entity_id: selectedSettlementContract.id,
                            metadata: {
                              contract_type: 'financial_settlement',
                              print_target: 'financial_settlement',
                              print_template: 'printtasoiah',
                              source_contract_id: selectedSettlementBaseContract.id,
                              resale_contract_id: selectedSettlementResaleContract?.id || null,
                            },
                          });
                        }}
                        className="flex items-center gap-2 px-5 py-2.5 bg-white text-emerald-800 rounded-xl hover:bg-emerald-50 transition-all font-semibold shadow-sm"
                      >
                        <Printer size={20} />
                        طباعة
                      </button>
                      {isAdmin && (
                        <button
                          type="button"
                          onClick={() => deleteSettlementContract(selectedSettlementBaseContract, selectedSettlementContract)}
                          className="p-3 bg-red-50 text-red-600 hover:bg-red-100 rounded-xl transition-all"
                        >
                          <Trash2 size={22} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>

                <div className="p-8 space-y-8">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">رقم العقد (تحت الإنشاء)</label>
                      <p className="text-lg font-bold text-gray-900">#{selectedSettlementBaseContract.id.slice(0, 8)}</p>
                      <p className="text-sm text-gray-500 mt-1">تاريخ العقد السابق: {selectedSettlementBaseContract.contract_date || '—'}</p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">تفاصيل العميل (الأصلي)</label>
                      <p className="text-lg font-bold text-gray-900">
                        {selectedSettlementBaseContract.client?.name || selectedSettlementBaseContract.client_name || '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        هوية: {selectedSettlementBaseContract.client?.id_number || selectedSettlementBaseContract.client_id_number || '—'} • جوال:{' '}
                        {selectedSettlementBaseContract.client?.phone || selectedSettlementBaseContract.client_phone || '—'}
                      </p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">بيانات الوحدة</label>
                      <p className="text-lg font-bold text-gray-900">
                        {selectedSettlementBaseContract.project?.project_number || '—'}-{selectedSettlementBaseContract.unit?.unit_number ?? '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        {selectedSettlementBaseContract.project?.name || 'مشروع غير معروف'} •{' '}
                        {selectedSettlementBaseContract.unit?.description || selectedSettlementBaseContract.unit?.direction_label || '—'}
                      </p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">بيانات التسوية</label>
                      <p className="text-lg font-bold text-gray-900">
                        تاريخ التسوية: {(selectedSettlementContract as any).settlement_date || selectedSettlementContract.contract_date || '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        مبلغ البيع المتفق: {Number((selectedSettlementContract as any).settlement_sale_price ?? selectedSettlementContract.total_amount ?? 0).toLocaleString()} ر.س
                      </p>
                    </div>
                  </div>

                  <div className="bg-emerald-50 border border-emerald-200 rounded-2xl p-5">
                    <div className="text-sm font-bold text-emerald-800 mb-2">العميل بعد التسوية</div>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div className="bg-white/70 border border-emerald-100 rounded-2xl p-4">
                        <div className="text-xs text-emerald-800 font-bold mb-1">الاسم</div>
                        <div className="font-extrabold text-emerald-900">
                          {(selectedSettlementContract as any).settlement_new_owner_name || '—'}
                        </div>
                      </div>
                      <div className="bg-white/70 border border-emerald-100 rounded-2xl p-4">
                        <div className="text-xs text-emerald-800 font-bold mb-1">الهوية</div>
                        <div className="font-extrabold text-emerald-900">
                          {(selectedSettlementContract as any).settlement_new_owner_id_number || '—'}
                        </div>
                      </div>
                      <div className="bg-white/70 border border-emerald-100 rounded-2xl p-4">
                        <div className="text-xs text-emerald-800 font-bold mb-1">الجوال</div>
                        <div className="font-extrabold text-emerald-900">
                          {(selectedSettlementContract as any).settlement_new_owner_phone || '—'}
                        </div>
                      </div>
                    </div>
                    <div className="mt-4 text-sm font-semibold text-emerald-900">
                      {Boolean((selectedSettlementContract as any).settlement_new_owner_client_id)
                        ? 'هذه التسوية تتضمن عميل جديد (تم ربطه في عقد التسوية).'
                        : 'هذه التسوية قد لا تتضمن إضافة عميل جديد، وتم تسجيل بيانات المشتري الجديد للطباعة فقط.'}
                    </div>
                  </div>
                </div>
              </div>
            ) : selectedContractViewType === 'deed' && selectedDeedContract && selectedDeedBaseContract ? (
              <div className="bg-white rounded-3xl shadow-xl border border-gray-100 overflow-hidden">
                <div className="bg-gradient-to-r from-indigo-700 to-purple-700 px-8 py-6">
                  <div className="flex justify-between items-center">
                    <div>
                      <h2 className="text-2xl font-bold text-white mb-2">تفاصيل عقد الإفراغ</h2>
                      <div className="flex flex-wrap items-center gap-2">
                        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                          المخالصة النهائية واستلام الوحدة
                        </div>
                        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                          المصدر: {String((selectedDeedContract as any).deed_recipient_source || 'contract')}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {isAdmin && (
                        <Link
                          href={`/contracts/deed/new?edit=${selectedDeedContract.id}`}
                          className="flex items-center gap-2 px-5 py-2.5 bg-white text-indigo-800 rounded-xl hover:bg-indigo-50 transition-all font-semibold shadow-sm"
                        >
                          <Pencil size={20} />
                          تعديل
                        </Link>
                      )}
                      <button
                        type="button"
                        onClick={() => {
                          setDeedPrintData(mapDeedToPrintData(selectedDeedBaseContract, selectedDeedContract));
                          setShowDeedPrintModal(true);
                          logContractEvent({
                            contract_id: selectedDeedContract.id,
                            action: 'contract_printed',
                            entity_type: 'contract',
                            entity_id: selectedDeedContract.id,
                            metadata: {
                              contract_type: 'deed',
                              print_target: 'deed',
                              print_template: 'printestlam',
                              source_contract_id: selectedDeedBaseContract.id,
                              waiver_contract_id: (selectedDeedContract as any).deed_waiver_contract_id || null,
                              settlement_contract_id: (selectedDeedContract as any).deed_settlement_contract_id || null,
                            },
                          });
                        }}
                        className="flex items-center gap-2 px-5 py-2.5 bg-white text-indigo-800 rounded-xl hover:bg-indigo-50 transition-all font-semibold shadow-sm"
                      >
                        <Printer size={20} />
                        طباعة
                      </button>
                      {isAdmin && (
                        <button
                          type="button"
                          onClick={() => deleteContract(selectedDeedContract.id)}
                          className="p-3 bg-red-50 text-red-600 hover:bg-red-100 rounded-xl transition-all"
                        >
                          <Trash2 size={22} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>

                <div className="p-8 space-y-8">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">رقم عقد الإفراغ</label>
                      <p className="text-lg font-bold text-gray-900">#{selectedDeedContract.id.slice(0, 8)}</p>
                      <p className="text-sm text-gray-500 mt-1">تاريخ الإفراغ: {selectedDeedContract.contract_date || '—'}</p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">مرجع العقد الأساسي</label>
                      <p className="text-lg font-bold text-gray-900">#{selectedDeedBaseContract.id.slice(0, 8)}</p>
                      <p className="text-sm text-gray-500 mt-1">تاريخ العقد الأساسي: {selectedDeedBaseContract.contract_date || '—'}</p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">المشروع والوحدة</label>
                      <p className="text-lg font-bold text-gray-900">
                        {selectedDeedBaseContract.project?.project_number || '—'}-{selectedDeedBaseContract.unit?.unit_number ?? '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        {selectedDeedBaseContract.project?.name || 'مشروع غير معروف'} •{' '}
                        {selectedDeedBaseContract.unit?.description || selectedDeedBaseContract.unit?.direction_label || '—'}
                      </p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">الطرف الثاني في الإفراغ</label>
                      <p className="text-lg font-bold text-gray-900">
                        {(selectedDeedContract as any).deed_recipient_name || selectedDeedContract.client?.name || selectedDeedContract.client_name || '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        هوية: {(selectedDeedContract as any).deed_recipient_id_number || selectedDeedContract.client?.id_number || selectedDeedContract.client_id_number || '—'}
                        {' • '}جوال: {(selectedDeedContract as any).deed_recipient_phone || selectedDeedContract.client?.phone || selectedDeedContract.client_phone || '—'}
                      </p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <div className="bg-gradient-to-br from-indigo-600 to-indigo-700 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">رقم الصك</label>
                      <p className="text-2xl font-extrabold">{(selectedDeedContract as any).deed_unit_deed_number || selectedDeedBaseContract.unit?.deed_number || '—'}</p>
                    </div>
                    <div className="bg-gradient-to-br from-sky-600 to-cyan-700 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">رقم العداد</label>
                      <p className="text-2xl font-extrabold">{(selectedDeedContract as any).deed_meter_number || 'غير مسجل'}</p>
                    </div>
                    <div className="bg-gradient-to-br from-violet-600 to-fuchsia-700 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">رقم الموقف</label>
                      <p className="text-2xl font-extrabold">{(selectedDeedContract as any).deed_parking_number || 'غير مسجل'}</p>
                    </div>
                  </div>

                  <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5">
                    <div className="text-sm font-bold text-indigo-800 mb-3">مصدر العميل النهائي</div>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div className="bg-white/80 border border-indigo-100 rounded-2xl p-4">
                        <div className="text-xs text-indigo-800 font-bold mb-1">طريقة تحديد العميل</div>
                        <div className="font-extrabold text-indigo-900">
                          {(() => {
                            const source = String((selectedDeedContract as any).deed_recipient_source || '').trim();
                            if (source === 'settlement') return 'عميل من التسوية';
                            if (source === 'manual') return 'اختيار يدوي';
                            return 'عميل العقد الأساسي';
                          })()}
                        </div>
                      </div>
                      <div className="bg-white/80 border border-indigo-100 rounded-2xl p-4">
                        <div className="text-xs text-indigo-800 font-bold mb-1">مرجع التنازل</div>
                        <div className="font-extrabold text-indigo-900">
                          {(selectedDeedContract as any).deed_waiver_contract_id
                            ? `#${String((selectedDeedContract as any).deed_waiver_contract_id).slice(0, 8)}`
                            : 'لا يوجد'}
                        </div>
                      </div>
                      <div className="bg-white/80 border border-indigo-100 rounded-2xl p-4">
                        <div className="text-xs text-indigo-800 font-bold mb-1">مرجع التسوية</div>
                        <div className="font-extrabold text-indigo-900">
                          {(selectedDeedContract as any).deed_settlement_contract_id
                            ? `#${String((selectedDeedContract as any).deed_settlement_contract_id).slice(0, 8)}`
                            : 'لا يوجد'}
                        </div>
                      </div>
                    </div>
                    <div className="mt-4 text-sm font-semibold text-indigo-900 leading-7">
                      هذا العقد يمثل المخالصة النهائية للوحدة، وتم فيه تثبيت الطرف الثاني النهائي الذي يستلم الشقة ويكمل إجراءات الإفراغ.
                    </div>
                  </div>
                </div>
              </div>
            ) : selectedContractViewType === 'resale' && selectedResaleContract && selectedResaleBaseContract ? (
              <div className="bg-white rounded-3xl shadow-xl border border-gray-100 overflow-hidden">
                <div className="bg-gradient-to-r from-amber-600 to-orange-600 px-8 py-6">
                  <div className="flex justify-between items-center">
                    <div>
                      <h2 className="text-2xl font-bold text-white mb-2">تفاصيل عقد إعادة بيع</h2>
                      <div className="flex flex-wrap items-center gap-2">
                        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                          مستند على عقد تحت الإنشاء
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {isAdmin && (
                        <button
                          type="button"
                          onClick={() => openResaleWizard(selectedResaleBaseContract)}
                          className="flex items-center gap-2 px-5 py-2.5 bg-white text-amber-800 rounded-xl hover:bg-amber-50 transition-all font-semibold shadow-sm"
                        >
                          <Pencil size={20} />
                          تعديل
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => {
                          setResalePrintData(mapResaleToPrintData(selectedResaleBaseContract, selectedResaleContract));
                          setShowResalePrintModal(true);
                          logContractEvent({
                            contract_id: selectedResaleContract.id,
                            action: 'contract_printed',
                            entity_type: 'contract',
                            entity_id: selectedResaleContract.id,
                            metadata: {
                              contract_type: 'resale',
                              print_target: 'resale',
                              print_template: 'printeaadtbia',
                              source_contract_id: selectedResaleBaseContract.id,
                            },
                          });
                        }}
                        className="flex items-center gap-2 px-5 py-2.5 bg-white text-amber-800 rounded-xl hover:bg-amber-50 transition-all font-semibold shadow-sm"
                      >
                        <Printer size={20} />
                        طباعة
                      </button>
                      {isAdmin && (
                        <button
                          type="button"
                          onClick={() => deleteResaleContract(selectedResaleBaseContract)}
                          className="p-3 bg-red-50 text-red-600 hover:bg-red-100 rounded-xl transition-all"
                        >
                          <Trash2 size={22} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>

                <div className="p-8 space-y-8">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">رقم العقد (تحت الإنشاء)</label>
                      <p className="text-lg font-bold text-gray-900">#{selectedResaleBaseContract.id.slice(0, 8)}</p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">تاريخ العقد السابق</label>
                      <p className="text-lg font-bold text-gray-900">{selectedResaleBaseContract.contract_date || '—'}</p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">تفاصيل العميل</label>
                      <p className="text-lg font-bold text-gray-900">
                        {selectedResaleBaseContract.client?.name || selectedResaleBaseContract.client_name || '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        هوية: {selectedResaleBaseContract.client?.id_number || selectedResaleBaseContract.client_id_number || '—'} • جوال:{' '}
                        {selectedResaleBaseContract.client?.phone || selectedResaleBaseContract.client_phone || '—'}
                      </p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">بيانات الوحدة</label>
                      <p className="text-lg font-bold text-gray-900">
                        {selectedResaleBaseContract.project?.project_number || '—'}-{selectedResaleBaseContract.unit?.unit_number ?? '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        {selectedResaleBaseContract.project?.name || 'مشروع غير معروف'} •{' '}
                        {selectedResaleBaseContract.unit?.description || selectedResaleBaseContract.unit?.direction_label || '—'}
                      </p>
                    </div>
                  </div>

                  <div className="bg-amber-50 border border-amber-200 rounded-2xl p-5">
                    <div className="text-sm font-bold text-amber-800 mb-2">ملاحظة</div>
                    <div className="text-amber-900 font-semibold leading-7">هذه مبالغ متفق عليها وليست مديونية حالية.</div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <div className="bg-gradient-to-br from-emerald-600 to-emerald-700 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">مبلغ البيع المتفق</label>
                      <p className="text-3xl font-extrabold">{Number(selectedResaleContract.resale_agreed_amount || selectedResaleContract.total_amount || 0).toLocaleString()} ر.س</p>
                    </div>
                    <div className="bg-gradient-to-br from-amber-600 to-amber-700 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">رسوم إعادة بيع</label>
                      <p className="text-3xl font-extrabold">{Number(selectedResaleContract.resale_fee || 0).toLocaleString()} ر.س</p>
                    </div>
                    <div className="bg-gradient-to-br from-blue-600 to-blue-700 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">رسوم التسويق</label>
                      <p className="text-3xl font-extrabold">{Number((selectedResaleContract as any).marketing_fee || 0).toLocaleString()} ر.س</p>
                    </div>
                    <div className="bg-gradient-to-br from-purple-600 to-purple-700 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">رسوم الشركة</label>
                      <p className="text-3xl font-extrabold">{Number((selectedResaleContract as any).company_service_fee || 0).toLocaleString()} ر.س</p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-700 to-gray-800 p-6 rounded-2xl text-white shadow-lg">
                      <label className="text-sm font-semibold opacity-90 block mb-2">رسوم المحاماة</label>
                      <p className="text-3xl font-extrabold">{Number((selectedResaleContract as any).lawyer_fee || 0).toLocaleString()} ر.س</p>
                    </div>
                  </div>
                </div>
              </div>
            ) : selectedContractViewType === 'waiver' && selectedWaiverContract && selectedWaiverBaseContract ? (
              <div className="bg-white rounded-3xl shadow-xl border border-gray-100 overflow-hidden">
                <div className="bg-gradient-to-r from-rose-700 to-pink-700 px-8 py-6">
                  <div className="flex justify-between items-center">
                    <div>
                      <h2 className="text-2xl font-bold text-white mb-2">تفاصيل عقد التنازل</h2>
                      <div className="flex flex-wrap items-center gap-2">
                        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                          عقد تنازل
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {isAdmin && (
                        <Link
                          href={`/contracts/waiver/new?edit=${selectedWaiverContract.id}`}
                          className="flex items-center gap-2 px-5 py-2.5 bg-white text-rose-800 rounded-xl hover:bg-rose-50 transition-all font-semibold shadow-sm"
                        >
                          <Pencil size={20} />
                          تعديل
                        </Link>
                      )}
                      <button
                        type="button"
                        onClick={() => {
                          setWaiverPrintData(mapWaiverToPrintData(selectedWaiverBaseContract, selectedWaiverContract));
                          setShowWaiverPrintModal(true);
                          logContractEvent({
                            contract_id: selectedWaiverContract.id,
                            action: 'contract_printed',
                            entity_type: 'contract',
                            entity_id: selectedWaiverContract.id,
                            metadata: {
                              contract_type: 'waiver',
                              print_target: 'waiver',
                              print_template: 'print_tnazol',
                              source_contract_id: selectedWaiverBaseContract.id,
                            },
                          });
                        }}
                        className="flex items-center gap-2 px-5 py-2.5 bg-white text-rose-800 rounded-xl hover:bg-rose-50 transition-all font-semibold shadow-sm"
                      >
                        <Printer size={20} />
                        طباعة
                      </button>
                      {isAdmin && (
                        <button
                          type="button"
                          onClick={() => deleteWaiverContract(selectedWaiverBaseContract, selectedWaiverContract)}
                          className="p-3 bg-red-50 text-red-600 hover:bg-red-100 rounded-xl transition-all"
                        >
                          <Trash2 size={22} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>

                <div className="p-8 space-y-8">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">بيانات التنازل</label>
                      <p className="text-lg font-bold text-gray-900">تاريخ التنازل: {selectedWaiverContract.contract_date || '—'}</p>
                      <p className="text-sm text-gray-500 mt-1">رقم عقد التنازل: #{selectedWaiverContract.id.slice(0, 8)}</p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">بيانات الوحدة</label>
                      <p className="text-lg font-bold text-gray-900">
                        {selectedWaiverBaseContract.project?.project_number || '—'}-{selectedWaiverBaseContract.unit?.unit_number ?? '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        {selectedWaiverBaseContract.project?.name || 'مشروع غير معروف'} •{' '}
                        {selectedWaiverBaseContract.unit?.description || selectedWaiverBaseContract.unit?.direction_label || '—'}
                      </p>
                    </div>
                    <div className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">العقد الحالي بعد التنازل</label>
                      <p className="text-lg font-bold text-gray-900">
                        {selectedWaiverBaseContract.client?.name || selectedWaiverBaseContract.client_name || '—'}
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        هوية: {selectedWaiverBaseContract.client?.id_number || selectedWaiverBaseContract.client_id_number || '—'} • جوال:{' '}
                        {selectedWaiverBaseContract.client?.phone || selectedWaiverBaseContract.client_phone || '—'}
                      </p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                    <div className="bg-amber-50 border border-amber-200 rounded-2xl p-5">
                      <div className="text-sm font-bold text-amber-800 mb-3">العميل السابق</div>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="bg-white/70 border border-amber-100 rounded-2xl p-4">
                          <div className="text-xs text-amber-800 font-bold mb-1">الاسم</div>
                          <div className="font-extrabold text-amber-900">
                            {(selectedWaiverContract as any).waived_previous_client_name || '—'}
                          </div>
                        </div>
                        <div className="bg-white/70 border border-amber-100 rounded-2xl p-4">
                          <div className="text-xs text-amber-800 font-bold mb-1">الهوية</div>
                          <div className="font-extrabold text-amber-900">
                            {(selectedWaiverContract as any).waived_previous_client_id_number || '—'}
                          </div>
                        </div>
                        <div className="bg-white/70 border border-amber-100 rounded-2xl p-4">
                          <div className="text-xs text-amber-800 font-bold mb-1">الجوال</div>
                          <div className="font-extrabold text-amber-900">
                            {(selectedWaiverContract as any).waived_previous_client_phone || '—'}
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="bg-rose-50 border border-rose-200 rounded-2xl p-5">
                      <div className="text-sm font-bold text-rose-800 mb-3">المتنازل له</div>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="bg-white/70 border border-rose-100 rounded-2xl p-4">
                          <div className="text-xs text-rose-800 font-bold mb-1">الاسم</div>
                          <div className="font-extrabold text-rose-900">
                            {(selectedWaiverContract as any).waived_to_client_name || '—'}
                          </div>
                        </div>
                        <div className="bg-white/70 border border-rose-100 rounded-2xl p-4">
                          <div className="text-xs text-rose-800 font-bold mb-1">الهوية</div>
                          <div className="font-extrabold text-rose-900">
                            {(selectedWaiverContract as any).waived_to_client_id_number || '—'}
                          </div>
                        </div>
                        <div className="bg-white/70 border border-rose-100 rounded-2xl p-4">
                          <div className="text-xs text-rose-800 font-bold mb-1">الجوال</div>
                          <div className="font-extrabold text-rose-900">
                            {(selectedWaiverContract as any).waived_to_client_phone || '—'}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="bg-rose-50 border border-rose-200 rounded-2xl p-5">
                    <div className="text-sm font-semibold text-rose-900 leading-7">
                      هذا العرض يركّز على بيانات التنازل نفسها: المتنازل، المتنازل له، وتاريخ التنازل، مع إظهار العميل الحالي بعد اكتمال الإجراء فقط.
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="bg-white rounded-3xl shadow-xl border border-gray-100 overflow-hidden">
              {/* Header */}
              <div className="bg-gradient-to-r from-blue-600 to-blue-700 px-8 py-6">
                <div className="flex justify-between items-center">
                  <div>
                    <h2 className="text-2xl font-bold text-white mb-2">تفاصيل العقد</h2>
                    <div className="flex flex-wrap items-center gap-2">
                      <div className={`inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold ${
                        selectedContract.status === 'active' ? 'bg-green-100 text-green-800' :
                        selectedContract.status === 'completed' ? 'bg-blue-100 text-blue-800' :
                        'bg-yellow-100 text-yellow-800'
                      }`}>
                        {CONTRACT_STATUSES[selectedContract.status as keyof typeof CONTRACT_STATUSES]}
                      </div>
                      <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                        {CONTRACT_TYPES[(selectedContract.type || 'other') as ContractTypeKey] || 'نوع غير محدد'}
                      </div>
                      {Boolean((selectedContract as any).is_legacy) && (
                        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-amber-100 text-amber-900 border border-amber-200">
                          عقد سابق
                        </div>
                      )}
                      {selectedContract.type === 'under_construction' &&
                        Boolean((selectedContract as any).settlement_new_owner_name) && (
                          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                            عميل بعد تسوية
                          </div>
                        )}
                      {selectedContract.type === 'under_construction' &&
                        Boolean((selectedContract as any).waived_previous_client_name) && (
                          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold bg-white/15 text-white border border-white/20">
                            عميل سابق بعد تنازل
                          </div>
                        )}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    {isAdmin && (
                      <Link
                        href={`/contracts/${selectedContract.id}/edit`}
                        className="flex items-center gap-2 px-5 py-2.5 bg-white text-blue-700 rounded-xl hover:bg-blue-50 transition-all font-semibold shadow-sm"
                      >
                        <Pencil size={20} />
                        تعديل العقد
                      </Link>
                    )}
                    <button
                      onClick={() => selectedContract && handlePrintContract(selectedContract)}
                      className="flex items-center gap-2 px-5 py-2.5 bg-white text-blue-700 rounded-xl hover:bg-blue-50 transition-all font-semibold shadow-sm"
                    >
                      <Printer size={20} />
                      طباعة العقد
                    </button>
                    {isAdmin && (
                      <button
                        onClick={() => deleteContract(selectedContract.id)}
                        className={`p-3 rounded-xl transition-all ${
                          selectedContract.type === 'under_construction' && !Boolean((selectedContract as any).is_archived)
                            ? 'bg-amber-50 text-amber-700 hover:bg-amber-100'
                            : 'bg-red-50 text-red-600 hover:bg-red-100'
                        }`}
                        title={
                          selectedContract.type === 'under_construction' && !Boolean((selectedContract as any).is_archived)
                            ? 'أرشفة العقد'
                            : 'حذف العقد'
                        }
                      >
                        {selectedContract.type === 'under_construction' && !Boolean((selectedContract as any).is_archived) ? <FileStack size={22} /> : <Trash2 size={22} />}
                      </button>
                    )}
                  </div>
                </div>
              </div>

              <div className="p-8 space-y-8">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {[
                    { label: 'المشروع', value: selectedContract.project?.name || '—' },
                    { label: 'الوحدة', value: selectedContract.unit?.unit_number ? `الوحدة ${selectedContract.unit.unit_number}` : '—' },
                    { label: 'العميل', value: selectedContract.client?.name || selectedContract.client_name || '—', sub: selectedContract.client?.phone },
                    ...(selectedContract.type === 'under_construction' && (selectedContract as any).settlement_new_owner_name
                      ? [
                          {
                            label: 'عميل بعد تسوية',
                            value: (selectedContract as any).settlement_new_owner_name || '—',
                            sub: `هوية: ${(selectedContract as any).settlement_new_owner_id_number || '—'} • جوال: ${(selectedContract as any).settlement_new_owner_phone || '—'}`,
                          },
                        ]
                      : []),
                    ...(selectedContract.type === 'under_construction' && (selectedContract as any).waived_previous_client_name
                      ? [
                          {
                            label: 'العميل السابق',
                            value: (selectedContract as any).waived_previous_client_name || '—',
                            sub: `هوية: ${(selectedContract as any).waived_previous_client_id_number || '—'} • جوال: ${(selectedContract as any).waived_previous_client_phone || '—'}`,
                          },
                        ]
                      : []),
                    { label: 'تاريخ العقد', value: selectedContract.contract_date }
                  ].map((item, idx) => (
                    <div key={idx} className="bg-gradient-to-br from-gray-50 to-white p-5 rounded-2xl border border-gray-100">
                      <label className="text-sm font-semibold text-gray-600 block mb-2">{item.label}</label>
                      <p className="text-lg font-bold text-gray-900">{item.value}</p>
                      {item.sub && <p className="text-sm text-gray-500 mt-1">{item.sub}</p>}
                    </div>
                  ))}
                </div>

                {isAdmin && (
                  <div className="flex flex-col md:flex-row gap-3">
                    <button
                      onClick={syncUnitClientFromContract}
                      disabled={syncingUnit}
                      className={`flex-1 px-5 py-3 rounded-2xl font-semibold transition-all ${
                        syncingUnit
                          ? 'bg-gray-100 text-gray-500 cursor-not-allowed'
                          : 'bg-blue-50 text-blue-700 hover:bg-blue-100'
                      }`}
                    >
                      {syncingUnit ? 'جارٍ تحديث بيانات الوحدة...' : 'تحديث بيانات العميل في الوحدة'}
                    </button>
                    <button
                      onClick={syncDebtClientFromContract}
                      disabled={syncingDebt}
                      className={`flex-1 px-5 py-3 rounded-2xl font-semibold transition-all ${
                        syncingDebt
                          ? 'bg-gray-100 text-gray-500 cursor-not-allowed'
                          : 'bg-green-50 text-green-700 hover:bg-green-100'
                      }`}
                    >
                      {syncingDebt ? 'جارٍ تحديث المديونية...' : 'تحديث اسم/جوال العميل في المديونية'}
                    </button>
                  </div>
                )}

                {selectedContract.type === 'under_construction' && (
                  <div className="pt-6 border-t border-gray-100 space-y-5">
                    <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
                      <div>
                        <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                          <div className="w-1.5 h-8 bg-indigo-600 rounded-full"></div>
                          مرفقات العقد
                        </h3>
                        <p className="mt-1 text-sm text-gray-500">
                          هذه الملفات ستُضاف في نهاية ملف `PDF` عند الضغط على تحميل العقد، ولن تغيّر طباعة المتصفح الحالية.
                        </p>
                      </div>
                      {loadingAttachments && (
                        <div className="inline-flex items-center gap-2 text-sm font-semibold text-gray-500">
                          <Loader2 size={16} className="animate-spin" />
                          جاري تحميل المرفقات...
                        </div>
                      )}
                    </div>

                    <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
                      {(Object.keys(CONTRACT_ATTACHMENT_LABELS) as ContractAttachmentCategory[]).map((category) => {
                        const items = (selectedContract.attachments || []).filter((attachment) => attachment.category === category);
                        const isUploading = uploadingAttachmentCategory === category;
                        return (
                          <div key={category} className="rounded-2xl border border-gray-200 bg-gray-50/70 p-5 space-y-4">
                            <div>
                              <div className="text-base font-extrabold text-gray-900">{CONTRACT_ATTACHMENT_LABELS[category]}</div>
                              <div className="mt-1 text-sm text-gray-500">{CONTRACT_ATTACHMENT_DESCRIPTIONS[category]}</div>
                            </div>

                            <label className={`flex items-center justify-center gap-2 px-4 py-3 rounded-xl border-2 border-dashed transition-colors ${
                              isUploading ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-300 bg-white text-gray-700 hover:border-indigo-400 hover:text-indigo-700'
                            } cursor-pointer`}>
                              {isUploading ? <Loader2 size={18} className="animate-spin" /> : <Upload size={18} />}
                              <span className="font-bold">{isUploading ? 'جارٍ الرفع...' : `رفع ${CONTRACT_ATTACHMENT_LABELS[category]}`}</span>
                              <input
                                type="file"
                                accept=".pdf,image/*"
                                className="hidden"
                                disabled={isUploading}
                                onChange={(e) => {
                                  const file = e.target.files?.[0];
                                  e.currentTarget.value = '';
                                  if (file) uploadContractAttachment(category, file);
                                }}
                              />
                            </label>

                            {items.length === 0 ? (
                              <div className="rounded-xl border border-gray-200 bg-white px-4 py-5 text-sm font-semibold text-gray-500 text-center">
                                لا توجد ملفات مرفوعة في هذا القسم.
                              </div>
                            ) : (
                              <div className="space-y-3">
                                {items.map((attachment) => (
                                  <div key={attachment.id} className="rounded-xl border border-gray-200 bg-white p-4">
                                    <div className="flex items-start justify-between gap-3">
                                      <div className="min-w-0">
                                        <div className="flex items-center gap-2">
                                          {attachment.file_type === 'pdf' ? (
                                            <FileText size={16} className="text-red-600" />
                                          ) : (
                                            <FileImage size={16} className="text-sky-600" />
                                          )}
                                          <div className="truncate font-bold text-gray-900">{attachment.file_name}</div>
                                        </div>
                                        <div className="mt-1 text-xs text-gray-500">
                                          {attachment.file_type === 'pdf' ? 'ملف PDF' : 'صورة'} • {new Date(attachment.created_at).toLocaleString('ar-SA')}
                                        </div>
                                      </div>
                                      <div className="flex items-center gap-2">
                                        <button
                                          type="button"
                                          onClick={() => openContractAttachment(attachment)}
                                          disabled={openingAttachmentId === attachment.id}
                                          className="inline-flex items-center gap-1 px-3 py-2 rounded-lg bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition-colors text-sm font-bold disabled:opacity-60"
                                        >
                                          {openingAttachmentId === attachment.id ? <Loader2 size={14} className="animate-spin" /> : <Eye size={14} />}
                                          فتح
                                        </button>
                                        {isAdmin && (
                                          <button
                                            type="button"
                                            onClick={() => deleteContractAttachment(attachment)}
                                            disabled={deletingAttachmentId === attachment.id}
                                            className="inline-flex items-center gap-1 px-3 py-2 rounded-lg bg-red-50 text-red-700 hover:bg-red-100 transition-colors text-sm font-bold disabled:opacity-60"
                                          >
                                            {deletingAttachmentId === attachment.id ? <Loader2 size={14} className="animate-spin" /> : <Trash2 size={14} />}
                                            حذف
                                          </button>
                                        )}
                                      </div>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-4">
                  <div className="bg-gradient-to-br from-blue-500 to-blue-600 p-6 rounded-2xl text-white shadow-lg">
                    <label className="text-sm font-semibold opacity-90 block mb-2">قيمة العقد الكلية</label>
                    <p className="text-3xl font-extrabold">{selectedContract.total_amount.toLocaleString()} ر.س</p>
                  </div>
                  <div className="bg-gradient-to-br from-green-500 to-green-600 p-6 rounded-2xl text-white shadow-lg">
                    <label className="text-sm font-semibold opacity-90 block mb-2">المدفوع</label>
                    <p className="text-3xl font-extrabold">{selectedContract.paid_amount.toLocaleString()} ر.س</p>
                  </div>
                  <div className="bg-gradient-to-br from-amber-500 to-amber-600 p-6 rounded-2xl text-white shadow-lg">
                    <label className="text-sm font-semibold opacity-90 block mb-2">المتبقي</label>
                    <p className="text-3xl font-extrabold">{(selectedContract.total_amount - selectedContract.paid_amount).toLocaleString()} ر.س</p>
                  </div>
                </div>

                {/* Obligations */}
                {selectedContract.obligations && selectedContract.obligations.length > 0 && (
                  <div className="pt-6 border-t border-gray-100">
                    <h3 className="text-xl font-bold text-gray-900 mb-5 flex items-center gap-2">
                      <div className="w-1.5 h-8 bg-blue-600 rounded-full"></div>
                      الالتزامات
                    </h3>
                    <div className="grid gap-3">
                      {selectedContract.obligations.map((obligation: ContractObligation) => (
                        <div key={obligation.id} className="flex items-center justify-between p-5 bg-gradient-to-r from-gray-50 to-white rounded-2xl border border-gray-100">
                          <div>
                            <span className="font-bold text-gray-900 text-lg">{obligation.description}</span>
                            <span className="mx-3 text-gray-400">•</span>
                            <span className="text-gray-700 font-mono font-semibold text-xl">{obligation.amount.toLocaleString()} ر.س</span>
                          </div>
                          <div className={`px-4 py-2 rounded-full text-xs font-bold ${
                            obligation.paid ? 'bg-green-100 text-green-800' : 'bg-amber-100 text-amber-800'
                          }`}>
                            {obligation.paid ? '✓ مدفوع' : '⏳ غير مدفوع'}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Payments */}
                <div className="pt-6 border-t border-gray-100">
                  <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between mb-5">
                    <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                      <div className="w-1.5 h-8 bg-green-600 rounded-full"></div>
                      الدفعات
                    </h3>
                    <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-end">
                      <button
                        onClick={openNewPaymentEditor}
                        className="inline-flex items-center justify-center gap-2 px-5 py-2.5 bg-green-600 text-white hover:bg-green-700 rounded-xl transition-colors font-semibold"
                      >
                        <Plus size={18} />
                        إضافة دفعة
                      </button>
                      {isAdmin && (
                        <Link
                          href={`/contracts/${selectedContract.id}/edit#payments-section`}
                          className="inline-flex items-center justify-center gap-2 px-5 py-2.5 bg-green-50 text-green-700 hover:bg-green-100 rounded-xl transition-all font-semibold"
                        >
                          <Pencil size={18} />
                          تعديل شامل للدفعات
                        </Link>
                      )}
                    </div>
                  </div>

                  {isPaymentEditorOpen && (
                    <div className="rounded-2xl border border-gray-200 bg-white p-6 mb-5">
                      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between mb-5">
                        <div>
                          <p className="text-lg font-extrabold text-gray-900">
                            {editingPaymentId ? 'تعديل دفعة' : 'إضافة دفعة'}
                          </p>
                          <p className="text-sm text-gray-500">يتم الحفظ مباشرة دون الدخول لصفحة تعديل العقد</p>
                        </div>
                        <button
                          onClick={closePaymentEditor}
                          className="px-5 py-2.5 text-gray-700 border border-gray-300 rounded-xl hover:bg-gray-50 transition-all font-semibold"
                        >
                          إغلاق
                        </button>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">المبلغ</label>
                          <input
                            type="number"
                            value={paymentForm.amount}
                            onChange={(e) => setPaymentForm(prev => ({ ...prev, amount: Number(e.target.value || 0) }))}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 transition-all"
                          />
                        </div>
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">التاريخ</label>
                          <input
                            type="date"
                            value={paymentForm.payment_date}
                            onChange={(e) => setPaymentForm(prev => ({ ...prev, payment_date: e.target.value }))}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 transition-all"
                          />
                        </div>
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">طريقة الدفع</label>
                          <select
                            value={paymentForm.payment_method || ''}
                            onChange={(e) =>
                              setPaymentForm(prev => ({
                                ...prev,
                                payment_method: (e.target.value || null) as any
                              }))
                            }
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 transition-all bg-white"
                          >
                            <option value="">—</option>
                            {Object.keys(PAYMENT_METHODS).map((k) => (
                              <option key={k} value={k}>
                                {PAYMENT_METHODS[k as keyof typeof PAYMENT_METHODS]}
                              </option>
                            ))}
                          </select>
                        </div>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">الرقم المرجعي</label>
                          <input
                            type="text"
                            value={paymentForm.transaction_number}
                            onChange={(e) => setPaymentForm(prev => ({ ...prev, transaction_number: e.target.value }))}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 transition-all"
                            placeholder="رقم العملية / رقم التحويل / رقم الشيك"
                          />
                        </div>
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">البيان</label>
                          <input
                            type="text"
                            value={paymentForm.statement}
                            onChange={(e) => setPaymentForm(prev => ({ ...prev, statement: e.target.value }))}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 transition-all"
                            placeholder="مثال: دفعة مقدمة، دفعة شهرية..."
                          />
                        </div>
                      </div>

                      <div className="space-y-2 mt-4">
                        <label className="text-sm font-semibold text-gray-700">ملاحظات</label>
                        <textarea
                          value={paymentForm.notes}
                          onChange={(e) => setPaymentForm(prev => ({ ...prev, notes: e.target.value }))}
                          className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 transition-all min-h-[110px]"
                          placeholder="أي تفاصيل إضافية..."
                        />
                      </div>

                      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-end mt-5">
                        <button
                          onClick={closePaymentEditor}
                          disabled={savingPayment}
                          className="px-6 py-3 rounded-2xl border border-gray-200 bg-white text-gray-700 font-semibold hover:bg-gray-50 transition-colors disabled:opacity-60"
                        >
                          إلغاء
                        </button>
                        <button
                          onClick={savePaymentFromEditor}
                          disabled={savingPayment}
                          className="px-6 py-3 rounded-2xl bg-green-600 text-white font-semibold hover:bg-green-700 transition-colors disabled:opacity-60"
                        >
                          {savingPayment ? 'جارٍ الحفظ...' : 'حفظ الدفعة'}
                        </button>
                      </div>
                    </div>
                  )}

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-5">
                    <div className="rounded-2xl border border-green-100 bg-green-50/70 p-4">
                      <div className="flex items-center gap-2 text-green-800 mb-2">
                        <Wallet size={18} />
                        <span className="text-sm font-semibold">إجمالي المدفوع</span>
                      </div>
                      <p className="text-2xl font-extrabold text-green-900">
                        {(selectedContract.payments || []).reduce((sum, payment) => sum + Number(payment.amount || 0), 0).toLocaleString()} ر.س
                      </p>
                    </div>
                    <div className="rounded-2xl border border-blue-100 bg-blue-50/70 p-4">
                      <div className="flex items-center gap-2 text-blue-800 mb-2">
                        <CalendarDays size={18} />
                        <span className="text-sm font-semibold">عدد الدفعات</span>
                      </div>
                      <p className="text-2xl font-extrabold text-blue-900">
                        {(selectedContract.payments || []).length}
                      </p>
                    </div>
                    <div className="rounded-2xl border border-amber-100 bg-amber-50/70 p-4">
                      <div className="flex items-center gap-2 text-amber-800 mb-2">
                        <Wallet size={18} />
                        <span className="text-sm font-semibold">المتبقي بعد الدفعات</span>
                      </div>
                      <p className="text-2xl font-extrabold text-amber-900">
                        {Math.max(
                          Number(selectedContract.total_amount || 0) -
                            (selectedContract.payments || []).reduce((sum, payment) => sum + Number(payment.amount || 0), 0),
                          0
                        ).toLocaleString()} ر.س
                      </p>
                    </div>
                  </div>

                  {selectedContract.payments && selectedContract.payments.length > 0 ? (
                    <div className="grid gap-4">
                      {selectedContract.payments.map((payment, index) => (
                        <div key={payment.id} className="p-5 bg-gradient-to-r from-green-50 to-white rounded-2xl border border-green-100">
                          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                            <div className="flex-1">
                              <div className="flex items-center gap-3 flex-wrap">
                                <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-green-100 text-green-700 text-sm font-bold">
                                  {index + 1}
                                </span>
                                <span className="font-extrabold text-green-800 font-mono text-2xl">
                                  {payment.amount.toLocaleString()} ر.س
                                </span>
                              </div>
                              <div className="mt-3 flex flex-wrap gap-3 text-sm text-gray-700">
                                <span className="bg-white px-3 py-1.5 rounded-lg border border-gray-200">
                                  التاريخ: {payment.payment_date || '—'}
                                </span>
                                <span className="bg-white px-3 py-1.5 rounded-lg border border-green-200 font-semibold">
                                  الطريقة: {payment.payment_method ? PAYMENT_METHODS[payment.payment_method as keyof typeof PAYMENT_METHODS] : '—'}
                                </span>
                                <span className="bg-white px-3 py-1.5 rounded-lg border border-gray-200">
                                  رقم العملية: {payment.transaction_number || '—'}
                                </span>
                              </div>
                            </div>
                            <div className="lg:max-w-xl w-full space-y-2">
                              <div className="bg-white px-4 py-3 rounded-xl border border-gray-200">
                                <p className="text-xs text-gray-500 mb-1 font-semibold">البيان</p>
                                <p className="text-sm text-gray-800">{payment.statement || '—'}</p>
                              </div>
                              <div className="bg-white px-4 py-3 rounded-xl border border-gray-200">
                                <p className="text-xs text-gray-500 mb-1 font-semibold">ملاحظات</p>
                                <p className="text-sm text-gray-800">{payment.notes || '—'}</p>
                              </div>
                            </div>
                            {isAdmin && (
                              <div className="flex items-center gap-2 lg:flex-col lg:items-stretch">
                                <button
                                  onClick={() => openEditPaymentEditor(payment)}
                                  disabled={savingPayment}
                                  className="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-white text-green-700 border border-green-200 hover:bg-green-50 transition-colors font-semibold disabled:opacity-60"
                                >
                                  <Pencil size={18} />
                                  تعديل
                                </button>
                                <button
                                  onClick={() => deletePaymentById(payment.id)}
                                  disabled={savingPayment}
                                  className="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-white text-red-600 border border-red-200 hover:bg-red-50 transition-colors font-semibold disabled:opacity-60"
                                >
                                  <Trash2 size={18} />
                                  حذف
                                </button>
                              </div>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="rounded-2xl border border-dashed border-gray-300 bg-gray-50 px-6 py-8 text-center">
                      <p className="text-gray-700 font-semibold mb-2">لا توجد دفعات مضافة لهذا العقد حالياً</p>
                      <p className="text-sm text-gray-500 mb-4">أضف أول دفعة من هنا مباشرة.</p>
                      <button
                        onClick={openNewPaymentEditor}
                        className="inline-flex items-center gap-2 px-5 py-2.5 bg-green-600 text-white rounded-xl hover:bg-green-700 transition-colors font-semibold"
                      >
                        <Plus size={18} />
                        إضافة أول دفعة
                      </button>
                    </div>
                  )}
                </div>

                {/* Agent */}
                <div className="pt-6 border-t border-gray-100">
                  <div className="flex items-center justify-between mb-6">
                    <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                      <div className="w-1.5 h-8 bg-purple-600 rounded-full"></div>
                      الوكيل
                    </h3>
                    {isAdmin &&
                      (!isEditingAgent ? (
                        <button
                          onClick={() => setIsEditingAgent(true)}
                          className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-xl hover:shadow-lg transition-all font-semibold"
                        >
                          <Plus size={20} />
                          {selectedContract.agent_name ? 'تعديل' : 'إضافة وكيل'}
                        </button>
                      ) : (
                        <div className="flex gap-3">
                          <button
                            onClick={() => setIsEditingAgent(false)}
                            className="px-5 py-2.5 text-gray-700 border border-gray-300 rounded-xl hover:bg-gray-50 transition-all font-semibold"
                          >
                            إلغاء
                          </button>
                          <button
                            onClick={handleSaveAgent}
                            className="px-5 py-2.5 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl hover:shadow-lg transition-all font-semibold"
                          >
                            حفظ
                          </button>
                        </div>
                      ))}
                  </div>

                  {isAdmin && isEditingAgent ? (
                    <div className="space-y-5">
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">رقم هوية الوكيل</label>
                          <input
                            type="text"
                            value={agentForm.agent_id_number}
                            onChange={(e) => {
                              const newId = e.target.value;
                              setAgentForm({ ...agentForm, agent_id_number: newId });
                              searchClientByIdNumber(newId);
                            }}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                            placeholder="رقم الهوية للبحث"
                          />
                          {foundClient && (
                            <div className="bg-gradient-to-r from-green-50 to-emerald-50 border-2 border-green-200 rounded-xl p-4 mt-3">
                              <p className="text-green-800 font-bold">✅ تم العثور على العميل: {foundClient.name}</p>
                              <p className="text-green-700 text-sm font-medium mt-1">رقم الجوال: {foundClient.phone}</p>
                            </div>
                          )}
                        </div>
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">اسم الوكيل</label>
                          <input
                            type="text"
                            value={agentForm.agent_name}
                            onChange={(e) => setAgentForm({ ...agentForm, agent_name: e.target.value })}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                            placeholder="اسم الوكيل"
                          />
                        </div>
                        {!foundClient && (
                          <div className="space-y-2">
                            <label className="text-sm font-semibold text-gray-700">رقم الجوال (لإضافة كعميل جديد)</label>
                            <input
                              type="tel"
                              value={agentForm.agent_phone}
                              onChange={(e) => setAgentForm({ ...agentForm, agent_phone: e.target.value })}
                              className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                              placeholder="رقم الجوال"
                              />
                          </div>
                        )}
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">رقم الوكالة</label>
                          <input
                            type="text"
                            value={agentForm.agency_number}
                            onChange={(e) => setAgentForm({ ...agentForm, agency_number: e.target.value })}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                            placeholder="رقم الوكالة"
                          />
                        </div>
                        <div className="space-y-2">
                          <label className="text-sm font-semibold text-gray-700">تاريخ الوكالة</label>
                          <input
                            type="date"
                            value={agentForm.agency_date}
                            onChange={(e) => setAgentForm({ ...agentForm, agency_date: e.target.value })}
                            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                          />
                        </div>
                      </div>
                    </div>
                  ) : selectedContract.agent_name ? (
                    <div className="space-y-5">
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                        {[
                          { label: 'اسم الوكيل', value: selectedContract.agent_name },
                          { label: 'رقم هوية الوكيل', value: selectedContract.agent_id_number },
                          { label: 'رقم الوكالة', value: selectedContract.agency_number },
                          { label: 'تاريخ الوكالة', value: selectedContract.agency_date }
                        ].map((item, idx) => (
                          <div key={idx} className="bg-gradient-to-br from-purple-50 to-white p-5 rounded-2xl border border-purple-100">
                            <label className="text-sm font-semibold text-purple-700 block mb-2">{item.label}</label>
                            <p className="text-lg font-bold text-gray-900">{item.value}</p>
                          </div>
                        ))}
                      </div>
                      {isAdmin && (
                        <button
                          onClick={handleClearAgent}
                          className="text-red-600 hover:text-red-700 text-sm font-semibold flex items-center gap-2"
                        >
                          <Trash2 size={18} />
                          مسح بيانات الوكيل
                        </button>
                      )}
                    </div>
                  ) : (
                    <div className="text-center py-12 bg-gradient-to-r from-gray-50 to-white rounded-2xl border border-gray-100">
                      <p className="text-xl font-semibold text-gray-500">لا يوجد وكيل مضاف بعد</p>
                    </div>
                  )}
                </div>
              </div>
            </div>
            )}
          </div>
        ) : (
          <div className="space-y-6">
            <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-3">
              {contractTypeCards.map((item) => {
                const count = contractsCountByType[item.key] || 0;
                const isActive = activeContractTypeFilter === item.key;

                return (
                  <div
                    key={item.key}
                    onClick={() => setActiveContractTypeFilter(item.key)}
                    className={`text-right rounded-md border px-3 py-3 shadow-md transition-all hover:-translate-y-0.5 hover:shadow-lg cursor-pointer ${item.border} ${item.bg} ${isActive ? 'ring-2 ring-offset-2 ring-blue-300 shadow-lg' : ''}`}
                  >
                    <div className="flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <h3 className="text-sm font-extrabold text-gray-900 leading-6">{item.title}</h3>
                      </div>
                      <div
                        className={`h-11 w-11 shrink-0 rounded-full border-2 border-white/90 bg-gradient-to-br ${item.accent} text-white flex items-center justify-center shadow-md ring-2 ring-black/5`}
                      >
                        <span className="text-sm font-extrabold leading-none">{count}</span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="overflow-x-auto pb-2">
              <div className="flex min-w-max items-center gap-4 border-b border-gray-200 pb-3">
                <span className="text-sm font-bold text-gray-500">الفلترة:</span>
                <button
                  type="button"
                  onClick={() => setActiveContractTypeFilter('all')}
                  className={`text-sm font-semibold transition-colors ${
                    activeContractTypeFilter === 'all'
                      ? 'text-blue-700 underline underline-offset-4'
                      : 'text-gray-600 hover:text-gray-900'
                  }`}
                >
                  جميع العقود
                </button>
                {Object.entries(CONTRACT_TYPES).map(([key, label]) => (
                  <button
                    key={key}
                    type="button"
                    onClick={() => setActiveContractTypeFilter(key as ContractTypeKey)}
                    className={`text-sm font-semibold transition-colors ${
                      activeContractTypeFilter === key
                        ? 'text-blue-700 underline underline-offset-4'
                        : 'text-gray-600 hover:text-gray-900'
                    }`}
                  >
                    {label}
                  </button>
                ))}
                <button
                  type="button"
                  onClick={() => setShowArchivedContracts((prev) => !prev)}
                  className={`text-sm font-semibold transition-colors ${
                    showArchivedContracts
                      ? 'text-amber-700 underline underline-offset-4'
                      : 'text-gray-600 hover:text-amber-700'
                  }`}
                >
                  {showArchivedContracts ? 'عرض الحالية' : 'عرض المؤرشفة'}
                </button>
                <span className="text-sm text-gray-400">|</span>
                <span className="text-sm text-gray-500">
                  المعروض: <span className="font-extrabold text-gray-900">{filteredContracts.length}</span>
                </span>
              </div>
            </div>

            <div className="flex items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-3 shadow-sm">
              <Search size={18} className="text-gray-500" />
              <input
                type="text"
                value={contractsSearchQuery}
                onChange={(e) => setContractsSearchQuery(e.target.value)}
                placeholder="بحث سريع باسم العميل أو رقم المشروع - رقم الوحدة"
                className="w-full bg-transparent text-sm font-medium text-gray-800 outline-none placeholder:text-gray-400"
              />
            </div>

            {filteredContracts.length === 0 ? (
              <div className="bg-white rounded-3xl shadow-lg border border-gray-100 p-16 text-center">
                <div className="w-20 h-20 bg-gradient-to-br from-blue-100 to-blue-200 rounded-full flex items-center justify-center mx-auto mb-6">
                  <Plus size={40} className="text-blue-600" />
                </div>
                <h3 className="text-2xl font-extrabold text-gray-900 mb-3">
                  {activeContractTypeFilter === 'all'
                    ? 'لا توجد عقود بعد'
                    : `لا توجد عقود ضمن قسم ${CONTRACT_TYPES[activeContractTypeFilter as ContractTypeKey] || 'هذا النوع'}`}
                </h3>
                <p className="text-lg text-gray-500 mb-8">
                  {activeContractTypeFilter === 'under_construction'
                    ? 'ابدأ بإضافة أول عقد تحت الإنشاء.'
                    : `لا توجد عقود مسجلة حاليًا ضمن قسم ${CONTRACT_TYPES[activeContractTypeFilter as ContractTypeKey] || 'هذا النوع'}، وستظهر هنا مباشرة عند إضافتها.`}
                </p>
                <Link
                  href="/contracts/new"
                  className="inline-flex items-center gap-3 px-8 py-4 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-1 transition-all font-semibold text-lg"
                >
                  <Plus size={24} />
                  إضافة عقد جديد
                </Link>
              </div>
            ) : (
              <div className="space-y-5">
                {Object.entries(groupedContracts).map(([typeKey, items]) => (
                  <div key={typeKey} className="space-y-4">
                    <div className="flex items-center gap-3">
                      <div className="w-1.5 h-8 bg-blue-600 rounded-full"></div>
                      <h3 className="text-xl font-extrabold text-gray-900">
                        {CONTRACT_TYPES[typeKey as ContractTypeKey] || 'نوع غير محدد'}
                      </h3>
                      <span className="px-3 py-1 rounded-full bg-gray-100 text-gray-700 text-sm font-bold">
                        {items.length}
                      </span>
                    </div>

                    <div className="overflow-x-auto">
                      <div className="min-w-[1100px] space-y-2">
                        {items.map((contract, index) => (
                          <div
                            key={contract.id}
                            className={`group relative overflow-hidden border border-gray-200 text-[11px] text-gray-700 shadow-sm hover:border-blue-200 cursor-pointer ${
                              index % 2 === 0
                                ? 'bg-white'
                                : typeKey === 'under_construction'
                                  ? 'bg-blue-50/40'
                                  : typeKey === 'resale'
                                    ? 'bg-amber-50/40'
                                    : typeKey === 'financial_settlement'
                                      ? 'bg-emerald-50/40'
                                      : typeKey === 'waiver'
                                        ? 'bg-rose-50/40'
                                        : typeKey === 'deed'
                                          ? 'bg-purple-50/40'
                                          : 'bg-gray-50'
                            }`}
                            onClick={() => setSelectedContract(contract)}
                          >
                            <div className="relative z-10 grid grid-cols-[1.1fr_1.6fr_1.4fr_0.95fr_1fr_1fr_0.9fr_0.8fr] transition-all duration-300 group-hover:opacity-0 group-hover:pointer-events-none">
                              <div className="px-3 py-2.5 border-l border-gray-100">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">العقد</div>
                                <div className="whitespace-nowrap font-bold text-gray-900">#{contract.id.slice(0, 8)}</div>
                                <div className="mt-1 text-[10px] text-gray-500 whitespace-nowrap">
                                  {CONTRACT_TYPES[((activeContractTypeFilter === 'resale' ? 'resale' : (contract.type || 'other')) as ContractTypeKey)] || 'نوع غير محدد'}
                                </div>
                                {Boolean((contract as any).is_legacy) && (
                                  <div className="mt-1 text-[10px] font-extrabold text-amber-700 whitespace-nowrap">
                                    عقد سابق
                                  </div>
                                )}
                              </div>
                              <div className="px-3 py-2.5 border-l border-gray-100">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">المشروع / الوحدة</div>
                                <div className="whitespace-nowrap font-semibold text-gray-800">
                                  {contract.project?.name || 'مشروع غير معروف'}
                                </div>
                                <div className="mt-1 whitespace-nowrap text-[10px] text-gray-500">
                                  {contract.project?.project_number || '—'} / {contract.unit?.unit_number ? `الوحدة ${contract.unit.unit_number}` : 'وحدة غير معروفة'}
                                </div>
                              </div>
                              <div className="px-3 py-2.5 border-l border-gray-100">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">العميل</div>
                                <div className="whitespace-nowrap font-semibold text-gray-800">
                                  {contract.client?.name || contract.client_name || '—'}
                                </div>
                                {contract.type === 'under_construction' && contract.resale_contract_id ? (
                                  <div className="mt-1 text-[10px] font-bold text-rose-700 whitespace-nowrap">مرتبط بإعادة بيع</div>
                                ) : null}
                              </div>
                              <div className="px-3 py-2.5 border-l border-gray-100">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">التاريخ</div>
                                <div className="whitespace-nowrap font-semibold text-gray-800">
                                  {contract.contract_date || '—'}
                                </div>
                              </div>
                              <div className="px-3 py-2.5 border-l border-gray-100">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">
                                  {contract.type === 'resale' ? 'مبلغ البيع' : 'القيمة'}
                                </div>
                                <div className="whitespace-nowrap font-bold text-blue-700">
                                  {Number((contract.type === 'resale' ? (contract.resale_agreed_amount ?? contract.total_amount) : contract.total_amount) || 0).toLocaleString()}
                                </div>
                              </div>
                              <div className="px-3 py-2.5 border-l border-gray-100">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">
                                  {contract.type === 'resale' ? 'الرسوم' : 'المدفوع'}
                                </div>
                                <div className="whitespace-nowrap font-bold text-green-700">
                                  {contract.type === 'resale'
                                    ? Number(
                                        (Number(contract.resale_fee || 0) +
                                          Number((contract as any).marketing_fee || 0) +
                                          Number((contract as any).company_service_fee || 0) +
                                          Number((contract as any).lawyer_fee || 0)) || 0
                                      ).toLocaleString()
                                    : Number(contract.paid_amount || 0).toLocaleString()}
                                </div>
                              </div>
                              <div className="px-3 py-2.5 border-l border-gray-100">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">الحالة</div>
                                <div className="whitespace-nowrap font-semibold text-gray-800">
                                  {CONTRACT_STATUSES[contract.status as keyof typeof CONTRACT_STATUSES]}
                                </div>
                              </div>
                              <div className="px-3 py-2.5">
                                <div className="text-[10px] font-bold text-gray-400 mb-1">إجراء</div>
                                {isAdmin ? (
                                  <button
                                    type="button"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      deleteContract(contract.id);
                                    }}
                                    title={
                                      contract.type === 'under_construction' && !Boolean((contract as any).is_archived)
                                        ? 'أرشفة العقد'
                                        : 'حذف العقد'
                                    }
                                    className={`inline-flex h-8 w-8 items-center justify-center border border-transparent transition-all ${
                                      contract.type === 'under_construction' && !Boolean((contract as any).is_archived)
                                        ? 'text-amber-700 hover:bg-amber-50 hover:border-amber-200 hover:text-amber-800'
                                        : 'text-red-600 hover:bg-red-50 hover:border-red-200 hover:text-red-700'
                                    }`}
                                  >
                                    {contract.type === 'under_construction' && !Boolean((contract as any).is_archived) ? <Archive size={16} /> : <Trash2 size={16} />}
                                  </button>
                                ) : (
                                  <span
                                    title="عرض تفاصيل العقد"
                                    className="inline-flex h-8 w-8 items-center justify-center text-gray-400"
                                  >
                                    <Eye size={16} />
                                  </span>
                                )}
                              </div>
                            </div>

                            <div
                              className="pointer-events-none absolute inset-0 z-20 flex items-center justify-between gap-6 px-6 text-white opacity-0 translate-y-1 transition-all duration-300 group-hover:opacity-100 group-hover:translate-y-0"
                              style={{ backgroundColor: getHoverOverlayColor(typeKey) }}
                            >
                                <div className="text-right">
                                  <div className="text-[10px] font-bold text-white/70 mb-1">المشروع / الوحدة</div>
                                  <div className="text-lg font-extrabold whitespace-nowrap">
                                    {contract.project?.project_number || '—'} / {contract.unit?.unit_number ? `الوحدة ${contract.unit.unit_number}` : 'وحدة غير معروفة'}
                                  </div>
                                </div>
                                <div className="text-left">
                                  <div className="text-[10px] font-bold text-white/70 mb-1">العميل</div>
                                  <div className="text-lg font-extrabold whitespace-nowrap">
                                    {contract.client?.name || contract.client_name || '—'}
                                  </div>
                                </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {showResaleWizard && (
        <div className="fixed inset-0 z-[9998] bg-black/40 flex items-center justify-center p-4" onClick={closeResaleWizard}>
          <div className="bg-white rounded-3xl shadow-2xl border border-gray-100 w-full max-w-3xl overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between gap-3 px-6 py-5 border-b border-gray-100">
              <div>
                <h3 className="text-xl font-extrabold text-gray-900">إنشاء عقد إعادة بيع</h3>
                <p className="text-sm text-gray-500 mt-1">خطوات بسيطة تعتمد على عقد تحت الإنشاء</p>
              </div>
              <button
                type="button"
                onClick={closeResaleWizard}
                disabled={savingResale}
                className="px-4 py-2 rounded-xl bg-gray-50 border border-gray-200 text-gray-700 font-semibold hover:bg-gray-100 transition-colors disabled:opacity-60"
              >
                إغلاق
              </button>
            </div>

            <div className="px-6 py-5">
              <div className="flex items-center gap-2 mb-5">
                <div className={`h-2.5 w-2.5 rounded-full ${resaleStep >= 1 ? 'bg-blue-600' : 'bg-gray-200'}`} />
                <div className={`h-2.5 w-2.5 rounded-full ${resaleStep >= 2 ? 'bg-blue-600' : 'bg-gray-200'}`} />
                <div className={`h-2.5 w-2.5 rounded-full ${resaleStep >= 3 ? 'bg-blue-600' : 'bg-gray-200'}`} />
              </div>

              {resaleStep === 1 && (
                <div className="space-y-4">
                  <div className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">1) اختر عقد تحت الإنشاء</div>
                    <input
                      type="text"
                      value={resaleSearch}
                      onChange={(e) => setResaleSearch(e.target.value)}
                      placeholder="ابحث بالكود (رقم المشروع-رقم الوحدة) أو اسم العميل..."
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-gray-50 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-semibold"
                    />
                    <div className="text-xs text-gray-500">سيتم عرض العقود التي ليس عليها عقد إعادة بيع بعد</div>
                  </div>

                  <div className="max-h-[360px] overflow-y-auto space-y-3">
                    {resaleCandidates.length === 0 ? (
                      <div className="text-center py-10 bg-gray-50 rounded-2xl border border-gray-100">
                        <div className="text-gray-700 font-extrabold mb-2">لا توجد عقود مطابقة</div>
                        <div className="text-sm text-gray-500">جرّب تغيير البحث أو تأكد من وجود عقود تحت الإنشاء</div>
                      </div>
                    ) : (
                      resaleCandidates.map((c) => {
                        const projectNo = c.project?.project_number || '—';
                        const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '—';
                        const clientName = c.client?.name || c.client_name || '—';
                        return (
                          <button
                            key={c.id}
                            type="button"
                            onClick={() => {
                              setResaleSourceContractId(c.id);
                              const unitAgreed = c.unit ? (c.unit as any).resale_agreed_amount : null;
                              setResaleAgreedAmount(unitAgreed != null ? String(unitAgreed) : '');
                              setResaleStep(2);
                            }}
                            className="w-full text-right bg-white border border-gray-200 rounded-2xl p-4 hover:shadow-md hover:border-blue-200 transition-all"
                          >
                            <div className="flex items-start justify-between gap-4">
                              <div className="space-y-1">
                                <div className="font-extrabold text-gray-900">{clientName}</div>
                                <div className="text-sm text-gray-600">الكود: {projectNo}-{unitNo}</div>
                              </div>
                              <div className="text-xs font-bold bg-blue-50 text-blue-700 px-3 py-1 rounded-full">
                                تحت الإنشاء
                              </div>
                            </div>
                          </button>
                        );
                      })
                    )}
                  </div>
                </div>
              )}

              {resaleStep === 2 && (
                <div className="space-y-5">
                  <div className="text-sm font-bold text-gray-700">2) أدخل مبلغ البيع والرسوم</div>

                  {resaleSourceContract ? (
                    <div className="bg-gray-50 border border-gray-200 rounded-2xl p-4">
                      <div className="font-extrabold text-gray-900">
                        {resaleSourceContract.client?.name || resaleSourceContract.client_name || '—'}
                      </div>
                      <div className="text-sm text-gray-600 mt-1">
                        مشروع رقم: {resaleSourceContract.project?.project_number || '—'} • الوحدة: {resaleSourceContract.unit?.unit_number ?? '—'}
                      </div>
                      <div className="text-sm text-gray-600 mt-1">
                        تاريخ العقد السابق: {resaleSourceContract.contract_date || '—'}
                      </div>
                    </div>
                  ) : (
                    <div className="text-center py-10 bg-gray-50 rounded-2xl border border-gray-100">
                      <div className="text-gray-700 font-extrabold mb-2">لم يتم اختيار عقد</div>
                      <div className="text-sm text-gray-500">ارجع للخطوة الأولى واختر عقد تحت الإنشاء</div>
                    </div>
                  )}

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">مبلغ البيع المتفق عليه</div>
                      <input
                        type="number"
                        value={resaleAgreedAmount}
                        onChange={(e) => setResaleAgreedAmount(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">رسوم إعادة بيع</div>
                      <input
                        type="number"
                        value={resaleFee}
                        onChange={(e) => setResaleFee(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">رسوم التسويق</div>
                      <input
                        type="number"
                        value={resaleMarketingFee}
                        onChange={(e) => setResaleMarketingFee(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">رسوم الشركة</div>
                      <input
                        type="number"
                        value={resaleCompanyFee}
                        onChange={(e) => setResaleCompanyFee(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">رسوم المحاماة</div>
                      <input
                        type="number"
                        value={resaleLawyerFee}
                        onChange={(e) => setResaleLawyerFee(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                  </div>

                  <div className="flex items-center justify-between gap-3 pt-2">
                    <button
                      type="button"
                      onClick={() => setResaleStep(1)}
                      className="px-5 py-3 rounded-2xl bg-gray-50 border border-gray-200 text-gray-700 font-extrabold hover:bg-gray-100 transition-colors"
                    >
                      رجوع
                    </button>
                    <button
                      type="button"
                      onClick={() => setResaleStep(3)}
                      disabled={!resaleSourceContract}
                      className="px-5 py-3 rounded-2xl bg-blue-600 text-white font-extrabold hover:bg-blue-700 transition-colors disabled:opacity-60"
                    >
                      متابعة
                    </button>
                  </div>
                </div>
              )}

              {resaleStep === 3 && (
                <div className="space-y-5">
                  <div className="text-sm font-bold text-gray-700">3) تأكيد وحفظ</div>

                  <div className="bg-gray-50 border border-gray-200 rounded-2xl p-4 space-y-2 text-sm font-semibold text-gray-700">
                    <div>العقد المعتمد: {resaleSourceContract?.client?.name || resaleSourceContract?.client_name || '—'}</div>
                    <div>
                      الكود: {resaleSourceContract?.project?.project_number || '—'}-{resaleSourceContract?.unit?.unit_number ?? '—'}
                    </div>
                    <div>مبلغ البيع المتفق: {resaleAgreedAmount || '—'}</div>
                    <div>رسوم إعادة بيع: {resaleFee}</div>
                    <div>رسوم التسويق: {resaleMarketingFee}</div>
                    <div>رسوم الشركة: {resaleCompanyFee}</div>
                    <div>رسوم المحاماة: {resaleLawyerFee}</div>
                  </div>

                  <div className="flex items-center justify-between gap-3 pt-2">
                    <button
                      type="button"
                      onClick={() => setResaleStep(2)}
                      disabled={savingResale}
                      className="px-5 py-3 rounded-2xl bg-gray-50 border border-gray-200 text-gray-700 font-extrabold hover:bg-gray-100 transition-colors disabled:opacity-60"
                    >
                      رجوع
                    </button>
                    <button
                      type="button"
                      onClick={saveResaleContract}
                      disabled={savingResale}
                      className="px-5 py-3 rounded-2xl bg-emerald-600 text-white font-extrabold hover:bg-emerald-700 transition-colors disabled:opacity-60"
                    >
                      {savingResale ? 'جارٍ الحفظ...' : 'حفظ عقد إعادة البيع'}
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {showSettlementWizard && (
        <div className="fixed inset-0 z-[9998] bg-black/40 flex items-center justify-center p-4" onClick={closeSettlementWizard}>
          <div className="bg-white rounded-3xl shadow-2xl border border-gray-100 w-full max-w-3xl overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between gap-3 px-6 py-5 border-b border-gray-100">
              <div>
                <h3 className="text-xl font-extrabold text-gray-900">إنشاء عقد تسوية مالية</h3>
                <p className="text-sm text-gray-500 mt-1">يرتبط بعقد تحت الإنشاء وعقد إعادة بيع</p>
              </div>
              <button
                type="button"
                onClick={closeSettlementWizard}
                disabled={savingSettlement}
                className="px-4 py-2 rounded-xl bg-gray-50 border border-gray-200 text-gray-700 font-semibold hover:bg-gray-100 transition-colors disabled:opacity-60"
              >
                إغلاق
              </button>
            </div>

            <div className="px-6 py-5">
              <div className="flex items-center gap-2 mb-5">
                <div className={`h-2.5 w-2.5 rounded-full ${settlementStep >= 1 ? 'bg-blue-600' : 'bg-gray-200'}`} />
                <div className={`h-2.5 w-2.5 rounded-full ${settlementStep >= 2 ? 'bg-blue-600' : 'bg-gray-200'}`} />
                <div className={`h-2.5 w-2.5 rounded-full ${settlementStep >= 3 ? 'bg-blue-600' : 'bg-gray-200'}`} />
              </div>

              {settlementStep === 1 && (
                <div className="space-y-4">
                  <div className="space-y-2">
                    <div className="text-sm font-bold text-gray-700">1) اختر عقد تحت الإنشاء (مرتبط بإعادة بيع)</div>
                    <input
                      type="text"
                      value={settlementSearch}
                      onChange={(e) => setSettlementSearch(e.target.value)}
                      placeholder="ابحث بالكود (رقم المشروع-رقم الوحدة) أو اسم العميل..."
                      className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-gray-50 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-semibold"
                    />
                    <div className="text-xs text-gray-500">سيتم عرض العقود التي عليها إعادة بيع ولا يوجد عليها تسوية بعد</div>
                  </div>

                  <div className="max-h-[360px] overflow-y-auto space-y-3">
                    {settlementCandidates.length === 0 ? (
                      <div className="text-center py-10 bg-gray-50 rounded-2xl border border-gray-100">
                        <div className="text-gray-700 font-extrabold mb-2">لا توجد عقود مطابقة</div>
                        <div className="text-sm text-gray-500">جرّب تغيير البحث أو تأكد من وجود عقد إعادة بيع مرتبط</div>
                      </div>
                    ) : (
                      settlementCandidates.map((c) => {
                        const projectNo = c.project?.project_number || '—';
                        const unitNo = c.unit?.unit_number != null ? String(c.unit.unit_number) : '—';
                        const clientName = c.client?.name || c.client_name || '—';
                        return (
                          <button
                            key={c.id}
                            type="button"
                            onClick={() => {
                              setSettlementSourceContractId(c.id);
                              setSettlementStep(2);
                            }}
                            className="w-full text-right bg-white border border-gray-200 rounded-2xl p-4 hover:shadow-md hover:border-blue-200 transition-all"
                          >
                            <div className="flex items-start justify-between gap-4">
                              <div className="space-y-1">
                                <div className="font-extrabold text-gray-900">{clientName}</div>
                                <div className="text-sm text-gray-600">الكود: {projectNo}-{unitNo}</div>
                              </div>
                              <div className="text-xs font-bold bg-violet-50 text-violet-800 px-3 py-1 rounded-full border border-violet-200">
                                جاهز للتسوية
                              </div>
                            </div>
                          </button>
                        );
                      })
                    )}
                  </div>
                </div>
              )}

              {settlementStep === 2 && (
                <div className="space-y-5">
                  <div className="text-sm font-bold text-gray-700">2) مبلغ البيع المتفق عليه الجديد</div>

                  {settlementSourceContract ? (
                    <div className="bg-gray-50 border border-gray-200 rounded-2xl p-4">
                      <div className="font-extrabold text-gray-900">
                        {settlementSourceContract.client?.name || settlementSourceContract.client_name || '—'}
                      </div>
                      <div className="text-sm text-gray-600 mt-1">
                        مشروع رقم: {settlementSourceContract.project?.project_number || '—'} • الوحدة: {settlementSourceContract.unit?.unit_number ?? '—'}
                      </div>
                      <div className="text-sm text-gray-600 mt-1">تاريخ العقد السابق: {settlementSourceContract.contract_date || '—'}</div>
                    </div>
                  ) : (
                    <div className="text-center py-10 bg-gray-50 rounded-2xl border border-gray-100">
                      <div className="text-gray-700 font-extrabold mb-2">لم يتم اختيار عقد</div>
                      <div className="text-sm text-gray-500">ارجع للخطوة الأولى واختر عقد تحت الإنشاء</div>
                    </div>
                  )}

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">تاريخ التسوية</div>
                      <input
                        type="date"
                        value={settlementDate}
                        onChange={(e) => setSettlementDate(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">مبلغ البيع المتفق عليه الجديد</div>
                      <input
                        type="number"
                        value={settlementSalePrice}
                        onChange={(e) => setSettlementSalePrice(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                  </div>

                  <div className="flex items-center justify-between gap-3 pt-2">
                    <button
                      type="button"
                      onClick={() => setSettlementStep(1)}
                      className="px-5 py-3 rounded-2xl bg-gray-50 border border-gray-200 text-gray-700 font-extrabold hover:bg-gray-100 transition-colors"
                    >
                      رجوع
                    </button>
                    <button
                      type="button"
                      onClick={() => setSettlementStep(3)}
                      disabled={!settlementSourceContract}
                      className="px-5 py-3 rounded-2xl bg-blue-600 text-white font-extrabold hover:bg-blue-700 transition-colors disabled:opacity-60"
                    >
                      متابعة
                    </button>
                  </div>
                </div>
              )}

              {settlementStep === 3 && (
                <div className="space-y-5">
                  <div className="text-sm font-bold text-gray-700">3) بيانات المالك الجديد</div>

                  <label className="flex items-center gap-3 bg-gray-50 border border-gray-200 rounded-2xl px-4 py-3">
                    <input
                      type="checkbox"
                      checked={settlementIncludeNewClient}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setSettlementIncludeNewClient(checked);
                        setSettlementFoundClient(null);
                        setSettlementClientLookupStatus('idle');
                        setSettlementClientSuggestions([]);
                      }}
                    />
                    <span className="font-extrabold text-gray-800">هذه التسوية تتضمن عميل جديد (تحديث العقد والوحدة)</span>
                  </label>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">هوية المالك الجديد</div>
                      <div className="flex items-stretch gap-2">
                        <input
                          type="text"
                          value={settlementNewOwnerIdNumber}
                          onChange={(e) => {
                            const value = e.target.value;
                            setSettlementNewOwnerIdNumber(value);
                            setSettlementFoundClient(null);
                            setSettlementClientLookupStatus('idle');
                            setSettlementClientSuggestions([]);
                          }}
                          className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                        />
                        {settlementIncludeNewClient && settlementSearchingClient && (
                          <div className="px-4 flex items-center text-xs font-extrabold text-gray-500">جارٍ البحث...</div>
                        )}
                      </div>

                      {settlementIncludeNewClient && settlementClientLookupStatus === 'selected' && settlementFoundClient && (
                        <div className="text-xs font-bold bg-emerald-50 text-emerald-800 px-3 py-2 rounded-xl border border-emerald-200">
                          عميل موجود: {settlementFoundClient.name || '—'}
                        </div>
                      )}
                      {settlementIncludeNewClient && settlementClientSuggestions.length > 0 && (
                        <div className="bg-white border border-gray-200 rounded-2xl overflow-hidden">
                          {settlementClientSuggestions.map((c) => (
                            <button
                              key={c.id}
                              type="button"
                              onClick={() => {
                                setSettlementFoundClient(c);
                                setSettlementClientLookupStatus('selected');
                                setSettlementNewOwnerIdNumber(c.id_number || '');
                                setSettlementNewOwnerName(c.name || '');
                                setSettlementNewOwnerPhone(c.phone || '');
                                setSettlementClientSuggestions([]);
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

                      {settlementIncludeNewClient && settlementClientLookupStatus === 'duplicate' && (
                        <div className="text-xs font-bold bg-amber-50 text-amber-800 px-3 py-2 rounded-xl border border-amber-200">
                          تم العثور على أكثر من عميل بنفس الهوية. اختر واحدًا من القائمة أعلاه ويُفضّل تنظيف البيانات.
                        </div>
                      )}
                      {settlementIncludeNewClient && settlementClientLookupStatus === 'not_found' && (
                        <div className="flex items-center justify-between gap-3 bg-rose-50 border border-rose-200 rounded-xl px-3 py-2">
                          <div className="text-xs font-bold text-rose-800">لا يوجد عميل بهذه الهوية. يمكنك إضافته.</div>
                          <button
                            type="button"
                            onClick={createSettlementClient}
                            disabled={settlementCreatingClient}
                            className="px-4 py-2 rounded-xl bg-rose-600 text-white font-extrabold hover:bg-rose-700 transition-colors disabled:opacity-60"
                          >
                            {settlementCreatingClient ? 'جارٍ الإضافة...' : 'إضافة عميل'}
                          </button>
                        </div>
                      )}
                    </div>
                    <label className="space-y-2">
                      <div className="text-sm font-bold text-gray-700">اسم المالك الجديد</div>
                      <input
                        type="text"
                        value={settlementNewOwnerName}
                        onChange={(e) => setSettlementNewOwnerName(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                    <label className="space-y-2 md:col-span-2">
                      <div className="text-sm font-bold text-gray-700">جوال المالك الجديد (اختياري)</div>
                      <input
                        type="text"
                        value={settlementNewOwnerPhone}
                        onChange={(e) => setSettlementNewOwnerPhone(e.target.value)}
                        className="w-full px-4 py-3 rounded-2xl border border-gray-200 bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none font-bold"
                      />
                    </label>
                  </div>

                  <div className="bg-violet-50 border border-violet-200 rounded-2xl p-4">
                    <div className="text-sm font-extrabold text-violet-800 mb-1">تنبيه</div>
                    <div className="text-sm text-violet-900 font-semibold leading-7">
                      {settlementIncludeNewClient
                        ? 'سيتم حفظ بيانات العميل الجديد كـ (عميل بعد تسوية) داخل عقد تحت الإنشاء دون تغيير العميل الأصلي، وكذلك تحديث بيانات المفرغ له في الوحدة وتحويل حالتها إلى قيد البيع.'
                        : 'سيتم إنشاء عقد التسوية وتحويل حالة الوحدة إلى قيد البيع، دون إضافة عميل جديد داخل العقد أو الوحدة.'}
                    </div>
                  </div>

                  <div className="flex items-center justify-between gap-3 pt-2">
                    <button
                      type="button"
                      onClick={() => setSettlementStep(2)}
                      disabled={savingSettlement}
                      className="px-5 py-3 rounded-2xl bg-gray-50 border border-gray-200 text-gray-700 font-extrabold hover:bg-gray-100 transition-colors disabled:opacity-60"
                    >
                      رجوع
                    </button>
                    <button
                      type="button"
                      onClick={saveSettlementContract}
                      disabled={savingSettlement}
                      className="px-5 py-3 rounded-2xl bg-emerald-600 text-white font-extrabold hover:bg-emerald-700 transition-colors disabled:opacity-60"
                    >
                      {savingSettlement ? 'جارٍ الحفظ...' : 'حفظ عقد التسوية'}
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Print Modal */}
      {showPrintModal && selectedContract && (
        <div className="fixed inset-0 z-[9999] bg-white overflow-y-auto contract-print-modal" style={{ top: 0, left: 0, right: 0, bottom: 0 }}>
          <ContractPrintPage 
            data={mapContractToPrintData(selectedContract)} 
            autoPrint={false}
            onClose={() => {
              console.log('🔒 Closing print modal');
              setShowPrintModal(false);
            }}
          />
        </div>
      )}

      {showResalePrintModal && resalePrintData && (
        <div className="fixed inset-0 z-[9999] bg-white overflow-y-auto contract-print-modal" style={{ top: 0, left: 0, right: 0, bottom: 0 }}>
          <ResalePrintPage
            data={resalePrintData}
            autoPrint={true}
            onClose={() => {
              setShowResalePrintModal(false);
              setResalePrintData(null);
            }}
          />
        </div>
      )}

      {showSettlementPrintModal && settlementPrintData && (
        <div className="fixed inset-0 z-[9999] bg-white overflow-y-auto contract-print-modal" style={{ top: 0, left: 0, right: 0, bottom: 0 }}>
          <SettlementPrintPage
            data={settlementPrintData}
            autoPrint={true}
            onClose={() => {
              setShowSettlementPrintModal(false);
              setSettlementPrintData(null);
            }}
          />
        </div>
      )}

      {showWaiverPrintModal && waiverPrintData && (
        <div className="fixed inset-0 z-[9999] bg-white overflow-y-auto contract-print-modal" style={{ top: 0, left: 0, right: 0, bottom: 0 }}>
          <TnazolPrintPage
            data={waiverPrintData}
            autoPrint={true}
            onClose={() => {
              setShowWaiverPrintModal(false);
              setWaiverPrintData(null);
            }}
          />
        </div>
      )}

      {showDeedPrintModal && deedPrintData && (
        <div className="fixed inset-0 z-[9999] bg-white overflow-y-auto contract-print-modal" style={{ top: 0, left: 0, right: 0, bottom: 0 }}>
          <ReceiptPrintPage
            data={deedPrintData}
            autoPrint={true}
            onClose={() => {
              setShowDeedPrintModal(false);
              setDeedPrintData(null);
            }}
          />
        </div>
      )}
    </div>
  );
}
