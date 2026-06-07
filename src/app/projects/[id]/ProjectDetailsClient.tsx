'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import { supabase } from '../../../lib/supabaseClient';
import { Project } from '../../../types';
import ProjectSettings from '../../../components/ProjectSettings';
import ProjectFileManager from '../../../components/ProjectFileManager';
import UnitsExcelView from '../../../components/UnitsExcelView';
import ProjectPlansManager from '../../../components/ProjectPlansManager';
import ProjectFilesSender from '../../../components/ProjectFilesSender';
import UnitCard from '../../../components/UnitCard';
import FilePreviewModal from '../../../components/FilePreviewModal';
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
  Edit,
  Share2,
  LocateFixed,
  Copy,
  Image as ImageIcon,
  Upload,
  Trash
} from 'lucide-react';
import Link from 'next/link';

const OSMLocationPicker = dynamic(() => import('../../../components/OSMLocationPicker'), { ssr: false });

export default function ProjectDetails({ id }: { id: string }) {
  
  const [project, setProject] = useState<Project | null>(null);
  const [units, setUnits] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'units' | 'models' | 'files' | 'gallery' | 'settings' | 'edit_basic' | 'send_files'>('units');
  const [isExcelMode, setIsExcelMode] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [galleryItems, setGalleryItems] = useState<
    Array<{ id: string; created_at: string; title: string; type: string; file_url: string; file_path: string }>
  >([]);
  const [loadingGallery, setLoadingGallery] = useState(false);
  const [uploadingGallery, setUploadingGallery] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const galleryInputRef = useRef<HTMLInputElement>(null);

  // Edit Basic Data State
  const [editBasicData, setEditBasicData] = useState({
    project_number: '',
    orientation: 'North' as 'North' | 'South' | 'East' | 'West',
    deed_number: '',
    location_lat: null as number | null,
    location_lng: null as number | null,
    location_url: ''
  });
  const [isSavingBasic, setIsSavingBasic] = useState(false);

  const buildOSMLink = (lat: number, lng: number) =>
    `https://www.openstreetmap.org/?mlat=${encodeURIComponent(lat)}&mlon=${encodeURIComponent(lng)}#map=18/${encodeURIComponent(
      lat
    )}/${encodeURIComponent(lng)}`;

  const buildGoogleMapsNavLink = (lat: number, lng: number) =>
    `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(lat)},${encodeURIComponent(lng)}`;

  const isGoogleMapsUrl = (url: string) => /google\.[a-z.]+\/maps|goo\.gl\/maps|maps\.app\.goo\.gl/i.test(url);

  const fetchGallery = async () => {
    if (!id) return;
    try {
      setLoadingGallery(true);
      const { data, error } = await supabase
        .from('project_documents')
        .select('id, created_at, title, type, file_url, file_path')
        .eq('project_id', id)
        .eq('type', 'gallery')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setGalleryItems((data as any[]) || []);
    } catch (e) {
      setGalleryItems([]);
    } finally {
      setLoadingGallery(false);
    }
  };

  const safeExt = (name: string) => {
    const raw = name.split('.').pop() || '';
    const ext = raw.toLowerCase().replace(/[^a-z0-9]/g, '');
    return ext || 'jpg';
  };

  const handleGalleryFiles = async (files: File[]) => {
    if (!id) return;
    if (files.length === 0) return;
    try {
      setUploadingGallery(true);
      for (const file of files) {
        const ext = safeExt(file.name);
        const filePath = `${id}/gallery/${Date.now()}_${Math.random().toString(16).slice(2)}.${ext}`;
        const { error: uploadError } = await supabase.storage.from('project-files').upload(filePath, file);
        if (uploadError) throw uploadError;
        const { data: pub } = supabase.storage.from('project-files').getPublicUrl(filePath);
        const fileUrl = pub?.publicUrl;
        const { error: dbError } = await supabase.from('project_documents').insert({
          project_id: id,
          title: file.name,
          type: 'gallery',
          file_path: filePath,
          file_url: fileUrl
        });
        if (dbError) throw dbError;
      }
      await fetchGallery();
    } catch (e: any) {
      alert(e?.message || 'تعذر رفع الصور');
    } finally {
      setUploadingGallery(false);
      if (galleryInputRef.current) galleryInputRef.current.value = '';
    }
  };

  const handleDeleteGalleryItem = async (docId: string, filePath: string) => {
    if (!confirm('هل تريد حذف الصورة؟')) return;
    try {
      await supabase.storage.from('project-files').remove([filePath]);
      await supabase.from('project_documents').delete().eq('id', docId);
      setGalleryItems((prev) => prev.filter((x) => x.id !== docId));
    } catch (e: any) {
      alert(e?.message || 'تعذر حذف الصورة');
    }
  };

  useEffect(() => {
    if (activeTab === 'gallery') fetchGallery();
  }, [activeTab, id]);

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
        deed_number: projectData.deed_number || '',
        location_lat: typeof projectData.location_lat === 'number' ? projectData.location_lat : null,
        location_lng: typeof projectData.location_lng === 'number' ? projectData.location_lng : null,
        location_url: projectData.location_url || ''
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
      const hasCoords = typeof editBasicData.location_lat === 'number' && typeof editBasicData.location_lng === 'number';
      const finalLocationUrl =
        editBasicData.location_url.trim() ||
        (hasCoords ? buildOSMLink(editBasicData.location_lat as number, editBasicData.location_lng as number) : null);

      // 1. Update Project
      const { error: updateError } = await supabase
        .from('projects')
        .update({
          project_number: editBasicData.project_number,
          orientation: newOrientation,
          deed_number: editBasicData.deed_number,
          location_lat: hasCoords ? editBasicData.location_lat : null,
          location_lng: hasCoords ? editBasicData.location_lng : null,
          location_url: finalLocationUrl
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

        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="p-6">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 mb-4">
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <MapPin size={18} className="text-teal-700" />
                  <div className="text-lg font-extrabold text-gray-900">موقع المشروع</div>
                </div>
                <div className="mt-1 text-sm text-gray-600 font-bold truncate">
                  {typeof project.location_lat === 'number' && typeof project.location_lng === 'number'
                    ? `${project.location_lat}, ${project.location_lng}`
                    : 'لا يوجد موقع محفوظ لهذا المشروع'}
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                {(() => {
                  const hasCoords = typeof project.location_lat === 'number' && typeof project.location_lng === 'number';
                  const savedUrl = (project.location_url || '').trim();
                  const primaryUrl = savedUrl || (hasCoords ? buildGoogleMapsNavLink(project.location_lat as number, project.location_lng as number) : '');
                  const googleUrl =
                    savedUrl && isGoogleMapsUrl(savedUrl)
                      ? savedUrl
                      : hasCoords
                        ? buildGoogleMapsNavLink(project.location_lat as number, project.location_lng as number)
                        : '';
                  const shareUrl = primaryUrl || googleUrl;

                  return (
                    <>
                      <button
                        type="button"
                        onClick={() => {
                          if (!googleUrl) {
                            setActiveTab('edit_basic');
                            return;
                          }
                          window.open(googleUrl, '_blank', 'noopener,noreferrer');
                        }}
                        className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-teal-950 bg-gradient-to-l from-emerald-900 via-teal-900 to-blue-900 text-white text-sm font-extrabold hover:from-emerald-950 hover:via-teal-950 hover:to-blue-950 transition-colors"
                      >
                        <Share2 size={16} />
                        تنقّل عبر Google
                      </button>

                      <button
                        type="button"
                        onClick={async () => {
                          if (!shareUrl) {
                            setActiveTab('edit_basic');
                            return;
                          }
                          try {
                            await navigator.clipboard.writeText(shareUrl);
                            alert('تم نسخ رابط الموقع');
                          } catch {
                            alert('تعذر نسخ الرابط');
                          }
                        }}
                        className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800"
                      >
                        <Copy size={16} />
                        نسخ الرابط
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          if (!shareUrl) {
                            setActiveTab('edit_basic');
                            return;
                          }
                          const text = `موقع المشروع: ${shareUrl}`;
                          window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank', 'noopener,noreferrer');
                        }}
                        className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800"
                      >
                        <Share2 size={16} />
                        إرسال واتساب
                      </button>

                      <button
                        type="button"
                        onClick={() => setActiveTab('edit_basic')}
                        className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800"
                      >
                        <Edit size={16} />
                        تعديل الموقع
                      </button>
                    </>
                  );
                })()}
              </div>
            </div>

            {typeof project.location_lat === 'number' && typeof project.location_lng === 'number' ? (
              <OSMLocationPicker
                value={{ lat: project.location_lat, lng: project.location_lng }}
                onChange={() => {}}
                readOnly
                heightClassName="h-80"
              />
            ) : (
              <div className="rounded-md border-2 border-dashed border-slate-300 bg-slate-50 p-6 text-center">
                <div className="text-sm font-extrabold text-slate-800">لم يتم تحديد موقع المشروع بعد</div>
                <div className="mt-1 text-xs font-bold text-slate-600">اضغط تعديل الموقع لإضافة الإحداثيات والرابط</div>
              </div>
            )}
          </div>
        </div>
        
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
        <div className="border-b border-gray-200 overflow-x-auto no-scrollbar">
          <nav className="-mb-px flex gap-4 sm:gap-8 min-w-max pb-1">
            <button
              onClick={() => setActiveTab('units')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors whitespace-nowrap ${
                activeTab === 'units'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <Building2 size={18} />
              وحدات المشروع
            </button>
            <button
              onClick={() => setActiveTab('models')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors whitespace-nowrap ${
                activeTab === 'models'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <Layers size={18} />
              نماذج الوحدات
            </button>
            <button
              onClick={() => setActiveTab('files')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors whitespace-nowrap ${
                activeTab === 'files'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <FolderOpen size={18} />
              الملفات والمستندات
            </button>
            <button
              onClick={() => setActiveTab('gallery')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors whitespace-nowrap ${
                activeTab === 'gallery'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <ImageIcon size={18} />
              مكتبة الصور
            </button>
            <button
              onClick={() => setActiveTab('send_files')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors whitespace-nowrap ${
                activeTab === 'send_files'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <Share2 size={18} />
              إرسال ملفات
            </button>
            <button
              onClick={() => setActiveTab('settings')}
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors whitespace-nowrap ${
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
              className={`pb-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors whitespace-nowrap ${
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

              <div className="rounded-xl border-2 border-slate-300 bg-white p-4">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 mb-4">
                  <div className="flex items-center gap-2">
                    <MapPin size={18} className="text-teal-700" />
                    <div className="font-bold text-gray-800">موقع المشروع</div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => {
                        if (!navigator.geolocation) {
                          alert('ميزة تحديد الموقع غير مدعومة في هذا المتصفح');
                          return;
                        }
                        navigator.geolocation.getCurrentPosition(
                          (pos) => {
                            const lat = Number(pos.coords.latitude.toFixed(6));
                            const lng = Number(pos.coords.longitude.toFixed(6));
                            setEditBasicData((prev) => ({
                              ...prev,
                              location_lat: lat,
                              location_lng: lng,
                              location_url: prev.location_url.trim() || buildOSMLink(lat, lng)
                            }));
                          },
                          () => alert('تعذر الحصول على موقعك الحالي'),
                          { enableHighAccuracy: true, timeout: 10000 }
                        );
                      }}
                      className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-bold text-slate-800"
                    >
                      <LocateFixed size={16} />
                      موقعي الحالي
                    </button>
                    <button
                      type="button"
                      onClick={() =>
                        setEditBasicData((prev) => ({ ...prev, location_lat: null, location_lng: null, location_url: prev.location_url }))
                      }
                      className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-bold text-slate-800"
                    >
                      مسح الإحداثيات
                    </button>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div className="space-y-2">
                    <label className="block text-sm font-medium text-gray-700">رابط الموقع (اختياري)</label>
                    <input
                      type="text"
                      value={editBasicData.location_url}
                      onChange={(e) => setEditBasicData({ ...editBasicData, location_url: e.target.value })}
                      className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-teal-600 outline-none"
                      placeholder="ضع رابط OpenStreetMap أو Google Maps"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="block text-sm font-medium text-gray-700">الإحداثيات</label>
                    <div className="w-full p-3 border border-gray-200 rounded-lg bg-gray-50 text-sm font-bold text-gray-800">
                      {typeof editBasicData.location_lat === 'number' && typeof editBasicData.location_lng === 'number'
                        ? `${editBasicData.location_lat}, ${editBasicData.location_lng}`
                        : 'اضغط على الخريطة لتحديد الموقع'}
                    </div>
                  </div>
                </div>

                <OSMLocationPicker
                  value={{ lat: editBasicData.location_lat, lng: editBasicData.location_lng }}
                  onChange={(next) => {
                    setEditBasicData((prev) => {
                      const hasCoords = typeof next.lat === 'number' && typeof next.lng === 'number';
                      return {
                        ...prev,
                        location_lat: hasCoords ? (next.lat as number) : null,
                        location_lng: hasCoords ? (next.lng as number) : null,
                        location_url:
                          prev.location_url.trim() ||
                          (hasCoords ? buildOSMLink(next.lat as number, next.lng as number) : prev.location_url)
                      };
                    });
                  }}
                  heightClassName="h-72"
                />
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

        {activeTab === 'gallery' && (
          <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
              <div className="flex items-center gap-2">
                <ImageIcon size={20} className="text-blue-600" />
                <div className="text-lg font-extrabold text-gray-900">مكتبة الصور</div>
                <div className="text-sm font-bold text-gray-500">({galleryItems.length})</div>
              </div>

              <div className="flex items-center gap-2">
                <input
                  ref={galleryInputRef}
                  type="file"
                  accept="image/*"
                  multiple
                  onChange={(e) => handleGalleryFiles(Array.from(e.target.files || []))}
                  className="hidden"
                />
                <button
                  type="button"
                  onClick={() => galleryInputRef.current?.click()}
                  disabled={uploadingGallery}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800 disabled:opacity-50"
                >
                  <Upload size={16} />
                  {uploadingGallery ? 'جارٍ الرفع...' : 'رفع صور'}
                </button>
              </div>
            </div>

            {loadingGallery ? (
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
                {Array.from({ length: 10 }).map((_, i) => (
                  <div key={i} className="aspect-square rounded-md border border-slate-200 bg-slate-100 animate-pulse" />
                ))}
              </div>
            ) : galleryItems.length === 0 ? (
              <div className="rounded-md border-2 border-dashed border-slate-300 bg-slate-50 p-8 text-center">
                <div className="text-sm font-extrabold text-slate-800">لا توجد صور للمشروع</div>
                <div className="mt-1 text-xs font-bold text-slate-600">اضغط “رفع صور” لإضافة صور للمشروع</div>
              </div>
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
                {galleryItems.map((img) => (
                  <div key={img.id} className="group relative overflow-hidden rounded-md border-2 border-slate-300 bg-white">
                    <button type="button" onClick={() => setPreviewUrl(img.file_url)} className="block w-full">
                      <img src={img.file_url} alt={img.title} className="aspect-square w-full object-cover" />
                    </button>
                    <div className="absolute inset-x-0 bottom-0 p-2 bg-gradient-to-t from-black/70 to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
                      <div className="flex items-center justify-between gap-2">
                        <div className="text-[11px] font-extrabold text-white truncate">{img.title}</div>
                        <button
                          type="button"
                          onClick={() => handleDeleteGalleryItem(img.id, img.file_path)}
                          className="shrink-0 inline-flex items-center justify-center w-8 h-8 rounded-md bg-white/10 hover:bg-white/20 text-white"
                          title="حذف"
                        >
                          <Trash size={16} />
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
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
            
          </div>
        )}

        {activeTab === 'models' && <ProjectPlansManager projectId={project.id} mode="modelsOnly" />}

        {activeTab === 'files' && (
          <ProjectFileManager projectId={project.id} />
        )}

        {activeTab === 'settings' && (
          <ProjectSettings project={project} onUpdate={fetchProjectDetails} />
        )}

        {activeTab === 'send_files' && (
          <ProjectFilesSender project={project} units={units} />
        )}

      </main>

      <FilePreviewModal url={previewUrl} onClose={() => setPreviewUrl(null)} />
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
