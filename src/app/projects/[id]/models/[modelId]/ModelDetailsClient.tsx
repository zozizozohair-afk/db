'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../../../../lib/supabaseClient';
import type { UnitModelAsset, UnitModelFile } from '../../../../../types';
import FilePreviewModal from '../../../../../components/FilePreviewModal';
import { ArrowRight, Copy, ExternalLink, FileCode, Image as ImageIcon, Link as LinkIcon, Save, Trash2, Upload, Video } from 'lucide-react';

type ModelRow = {
  id: string;
  project_id: string;
  name: string;
  description: string | null;
  location_url: string | null;
  files: UnitModelFile[];
  created_at: string;
  public_enabled?: boolean | null;
  area_sqm?: number | null;
};

type TabKey = 'images' | 'videos' | 'files' | 'location' | 'description' | 'message';

export default function ModelDetailsClient({ projectId, modelId }: { projectId: string; modelId: string }) {
  const [loading, setLoading] = useState(true);
  const [model, setModel] = useState<ModelRow | null>(null);
  const [assets, setAssets] = useState<UnitModelAsset[]>([]);
  const [tab, setTab] = useState<TabKey>('images');
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState<null | 'image' | 'video' | 'file'>(null);
  const [publishSaving, setPublishSaving] = useState(false);

  const [locationUrl, setLocationUrl] = useState('');
  const [projectLocationUrl, setProjectLocationUrl] = useState<string | null>(null);
  const [description, setDescription] = useState('');
  const [areaSqm, setAreaSqm] = useState('');
  const [roleSavingId, setRoleSavingId] = useState<string | null>(null);

  const imgInputRef = useRef<HTMLInputElement>(null);
  const videoInputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const images = useMemo(() => assets.filter((a) => a.kind === 'image'), [assets]);
  const videos = useMemo(() => assets.filter((a) => a.kind === 'video'), [assets]);
  const files = useMemo(() => assets.filter((a) => a.kind === 'file'), [assets]);

  const isPreviewable = (url: string) => {
    const u = String(url || '').toLowerCase();
    if (u.includes('.pdf') || u.endsWith('.pdf')) return true;
    return ['.png', '.jpg', '.jpeg', '.webp', '.gif'].some((ext) => u.endsWith(ext));
  };

  const fetchAll = async () => {
    setLoading(true);
    try {
      let modelRes = await supabase
        .from('unit_models')
        .select('id, project_id, name, description, location_url, files, created_at, public_enabled, area_sqm')
        .eq('id', modelId)
        .eq('project_id', projectId)
        .single();

      if (modelRes.error && String(modelRes.error.message || '').toLowerCase().includes('column')) {
        modelRes = await supabase
          .from('unit_models')
          .select('id, project_id, name, description, location_url, files, created_at')
          .eq('id', modelId)
          .eq('project_id', projectId)
          .single();
      }

      const projRes = await supabase.from('projects').select('location_url').eq('id', projectId).single();

      if (modelRes.error) throw modelRes.error;
      const m = modelRes.data as any;
      setModel(m as any);
      setDescription(String(m?.description || ''));
      setAreaSqm(m?.area_sqm == null ? '' : String(m.area_sqm));

      const projectUrl = (projRes.data as any)?.location_url || null;
      setProjectLocationUrl(projectUrl ? String(projectUrl) : null);
      setLocationUrl(String(projectUrl || m?.location_url || ''));

      const { data: a, error: aErr } = await supabase
        .from('unit_model_assets')
        .select('id, created_at, model_id, project_id, kind, display_role, title, file_url, file_path')
        .eq('model_id', modelId)
        .order('created_at', { ascending: false });
      if (aErr) throw aErr;
      setAssets(((a as any[]) || []) as any);
    } catch (e: any) {
      const msg = String(e?.message || '');
      if (msg.toLowerCase().includes('unit_model_assets') && msg.toLowerCase().includes('does not exist')) {
        alert('الرجاء إنشاء جدول unit_model_assets في قاعدة البيانات أولاً.');
      }
      setModel(null);
      setAssets([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
  }, [projectId, modelId]);

  const safeExt = (name: string) => {
    const raw = name.split('.').pop() || '';
    const ext = raw.toLowerCase().replace(/[^a-z0-9]/g, '');
    return ext || 'bin';
  };

  const uploadAssets = async (kind: 'image' | 'video' | 'file', filesToUpload: File[]) => {
    if (!filesToUpload.length) return;
    try {
      setUploading(kind);
      for (const file of filesToUpload) {
        const ext = safeExt(file.name);
        const filePath = `unit-model-assets/${projectId}/${modelId}/${kind}/${Date.now()}_${Math.random()
          .toString(36)
          .slice(2)}.${ext}`;

        const { error: upErr } = await supabase.storage.from('public-media').upload(filePath, file);
        if (upErr) {
          const msg = String(upErr.message || '').toLowerCase();
          if (msg.includes('bucket') && (msg.includes('not found') || msg.includes('does not exist'))) {
            throw new Error(
              "لا يمكن رفع ملفات النموذج لأن Bucket العرض العام غير موجود.\n\nأنشئ Bucket في Supabase Storage باسم: public-media\nواجعله Public.\n\nبعدها أعد المحاولة."
            );
          }
          throw upErr;
        }

        const { data: { publicUrl } } = supabase.storage.from('public-media').getPublicUrl(filePath);

        const { error: dbErr } = await supabase.from('unit_model_assets').insert({
          project_id: projectId,
          model_id: modelId,
          kind,
          title: file.name,
          file_url: publicUrl,
          file_path: filePath
        });
        if (dbErr) throw dbErr;
      }
      await fetchAll();
    } catch (e: any) {
      alert(e?.message || 'تعذر رفع الملفات');
    } finally {
      setUploading(null);
      if (imgInputRef.current) imgInputRef.current.value = '';
      if (videoInputRef.current) videoInputRef.current.value = '';
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const deleteAsset = async (a: UnitModelAsset) => {
    if (!confirm('هل تريد حذف هذا العنصر؟')) return;
    try {
      const resPublic = await supabase.storage.from('public-media').remove([a.file_path]);
      if (resPublic.error) {
        await supabase.storage.from('project-files').remove([a.file_path]);
      }
      await supabase.from('unit_model_assets').delete().eq('id', a.id);
      setAssets((prev) => prev.filter((x) => x.id !== a.id));
    } catch (e: any) {
      alert(e?.message || 'تعذر حذف العنصر');
    }
  };

  const roleLabel = (role: UnitModelAsset['display_role']) => {
    if (role === 'cover') return 'غلاف';
    if (role === 'facade') return 'واجهة';
    return 'بدون';
  };

  const setImageRole = async (asset: UnitModelAsset, nextRole: 'cover' | 'facade' | null) => {
    try {
      setRoleSavingId(asset.id);

      const roleRes = await supabase
        .from('unit_model_assets')
        .update({ display_role: nextRole })
        .eq('id', asset.id);

      if (roleRes.error) {
        const msg = String(roleRes.error.message || '').toLowerCase();
        if (msg.includes('column')) {
          alert(
            "العمود display_role غير موجود في جدول unit_model_assets.\n\nنفّذ هذا في Supabase SQL Editor:\n\nalter table public.unit_model_assets add column if not exists display_role text check (display_role in ('cover','facade'));"
          );
          return;
        }
        throw roleRes.error;
      }

      if (nextRole) {
        const clearRes = await supabase
          .from('unit_model_assets')
          .update({ display_role: null })
          .eq('model_id', asset.model_id)
          .eq('kind', 'image')
          .eq('display_role', nextRole)
          .neq('id', asset.id);
        if (clearRes.error) throw clearRes.error;
      }

      setAssets((prev) =>
        prev.map((x) => {
          if (x.kind !== 'image') return x;
          if (x.id === asset.id) return { ...x, display_role: nextRole };
          if (nextRole && x.model_id === asset.model_id && x.display_role === nextRole) return { ...x, display_role: null };
          return x;
        })
      );
    } catch (e: any) {
      alert(e?.message || 'تعذر تحديث دور الصورة');
    } finally {
      setRoleSavingId(null);
    }
  };

  const saveMeta = async () => {
    if (!model) return;
    try {
      setSaving(true);
      const payload: any = {
        description: description.trim() || null,
        area_sqm: areaSqm.trim() ? Number(areaSqm) : null
      };
      if (!projectLocationUrl) {
        payload.location_url = locationUrl.trim() || null;
      }
      const { error } = await supabase
        .from('unit_models')
        .update(payload)
        .eq('id', modelId)
        .eq('project_id', projectId);
      if (error) {
        const msg = String(error.message || '').toLowerCase();
        if (msg.includes('column')) {
          alert(
            'بعض أعمدة النشر غير موجودة في unit_models.\n\nنفّذ هذا في Supabase SQL Editor:\n\nalter table public.unit_models add column if not exists area_sqm numeric;'
          );
          return;
        }
        throw error;
      }
      await fetchAll();
    } catch (e: any) {
      alert(e?.message || 'تعذر حفظ البيانات');
    } finally {
      setSaving(false);
    }
  };

  const togglePublish = async () => {
    if (!model) return;
    setPublishSaving(true);
    try {
      const next = !Boolean((model as any)?.public_enabled);
      let res = await supabase
        .from('unit_models')
        .update({ public_enabled: next })
        .eq('id', modelId)
        .eq('project_id', projectId);
      if (res.error && String(res.error.message || '').toLowerCase().includes('column')) {
        alert(
          'العمود public_enabled غير موجود في جدول unit_models.\n\nنفّذ هذا في Supabase SQL Editor:\n\nalter table public.unit_models add column if not exists public_enabled boolean not null default false;'
        );
        return;
      }
      if (res.error) throw res.error;
      setModel((prev) => (prev ? ({ ...(prev as any), public_enabled: next } as any) : prev));
    } catch (e: any) {
      alert(e?.message || 'تعذر تحديث حالة النشر');
    } finally {
      setPublishSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
      </div>
    );
  }

  if (!model) {
    return (
      <div className="min-h-screen bg-gray-50 flex flex-col items-center justify-center gap-4" dir="rtl">
        <div className="text-xl font-extrabold text-gray-900">النموذج غير موجود</div>
        <Link href={`/projects/${projectId}`} className="text-blue-600 font-bold hover:underline">
          العودة للمشروع
        </Link>
      </div>
    );
  }

  const coverFromLegacy = (model.files || []).find((f) => f.type === 'image')?.url || null;
  const coverFromAssets = images[0]?.file_url || null;
  const coverUrl = coverFromLegacy || coverFromAssets;

  return (
    <div className="min-h-screen bg-gray-50 pb-10" dir="rtl">
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3 min-w-0">
            <Link href={`/projects/${projectId}`} className="p-2 hover:bg-gray-100 rounded-full text-gray-500 transition-colors">
              <ArrowRight size={20} />
            </Link>
            <div className="min-w-0">
              <div className="text-xs font-bold text-gray-500">نموذج وحدات</div>
              <h1 className="text-lg sm:text-xl font-extrabold text-gray-900 truncate">{model.name}</h1>
            </div>
          </div>

          <button
            type="button"
            onClick={saveMeta}
            disabled={saving}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800 disabled:opacity-50"
          >
            <Save size={16} />
            {saving ? 'جارٍ الحفظ...' : 'حفظ'}
          </button>

          <button
            type="button"
            onClick={togglePublish}
            disabled={publishSaving}
            className={`inline-flex items-center gap-2 px-4 py-2 rounded-lg border text-sm font-extrabold disabled:opacity-50 ${
              Boolean((model as any)?.public_enabled)
                ? 'border-emerald-300 bg-emerald-50 text-emerald-800 hover:bg-emerald-100'
                : 'border-slate-300 bg-white text-slate-800 hover:bg-slate-50'
            }`}
          >
            <ExternalLink size={16} />
            {publishSaving ? 'جارٍ التحديث...' : Boolean((model as any)?.public_enabled) ? 'منشور في الهبوط' : 'غير منشور'}
          </button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
        {coverUrl ? (
          <div className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
            <div className="relative h-56 sm:h-72 bg-slate-100">
              <img src={coverUrl} alt={model.name} className="absolute inset-0 w-full h-full object-cover" />
              <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent" />
              <div className="absolute bottom-0 right-0 left-0 p-4 sm:p-6">
                <div className="text-white font-extrabold text-lg sm:text-2xl truncate">{model.name}</div>
              </div>
            </div>
          </div>
        ) : null}

        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="border-b border-gray-200 overflow-x-auto no-scrollbar">
            <div className="flex gap-2 p-3 min-w-max">
              <button
                type="button"
                onClick={() => setTab('images')}
                className={`px-4 py-2 rounded-lg text-sm font-extrabold border ${
                  tab === 'images' ? 'border-blue-600 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                مكتبة الصور
              </button>
              <button
                type="button"
                onClick={() => setTab('videos')}
                className={`px-4 py-2 rounded-lg text-sm font-extrabold border ${
                  tab === 'videos' ? 'border-blue-600 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                الفيديوهات
              </button>
              <button
                type="button"
                onClick={() => setTab('files')}
                className={`px-4 py-2 rounded-lg text-sm font-extrabold border ${
                  tab === 'files' ? 'border-blue-600 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                الملفات
              </button>
              <button
                type="button"
                onClick={() => setTab('location')}
                className={`px-4 py-2 rounded-lg text-sm font-extrabold border ${
                  tab === 'location' ? 'border-blue-600 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                رابط الموقع
              </button>
              <button
                type="button"
                onClick={() => setTab('description')}
                className={`px-4 py-2 rounded-lg text-sm font-extrabold border ${
                  tab === 'description' ? 'border-blue-600 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                الوصف
              </button>
              <button
                type="button"
                onClick={() => setTab('message')}
                className={`px-4 py-2 rounded-lg text-sm font-extrabold border ${
                  tab === 'message' ? 'border-blue-600 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                مراسلة
              </button>
            </div>
          </div>

          <div className="p-6">
            {tab === 'location' ? (
              <div className="space-y-3">
                <div className="flex items-center gap-2 text-sm font-extrabold text-slate-900">
                  <LinkIcon size={18} className="text-blue-600" />
                  رابط الموقع
                </div>
                <input
                  value={locationUrl}
                  onChange={(e) => setLocationUrl(e.target.value)}
                  placeholder="رابط Google Maps أو OpenStreetMap (اختياري)"
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none"
                  dir="ltr"
                  disabled={Boolean(projectLocationUrl)}
                />
                {projectLocationUrl ? (
                  <div className="text-xs font-bold text-slate-600">يتم أخذ الرابط مباشرة من موقع المشروع.</div>
                ) : null}
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    disabled={!locationUrl.trim()}
                    onClick={async () => {
                      try {
                        await navigator.clipboard.writeText(locationUrl.trim());
                        alert('تم نسخ الرابط');
                      } catch {
                        alert('تعذر نسخ الرابط');
                      }
                    }}
                    className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800 disabled:opacity-50"
                  >
                    <Copy size={16} />
                    نسخ
                  </button>
                  <a
                    href={locationUrl.trim() || '#'}
                    target="_blank"
                    rel="noreferrer"
                    className={`inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800 ${
                      locationUrl.trim() ? '' : 'pointer-events-none opacity-50'
                    }`}
                  >
                    <ExternalLink size={16} />
                    فتح
                  </a>
                </div>
              </div>
            ) : tab === 'description' ? (
              <div className="space-y-3">
                <div className="text-sm font-extrabold text-slate-900">وصف الشقة</div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <div className="text-sm font-extrabold text-slate-800">المساحة (م²)</div>
                    <input
                      type="number"
                      value={areaSqm}
                      onChange={(e) => setAreaSqm(e.target.value)}
                      className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none"
                      placeholder="مثال: 145"
                    />
                  </div>
                </div>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none min-h-[240px]"
                  placeholder="اكتب وصف تفصيلي للنموذج..."
                />
              </div>
            ) : tab === 'images' ? (
              <div className="space-y-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2 text-sm font-extrabold text-slate-900">
                    <ImageIcon size={18} className="text-blue-600" />
                    مكتبة الصور
                    <span className="text-slate-500">({images.length})</span>
                  </div>
                  <div>
                    <input ref={imgInputRef} type="file" accept="image/*" multiple className="hidden" onChange={(e) => uploadAssets('image', Array.from(e.target.files || []))} />
                    <button
                      type="button"
                      onClick={() => imgInputRef.current?.click()}
                      disabled={uploading !== null}
                      className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800 disabled:opacity-50"
                    >
                      <Upload size={16} />
                      {uploading === 'image' ? 'جارٍ الرفع...' : 'رفع صور'}
                    </button>
                  </div>
                </div>

                {images.length === 0 ? (
                  <div className="rounded-md border-2 border-dashed border-slate-300 bg-slate-50 p-8 text-center">
                    <div className="text-sm font-extrabold text-slate-800">لا توجد صور</div>
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
                    {images.map((img) => (
                      <div key={img.id} className="group relative overflow-hidden rounded-md border-2 border-slate-300 bg-white">
                        <button type="button" onClick={() => setPreviewUrl(img.file_url)} className="block w-full">
                          <img src={img.file_url} alt={img.title || ''} className="aspect-square w-full object-cover" />
                        </button>
                        <div className="p-2 space-y-2 border-t border-slate-200 bg-white">
                          <div className="text-[11px] font-extrabold text-slate-700">الدور الحالي: {roleLabel(img.display_role || null)}</div>
                          <div className="grid grid-cols-3 gap-1">
                            <button
                              type="button"
                              onClick={() => setImageRole(img, 'cover')}
                              disabled={roleSavingId === img.id}
                              className={`px-2 py-1 rounded text-[11px] font-extrabold border ${
                                img.display_role === 'cover'
                                  ? 'border-emerald-300 bg-emerald-50 text-emerald-700'
                                  : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                              }`}
                            >
                              غلاف
                            </button>
                            <button
                              type="button"
                              onClick={() => setImageRole(img, 'facade')}
                              disabled={roleSavingId === img.id}
                              className={`px-2 py-1 rounded text-[11px] font-extrabold border ${
                                img.display_role === 'facade'
                                  ? 'border-blue-300 bg-blue-50 text-blue-700'
                                  : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                              }`}
                            >
                              واجهة
                            </button>
                            <button
                              type="button"
                              onClick={() => setImageRole(img, null)}
                              disabled={roleSavingId === img.id}
                              className="px-2 py-1 rounded text-[11px] font-extrabold border border-slate-200 bg-white text-slate-700 hover:bg-slate-50"
                            >
                              مسح
                            </button>
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => deleteAsset(img)}
                          className="absolute top-2 left-2 w-9 h-9 rounded-md bg-white/80 hover:bg-white text-slate-800 border border-slate-200 opacity-0 group-hover:opacity-100 transition-opacity inline-flex items-center justify-center"
                          title="حذف"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : tab === 'videos' ? (
              <div className="space-y-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2 text-sm font-extrabold text-slate-900">
                    <Video size={18} className="text-blue-600" />
                    الفيديوهات
                    <span className="text-slate-500">({videos.length})</span>
                  </div>
                  <div>
                    <input ref={videoInputRef} type="file" accept="video/*" multiple className="hidden" onChange={(e) => uploadAssets('video', Array.from(e.target.files || []))} />
                    <button
                      type="button"
                      onClick={() => videoInputRef.current?.click()}
                      disabled={uploading !== null}
                      className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800 disabled:opacity-50"
                    >
                      <Upload size={16} />
                      {uploading === 'video' ? 'جارٍ الرفع...' : 'رفع فيديو'}
                    </button>
                  </div>
                </div>

                {videos.length === 0 ? (
                  <div className="rounded-md border-2 border-dashed border-slate-300 bg-slate-50 p-8 text-center">
                    <div className="text-sm font-extrabold text-slate-800">لا توجد فيديوهات</div>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                    {videos.map((v) => (
                      <div key={v.id} className="rounded-md border-2 border-slate-300 bg-white overflow-hidden">
                        <video src={v.file_url} controls className="w-full h-52 bg-black" />
                        <div className="p-3 flex items-center justify-between gap-2">
                          <div className="text-xs font-extrabold text-slate-900 truncate">{v.title || 'فيديو'}</div>
                          <button
                            type="button"
                            onClick={() => deleteAsset(v)}
                            className="w-9 h-9 rounded-md border border-slate-200 bg-white hover:bg-slate-50 inline-flex items-center justify-center"
                            title="حذف"
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : tab === 'files' ? (
              <div className="space-y-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2 text-sm font-extrabold text-slate-900">
                    <FileCode size={18} className="text-blue-600" />
                    الملفات
                    <span className="text-slate-500">({files.length})</span>
                  </div>
                  <div>
                    <input ref={fileInputRef} type="file" multiple className="hidden" onChange={(e) => uploadAssets('file', Array.from(e.target.files || []))} />
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={uploading !== null}
                      className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-sm font-extrabold text-slate-800 disabled:opacity-50"
                    >
                      <Upload size={16} />
                      {uploading === 'file' ? 'جارٍ الرفع...' : 'رفع ملفات'}
                    </button>
                  </div>
                </div>

                {files.length === 0 ? (
                  <div className="rounded-md border-2 border-dashed border-slate-300 bg-slate-50 p-8 text-center">
                    <div className="text-sm font-extrabold text-slate-800">لا توجد ملفات</div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    {files.map((f) => (
                      <div key={f.id} className="rounded-md border border-slate-200 bg-slate-50 px-3 py-2 flex items-center justify-between gap-3">
                        <div className="min-w-0">
                          <div className="text-sm font-extrabold text-slate-900 truncate">{f.title || 'ملف'}</div>
                          <div className="text-[11px] font-bold text-slate-600">{new Date(f.created_at).toLocaleDateString('ar-SA')}</div>
                        </div>
                        <div className="flex items-center gap-2">
                          {isPreviewable(f.file_url) ? (
                            <button
                              type="button"
                              onClick={() => setPreviewUrl(f.file_url)}
                              className="px-3 py-2 rounded-md border border-slate-300 bg-white text-slate-800 text-xs font-extrabold"
                            >
                              عرض
                            </button>
                          ) : null}
                          <a
                            href={f.file_url}
                            target="_blank"
                            rel="noreferrer"
                            className="px-3 py-2 rounded-md border border-slate-300 bg-white text-slate-800 text-xs font-extrabold"
                          >
                            فتح
                          </a>
                          <button
                            type="button"
                            onClick={() => deleteAsset(f)}
                            className="w-9 h-9 rounded-md border border-slate-300 bg-white hover:bg-slate-50 inline-flex items-center justify-center"
                            title="حذف"
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <div className="rounded-md border-2 border-dashed border-slate-300 bg-slate-50 p-8 text-center">
                <div className="text-sm font-extrabold text-slate-800">سيتم تطوير تبويب المراسلة لاحقًا</div>
                <div className="mt-1 text-xs font-bold text-slate-600">الهدف: تجهيز تحميل صور/فيديو/بروفايل النموذج</div>
              </div>
            )}
          </div>
        </div>
      </main>

      <FilePreviewModal url={previewUrl} onClose={() => setPreviewUrl(null)} />
    </div>
  );
}

