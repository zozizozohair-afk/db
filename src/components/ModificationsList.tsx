import React, { useRef, useState } from 'react';
import { 
  Building2, 
  Eye, 
  CheckCircle2, 
  UserCheck, 
  HardHat, 
  RefreshCw,
  Search
} from 'lucide-react';
import { supabase } from '../lib/supabaseClient';

export interface ModificationUnit {
  id: string;
  unit_number: string;
  floor_number: string;
  modifications_file_url: string;
  project_id: string;
  modification_client_confirmed: boolean;
  modification_engineer_reviewed: boolean;
  modification_completed: boolean;
}

export interface ProjectWithModifications {
  id: string;
  name: string;
  project_number: string;
  units: ModificationUnit[];
}

interface ModificationsListProps {
  projects: ProjectWithModifications[];
  loading: boolean;
  onProjectsUpdate: (projects: ProjectWithModifications[]) => void;
  onPreviewFile: (url: string) => void;
}

export default function ModificationsList({ projects, loading, onProjectsUpdate, onPreviewFile }: ModificationsListProps) {
  const [uploading, setUploading] = useState<string | null>(null);
  const fileInputRefs = useRef<{ [key: string]: HTMLInputElement | null }>({});

  const updateStatus = async (unitId: string, field: keyof ModificationUnit, currentValue: boolean) => {
    try {
      const { error } = await supabase
        .from('units')
        .update({ [field]: !currentValue })
        .eq('id', unitId);

      if (error) throw error;

      // Optimistic update
      const updatedProjects = projects.map(p => ({
        ...p,
        units: p.units.map(u => 
          u.id === unitId ? { ...u, [field]: !currentValue } : u
        )
      }));
      onProjectsUpdate(updatedProjects);
    } catch (error) {
      console.error('Error updating status:', error);
      alert('حدث خطأ أثناء تحديث الحالة');
    }
  };

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>, unit: ModificationUnit) => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      setUploading(unit.id);

      // 1. Delete old file if exists
      if (unit.modifications_file_url) {
        const oldPath = unit.modifications_file_url.split('/modifications/')[1];
        if (oldPath) {
          await supabase.storage
            .from('modifications')
            .remove([oldPath]);
        }
      }

      // 2. Upload new file
      const fileExt = file.name.split('.').pop();
      const fileName = `${unit.project_id}/${unit.id}_${Date.now()}.${fileExt}`;
      
      const { error: uploadError } = await supabase.storage
        .from('modifications')
        .upload(fileName, file);

      if (uploadError) throw uploadError;

      // 3. Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('modifications')
        .getPublicUrl(fileName);

      // 4. Update database
      const { error: dbError } = await supabase
        .from('units')
        .update({ modifications_file_url: publicUrl })
        .eq('id', unit.id);

      if (dbError) throw dbError;

      // Update local state
      const updatedProjects = projects.map(p => ({
        ...p,
        units: p.units.map(u => 
          u.id === unit.id ? { ...u, modifications_file_url: publicUrl } : u
        )
      }));
      onProjectsUpdate(updatedProjects);

      alert('تم تحديث ملف التعديل بنجاح');
    } catch (error) {
      console.error('Error updating file:', error);
      alert('حدث خطأ أثناء رفع الملف');
    } finally {
      setUploading(null);
      if (fileInputRefs.current[unit.id]) {
        fileInputRefs.current[unit.id]!.value = '';
      }
    }
  };

  if (loading) {
    return (
      <div className="space-y-6">
        {[1, 2].map((i) => (
          <div key={i} className="h-64 bg-gray-100 rounded-2xl animate-pulse" />
        ))}
      </div>
    );
  }

  if (projects.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-[50vh] text-center bg-white rounded-3xl border border-dashed border-gray-200 p-4">
        <div className="w-16 h-16 md:w-24 md:h-24 bg-gray-50 rounded-full flex items-center justify-center text-gray-300 mb-4">
          <Search size={32} className="md:w-12 md:h-12" />
        </div>
        <h3 className="text-lg md:text-xl font-display font-bold text-gray-900 mb-2">لا توجد نتائج</h3>
        <p className="text-sm md:text-base text-gray-500 max-w-md">
          لم يتم العثور على أي وحدات تطابق معايير البحث
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6 md:space-y-8">
      {projects.map((project) => (
        <div 
          key={project.id} 
          className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden"
        >
          {/* Project Header */}
          <div className="bg-gray-50/50 p-4 md:p-6 border-b border-gray-100">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3 md:gap-4">
                <div className="w-10 h-10 md:w-12 md:h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-600/20 shrink-0">
                  <Building2 size={20} className="md:w-6 md:h-6" />
                </div>
                <div>
                  <h3 className="font-display font-bold text-lg md:text-xl text-gray-900">{project.name}</h3>
                  <div className="flex items-center gap-2 md:gap-3 text-xs md:text-sm mt-1">
                    <span className="bg-white border border-gray-200 px-1.5 py-0.5 rounded text-gray-600 font-mono">
                      {project.project_number}
                    </span>
                    <span className="text-gray-400">•</span>
                    <span className="text-blue-600 font-medium">
                      {project.units.length} وحدة
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Units Table Header (Desktop Only) */}
          <div className="hidden md:grid grid-cols-12 gap-4 px-6 py-3 bg-gray-50 border-b border-gray-100 text-xs font-display font-bold text-gray-500 uppercase tracking-wider">
            <div className="col-span-2">الوحدة</div>
            <div className="col-span-3">ملف التعديل</div>
            <div className="col-span-2 text-center">تأكيد العميل</div>
            <div className="col-span-2 text-center">مراجعة المهندس</div>
            <div className="col-span-2 text-center">حالة الإنجاز</div>
            <div className="col-span-1 text-center">إجراءات</div>
          </div>

          {/* Units List */}
          <div className="divide-y divide-gray-100">
            {project.units.map((unit) => (
              <div 
                key={unit.id}
                className="flex flex-col md:grid md:grid-cols-12 gap-4 p-4 md:p-6 items-start md:items-center hover:bg-gray-50/50 transition-colors"
              >
                {/* Unit Info (Mobile: Top Row) */}
                <div className="w-full md:col-span-2 flex items-center justify-between md:justify-start gap-3">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-blue-50 rounded-lg flex items-center justify-center text-blue-700 font-display font-bold border border-blue-100 shrink-0">
                      {unit.unit_number}
                    </div>
                    <div className="flex flex-col">
                      <span className="font-display font-bold text-gray-900 md:hidden">الوحدة {unit.unit_number}</span>
                      <span className="text-xs md:text-sm text-gray-500">الدور {unit.floor_number}</span>
                    </div>
                  </div>
                  
                  {/* Mobile Actions: Edit File */}
                  <div className="md:hidden">
                    <button 
                      onClick={() => fileInputRefs.current[unit.id]?.click()}
                      disabled={uploading === unit.id}
                      className="p-2 text-gray-400 hover:text-blue-600 bg-gray-50 rounded-lg"
                    >
                      {uploading === unit.id ? (
                        <RefreshCw size={18} className="animate-spin text-blue-600" />
                      ) : (
                        <RefreshCw size={18} />
                      )}
                    </button>
                  </div>
                </div>

                {/* File Section (Mobile: Full Width Button) */}
                <div className="w-full md:col-span-3">
                  <button 
                    onClick={() => onPreviewFile(unit.modifications_file_url)}
                    className="w-full md:w-auto flex items-center justify-center md:justify-start gap-2 px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm font-display font-bold text-gray-600 hover:text-blue-600 hover:border-blue-200 hover:shadow-sm transition-all group"
                  >
                    <Eye size={16} className="text-gray-400 group-hover:text-blue-500" />
                    <span className="truncate max-w-[200px]">معاينة الملف</span>
                  </button>
                </div>

                {/* Status Toggles Grid (Mobile: 3 Columns) */}
                <div className="w-full md:col-span-6 grid grid-cols-3 md:grid-cols-3 gap-2 md:gap-4 mt-2 md:mt-0">
                  {/* Client Confirmation */}
                  <div className="flex flex-col items-center gap-1">
                    <span className="md:hidden text-[10px] text-gray-400 font-medium">العميل</span>
                    <button
                      onClick={() => updateStatus(unit.id, 'modification_client_confirmed', unit.modification_client_confirmed)}
                      className={`
                        w-full md:w-auto flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-lg text-xs font-display font-bold transition-all
                        ${unit.modification_client_confirmed 
                          ? 'bg-green-100 text-green-700 border border-green-200' 
                          : 'bg-gray-50 text-gray-400 border border-gray-100 hover:bg-gray-100'
                        }
                      `}
                    >
                      <UserCheck size={14} />
                      <span className="hidden md:inline">{unit.modification_client_confirmed ? 'تم التأكيد' : 'قيد الانتظار'}</span>
                      <span className="md:hidden">{unit.modification_client_confirmed ? 'تم' : '-'}</span>
                    </button>
                  </div>

                  {/* Engineer Review */}
                  <div className="flex flex-col items-center gap-1">
                    <span className="md:hidden text-[10px] text-gray-400 font-medium">المهندس</span>
                    <button
                      onClick={() => updateStatus(unit.id, 'modification_engineer_reviewed', unit.modification_engineer_reviewed)}
                      className={`
                        w-full md:w-auto flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-lg text-xs font-display font-bold transition-all
                        ${unit.modification_engineer_reviewed 
                          ? 'bg-blue-100 text-blue-700 border border-blue-200' 
                          : 'bg-gray-50 text-gray-400 border border-gray-100 hover:bg-gray-100'
                        }
                      `}
                    >
                      <HardHat size={14} />
                      <span className="hidden md:inline">{unit.modification_engineer_reviewed ? 'تمت المراجعة' : 'قيد المراجعة'}</span>
                      <span className="md:hidden">{unit.modification_engineer_reviewed ? 'تم' : '-'}</span>
                    </button>
                  </div>

                  {/* Completion Status */}
                  <div className="flex flex-col items-center gap-1">
                    <span className="md:hidden text-[10px] text-gray-400 font-medium">الإنجاز</span>
                    <button
                      onClick={() => updateStatus(unit.id, 'modification_completed', unit.modification_completed)}
                      className={`
                        w-full md:w-auto flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-lg text-xs font-display font-bold transition-all
                        ${unit.modification_completed 
                          ? 'bg-purple-100 text-purple-700 border border-purple-200' 
                          : 'bg-yellow-50 text-yellow-600 border border-yellow-200 hover:bg-yellow-100'
                        }
                      `}
                    >
                      <CheckCircle2 size={14} />
                      <span className="hidden md:inline">{unit.modification_completed ? 'مكتمل' : 'قيد التنفيذ'}</span>
                      <span className="md:hidden">{unit.modification_completed ? 'مكتمل' : 'جاري'}</span>
                    </button>
                  </div>
                </div>

                {/* Desktop Actions */}
                <div className="hidden md:flex col-span-1 items-center justify-center gap-2">
                  <input
                    type="file"
                    ref={el => { fileInputRefs.current[unit.id] = el }}
                    className="hidden"
                    accept="image/*,application/pdf"
                    onChange={(e) => handleFileUpload(e, unit)}
                  />
                  <button 
                    onClick={() => fileInputRefs.current[unit.id]?.click()}
                    disabled={uploading === unit.id}
                    className="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors relative group"
                    title="تحديث ملف التعديل"
                  >
                    {uploading === unit.id ? (
                      <RefreshCw size={20} className="animate-spin text-blue-600" />
                    ) : (
                      <RefreshCw size={20} />
                    )}
                  </button>
                </div>

                {/* Mobile Hidden Input */}
                <input
                  type="file"
                  ref={el => { fileInputRefs.current[unit.id] = el }}
                  className="hidden"
                  accept="image/*,application/pdf"
                  onChange={(e) => handleFileUpload(e, unit)}
                />
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
