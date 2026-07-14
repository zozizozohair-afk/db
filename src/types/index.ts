export interface Project {
  id: string;
  created_at: string;
  name: string;
  project_number: string;
  deed_number: string;
  deed_date?: string | null; // تاريخ الصك
  plot_number?: string | null; // رقم القطعة
  plan_number?: string | null; // رقم المخطط
  orientation: string;
  floors_count: number;
  units_per_floor: number;
  has_annex: boolean;
  annex_count: number;
  water_meter: string;
  electricity_meter?: string; // Legacy
  electricity_meters?: string[]; // New array
  status: string;
  hoa_start_date?: string;
  hoa_end_date?: string;
  location_lat?: number | null;
  location_lng?: number | null;
  location_url?: string | null;
  location_text?: string | null;
}

export interface Unit {
  id: string;
  created_at: string;
  project_id: string;
  unit_number: number;
  floor_number: number;
  floor_label: string;
  direction_label: string;
  type: 'apartment' | 'annex';
  area_sqm?: number | null; // مساحة الشقة بالمتر المربع
  description?: string | null; // وصف الشقة
  electricity_meter: string;
  water_meter: string;
  client_name: string;
  deed_number: string;
  status: 
    | 'available'
    | 'sold'
    | 'sold_to_other'
    | 'pending_sale'
    | 'resale'
    | 'for_resale'
    | 'rented'
    | 'under_construction'
    | 'deed_completed'
    | 'resold'
    | 'transferred_to_other';
  title_deed_owner?: string;
  client_id_number?: string;
  client_phone?: string;
  deed_file_url?: string;
  title_deed_owner_id?: string;
  title_deed_owner_phone?: string;
  sorting_record_file_url?: string;
  modifications_file_url?: string;
  modification_client_confirmed?: boolean;
  modification_engineer_reviewed?: boolean;
  modification_completed?: boolean;
  notes?: string;
  resale_fee?: number | null;
  marketing_fee?: number | null;
  company_fee?: number | null;
  lawyer_fee?: number | null;
  resale_agreed_amount?: number | null;
  resale_saved_at?: string | null;
  original_client_id?: string;
  current_client_id?: string;
  account_number?: string;
}

export interface ProjectDocument {
  id: string;
  created_at: string;
  project_id: string;
  title: string;
  type: 'license' | 'guarantee' | 'occupancy' | 'wafi' | 'val' | 'other' | 'project_plan' | 'architectural_plan' | 'autocad' | 'gallery';
  file_url: string;
  file_path: string;
}

export const DOCUMENT_TYPES = {
  license: 'رخصة البناء',
  guarantee: 'ضمانات المشروع',
  occupancy: 'شهادة الإشغال',
  wafi: 'شهادة وافي',
  val: 'رخصة فال',
  other: 'ملفات أخرى',
  project_plan: 'مخطط مشروع',
  architectural_plan: 'مخطط معماري',
  autocad: 'ملف أوتوكاد'
};

export interface UnitModelFile {
  url: string;
  type: 'image' | 'pdf';
  path: string;
}

export interface UnitModel {
  id: string;
  created_at: string;
  project_id: string;
  name: string;
  description?: string;
  location_url?: string | null;
  area_sqm?: number | null;
  files: UnitModelFile[];
}

export interface UnitModelAsset {
  id: string;
  created_at: string;
  model_id: string;
  project_id: string;
  kind: 'image' | 'video' | 'file';
  display_role?: 'cover' | 'facade' | null;
  title?: string | null;
  file_url: string;
  file_path: string;
}

export interface UnitContract {
  id: string;
  created_at: string;
  unit_id: string;
  type: string;
  custom_type?: string;
  file_url: string;
  file_path: string;
}

export const CONTRACT_TYPES = {
  under_construction: 'عقد تحت الإنشاء',
  resale: 'عقد إعادة بيع',
  financial_settlement: 'عقد تسوية مالية',
  deed: 'عقد إفراغ',
  waiver: 'تنازل',
  power_of_attorney: 'وكالة',
  other: 'أخرى'
};

export interface Client {
  id: string;
  created_at: string;
  name: string;
  id_number?: string;
  phone?: string;
  notes?: string;
}

export interface UnitOwnershipHistory {
  id: string;
  created_at: string;
  unit_id: string;
  client_id?: string;
  previous_client_id?: string;
  transaction_type: 'purchase' | 'sale' | 'transfer';
  transaction_date?: string;
  price?: number;
  notes?: string;
}

export interface EnrichedClient extends Client {
  units: {
    unit: Unit;
    project: Project;
    history: UnitOwnershipHistory[];
  }[];
}

export type CrmPipelineStage = {
  id: string;
  created_at: string;
  name: string;
  sort_order: number;
};

export type CrmClientStage = {
  client_id: string;
  stage_id: string | null;
  updated_at: string;
};

export type CrmRelationType = 'prospect' | 'original' | 'current';

export type CrmClientUnit = {
  id: string;
  created_at: string;
  client_id: string;
  unit_id: string;
  relation_type: CrmRelationType;
};

export type CrmActivityChannel = 'note' | 'call' | 'whatsapp' | 'visit' | 'email';

export type CrmActivityOutcome = 'completed' | 'no_answer' | 'appointment';

export type CrmActivity = {
  id: string;
  created_at: string;
  client_id: string;
  unit_id: string | null;
  channel: CrmActivityChannel;
  content: string;
  created_by?: string | null;
  next_contact_at?: string | null;
  outcome?: CrmActivityOutcome | null;
  appointment_at?: string | null;
  appointment_with?: string | null;
};

export type CrmTaskStatus = 'open' | 'done';

export type CrmTaskPriority = 'low' | 'medium' | 'high';

export type CrmTask = {
  id: string;
  created_at: string;
  client_id: string;
  unit_id: string | null;
  assigned_to?: string | null;
  updated_at?: string | null;
  completed_at?: string | null;
  title: string;
  description?: string | null;
  due_at: string | null;
  status: CrmTaskStatus;
  priority: CrmTaskPriority;
};

export const PAYMENT_METHODS = {
  cash: 'كاش',
  cheque: 'شيك',
  transfer: 'حواله'
};

export const CONTRACT_LOG_ACTIONS = {
  contract_created: 'إضافة عقد',
  contract_updated: 'تعديل عقد',
  contract_deleted: 'حذف عقد',
  contract_archived: 'أرشفة عقد',
  payment_added: 'إضافة دفعة',
  payment_updated: 'تعديل دفعة',
  payment_deleted: 'حذف دفعة',
  unit_client_synced: 'مزامنة العميل للوحدة',
  debt_synced: 'مزامنة المديونية',
  agent_updated: 'تعديل الوكيل',
  contract_printed: 'طباعة عقد'
};

export interface ContractLog {
  id: string;
  created_at: string;
  contract_id?: string | null;
  actor_id?: string | null;
  actor_name?: string | null;
  action: string;
  entity_type?: string | null;
  entity_id?: string | null;
  metadata?: Record<string, any> | null;
}

export interface ContractPayment {
  id: string;
  created_at: string;
  contract_id: string;
  amount: number;
  payment_date: string;
  notes?: string | null;
  payment_method?: keyof typeof PAYMENT_METHODS | null;
  transaction_number?: string | null;
  statement?: string | null;
}

export interface ContractObligation {
  id: string;
  created_at: string;
  contract_id: string;
  amount: number;
  description: string;
  due_date?: string | null;
  paid?: boolean;
}

export interface NewContract {
  id?: string;
  created_at?: string;
  project_id: string;
  unit_id: string;
  client_id?: string | null;
  source_contract_id?: string | null;
  resale_contract_id?: string | null;
  resale_signed_at?: string | null;
  settlement_source_contract_id?: string | null;
  settlement_resale_contract_id?: string | null;
  settlement_date?: string | null;
  settlement_sale_price?: number | null;
  settlement_new_owner_client_id?: string | null;
  settlement_new_owner_name?: string | null;
  settlement_new_owner_id_number?: string | null;
  settlement_new_owner_phone?: string | null;
  financial_settlement_contract_id?: string | null;
  financial_settlement_signed_at?: string | null;
  settlement_new_client_id?: string | null;
  settlement_new_client_applied_at?: string | null;
  deed_source_contract_id?: string | null;
  deed_waiver_contract_id?: string | null;
  deed_settlement_contract_id?: string | null;
  deed_recipient_client_id?: string | null;
  deed_recipient_name?: string | null;
  deed_recipient_id_number?: string | null;
  deed_recipient_phone?: string | null;
  deed_recipient_source?: string | null;
  deed_unit_deed_number?: string | null;
  deed_meter_number?: string | null;
  deed_parking_number?: string | null;
  contract_date: string;
  total_amount: number;
  paid_amount: number;
  completion_period_months: number; // 12 شهر افتراضي
  payment_grace_period_months?: number | null;
  status: 'draft' | 'active' | 'completed';
  type: keyof typeof CONTRACT_TYPES;
  created_by_id?: string | null;
  created_by_name?: string | null;
  notes?: string | null;
  client_name?: string | null;
  client_id_number?: string | null;
  client_phone?: string | null;
  agent_name?: string | null;
  agent_id_number?: string | null;
  agency_number?: string | null;
  agency_date?: string | null;
  resale_agreed_amount?: number | null;
  resale_fee?: number | null;
  marketing_fee?: number | null;
  company_service_fee?: number | null;
  lawyer_fee?: number | null;
  is_legacy?: boolean | null;
  is_archived?: boolean | null;
  archived_at?: string | null;
  archived_by_id?: string | null;
  archived_by_name?: string | null;
  is_waived?: boolean | null;
  waived_at?: string | null;
  waived_previous_client_id?: string | null;
  waived_previous_client_name?: string | null;
  waived_previous_client_id_number?: string | null;
  waived_previous_client_phone?: string | null;
  waived_to_client_id?: string | null;
  waived_to_client_name?: string | null;
  waived_to_client_id_number?: string | null;
  waived_to_client_phone?: string | null;
}

export const CONTRACT_STATUSES = {
  draft: 'مسودة',
  active: 'نشط',
  completed: 'مكتمل'
};

export interface FullContract extends NewContract {
  id: string;
  created_at: string;
  project?: Project | null;
  unit?: Unit | null;
  client?: Client | null;
  obligations?: ContractObligation[];
  payments?: ContractPayment[];
}
