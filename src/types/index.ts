export interface Project {
  id: string;
  created_at: string;
  name: string;
  project_number: string;
  deed_number: string;
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
  electricity_meter: string;
  water_meter: string;
  client_name: string;
  deed_number: string;
  status: 'available' | 'sold' | 'sold_to_other' | 'resale' | 'pending_sale';
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
}

export interface ProjectDocument {
  id: string;
  created_at: string;
  project_id: string;
  title: string;
  type: 'license' | 'guarantee' | 'occupancy' | 'wafi' | 'val' | 'other' | 'project_plan' | 'architectural_plan' | 'autocad';
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
  files: UnitModelFile[];
}
