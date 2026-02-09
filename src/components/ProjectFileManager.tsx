import React, { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabaseClient';
import { ProjectDocument, DOCUMENT_TYPES } from '../types';
import { FileText, Upload, Trash2, Eye, Download, AlertCircle } from 'lucide-react';

interface ProjectFileManagerProps {
  projectId: string;
}

export default function ProjectFileManager({ projectId }: ProjectFileManagerProps) {
  const [documents, setDocuments] = useState<ProjectDocument[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [selectedType, setSelectedType] = useState<string>('other');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const fetchDocuments = async () => {
    try {
      const { data, error } = await supabase
        .from('project_documents')
        .select('*')
        .eq('project_id', projectId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setDocuments(data || []);
    } catch (error) {
      console.error('Error fetching documents:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDocuments();
  }, [projectId]);

  const handleUploadClick = (type: string) => {
    setSelectedType(type);
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setUploading(true);
    try {
      const fileExt = file.name.split('.').pop();
      const fileName = `${projectId}/${Date.now()}_${selectedType}.${fileExt}`;
      const filePath = fileName;

      // 1. Upload to Storage
      const { error: uploadError } = await supabase.storage
        .from('project-files')
        .upload(filePath, file);

      if (uploadError) {
        if (uploadError.message.includes('Bucket not found')) {
           alert('خطأ: لم يتم العثور على مجلد التخزين (Bucket). يرجى التأكد من إنشاء bucket باسم "project-files" في Supabase.');
        } else {
           throw uploadError;
        }
        return;
      }

      // 2. Get Public URL
      const { data: { publicUrl } } = supabase.storage
        .from('project-files')
        .getPublicUrl(filePath);

      // 3. Save to Database
      const { error: dbError } = await supabase
        .from('project_documents')
        .insert({
          project_id: projectId,
          title: file.name,
          type: selectedType,
          file_path: filePath,
          file_url: publicUrl
        });

      if (dbError) throw dbError;

      fetchDocuments();
      alert('تم رفع الملف بنجاح');
    } catch (error: any) {
      console.error('Error uploading file:', error);
      alert(`فشل رفع الملف: ${error.message}`);
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleDelete = async (docId: string, filePath: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا الملف؟')) return;

    try {
      // 1. Delete from Storage
      const { error: storageError } = await supabase.storage
        .from('project-files')
        .remove([filePath]);

      if (storageError) console.error('Storage delete error:', storageError);

      // 2. Delete from DB
      const { error: dbError } = await supabase
        .from('project_documents')
        .delete()
        .eq('id', docId);

      if (dbError) throw dbError;

      setDocuments(documents.filter(d => d.id !== docId));
    } catch (error) {
      console.error('Error deleting file:', error);
      alert('حدث خطأ أثناء الحذف');
    }
  };

  // Group documents by type for display if needed, but a list is fine for now.
  // We can show "Missing" indicators for required files.
  
  const requiredTypes = ['license', 'guarantee', 'occupancy'];
  const uploadedTypes = documents.map(d => d.type);

  return (
    <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100">
      <h3 className="text-lg font-bold text-gray-800 mb-4 flex items-center gap-2">
        <FileText className="w-5 h-5 text-blue-600" />
        ملفات ومستندات المشروع
      </h3>

      <div className="mb-6 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
        {/* Upload Buttons for specific types */}
        {Object.entries(DOCUMENT_TYPES).map(([type, label]) => {
          const isUploaded = uploadedTypes.includes(type as any);
          const isRequired = requiredTypes.includes(type);
          
          return (
            <button
              key={type}
              onClick={() => handleUploadClick(type)}
              disabled={uploading}
              className={`p-4 border-2 border-dashed rounded-lg flex flex-col items-center justify-center gap-2 transition-colors
                ${isUploaded 
                  ? 'border-green-200 bg-green-50 text-green-700' 
                  : 'border-gray-300 hover:border-blue-400 hover:bg-blue-50 text-gray-600'
                }`}
            >
              <Upload className={`w-6 h-6 ${isUploaded ? 'text-green-500' : 'text-gray-400'}`} />
              <span className="font-medium text-sm">{label}</span>
              {isUploaded && <span className="text-xs text-green-600">تم الرفع</span>}
              {!isUploaded && isRequired && <span className="text-xs text-red-400">* مطلوب</span>}
            </button>
          );
        })}
      </div>

      <input
        type="file"
        ref={fileInputRef}
        onChange={handleFileChange}
        className="hidden"
      />

      {/* Files List */}
      <div className="space-y-3">
        <h4 className="font-semibold text-gray-700 border-b pb-2">الملفات المرفوعة</h4>
        {loading ? (
          <p className="text-gray-500 text-center py-4">جاري التحميل...</p>
        ) : documents.length === 0 ? (
          <div className="text-center py-8 text-gray-400 bg-gray-50 rounded-lg">
            <FileText className="w-10 h-10 mx-auto mb-2 opacity-50" />
            <p>لا توجد ملفات مرفوعة حالياً</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-3">
            {documents.map((doc) => (
              <div key={doc.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-md hover:bg-gray-100 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="bg-blue-100 p-2 rounded-full text-blue-600">
                    <FileText className="w-4 h-4" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-800 text-sm">{doc.title}</p>
                    <p className="text-xs text-gray-500">
                      {DOCUMENT_TYPES[doc.type as keyof typeof DOCUMENT_TYPES] || doc.type} • {new Date(doc.created_at).toLocaleDateString('ar-SA')}
                    </p>
                  </div>
                </div>
                
                <div className="flex items-center gap-2">
                  <a 
                    href={doc.file_url} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="p-2 text-gray-500 hover:text-blue-600 hover:bg-white rounded-full transition-colors"
                    title="معاينة"
                  >
                    <Eye className="w-4 h-4" />
                  </a>
                  <button
                    onClick={() => handleDelete(doc.id, doc.file_path)}
                    className="p-2 text-gray-500 hover:text-red-600 hover:bg-white rounded-full transition-colors"
                    title="حذف"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
