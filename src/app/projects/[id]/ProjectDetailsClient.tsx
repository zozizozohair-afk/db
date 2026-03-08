'use client';

import React, { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { Project } from '../../../types';
import ProjectSettings from '../../../components/ProjectSettings';
import ProjectFileManager from '../../../components/ProjectFileManager';
import UnitsExcelView from '../../../components/UnitsExcelView';
import ProjectPlansManager from '../../../components/ProjectPlansManager';
import UnitCard from '../../../components/UnitCard';
import { generateUnitsLogic } from '../../../utils/projectLogic';
import { 
  Building2, 
  ArrowRight, 
  MapPin, 
  FileText, 
  Zap, 
  Droplets, 
  Home, 
  Layers, 
  Maximize2,
  Settings,
  FolderOpen,
  Table,
  Trash2,
  Loader2,
  Edit
} from 'lucide-react';
import Link from 'next/link';

export default function ProjectDetails({ id }: { id: string }) {
  
  const [project, setProject] = useState<Project | null>(null);
  const [units, setUnits] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'units' | 'files' | 'settings' | 'edit_basic'>('units');
  const [isExcelMode, setIsExcelMode] = useState(false);
  const [deleting, setDeleting] = useState(false);

  // Edit Basic Data State
  const [editBasicData, setEditBasicData] = useState({
    project_number: '',
    orientation: 'North' as 'North' | 'South' | 'East' | 'West',
    deed_number: ''
  });
  const [isSavingBasic, setIsSavingBasic] = useState(false);

  const fetchProjectDetails = async () => {
    try {
      setLoading(true);

      // 1. Fetch Project Details
      const { data: projectData, error: projectError } = await supabase
        .from('projects')
        .select('*')
        .eq('id', id)
        .single();

      if (projectError) throw projectError;
      setProject(projectData);
      setEditBasicData({
        project_number: projectData.project_number,
        orientation: projectData.orientation as any,
        deed_number: projectData.deed_number || ''
      });

      // 2. Fetch Units
      const { data: unitsData, error: unitsError } = await supabase
        .from('units')
        .select('*')
        .eq('project_id', id)
        .order('unit_number', { ascending: true });

      if (unitsError) throw unitsError;
      setUnits(unitsData || []);

    } catch (error) {
      console.error('Error fetching details:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSaveBasicData = async () => {
    if (!project) return;
    try {
      setIsSavingBasic(true);

      const oldOrientation = project.orientation;
      const newOrientation = editBasicData.orientation;
      const isOrientationChanged = oldOrientation !== newOrientation;

      // 1. Update Project
      const { error: updateError } = await supabase
        .from('projects')
        .update({
          project_number: editBasicData.project_number,
          orientation: newOrientation,
          deed_number: editBasicData.deed_number
        })
        .eq('id', id);

      if (updateError) throw updateError;

      // 2. Update Units if orientation changed (and units_per_floor is 4)
      if (isOrientationChanged && project.units_per_floor === 4) {
        // Regenerate logic for all units
        // We need to map current units to their logical position (1, 2, 3, 4)
        // Assumption: unit_number is sequential 1..N
        
        // Let's use generateUnitsLogic to get the "correct" labels for the new orientation
        const generatedUnits = generateUnitsLogic(
          newOrientation,
          project.floors_count,
          project.units_per_floor,
          project.has_annex,
          project.annex_count
        );

        // Update each unit in DB
        // We match by unit_number
        const updates = generatedUnits.map(genUnit => {
          // Find the real unit ID if possible, or just update by project_id + unit_number
          // Since we have 'units' state, we can use it, but safer to update by compound key or loop
          return {
            unit_number: genUnit.unitNumber,
            direction_label: genUnit.directionLabel
          };
        });

        // Supabase doesn't support bulk update with different values easily in one query unless we use upsert or RPC.
        // We'll loop for now as N is small (usually < 100).
        for (const update of updates) {
          await supabase
            .from('units')
            .update({ direction_label: update.direction_label })
            .eq('project_id', id)
            .eq('unit_number', update.unit_number);
        }
      }

      alert('تم حفظ التعديلات بنجاح');
      fetchProjectDetails(); // Refresh
      setActiveTab('units'); // Go back to units
    } catch (error: any) {
      console.error('Error saving basic data:', error);
      alert('حدث خطأ أثناء الحفظ: ' + error.message);
    } finally {
      setIsSavingBasic(false);
    }
  };

  useEffect(() => {
    if (id) {
      fetchProjectDetails();
    }
  }, [id]);

  const handleDeleteProject = async () => {
    if (!project) return;
    if (!confirm('هل أنت متأكد من حذف المشروع بالكامل وكل ما يتعلق به؟')) return;
    if (!confirm('تأكيد نهائي: سيتم حذف جميع الوحدات والملفات والنماذج المرتبطة. متابعة؟')) return;
    try {
      setDeleting(true);
      const { data: models } = await supabase
        .from('unit_models')
        .select('id, files')
        .eq('project_id', id);
      const { data: docs } = await supabase
        .from('project_documents')
        .select('id, file_path')
        .eq('project_id', id);
      const modelPaths = (models || []).flatMap((m: any) => (m.files || []).map((f: any) => f.path));
      const docPaths = (docs || []).map((d: any) => d.file_path);
      const allPaths = [...modelPaths, ...docPaths];
      if (allPaths.length > 0) {
        await supabase.storage.from('project-files').remove(allPaths);
      }
      await supabase.from('unit_models').delete().eq('project_id', id);
      await supabase.from('project_documents').delete().eq('project_id', id);
      await supabase.from('debts').delete().eq('project_id', id);
      await supabase.from('units').delete().eq('project_id', id);
      await supabase.from('projects').delete().eq('id', id);
      window.location.href = '/';
    } catch (e: any) {
      alert(e?.message || 'تعذر حذف المشروع');
    } finally {
      setDeleting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!project) {
    return (
      <div className="flex flex-col items-center justify-center h-screen bg-gray-50 gap-4">
        <h2 className="text-xl font-bold text-gray-800">المشروع غير موجود</h2>
        <Link href="/" className="text-blue-600 hover:underline">العودة للرئيسية</Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-10">
      
      {/* Header / Navigation */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link href="/" className="p-2 hover:bg-gray-100 rounded-full text-gray-500 transition-colors">
              <ArrowRight size={20} />
            </Link>
            <h1 className="text-xl font-bold text-gray-900 truncate">
              {project.name}
            </h1>
            <span className="px-2 py-1 bg-blue-50 text-blue-700 text-xs rounded-md font-medium border border-blue-100">
              {project.status === 'active' ? 'نشط' : 'قيد المعالجة'}
            </span>
          </div>
          <div className="flex items-center gap-3">
            <div className="text-sm text-gray-500 hidden sm:block">
              آخر تحديث: {new Date(project.created_at).toLocaleDateString('ar-SA')}
            </div>
            <button
              onClick={handleDeleteProject}
              disabled={deleting}
              className={`inline-flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-bold transition-colors ${deleting ? 'bg-red-200 text-white cursor-not-allowed' : 'bg-red-600 text-white hover:bg-red-700'}`}
              title="حذف المشروع"
            >
              {deleting ? <Loader2 size={16} className="animate-spin" /> : <Trash2 size={16} />}
              {deleting ? 'جارٍ الحذف...' : 'حذف المشروع'}
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
        
        {/* Project Info Card */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="p-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            
            <div className="flex items-start gap-3">
              <div className="p-2 bg-blue-50 text-blue-600 rounded-lg">
                <FileText size={20} />
              </div>
              <div>
                <p className="text-sm text-gray-500 mb-1">رقم الصك الأم</p>
                <p className="font-mono font-medium text-gray-900">{project.deed_number || '-'}</p>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="p-2 bg-yellow-50 text-yellow-600 rounded-lg">
                <Zap size={20} />
              </div>
              <div>
                <p className="text-sm text-gray-500 mb-1">عدادات الكهرباء</p>
                <div className="font-mono font-medium text-gray-900 text-sm">
                  {project.electricity_meters && project.electricity_meters.length > 0 ? (
                    <div className="flex flex-wrap gap-1">
                      {project.electricity_meters.map((m, i) => (
                        <span key={i} className="bg-yellow-100 px-1 rounded">{m}</span>
                      ))}
                    </div>
                  ) : (
                     project.electricity_meter || '-'
                  )}
                </div>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="p-2 bg-cyan-50 text-cyan-600 rounded-lg">
                <Droplets size={20} />
              </div>
              <div>
                <p className="text-sm text-gray-500 mb-1">عداد المياه العام</p>
                <p className="font-mono font-medium text-gray-900">{project.water_meter || '-'}</p>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="p-2 bg-purple-50 text-purple-600 rounded-lg">
                <MapPin size={20} />
              </div>
              <div>
                <p className="text-sm text-gray-500 mb-1">الاتجاه / الواجهة</p>
                <p className="font-medium text-gray-900">{getOrientationAr(project.orientation)}</p>
              </div>
            </div>

          </div>
          
          <div className="bg-gray-50 px-6 py-4 border-t border-gray-100 flex flex-wrap gap-6 text-sm text-gray-600">
            <div className="flex items-center gap-2">
              <Layers size={16} />
              <span>عدد الأدوار: <span className="font-semibold text-gray-900">{project.floors_count}</span></span>
            </div>
            <div className="flex items-center gap-2">
              <Home size={16} />
              <span>إجمالي الوحدات: <span className="font-semibold text-gray-900">{units.length}</span></span>
            </div>
            {project.has_annex && (
              <div className="flex items-center gap-2">
                <Maximize2 size={16} />
                <span>الملاحق: <span className="font-semibold text-gray-900">{project.annex_count}</span></span>
              </div>
            )}
            {project.hoa_start_date && (
               <div className="flex items-center gap-2 text-indigo-600">
                <span className="font-bold">اتحاد الملاك:</span>
                <span>{new Date(project.hoa_start_date).toLocaleDateString('ar-SA')} - {project.hoa_end_date ? new Date(project.hoa_end_date).toLocaleDateString('ar-SA') : 'مستمر'}</span>
               </div>
            )}
          </div>
        </div>

        {/* Tabs */}
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex gap-8">
            <button
              onClick={() => setActiveTab('units')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors ${
                activeTab === 'units'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <Building2 size={18} />
              وحدات المشروع
            </button>
            <button
              onClick={() => setActiveTab('files')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors ${
                activeTab === 'files'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <FolderOpen size={18} />
              الملفات والمستندات
            </button>
            <button
              onClick={() => setActiveTab('settings')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors ${
                activeTab === 'settings'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <Settings size={18} />
              الإعدادات والخدمات
            </button>
            <button
              onClick={() => setActiveTab('edit_basic')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors ${
                activeTab === 'edit_basic'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <Edit size={18} />
              تعديل بيانات أساسية
            </button>
          </nav>
        </div>

        {/* Edit Basic Data Tab */}
        {activeTab === 'edit_basic' && (
          <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 max-w-2xl mx-auto">
            <h2 className="text-xl font-bold mb-6 text-gray-800 flex items-center gap-2">
              <Edit size={24} className="text-blue-600" />
              تعديل البيانات الأساسية
            </h2>
            
            <div className="space-y-6">
              {/* Project Number */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  رقم المشروع
                </label>
                <input
                  type="text"
                  value={editBasicData.project_number}
                  onChange={(e) => setEditBasicData({...editBasicData, project_number: e.target.value})}
                  className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="مثال: 123"
                />
              </div>

              {/* Deed Number */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  رقم الصك الأم
                </label>
                <input
                  type="text"
                  value={editBasicData.deed_number}
                  onChange={(e) => setEditBasicData({...editBasicData, deed_number: e.target.value})}
                  className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="رقم الصك"
                />
              </div>

              {/* Orientation */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  اتجاه المشروع (الواجهة)
                </label>
                <select
                  value={editBasicData.orientation}
                  onChange={(e) => setEditBasicData({...editBasicData, orientation: e.target.value as any})}
                  className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="North">شمال</option>
                  <option value="South">جنوب</option>
                  <option value="East">شرق</option>
                  <option value="West">غرب</option>
                </select>
                <p className="mt-2 text-sm text-yellow-600 bg-yellow-50 p-2 rounded border border-yellow-200">
                  تنبيه: تغيير اتجاه المشروع سيؤدي تلقائياً إلى إعادة حساب اتجاهات جميع الوحدات (للشقق النمطية 4 شقق).
                </p>
              </div>

              <div className="pt-4 flex justify-end gap-3">
                <button
                  onClick={() => setActiveTab('units')}
                  className="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
                >
                  إلغاء
                </button>
                <button
                  onClick={handleSaveBasicData}
                  disabled={isSavingBasic}
                  className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2"
                >
                  {isSavingBasic && <Loader2 size={16} className="animate-spin" />}
                  حفظ التعديلات
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Tab Content */}
        {activeTab === 'units' && (
          <div>
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
                <Building2 size={20} className="text-blue-600" />
                قائمة الوحدات
              </h2>
              <div className="flex gap-2">
                {!isExcelMode && (
                  <button
                    onClick={() => setIsExcelMode(true)}
                    className="flex items-center gap-2 px-3 py-1.5 bg-green-600 text-white rounded-md text-sm hover:bg-green-700 transition-colors shadow-sm"
                  >
                    <Table size={16} />
                    تعديل كملف إكسل
                  </button>
                )}
                <span className="text-xs px-2 py-1 bg-green-100 text-green-700 rounded-md flex items-center">متاح: {units.filter(u => u.status === 'available').length}</span>
                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded-md flex items-center">إجمالي: {units.length}</span>
              </div>
            </div>

            {isExcelMode ? (
              <UnitsExcelView 
                units={units} 
                onUpdate={() => {
                  fetchProjectDetails();
                  setIsExcelMode(false);
                }}
                onCancel={() => setIsExcelMode(false)}
              />
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                {units.map((unit) => (
                  <Link 
                    href={`/units/${unit.id}`}
                    key={unit.id} 
                    className="bg-white rounded-xl shadow-sm border border-gray-200 hover:shadow-md transition-shadow p-4 relative group cursor-pointer block"
                  >
                    <div className="absolute top-4 left-4">
                      <span className={`w-2 h-2 rounded-full block ${
                        unit.status === 'available' ? 'bg-green-500' : 'bg-red-500'
                      }`}></span>
                    </div>

                    <div className="flex items-center gap-3 mb-3">
                      <div className={`w-10 h-10 rounded-lg flex items-center justify-center text-white font-bold shadow-sm ${
                        unit.type === 'annex' ? 'bg-purple-600' : 'bg-blue-600'
                      }`}>
                        {unit.unit_number}
                      </div>
                      <div>
                        <p className="text-xs text-gray-500 font-medium">{unit.floor_label}</p>
                        <p className="text-sm font-bold text-gray-900">
                          {unit.type === 'annex' ? 'ملحق علوي' : 'شقة سكنية'}
                        </p>
                      </div>
                    </div>

                    <div className="space-y-2 pt-2 border-t border-gray-50">
                      <div className="flex items-center justify-between text-xs">
                        <span className="text-gray-500">الاتجاه:</span>
                        <span className="font-medium text-gray-900 text-left" title={unit.direction_label}>
                          {unit.direction_label.length > 20 
                            ? unit.direction_label.substring(0, 20) + '...' 
                            : unit.direction_label}
                        </span>
                      </div>
                      
                      {unit.client_name && (
                        <div className="flex items-center justify-between text-xs">
                          <span className="text-gray-500">العميل:</span>
                          <span className="font-medium text-gray-900">{unit.client_name}</span>
                        </div>
                      )}
                      {unit.deed_number && (
                        <div className="flex items-center justify-between text-xs">
                          <span className="text-gray-500">الصك:</span>
                          <span className="font-mono text-gray-900">{unit.deed_number}</span>
                        </div>
                      )}
                    </div>

                    {/* Hover Action */}
                    <div className="absolute inset-0 bg-blue-600/5 opacity-0 group-hover:opacity-100 transition-opacity rounded-xl pointer-events-none" />
                  </Link>
                ))}
              </div>
            )}
            
            <ProjectPlansManager projectId={project.id} />
          </div>
        )}

        {activeTab === 'files' && (
          <ProjectFileManager projectId={project.id} />
        )}

        {activeTab === 'settings' && (
          <ProjectSettings project={project} onUpdate={fetchProjectDetails} />
        )}

      </main>
    </div>
  );
}

function getOrientationAr(dir: string) {
  const map: Record<string, string> = {
    North: 'شمالي',
    South: 'جنوبي',
    East: 'شرقي',
    West: 'غربي'
  };
  return map[dir] || dir;
}
