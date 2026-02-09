import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { ProjectDocument, UnitModel, UnitModelFile, DOCUMENT_TYPES } from '../types';
import { Upload, FileText, Image as ImageIcon, Trash2, Plus, X, FileCode, Loader2, Download, ExternalLink, Box, LayoutTemplate, Save } from 'lucide-react';

interface ProjectPlansManagerProps {
  projectId: string;
}

export default function ProjectPlansManager({ projectId }: ProjectPlansManagerProps) {
  const [activeTab, setActiveTab] = useState<'plans' | 'models'>('plans');
  
  // Plans State
  const [plans, setPlans] = useState<ProjectDocument[]>([]);
  const [loadingPlans, setLoadingPlans] = useState(false);
  const [uploadingPlan, setUploadingPlan] = useState(false);
  const [newPlanTitle, setNewPlanTitle] = useState('');
  const [newPlanType, setNewPlanType] = useState<ProjectDocument['type']>('project_plan');
  
  // Models State
  const [models, setModels] = useState<UnitModel[]>([]);
  const [uniqueDirections, setUniqueDirections] = useState<string[]>([]);
  const [loadingModels, setLoadingModels] = useState(false);
  const [uploadingModel, setUploadingModel] = useState(false);
  
  // Model Upload State
  const [editingDirection, setEditingDirection] = useState<string | null>(null); // The direction currently being edited
  const [newModelFiles, setNewModelFiles] = useState<{file: File, type: 'image' | 'pdf'}[]>([]);

  useEffect(() => {
    if (projectId) {
      fetchPlans();
      fetchModels();
    }
  }, [projectId]);

  const fetchPlans = async () => {
    setLoadingPlans(true);
    try {
      const { data, error } = await supabase
        .from('project_documents')
        .select('*')
        .eq('project_id', projectId)
        .in('type', ['project_plan', 'architectural_plan', 'autocad', 'other']);
      
      if (error) throw error;
      setPlans(data || []);
    } catch (error) {
      console.error('Error fetching plans:', error);
    } finally {
      setLoadingPlans(false);
    }
  };

  const fetchModels = async () => {
    setLoadingModels(true);
    try {
      // 1. Fetch existing models
      const { data: modelsData, error: modelsError } = await supabase
        .from('unit_models')
        .select('*')
        .eq('project_id', projectId);
      
      if (modelsError) throw modelsError;
      setModels(modelsData || []);

      // 2. Fetch unique directions from units
      const { data: unitsData, error: unitsError } = await supabase
        .from('units')
        .select('direction_label')
        .eq('project_id', projectId);

      if (unitsError) throw unitsError;

      // Extract unique directions
      const directions = Array.from(new Set(
        unitsData
          ?.map(u => u.direction_label)
          .filter(d => d && d.trim() !== '') // Filter empty/null
      )).sort();
      
      setUniqueDirections(directions);

    } catch (error) {
      console.error('Error fetching models/directions:', error);
    } finally {
      setLoadingModels(false);
    }
  };

  // --- Plans Handlers ---

  const handlePlanUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || e.target.files.length === 0) return;
    const file = e.target.files[0];
    
    if (!newPlanTitle) {
      alert('الرجاء إدخال عنوان المخطط أولاً');
      return;
    }

    setUploadingPlan(true);
    try {
      const fileExt = file.name.split('.').pop();
      const fileName = `plans/${projectId}/${Date.now()}_${Math.random().toString(36).substring(7)}.${fileExt}`;
      
      const { error: uploadError } = await supabase.storage
        .from('project-files')
        .upload(fileName, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('project-files')
        .getPublicUrl(fileName);

      const { error: dbError } = await supabase
        .from('project_documents')
        .insert({
          project_id: projectId,
          title: newPlanTitle,
          type: newPlanType,
          file_url: publicUrl,
          file_path: fileName
        });

      if (dbError) throw dbError;

      setNewPlanTitle('');
      fetchPlans();
    } catch (error: any) {
      alert('حدث خطأ أثناء الرفع: ' + error.message);
    } finally {
      setUploadingPlan(false);
    }
  };

  const handleDeletePlan = async (id: string, path: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا المخطط؟')) return;
    
    try {
      await supabase.storage.from('project-files').remove([path]);
      await supabase.from('project_documents').delete().eq('id', id);
      fetchPlans();
    } catch (error) {
      console.error('Error deleting plan:', error);
    }
  };

  // --- Models Handlers ---

  const openModelEditor = (direction: string) => {
    setEditingDirection(direction);
    setNewModelFiles([]);
    // Note: We don't load existing files into newModelFiles because they are different types (File vs UnitModelFile)
    // We will handle the "total files" validation by checking models state + newModelFiles
  };

  const handleModelFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || e.target.files.length === 0) return;
    const file = e.target.files[0];
    const type = file.type.startsWith('image/') ? 'image' : 'pdf';
    
    // Find current model files
    const currentModel = models.find(m => m.name === editingDirection);
    const existingFiles = currentModel?.files || [];
    
    // Calculate totals including pending files
    const allFiles = [...existingFiles, ...newModelFiles];
    const hasPdf = allFiles.some(f => f.type === 'pdf'); // existing or new
    const imageCount = allFiles.filter(f => f.type === 'image').length;

    if (type === 'pdf') {
      if (allFiles.length > 0) {
        alert('لا يمكن إضافة ملف PDF إذا كانت هناك ملفات أخرى. النموذج يقبل إما ملف PDF واحد أو صورتين.');
        return;
      }
    } else {
      // Adding image
      if (hasPdf) {
        alert('لا يمكن إضافة صورة إذا كان هناك ملف PDF.');
        return;
      }
      if (imageCount >= 2) {
        alert('لا يمكن إضافة أكثر من صورتين.');
        return;
      }
    }

    setNewModelFiles([...newModelFiles, { file, type }]);
    e.target.value = '';
  };

  const removeNewModelFile = (index: number) => {
    setNewModelFiles(prev => prev.filter((_, i) => i !== index));
  };

  const removeExistingModelFile = async (modelId: string, fileUrl: string, filePath: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا الملف؟')) return;

    try {
      // 1. Remove from Storage
      await supabase.storage.from('project-files').remove([filePath]);

      // 2. Update DB
      const model = models.find(m => m.id === modelId);
      if (!model) return;

      const updatedFiles = model.files.filter(f => f.url !== fileUrl);

      // If no files left, maybe delete the model record? 
      // User didn't specify, but keeping an empty model record is fine, or deleting it.
      // Let's update it for now.
      
      const { error } = await supabase
        .from('unit_models')
        .update({ files: updatedFiles })
        .eq('id', modelId);

      if (error) throw error;

      // Update local state
      setModels(prev => prev.map(m => 
        m.id === modelId ? { ...m, files: updatedFiles } : m
      ));

    } catch (error) {
      console.error('Error deleting file:', error);
      alert('حدث خطأ أثناء حذف الملف');
    }
  };

  const handleSaveModel = async () => {
    if (!editingDirection) return;
    if (newModelFiles.length === 0) {
      setEditingDirection(null); // Just close if nothing to save
      return;
    }

    setUploadingModel(true);
    try {
      const uploadedFiles: UnitModelFile[] = [];

      // Upload new files
      for (const fileObj of newModelFiles) {
        const fileExt = fileObj.file.name.split('.').pop();
        const fileName = `models/${projectId}/${Date.now()}_${Math.random().toString(36).substring(7)}.${fileExt}`;
        
        const { error: uploadError } = await supabase.storage
          .from('project-files')
          .upload(fileName, fileObj.file);

        if (uploadError) throw uploadError;

        const { data: { publicUrl } } = supabase.storage
          .from('project-files')
          .getPublicUrl(fileName);

        uploadedFiles.push({
          url: publicUrl,
          type: fileObj.type,
          path: fileName
        });
      }

      // Check if model exists
      const existingModel = models.find(m => m.name === editingDirection);
      
      if (existingModel) {
        // Update existing
        const updatedFiles = [...existingModel.files, ...uploadedFiles];
        const { error } = await supabase
          .from('unit_models')
          .update({ files: updatedFiles })
          .eq('id', existingModel.id);
        if (error) throw error;
      } else {
        // Create new
        const { error } = await supabase
          .from('unit_models')
          .insert({
            project_id: projectId,
            name: editingDirection,
            files: uploadedFiles
          });
        if (error) throw error;
      }

      setEditingDirection(null);
      setNewModelFiles([]);
      fetchModels();
    } catch (error: any) {
      alert('حدث خطأ أثناء حفظ النموذج: ' + error.message);
    } finally {
      setUploadingModel(false);
    }
  };

  const handleDeleteModel = async (id: string, files: UnitModelFile[]) => {
    if (!confirm('هل أنت متأكد من حذف جميع ملفات هذا النموذج؟')) return;

    try {
      const paths = files.map(f => f.path);
      if (paths.length > 0) {
        await supabase.storage.from('project-files').remove(paths);
      }
      await supabase.from('unit_models').delete().eq('id', id);
      fetchModels();
    } catch (error) {
      console.error('Error deleting model:', error);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 mt-8 p-6" dir="rtl">
      <div className="flex items-center gap-2 mb-6 border-b border-gray-200 pb-4">
        <LayoutTemplate className="text-blue-600" size={24} />
        <h2 className="text-xl font-bold text-gray-900">إدارة المخططات والنماذج</h2>
      </div>

      <div className="flex gap-4 mb-6">
        <button
          onClick={() => setActiveTab('plans')}
          className={`flex-1 py-3 px-4 rounded-lg font-bold transition-all flex items-center justify-center gap-2
            ${activeTab === 'plans' ? 'bg-blue-50 text-blue-700 border-2 border-blue-200' : 'bg-gray-50 text-gray-600 border border-gray-200 hover:bg-gray-100'}`}
        >
          <FileCode size={20} />
          مخططات المشروع
        </button>
        <button
          onClick={() => setActiveTab('models')}
          className={`flex-1 py-3 px-4 rounded-lg font-bold transition-all flex items-center justify-center gap-2
            ${activeTab === 'models' ? 'bg-orange-50 text-orange-700 border-2 border-orange-200' : 'bg-gray-50 text-gray-600 border border-gray-200 hover:bg-gray-100'}`}
        >
          <Box size={20} />
          نماذج الوحدات
        </button>
      </div>

      {activeTab === 'plans' && (
        <div className="space-y-6">
          <div className="bg-gray-50 p-4 rounded-lg border border-gray-200">
            <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Plus size={18} />
              إضافة مخطط جديد
            </h3>
            <div className="flex flex-col md:flex-row gap-4 items-end">
              <div className="flex-1 w-full">
                <label className="block text-sm font-medium text-gray-700 mb-1">عنوان المخطط</label>
                <input
                  type="text"
                  value={newPlanTitle}
                  onChange={(e) => setNewPlanTitle(e.target.value)}
                  className="w-full p-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 outline-none text-right"
                  placeholder="مثلاً: المخطط المعماري الدور الأول"
                />
              </div>
              <div className="w-full md:w-48">
                <label className="block text-sm font-medium text-gray-700 mb-1">النوع</label>
                <select
                  value={newPlanType}
                  onChange={(e) => setNewPlanType(e.target.value as any)}
                  className="w-full p-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 outline-none"
                >
                  <option value="project_plan">مخطط مشروع</option>
                  <option value="architectural_plan">مخطط معماري</option>
                  <option value="autocad">ملف أوتوكاد</option>
                  <option value="other">أخرى</option>
                </select>
              </div>
              <div className="w-full md:w-auto">
                <label 
                  className={`flex items-center justify-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-md cursor-pointer hover:bg-blue-700 transition-colors ${uploadingPlan ? 'opacity-50 pointer-events-none' : ''}`}
                >
                  {uploadingPlan ? <Loader2 size={20} className="animate-spin" /> : <Upload size={20} />}
                  <span>رفع الملف</span>
                  <input
                    type="file"
                    className="hidden"
                    onChange={handlePlanUpload}
                    disabled={uploadingPlan}
                  />
                </label>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {plans.map((plan) => (
              <div key={plan.id} className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow bg-white group">
                <div className="flex items-start justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${plan.type === 'autocad' ? 'bg-red-50 text-red-600' : 'bg-blue-50 text-blue-600'}`}>
                      {plan.type === 'autocad' ? <FileCode size={24} /> : <FileText size={24} />}
                    </div>
                    <div>
                      <h4 className="font-bold text-gray-900 truncate max-w-[150px]" title={plan.title}>{plan.title}</h4>
                      <p className="text-xs text-gray-500">{DOCUMENT_TYPES[plan.type as keyof typeof DOCUMENT_TYPES] || plan.type}</p>
                    </div>
                  </div>
                  <button 
                    onClick={() => handleDeletePlan(plan.id, plan.file_path)}
                    className="text-gray-400 hover:text-red-500 transition-colors p-1 opacity-0 group-hover:opacity-100"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
                <div className="flex gap-2 mt-4">
                  <a 
                    href={plan.file_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex-1 bg-gray-50 text-gray-700 py-2 rounded-md text-sm font-medium hover:bg-gray-100 flex items-center justify-center gap-2 transition-colors"
                  >
                    <ExternalLink size={16} />
                    عرض
                  </a>
                  <a 
                    href={`${plan.file_url}?download=true`}
                    download
                    className="bg-gray-50 text-gray-700 p-2 rounded-md hover:bg-gray-100 transition-colors"
                    title="تحميل"
                  >
                    <Download size={16} />
                  </a>
                </div>
              </div>
            ))}
            {plans.length === 0 && !loadingPlans && (
              <div className="col-span-full text-center py-12 text-gray-500 border-2 border-dashed border-gray-200 rounded-lg">
                لا توجد مخططات مضافة بعد
              </div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'models' && (
        <div className="space-y-6">
          {uniqueDirections.length === 0 && !loadingModels ? (
            <div className="text-center py-12 text-gray-500 border-2 border-dashed border-gray-200 rounded-lg">
              لا توجد اتجاهات وحدات معرفة في هذا المشروع بعد.
              <br />
              <span className="text-sm mt-2 block">سيتم استخراج النماذج تلقائياً من اتجاهات الوحدات (مثل: شمالية شرقية).</span>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {uniqueDirections.map((direction) => {
                const model = models.find(m => m.name === direction);
                const isEditing = editingDirection === direction;
                const files = model?.files || [];

                return (
                  <div 
                    key={direction} 
                    className={`bg-white rounded-xl border transition-all duration-300 ${
                      isEditing 
                        ? 'border-orange-500 shadow-lg ring-2 ring-orange-100 col-span-full' 
                        : 'border-gray-200 hover:shadow-lg'
                    }`}
                  >
                    <div className={`p-4 border-b flex justify-between items-center rounded-t-xl ${isEditing ? 'bg-orange-50 border-orange-200' : 'bg-gray-50 border-gray-100'}`}>
                      <div>
                        <h4 className="font-bold text-lg text-gray-900">{direction}</h4>
                        <span className="text-xs text-gray-500">
                          {files.length > 0 ? `${files.length} ملفات` : 'لا توجد ملفات'}
                        </span>
                      </div>
                      {!isEditing ? (
                        <button 
                          onClick={() => openModelEditor(direction)}
                          className="text-orange-600 hover:text-orange-700 hover:bg-orange-50 px-3 py-1.5 rounded-lg text-sm font-bold flex items-center gap-2 transition-colors"
                        >
                          <Box size={16} />
                          إدارة النموذج
                        </button>
                      ) : (
                        <button onClick={() => setEditingDirection(null)} className="text-gray-500 hover:text-gray-700 p-1 hover:bg-gray-200 rounded-full">
                          <X size={20} />
                        </button>
                      )}
                    </div>

                    <div className="p-4">
                      {/* View Mode */}
                      {!isEditing && (
                        <div className="min-h-[100px] flex items-center justify-center">
                          {files.length > 0 ? (
                            <div className="grid grid-cols-2 gap-2 w-full">
                              {files.map((file, idx) => (
                                <a 
                                  key={idx}
                                  href={file.url}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="relative group block w-full h-24 bg-gray-50 rounded border border-gray-200 overflow-hidden hover:border-orange-300 transition-colors"
                                >
                                  {file.type === 'image' ? (
                                    <img src={file.url} alt={direction} className="w-full h-full object-cover" />
                                  ) : (
                                    <div className="w-full h-full flex flex-col items-center justify-center text-red-500">
                                      <FileText size={24} />
                                      <span className="text-[10px] mt-1">PDF</span>
                                    </div>
                                  )}
                                </a>
                              ))}
                            </div>
                          ) : (
                            <div className="text-center text-gray-400 text-sm flex flex-col items-center gap-2">
                              <Box size={24} className="opacity-20" />
                              <span>لا توجد ملفات مرفقة</span>
                            </div>
                          )}
                        </div>
                      )}

                      {/* Edit Mode */}
                      {isEditing && (
                        <div className="animate-in fade-in space-y-6">
                          {/* Existing Files Section */}
                          {files.length > 0 && (
                            <div>
                              <h5 className="text-sm font-bold text-gray-700 mb-3 flex items-center gap-2">
                                <FileCode size={16} />
                                الملفات الحالية
                              </h5>
                              <div className="flex flex-wrap gap-4">
                                {files.map((file, idx) => (
                                  <div key={idx} className="relative group w-24 h-24 bg-white rounded border border-gray-200 shadow-sm overflow-hidden">
                                    {file.type === 'image' ? (
                                      <img src={file.url} alt="thumbnail" className="w-full h-full object-cover" />
                                    ) : (
                                      <div className="w-full h-full flex flex-col items-center justify-center text-red-500">
                                        <FileText size={24} />
                                        <span className="text-[10px]">PDF</span>
                                      </div>
                                    )}
                                    <button
                                      onClick={() => removeExistingModelFile(model!.id, file.url, file.path)}
                                      className="absolute top-1 right-1 bg-red-500 text-white p-1.5 rounded-full opacity-0 group-hover:opacity-100 transition-all hover:bg-red-600 shadow-sm"
                                      title="حذف الملف"
                                    >
                                      <Trash2 size={12} />
                                    </button>
                                  </div>
                                ))}
                              </div>
                            </div>
                          )}

                          {/* Upload New Files Section */}
                          <div>
                            <h5 className="text-sm font-bold text-gray-700 mb-3 flex items-center gap-2">
                              <Plus size={16} />
                              إضافة ملفات جديدة
                            </h5>
                            
                            <div className="flex flex-wrap gap-4 mb-3">
                              {newModelFiles.map((file, idx) => (
                                <div key={idx} className="relative group bg-white p-2 rounded border border-gray-200 shadow-sm w-24 h-24 flex items-center justify-center">
                                  {file.type === 'image' ? (
                                    <div className="text-center">
                                      <ImageIcon className="mx-auto text-orange-500 mb-1" size={24} />
                                      <span className="text-[10px] text-gray-500 block truncate w-20">{file.file.name}</span>
                                    </div>
                                  ) : (
                                    <div className="text-center">
                                      <FileText className="mx-auto text-red-500 mb-1" size={24} />
                                      <span className="text-[10px] text-gray-500 block truncate w-20">PDF</span>
                                    </div>
                                  )}
                                  <button
                                    onClick={() => removeNewModelFile(idx)}
                                    className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 shadow-sm hover:bg-red-600"
                                  >
                                    <X size={12} />
                                  </button>
                                </div>
                              ))}
                              
                              <label className="w-24 h-24 border-2 border-dashed border-gray-300 rounded flex flex-col items-center justify-center cursor-pointer hover:border-orange-500 hover:bg-orange-50 transition-colors text-gray-400 hover:text-orange-500">
                                <Plus size={24} />
                                <span className="text-[10px] mt-1 font-bold">رفع ملف</span>
                                <input
                                  type="file"
                                  className="hidden"
                                  accept=".pdf,image/*"
                                  onChange={handleModelFileSelect}
                                />
                              </label>
                            </div>
                            <p className="text-xs text-gray-500 bg-gray-50 p-2 rounded inline-block">
                              * القواعد: إما ملف PDF واحد فقط، أو حتى صورتين (JPEG/PNG).
                            </p>
                          </div>

                          <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
                            <button
                              onClick={() => setEditingDirection(null)}
                              className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-lg font-medium"
                            >
                              إلغاء
                            </button>
                            <button
                              onClick={handleSaveModel}
                              disabled={uploadingModel || newModelFiles.length === 0}
                              className="bg-orange-600 text-white px-6 py-2 rounded-lg hover:bg-orange-700 transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed font-bold"
                            >
                              {uploadingModel ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} />}
                              حفظ التغييرات
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

const SaveIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path>
    <polyline points="17 21 17 13 7 13 7 21"></polyline>
    <polyline points="7 3 7 8 15 8"></polyline>
  </svg>
);
