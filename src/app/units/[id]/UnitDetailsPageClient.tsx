'use client';

import React, { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { Unit, Project, ProjectDocument, UnitModel, DOCUMENT_TYPES, UnitContract, CONTRACT_TYPES } from '../../../types';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { PDFDocument } from 'pdf-lib';
import { 
  ArrowRight, 
  ArrowLeft,
  Building2, 
  MapPin, 
  FileText, 
  User, 
  Phone, 
  CreditCard, 
  Calendar,
  CheckCircle2,
  AlertCircle,
  Download,
  ExternalLink,
  Printer,
  Home,
  Zap,
  Droplets,
  FileCheck,
  Layers,
  MessageCircle,
  FolderOpen,
  LayoutTemplate,
  Image as ImageIcon,
  Plus,
  X,
  FileSignature,
  Trash2,
  Upload,
  Files,
  Share2,
  Edit2,
  Save,
  Loader2
} from 'lucide-react';

interface MergeableFile {
  id: string;
  name: string;
  url: string;
  type: 'deed' | 'sorting' | 'electricity_release' | 'contract' | 'project_doc' | 'unit_model';
  selected: boolean;
}

interface ProjectUnitNavItem {
  id: string;
  unit_number: number;
  floor_number: number;
  floor_label: string;
  direction_label: string;
  status: Unit['status'];
  type: Unit['type'];
}

type UnitFileField = 'deed_file_url' | 'sorting_record_file_url' | 'electricity_release_file_url';

export default function UnitDetailsPage({ params }: { params: { id: string } }) {
  const { id } = params;
  const router = useRouter();
  
  const [unit, setUnit] = useState<Unit | null>(null);
  const [project, setProject] = useState<Project | null>(null);
  const [projectUnits, setProjectUnits] = useState<ProjectUnitNavItem[]>([]);
  const [projectDocuments, setProjectDocuments] = useState<ProjectDocument[]>([]);
  const [unitModel, setUnitModel] = useState<UnitModel | null>(null);
  const [contracts, setContracts] = useState<UnitContract[]>([]);
  const [loading, setLoading] = useState(true);

  const trySignProjectFileUrl = async (filePath: string, fallbackUrl?: string | null) => {
    const path = String(filePath || '').trim();
    if (!path) return String(fallbackUrl || '').trim() || null;
    try {
      const res = await supabase.storage.from('project-files').createSignedUrl(path, 60 * 60);
      if (res.error) return String(fallbackUrl || '').trim() || null;
      return String(res.data?.signedUrl || '').trim() || String(fallbackUrl || '').trim() || null;
    } catch {
      return String(fallbackUrl || '').trim() || null;
    }
  };

  // Contract Upload Modal State
  const [showContractModal, setShowContractModal] = useState(false);
  const [contractType, setContractType] = useState<string>('');
  const [customContractType, setCustomContractType] = useState('');
  const [contractFile, setContractFile] = useState<File | null>(null);
  const [uploadingContract, setUploadingContract] = useState(false);

  // Merge & Send State
  const [showMergeModal, setShowMergeModal] = useState(false);
  const [mergeableFiles, setMergeableFiles] = useState<MergeableFile[]>([]);
  const [isMerging, setIsMerging] = useState(false);
  const [isDownloadingSeparate, setIsDownloadingSeparate] = useState(false);
  const [uploadingUnitFileField, setUploadingUnitFileField] = useState<UnitFileField | null>(null);
  const [movingContractId, setMovingContractId] = useState<string | null>(null);

  // Edit Unit State
  const [showEditModal, setShowEditModal] = useState(false);
  const [isSavingEdit, setIsSavingEdit] = useState(false);
  const [editData, setEditData] = useState<Partial<Unit>>({});

  useEffect(() => {
    const fetchUnitDetails = async () => {
      try {
        setLoading(true);
        
        // Fetch Unit
        const { data: unitData, error: unitError } = await supabase
          .from('units')
          .select('*')
          .eq('id', id)
          .single();

        if (unitError) throw unitError;
        setUnit(unitData);
        // Initialize edit data
        setEditData(unitData);

        if (unitData.project_id) {
          const siblingUnitsPromise = supabase
            .from('units')
            .select('id, unit_number, floor_number, floor_label, direction_label, status, type')
            .eq('project_id', unitData.project_id)
            .order('unit_number', { ascending: true });

          const projectPromise = supabase
            .from('projects')
            .select('*')
            .eq('id', unitData.project_id)
            .single();

          const docsPromise = supabase
            .from('project_documents')
            .select('*')
            .eq('project_id', unitData.project_id);

          const contractsPromise = supabase
            .from('unit_contracts')
            .select('*')
            .eq('unit_id', id)
            .order('created_at', { ascending: false });

          const unitModelPromise = unitData.direction_label
            ? supabase
                .from('unit_models')
                .select('*')
                .eq('project_id', unitData.project_id)
                .eq('name', unitData.direction_label)
                .maybeSingle()
            : Promise.resolve({ data: null, error: null } as const);

          const [
            { data: siblingUnits, error: siblingUnitsError },
            { data: projectData, error: projectError },
            { data: docsData, error: docsError },
            { data: contractsData, error: contractsError },
            { data: modelData, error: modelError },
          ] = await Promise.all([
            siblingUnitsPromise,
            projectPromise,
            docsPromise,
            contractsPromise,
            unitModelPromise,
          ]);

          if (!siblingUnitsError && siblingUnits) {
            setProjectUnits(siblingUnits as ProjectUnitNavItem[]);
          } else {
            setProjectUnits([]);
          }

          setProject(projectError ? null : (projectData as Project | null));
          setUnitModel(!modelError && modelData ? (modelData as UnitModel) : null);

          if (!docsError && docsData) {
            const signedDocs = await Promise.all(
              (docsData as any[]).map(async (d) => {
                const signedUrl = await trySignProjectFileUrl(String((d as any)?.file_path || ''), String((d as any)?.file_url || ''));
                return { ...(d as any), file_url: signedUrl || (d as any)?.file_url } as any;
              })
            );
            setProjectDocuments(signedDocs as any);
          } else {
            setProjectDocuments([]);
          }

          if (!contractsError && contractsData) {
            const signedContracts = await Promise.all(
              (contractsData as any[]).map(async (c) => {
                const signedUrl = await trySignProjectFileUrl(String((c as any)?.file_path || ''), String((c as any)?.file_url || ''));
                return { ...(c as any), file_url: signedUrl || (c as any)?.file_url } as any;
              })
            );
            setContracts(signedContracts as any);
          } else {
            setContracts([]);
          }
        } else {
          setProjectUnits([]);
          setProject(null);
          setProjectDocuments([]);
          setUnitModel(null);
          setContracts([]);
        }

      } catch (error) {
        console.error('Error fetching unit details:', error);
      } finally {
        setLoading(false);
      }
    };

    if (id) {
      fetchUnitDetails();
    }
  }, [id]);

  const getStatusBadge = (status: string) => {
    const styles = {
      available: 'bg-green-100 text-green-800 border-green-200',
      sold: 'bg-red-100 text-red-800 border-red-200',
      sold_to_other: 'bg-gray-100 text-gray-800 border-gray-200',
      transferred_to_other: 'bg-slate-100 text-slate-800 border-slate-200',
      resale: 'bg-purple-100 text-purple-800 border-purple-200',
      pending_sale: 'bg-orange-100 text-orange-800 border-orange-200',
    };

    const labels = {
      available: 'غير مباعة',
      sold: 'مباعة',
      sold_to_other: 'مباعة لآخر',
      transferred_to_other: 'مفرغة لآخر',
      resale: 'إعادة بيع',
      pending_sale: 'بيع على الخارطة',
    };

    const statusKey = status as keyof typeof styles;
    
    return (
      <span className={`px-3 py-1 rounded-full text-sm font-medium border ${styles[statusKey] || 'bg-gray-100 text-gray-800'}`}>
        {labels[statusKey] || status}
      </span>
    );
  };

  const formatPhoneForWhatsapp = (phone: string) => {
    let cleaned = phone.replace(/\D/g, '');
    if (cleaned.startsWith('05')) {
      cleaned = '966' + cleaned.substring(1);
    }
    return cleaned;
  };

  const ContactButtons = ({ phone }: { phone: string }) => {
    if (!phone) return null;
    return (
      <div className="flex items-center gap-2">
        <a 
          href={`tel:${phone}`}
          className="p-2 bg-gray-100 text-gray-600 rounded-lg hover:bg-gray-200 hover:text-gray-900 transition-colors"
          title="اتصال"
        >
          <Phone size={16} />
        </a>
        <a 
          href={`https://wa.me/${formatPhoneForWhatsapp(phone)}`}
          target="_blank"
          rel="noopener noreferrer"
          className="p-2 bg-green-50 text-green-600 rounded-lg hover:bg-green-100 hover:text-green-700 transition-colors"
          title="واتساب"
        >
          <MessageCircle size={16} />
        </a>
      </div>
    );
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setContractFile(e.target.files[0]);
    }
  };

  const handleUploadUnitFile = async (field: UnitFileField, file: File) => {
    if (!unit) return;

    const prefixMap: Record<UnitFileField, string> = {
      deed_file_url: 'deeds',
      sorting_record_file_url: 'sorting_records',
      electricity_release_file_url: 'electricity_release',
    };

    try {
      setUploadingUnitFileField(field);
      const fileExt = file.name.split('.').pop() || 'pdf';
      const fileName = `${prefixMap[field]}/${unit.project_id}/${unit.id}_${Date.now()}.${fileExt}`;

      const { error: uploadError } = await supabase.storage
        .from('project-files')
        .upload(fileName, file, { upsert: true });
      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('project-files')
        .getPublicUrl(fileName);

      const { error: updateError } = await supabase
        .from('units')
        .update({ [field]: publicUrl })
        .eq('id', unit.id);
      if (updateError) throw updateError;

      setUnit((prev) => prev ? { ...prev, [field]: publicUrl } : prev);
    } catch (error) {
      console.error('Error uploading unit file:', error);
      alert('حدث خطأ أثناء رفع الملف');
    } finally {
      setUploadingUnitFileField(null);
    }
  };

  const handleUploadContract = async () => {
    if (!contractFile || !contractType || !id) return;
    
    if (contractType === 'other' && !customContractType) return;

    try {
      setUploadingContract(true);
      const fileExt = contractFile.name.split('.').pop();
      const fileName = `${Math.random().toString(36).substring(2)}.${fileExt}`;
      const filePath = `contracts/${id}/${fileName}`;

      // 1. Upload file
      const { error: uploadError } = await supabase.storage
        .from('project-files')
        .upload(filePath, contractFile);

      if (uploadError) throw uploadError;

      // 2. Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('project-files')
        .getPublicUrl(filePath);

      // 3. Save to database
      const { data: contractData, error: dbError } = await supabase
        .from('unit_contracts')
        .insert([
          {
            unit_id: id,
            type: contractType,
            custom_type: contractType === 'other' ? customContractType : null,
            file_url: publicUrl,
            file_path: filePath
          }
        ])
        .select()
        .single();

      if (dbError) throw dbError;

      // 4. Update state
      const signedUrl = await trySignProjectFileUrl(String((contractData as any)?.file_path || ''), String((contractData as any)?.file_url || ''));
      setContracts([{ ...(contractData as any), file_url: signedUrl || (contractData as any)?.file_url } as any, ...contracts]);
      setShowContractModal(false);
      setContractType('');
      setCustomContractType('');
      setContractFile(null);

    } catch (error) {
      console.error('Error uploading contract:', error);
      alert('حدث خطأ أثناء رفع العقد');
    } finally {
      setUploadingContract(false);
    }
  };

  const handleDeleteContract = async (contractId: string, filePath: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا العقد؟')) return;

    try {
      // 1. Delete file
      const { error: storageError } = await supabase.storage
        .from('project-files')
        .remove([filePath]);

      if (storageError) {
        console.error('Error deleting file:', storageError);
        // Continue to delete record even if file deletion fails (might be already gone)
      }

      // 2. Delete record
      const { error: dbError } = await supabase
        .from('unit_contracts')
        .delete()
        .eq('id', contractId);

      if (dbError) throw dbError;

      // 3. Update state
      setContracts(contracts.filter(c => c.id !== contractId));

    } catch (error) {
      console.error('Error deleting contract:', error);
      alert('حدث خطأ أثناء حذف العقد');
    }
  };

  const handleConvertOtherContractToElectricityRelease = async (contract: UnitContract) => {
    if (!unit) return;

    if (contract.type !== 'other') return;

    const hasExistingCertificate = Boolean(unit.electricity_release_file_url);
    const confirmMessage = hasExistingCertificate
      ? 'يوجد حالياً ملف مسجل كشهادة إطلاق تيار. هل تريد استبداله بهذا الملف ونقله من العقود؟'
      : 'هل تريد تحويل هذا الملف من العقود إلى شهادة إطلاق تيار؟';

    if (!confirm(confirmMessage)) return;

    try {
      setMovingContractId(contract.id);

      const publicUrl = contract.file_path
        ? supabase.storage.from('project-files').getPublicUrl(contract.file_path).data.publicUrl
        : contract.file_url;

      const { error: updateUnitError } = await supabase
        .from('units')
        .update({ electricity_release_file_url: publicUrl })
        .eq('id', unit.id);
      if (updateUnitError) throw updateUnitError;

      const { error: deleteContractError } = await supabase
        .from('unit_contracts')
        .delete()
        .eq('id', contract.id);
      if (deleteContractError) throw deleteContractError;

      setUnit((prev) => prev ? { ...prev, electricity_release_file_url: publicUrl } : prev);
      setContracts((prev) => prev.filter((item) => item.id !== contract.id));
    } catch (error) {
      console.error('Error converting contract to electricity release certificate:', error);
      alert('حدث خطأ أثناء تحويل الملف إلى شهادة إطلاق تيار');
    } finally {
      setMovingContractId(null);
    }
  };

  const handlePrepareMerge = () => {
    const files: MergeableFile[] = [];

    // 1. Add Deed File
    if (unit?.deed_file_url) {
      files.push({
        id: 'deed',
        name: 'صك الملكية',
        url: unit.deed_file_url,
        type: 'deed',
        selected: true
      });
    }

    // 2. Add Sorting Record
    if (unit?.sorting_record_file_url) {
      files.push({
        id: 'sorting',
        name: 'محضر الفرز',
        url: unit.sorting_record_file_url,
        type: 'sorting',
        selected: true
      });
    }

    // 3. Add Electricity Release Certificate
    if (unit?.electricity_release_file_url) {
      files.push({
        id: 'electricity_release',
        name: 'شهادة إطلاق تيار',
        url: unit.electricity_release_file_url,
        type: 'electricity_release',
        selected: true
      });
    }

    // 4. Add Contracts
    contracts.forEach(contract => {
      files.push({
        id: contract.id,
        name: CONTRACT_TYPES[contract.type as keyof typeof CONTRACT_TYPES] || contract.type,
        url: contract.file_url,
        type: 'contract',
        selected: true
      });
    });

    // 5. Add Project Documents
    projectDocuments.forEach(doc => {
      files.push({
        id: doc.id,
        name: doc.title,
        url: doc.file_url,
        type: 'project_doc',
        selected: false
      });
    });

    setMergeableFiles(files);
    setShowMergeModal(true);
  };

  const handleToggleFileSelection = (id: string) => {
    setMergeableFiles(prev => prev.map(f => 
      f.id === id ? { ...f, selected: !f.selected } : f
    ));
  };

  const handleMergeAndDownload = async () => {
    const selectedFiles = mergeableFiles.filter(f => f.selected);
    if (selectedFiles.length === 0) {
      alert('الرجاء اختيار ملف واحد على الأقل');
      return;
    }

    try {
      setIsMerging(true);
      const mergedPdf = await PDFDocument.create();

      for (const file of selectedFiles) {
        try {
          // Fetch file
          const response = await fetch(file.url);
          const arrayBuffer = await response.arrayBuffer();
          const fileExt = file.url.split('.').pop()?.toLowerCase();

          if (fileExt === 'pdf') {
            const pdf = await PDFDocument.load(arrayBuffer);
            const copiedPages = await mergedPdf.copyPages(pdf, pdf.getPageIndices());
            copiedPages.forEach((page) => mergedPdf.addPage(page));
          } else if (['jpg', 'jpeg', 'png'].includes(fileExt || '')) {
             const image = fileExt === 'png' 
               ? await mergedPdf.embedPng(arrayBuffer)
               : await mergedPdf.embedJpg(arrayBuffer);
             
             const page = mergedPdf.addPage();
             const { width, height } = image.scale(1);
             const pageWidth = page.getWidth();
             const pageHeight = page.getHeight();
             
             // Scale image to fit page
             const scale = Math.min(pageWidth / width, pageHeight / height, 1);
             page.drawImage(image, {
               x: (pageWidth - width * scale) / 2,
               y: (pageHeight - height * scale) / 2,
               width: width * scale,
               height: height * scale,
             });
          }
        } catch (error) {
          console.error(`Error processing file ${file.name}:`, error);
          // Continue with other files even if one fails
        }
      }

      const pdfBytes = await mergedPdf.save();
      const blob = new Blob([pdfBytes as any], { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      
      // Download
      const link = document.createElement('a');
      link.href = url;
      link.download = `ملف_مجمع_${unit?.unit_number || 'وحدة'}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      setShowMergeModal(false);

    } catch (error) {
      console.error('Error merging files:', error);
      alert('حدث خطأ أثناء دمج الملفات');
    } finally {
      setIsMerging(false);
    }
  };

  const handleDownloadSelectedSeparately = async () => {
    const selectedFiles = mergeableFiles.filter(f => f.selected);
    if (selectedFiles.length === 0) {
      alert('الرجاء اختيار ملف واحد على الأقل');
      return;
    }

    const buildDownloadName = (file: MergeableFile, index: number, contentType?: string) => {
      const cleanBaseName = file.name.replace(/[<>:"/\\|?*\u0000-\u001F]/g, '_').trim() || `file-${index + 1}`;
      const urlWithoutQuery = file.url.split('?')[0];
      const urlFileName = urlWithoutQuery.split('/').pop() || '';
      const urlExt = urlFileName.includes('.') ? `.${urlFileName.split('.').pop()}` : '';
      const typeMap: Record<string, string> = {
        'application/pdf': '.pdf',
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'application/msword': '.doc',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
      };
      const typeExt = contentType ? (typeMap[contentType] || '') : '';
      const finalExt = urlExt || typeExt;
      const suffixParts = [
        project?.project_number ? `مشروع ${project.project_number}` : null,
        unit?.unit_number ? `وحدة ${unit.unit_number}` : null,
      ].filter(Boolean);
      const baseWithSuffix = suffixParts.length > 0 ? `${cleanBaseName} - ${suffixParts.join(' - ')}` : cleanBaseName;
      return baseWithSuffix.endsWith(finalExt) || !finalExt ? baseWithSuffix : `${baseWithSuffix}${finalExt}`;
    };

    try {
      setIsDownloadingSeparate(true);

      for (let i = 0; i < selectedFiles.length; i += 1) {
        const file = selectedFiles[i];
        try {
          const response = await fetch(file.url);
          if (!response.ok) {
            throw new Error(`فشل تحميل الملف ${file.name}`);
          }

          const blob = await response.blob();
          const blobUrl = URL.createObjectURL(blob);
          const link = document.createElement('a');
          link.href = blobUrl;
          link.download = buildDownloadName(file, i, blob.type);
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          URL.revokeObjectURL(blobUrl);
        } catch (error) {
          console.error(`Error downloading file ${file.name}:`, error);
        }
      }

      setShowMergeModal(false);
    } catch (error) {
      console.error('Error downloading selected files separately:', error);
      alert('حدث خطأ أثناء تحميل الملفات');
    } finally {
      setIsDownloadingSeparate(false);
    }
  };

  const handleSaveEdit = async () => {
    try {
      setIsSavingEdit(true);
      
      const { error } = await supabase
        .from('units')
        .update(editData)
        .eq('id', id);

      if (error) throw error;

      // Update the local state
      setUnit(prev => prev ? { ...prev, ...editData } : null);
      setShowEditModal(false);
      alert('تم تحديث الوحدة بنجاح!');
    } catch (error) {
      console.error('Error updating unit:', error);
      alert('حدث خطأ أثناء تحديث الوحدة');
    } finally {
      setIsSavingEdit(false);
    }
  };

  const currentUnitIndex = projectUnits.findIndex((projectUnit) => projectUnit.id === unit?.id);
  const previousUnit = currentUnitIndex > 0 ? projectUnits[currentUnitIndex - 1] : null;
  const nextUnit = currentUnitIndex >= 0 && currentUnitIndex < projectUnits.length - 1
    ? projectUnits[currentUnitIndex + 1]
    : null;

  useEffect(() => {
    if (previousUnit?.id) {
      router.prefetch(`/units/${previousUnit.id}`);
    }
    if (nextUnit?.id) {
      router.prefetch(`/units/${nextUnit.id}`);
    }
  }, [nextUnit?.id, previousUnit?.id, router]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!unit) {
    return (
      <div className="min-h-screen bg-gray-50 flex flex-col items-center justify-center gap-4">
        <AlertCircle size={48} className="text-red-500" />
        <h2 className="text-2xl font-bold text-gray-900">الوحدة غير موجودة</h2>
        <Link href="/" className="text-blue-600 hover:underline flex items-center gap-2">
          <ArrowRight size={20} />
          العودة للرئيسية
        </Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-12" dir="rtl">
      {/* Top Navigation Bar */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10 shadow-sm">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-3 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex items-center gap-4">
            <Link 
              href={project ? `/projects/${project.id}` : '/'} 
              className="p-2 hover:bg-gray-100 rounded-full text-gray-500 transition-colors"
            >
              <ArrowRight size={20} />
            </Link>
            <div>
              <h1 className="text-lg font-bold text-gray-900">
                وحدة رقم {unit.unit_number}
              </h1>
              {project && (
                <p className="text-xs text-gray-500">{project.name}</p>
              )}
            </div>
          </div>

          <div className="flex flex-col items-stretch gap-3 lg:items-end">
            <div className="flex items-center gap-3">
              <button 
                onClick={() => window.print()}
                className="p-2 text-gray-600 hover:bg-gray-100 rounded-md transition-colors hidden sm:flex"
                title="طباعة"
              >
                <Printer size={20} />
              </button>
              <button 
                onClick={() => {
                  if (unit) setEditData(unit);
                  setShowEditModal(true);
                }}
                className="p-2 text-blue-600 hover:bg-blue-100 rounded-md transition-colors flex items-center gap-2"
                title="تعديل الوحدة"
              >
                <Edit2 size={20} />
                <span className="hidden sm:inline text-sm font-medium">تعديل</span>
              </button>
              {getStatusBadge(unit.status)}
            </div>

            <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
              <div className="text-xs text-gray-500 font-medium">
                {projectUnits.length > 0 ? `التنقل داخل وحدات المشروع (${currentUnitIndex + 1} من ${projectUnits.length})` : 'لا توجد وحدات أخرى ضمن هذا المشروع'}
              </div>
              <div className="flex items-center gap-2">
                {previousUnit ? (
                  <Link
                    href={`/units/${previousUnit.id}`}
                    className="inline-flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-semibold text-gray-700 hover:border-blue-300 hover:bg-blue-50 hover:text-blue-700 transition-colors"
                    title={`الانتقال إلى الوحدة ${previousUnit.unit_number}`}
                  >
                    <ArrowRight size={16} />
                    السابقة: {previousUnit.unit_number}
                  </Link>
                ) : (
                  <span className="inline-flex items-center gap-2 rounded-lg border border-gray-100 bg-gray-50 px-3 py-2 text-sm font-semibold text-gray-400 cursor-not-allowed">
                    <ArrowRight size={16} />
                    لا توجد سابقة
                  </span>
                )}

                {nextUnit ? (
                  <Link
                    href={`/units/${nextUnit.id}`}
                    className="inline-flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-semibold text-gray-700 hover:border-blue-300 hover:bg-blue-50 hover:text-blue-700 transition-colors"
                    title={`الانتقال إلى الوحدة ${nextUnit.unit_number}`}
                  >
                    التالية: {nextUnit.unit_number}
                    <ArrowLeft size={16} />
                  </Link>
                ) : (
                  <span className="inline-flex items-center gap-2 rounded-lg border border-gray-100 bg-gray-50 px-3 py-2 text-sm font-semibold text-gray-400 cursor-not-allowed">
                    لا توجد تالية
                    <ArrowLeft size={16} />
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Unit Header Card */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-8 relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-blue-500 to-teal-400"></div>
          <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
            <div>
              <div className="flex items-center gap-2 text-blue-600 font-medium mb-1">
                <Building2 size={18} />
                <span>تفاصيل الوحدة</span>
              </div>
              <h2 className="text-3xl font-bold text-gray-900 mb-2">
                {unit.type === 'apartment' ? 'شقة سكنية' : 'ملحق علوي'} - {unit.floor_label}
              </h2>
              <div className="flex items-center gap-4 text-gray-500 text-sm mb-4">
                <span className="flex items-center gap-1">
                  <MapPin size={14} />
                  {unit.direction_label}
                </span>
                {project && (
                  <span className="flex items-center gap-1">
                    <Home size={14} />
                    {project.name}
                  </span>
                )}
              </div>
              {unit.description && (
                <div className="mt-2 p-3 bg-yellow-50 rounded-lg border border-yellow-200">
                  <p className="text-sm text-yellow-900 font-medium">{unit.description}</p>
                </div>
              )}
            </div>
            
            <div className="flex gap-4 flex-wrap">
               <div className="bg-blue-50 px-4 py-3 rounded-xl flex flex-col items-center min-w-[100px]">
                 <span className="text-xs text-blue-600 font-medium mb-1">رقم العداد</span>
                 <div className="flex items-center gap-1 text-blue-900 font-bold">
                   <Zap size={16} />
                   {unit.electricity_meter || '-'}
                 </div>
               </div>
               <div className="bg-cyan-50 px-4 py-3 rounded-xl flex flex-col items-center min-w-[100px]">
                 <span className="text-xs text-cyan-600 font-medium mb-1">عداد المياه</span>
                 <div className="flex items-center gap-1 text-cyan-900 font-bold">
                   <Droplets size={16} />
                   {unit.water_meter || '-'}
                 </div>
               </div>
               {unit.area_sqm && (
                 <div className="bg-green-50 px-4 py-3 rounded-xl flex flex-col items-center min-w-[100px]">
                   <span className="text-xs text-green-600 font-medium mb-1">المساحة</span>
                   <div className="flex items-center gap-1 text-green-900 font-bold">
                     <Layers size={16} />
                     {unit.area_sqm} م²
                   </div>
                 </div>
               )}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          
          {/* Client Information */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 md:col-span-2">
            <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
              <User size={20} className="text-purple-600" />
              بيانات العميل
            </h3>
            
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs text-gray-500 mb-1">اسم العميل</label>
                <p className="font-medium text-gray-900 text-lg">{unit.client_name || '-'}</p>
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">رقم الهوية</label>
                <p className="font-medium text-gray-900 flex items-center gap-2">
                  <CreditCard size={16} className="text-gray-400" />
                  {unit.client_id_number || '-'}
                </p>
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">رقم الجوال</label>
                <div className="flex items-center gap-3">
                  <p className="font-medium text-gray-900 flex items-center gap-2" dir="ltr">
                    <Phone size={16} className="text-gray-400" />
                    {unit.client_phone || '-'}
                  </p>
                  {unit.client_phone && <ContactButtons phone={unit.client_phone} />}
                </div>
              </div>
            </div>
          </div>

          {/* Legal Information */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
              <FileCheck size={20} className="text-teal-600" />
              البيانات العقارية
            </h3>
            
            <div className="space-y-4">
              <div>
                <label className="block text-xs text-gray-500 mb-1">رقم الصك</label>
                <p className="font-mono font-bold text-gray-900 bg-gray-50 p-2 rounded border border-gray-100 inline-block">
                  {unit.deed_number || '-'}
                </p>
              </div>
              
              {(unit.title_deed_owner || unit.title_deed_owner_id) && (
                <div className="pt-4 border-t border-gray-100">
                  <label className="block text-xs text-gray-500 mb-2">المفرغ له (المالك الحالي)</label>
                  <div className="bg-teal-50 rounded-lg p-3">
                    <p className="font-bold text-teal-900 mb-1">{unit.title_deed_owner || '-'}</p>
                    <div className="flex flex-col gap-2 text-xs text-teal-700">
                      {unit.title_deed_owner_id && <span>هوية: {unit.title_deed_owner_id}</span>}
                      {unit.title_deed_owner_phone && (
                        <div className="flex items-center gap-3">
                          <span dir="ltr" className="font-medium">{unit.title_deed_owner_phone}</span>
                          <ContactButtons phone={unit.title_deed_owner_phone} />
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Files Section */}
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
            <FileText size={24} className="text-blue-600" />
            الملفات والمستندات
          </h3>
          <div className="flex items-center gap-2">
            <button
              onClick={handlePrepareMerge}
              className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors"
            >
              <Files size={16} />
              دمج وإرسال
            </button>
            <button
              onClick={handlePrepareMerge}
              className="flex items-center gap-2 bg-white text-indigo-700 border border-indigo-200 px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-50 transition-colors"
            >
              <Download size={16} />
              تحميل منفصل
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          
          {/* Deed File Card */}
          <div className={`rounded-xl border p-6 transition-all duration-200 group ${unit.deed_file_url ? 'bg-white border-blue-100 hover:shadow-md hover:border-blue-300' : 'bg-gray-50 border-gray-200 border-dashed'}`}>
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className={`p-3 rounded-lg ${unit.deed_file_url ? 'bg-blue-100 text-blue-600' : 'bg-gray-200 text-gray-400'}`}>
                  <FileText size={24} />
                </div>
                <div>
                  <h4 className="font-bold text-gray-900">صك الملكية</h4>
                  <p className="text-sm text-gray-500">نسخة إلكترونية من الصك</p>
                </div>
              </div>
              {unit.deed_file_url && (
                <span className="bg-green-100 text-green-700 text-xs px-2 py-1 rounded-full flex items-center gap-1">
                  <CheckCircle2 size={12} />
                  متوفر
                </span>
              )}
            </div>
            
            {unit.deed_file_url ? (
              <div className="flex gap-3 mt-4">
                <a 
                  href={unit.deed_file_url} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                >
                  <ExternalLink size={16} />
                  عرض الملف
                </a>
                <a 
                  href={`${unit.deed_file_url}?download=true`} 
                  download
                  className="bg-blue-50 text-blue-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-100 transition-colors flex items-center justify-center"
                  title="تحميل"
                >
                  <Download size={16} />
                </a>
              </div>
            ) : (
              <div className="mt-4 text-center text-gray-400 text-sm py-2">
                لا يوجد ملف مرفق
              </div>
            )}
          </div>

          {/* Sorting Record File Card */}
          <div className={`rounded-xl border p-6 transition-all duration-200 group ${unit.sorting_record_file_url ? 'bg-white border-purple-100 hover:shadow-md hover:border-purple-300' : 'bg-gray-50 border-gray-200 border-dashed'}`}>
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className={`p-3 rounded-lg ${unit.sorting_record_file_url ? 'bg-purple-100 text-purple-600' : 'bg-gray-200 text-gray-400'}`}>
                  <Layers size={24} />
                </div>
                <div>
                  <h4 className="font-bold text-gray-900">محضر الفرز</h4>
                  <p className="text-sm text-gray-500">تفاصيل مساحات الوحدة</p>
                </div>
              </div>
              {unit.sorting_record_file_url && (
                <span className="bg-green-100 text-green-700 text-xs px-2 py-1 rounded-full flex items-center gap-1">
                  <CheckCircle2 size={12} />
                  متوفر
                </span>
              )}
            </div>
            
            {unit.sorting_record_file_url ? (
              <div className="flex gap-3 mt-4">
                <a 
                  href={unit.sorting_record_file_url} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="flex-1 bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 transition-colors flex items-center justify-center gap-2"
                >
                  <ExternalLink size={16} />
                  عرض الملف
                </a>
                <a 
                  href={`${unit.sorting_record_file_url}?download=true`} 
                  download
                  className="bg-purple-50 text-purple-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-100 transition-colors flex items-center justify-center"
                  title="تحميل"
                >
                  <Download size={16} />
                </a>
              </div>
            ) : (
              <div className="mt-4 text-center text-gray-400 text-sm py-2">
                لا يوجد ملف مرفق
              </div>
            )}
          </div>

          {/* Electricity Release Certificate Card */}
          <div className={`rounded-xl border p-6 transition-all duration-200 group ${unit.electricity_release_file_url ? 'bg-white border-amber-100 hover:shadow-md hover:border-amber-300' : 'bg-gray-50 border-gray-200 border-dashed'}`}>
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className={`p-3 rounded-lg ${unit.electricity_release_file_url ? 'bg-amber-100 text-amber-600' : 'bg-gray-200 text-gray-400'}`}>
                  <Zap size={24} />
                </div>
                <div>
                  <h4 className="font-bold text-gray-900">شهادة إطلاق تيار</h4>
                  <p className="text-sm text-gray-500">ملف إطلاق التيار أو الشهادة المرتبطة به</p>
                </div>
              </div>
              {unit.electricity_release_file_url && (
                <span className="bg-green-100 text-green-700 text-xs px-2 py-1 rounded-full flex items-center gap-1">
                  <CheckCircle2 size={12} />
                  متوفر
                </span>
              )}
            </div>
            
            {unit.electricity_release_file_url ? (
              <div className="flex flex-wrap gap-3 mt-4">
                <a 
                  href={unit.electricity_release_file_url} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="flex-1 bg-amber-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-amber-700 transition-colors flex items-center justify-center gap-2"
                >
                  <ExternalLink size={16} />
                  عرض الملف
                </a>
                <a 
                  href={`${unit.electricity_release_file_url}?download=true`} 
                  download
                  className="bg-amber-50 text-amber-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-amber-100 transition-colors flex items-center justify-center"
                  title="تحميل"
                >
                  <Download size={16} />
                </a>
                <label className="bg-white text-amber-700 border border-amber-200 px-4 py-2 rounded-lg text-sm font-medium hover:bg-amber-50 transition-colors flex items-center justify-center gap-2 cursor-pointer">
                  {uploadingUnitFileField === 'electricity_release_file_url' ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Upload size={16} />
                  )}
                  {uploadingUnitFileField === 'electricity_release_file_url' ? 'جاري الرفع...' : 'استبدال الملف'}
                  <input
                    type="file"
                    accept=".pdf,.doc,.docx,.jpg,.jpeg,.png,.webp"
                    className="hidden"
                    disabled={uploadingUnitFileField === 'electricity_release_file_url'}
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      e.currentTarget.value = '';
                      if (file) handleUploadUnitFile('electricity_release_file_url', file);
                    }}
                  />
                </label>
              </div>
            ) : (
              <div className="mt-4 space-y-3">
                <div className="text-center text-gray-400 text-sm py-2">
                  لا يوجد ملف مرفق
                </div>
                <label className="w-full bg-amber-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-amber-700 transition-colors flex items-center justify-center gap-2 cursor-pointer">
                  {uploadingUnitFileField === 'electricity_release_file_url' ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Upload size={16} />
                  )}
                  {uploadingUnitFileField === 'electricity_release_file_url' ? 'جاري الرفع...' : 'رفع الملف'}
                  <input
                    type="file"
                    accept=".pdf,.doc,.docx,.jpg,.jpeg,.png,.webp"
                    className="hidden"
                    disabled={uploadingUnitFileField === 'electricity_release_file_url'}
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      e.currentTarget.value = '';
                      if (file) handleUploadUnitFile('electricity_release_file_url', file);
                    }}
                  />
                </label>
              </div>
            )}
          </div>
        </div>

        {/* Contracts Section */}
        <div className="flex items-center justify-between mb-4 mt-8 pt-8 border-t border-gray-200">
          <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
            <FileSignature size={24} className="text-emerald-600" />
            العقود
          </h3>
          <button
            onClick={() => setShowContractModal(true)}
            className="flex items-center gap-2 bg-emerald-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors"
          >
            <Plus size={16} />
            رفع عقود
          </button>
        </div>

        {contracts.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
            {contracts.map((contract) => (
              <div key={contract.id} className="bg-white rounded-xl border border-gray-200 p-6 hover:shadow-md transition-shadow group relative">
                <button
                  onClick={() => handleDeleteContract(contract.id, contract.file_path)}
                  className="absolute top-4 left-4 p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-full transition-colors opacity-0 group-hover:opacity-100"
                  title="حذف العقد"
                >
                  <Trash2 size={16} />
                </button>
                
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="p-3 rounded-lg bg-emerald-50 text-emerald-600">
                      <FileText size={24} />
                    </div>
                    <div>
                      <h4 className="font-bold text-gray-900">
                        {CONTRACT_TYPES[contract.type as keyof typeof CONTRACT_TYPES] || contract.type}
                      </h4>
                      {contract.custom_type && (
                        <p className="text-xs text-gray-500 mt-1">{contract.custom_type}</p>
                      )}
                      <p className="text-xs text-gray-400 mt-1">
                        {new Date(contract.created_at).toLocaleDateString('ar-SA')}
                      </p>
                    </div>
                  </div>
                </div>
                
                <div className="flex gap-3 mt-4">
                  <a 
                    href={contract.file_url} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="flex-1 bg-emerald-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors flex items-center justify-center gap-2"
                  >
                    <ExternalLink size={16} />
                    عرض
                  </a>
                  <a 
                    href={`${contract.file_url}?download=true`} 
                    download
                    className="bg-emerald-50 text-emerald-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-emerald-100 transition-colors flex items-center justify-center"
                    title="تحميل"
                  >
                    <Download size={16} />
                  </a>
                </div>

                {contract.type === 'other' && (
                  <button
                    type="button"
                    onClick={() => handleConvertOtherContractToElectricityRelease(contract)}
                    disabled={movingContractId === contract.id}
                    className="w-full mt-3 bg-amber-50 text-amber-800 border border-amber-200 px-4 py-2 rounded-lg text-sm font-medium hover:bg-amber-100 transition-colors flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    {movingContractId === contract.id ? (
                      <Loader2 size={16} className="animate-spin" />
                    ) : (
                      <Zap size={16} />
                    )}
                    {movingContractId === contract.id ? 'جاري التحويل...' : 'تحويل إلى شهادة إطلاق تيار'}
                  </button>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="bg-gray-50 border-2 border-dashed border-gray-200 rounded-xl p-8 text-center mb-8">
            <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4 text-gray-400">
              <FileSignature size={32} />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-1">لا توجد عقود مرفقة</h3>
            <p className="text-gray-500 text-sm mb-4">يمكنك رفع عقود جديدة بالضغط على زر "رفع عقود"</p>
            <button
              onClick={() => setShowContractModal(true)}
              className="text-emerald-600 font-medium hover:underline text-sm"
            >
              رفع عقد جديد
            </button>
          </div>
        )}

        {/* Project Files Section */}
        {projectDocuments.length > 0 && (
          <>
            <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2 pt-8 border-t border-gray-200">
              <FolderOpen size={24} className="text-orange-500" />
              ملفات المشروع
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {projectDocuments.map((doc) => (
                <div key={doc.id} className="bg-white rounded-xl border border-gray-200 p-6 hover:shadow-md transition-shadow group">
                  <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center gap-3">
                      <div className="p-3 rounded-lg bg-orange-50 text-orange-600">
                        <FileText size={24} />
                      </div>
                      <div>
                        <h4 className="font-bold text-gray-900">{doc.title}</h4>
                        <p className="text-sm text-gray-500">{DOCUMENT_TYPES[doc.type as keyof typeof DOCUMENT_TYPES] || doc.type}</p>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex gap-3 mt-4">
                    <a 
                      href={doc.file_url} 
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="flex-1 bg-orange-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-orange-700 transition-colors flex items-center justify-center gap-2"
                    >
                      <ExternalLink size={16} />
                      عرض
                    </a>
                    <a 
                      href={`${doc.file_url}?download=true`} 
                      download
                      className="bg-orange-50 text-orange-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-orange-100 transition-colors flex items-center justify-center"
                      title="تحميل"
                    >
                      <Download size={16} />
                    </a>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}

        {/* Unit Model Files Section */}
        {unitModel && unitModel.files.length > 0 && (
          <>
            <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2 pt-8 border-t border-gray-200">
              <LayoutTemplate size={24} className="text-indigo-600" />
              نموذج الوحدة ({unitModel.name})
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {unitModel.files.map((file, idx) => (
                <div key={idx} className="bg-white rounded-xl border border-gray-200 overflow-hidden hover:shadow-md transition-shadow group">
                  <div className="p-4 flex items-center gap-3">
                    <div className="p-2 bg-indigo-50 text-indigo-600 rounded-lg">
                      <ImageIcon size={20} />
                    </div>
                    <span className="font-medium text-gray-900 truncate flex-1" title={typeof file === 'string' ? file : file.url}>
                      صورة {idx + 1}
                    </span>
                    <a 
                      href={typeof file === 'string' ? file : file.url}
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="p-2 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                    >
                      <ExternalLink size={16} />
                    </a>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}

        {/* Contract Upload Modal */}
        {showContractModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
            <div className="bg-white rounded-2xl w-full max-w-lg shadow-xl overflow-hidden animate-in fade-in zoom-in duration-200">
              <div className="flex items-center justify-between p-6 border-b border-gray-100">
                <h3 className="text-xl font-bold text-gray-900">رفع عقد جديد</h3>
                <button
                  onClick={() => setShowContractModal(false)}
                  className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors"
                >
                  <X size={20} />
                </button>
              </div>
              
              <div className="p-6 space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">نوع العقد</label>
                  <select
                    value={contractType}
                    onChange={(e) => setContractType(e.target.value)}
                    className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-200 outline-none transition-all bg-white"
                  >
                    <option value="">اختر نوع العقد...</option>
                    {Object.entries(CONTRACT_TYPES).map(([key, label]) => (
                      <option key={key} value={key}>{label}</option>
                    ))}
                  </select>
                </div>

                {contractType === 'other' && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">تحديد نوع العقد</label>
                    <input
                      type="text"
                      value={customContractType}
                      onChange={(e) => setCustomContractType(e.target.value)}
                      placeholder="اكتب نوع العقد هنا..."
                      className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-200 outline-none transition-all"
                    />
                  </div>
                )}

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">ملف العقد</label>
                  <div className={`border-2 border-dashed rounded-xl p-8 text-center transition-colors relative ${contractFile ? 'border-emerald-500 bg-emerald-50' : 'border-gray-300 hover:border-emerald-400 hover:bg-gray-50'}`}>
                    <input
                      type="file"
                      id="contract-file"
                      className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                      onChange={handleFileSelect}
                      accept=".pdf,.doc,.docx,.jpg,.jpeg,.png"
                    />
                    <div className="flex flex-col items-center gap-2 pointer-events-none">
                      {contractFile ? (
                        <>
                          <FileCheck size={32} className="text-emerald-600" />
                          <span className="text-emerald-700 font-medium">{contractFile.name}</span>
                          <span className="text-xs text-emerald-600">تم اختيار الملف</span>
                        </>
                      ) : (
                        <>
                          <Upload size={32} className="text-gray-400" />
                          <span className="text-gray-600 font-medium">اضغط لاختيار ملف</span>
                          <span className="text-xs text-gray-400">PDF, DOC, Images (Max 10MB)</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-6 border-t border-gray-100 bg-gray-50 flex gap-3">
                <button
                  onClick={handleUploadContract}
                  disabled={uploadingContract || !contractFile || !contractType || (contractType === 'other' && !customContractType)}
                  className="flex-1 bg-emerald-600 text-white px-6 py-3 rounded-xl font-bold hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
                >
                  {uploadingContract ? (
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  ) : (
                    <Upload size={20} />
                  )}
                  {uploadingContract ? 'جاري الرفع...' : 'رفع العقد'}
                </button>
                <button
                  onClick={() => setShowContractModal(false)}
                  disabled={uploadingContract}
                  className="px-6 py-3 rounded-xl font-bold text-gray-600 hover:bg-gray-200 transition-colors"
                >
                  إلغاء
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Merge Files Modal */}
        {showMergeModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
            <div className="bg-white rounded-2xl w-full max-w-lg shadow-xl overflow-hidden animate-in fade-in zoom-in duration-200">
              <div className="flex items-center justify-between p-6 border-b border-gray-100">
                <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                  <Files size={24} className="text-indigo-600" />
                  دمج الملفات وإرسالها
                </h3>
                <button
                  onClick={() => setShowMergeModal(false)}
                  className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors"
                >
                  <X size={20} />
                </button>
              </div>
              
              <div className="p-6 max-h-[60vh] overflow-y-auto">
                <p className="text-sm text-gray-500 mb-4">
                  حدد الملفات التي تريد التعامل معها، ويمكنك بعدها إما دمجها في ملف واحد أو تحميلها بشكل منفصل.
                </p>
                
                <div className="space-y-3">
                  {mergeableFiles.map((file) => (
                    <div 
                      key={file.id} 
                      className={`flex items-center p-3 rounded-lg border transition-colors cursor-pointer ${file.selected ? 'bg-indigo-50 border-indigo-200' : 'bg-gray-50 border-gray-200 hover:bg-gray-100'}`}
                      onClick={() => handleToggleFileSelection(file.id)}
                    >
                      <div className={`w-5 h-5 rounded border flex items-center justify-center mr-3 transition-colors ${file.selected ? 'bg-indigo-600 border-indigo-600 text-white' : 'border-gray-400 bg-white'}`}>
                        {file.selected && <CheckCircle2 size={14} />}
                      </div>
                      <div className="flex-1">
                        <p className="font-medium text-gray-900">{file.name}</p>
                        <p className="text-xs text-gray-500">{file.type === 'contract' ? 'عقد' : file.type === 'project_doc' ? 'ملف مشروع' : 'مستند'}</p>
                      </div>
                      <a 
                        href={file.url} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        className="p-2 text-gray-400 hover:text-indigo-600"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <ExternalLink size={16} />
                      </a>
                    </div>
                  ))}
                  
                  {mergeableFiles.length === 0 && (
                    <div className="text-center py-8 text-gray-500">
                      لا توجد ملفات متاحة للدمج
                    </div>
                  )}
                </div>
              </div>

              <div className="p-6 border-t border-gray-100 bg-gray-50 flex flex-col sm:flex-row gap-3">
                <button
                  onClick={handleDownloadSelectedSeparately}
                  disabled={isDownloadingSeparate || isMerging || mergeableFiles.filter(f => f.selected).length === 0}
                  className="flex-1 bg-white text-indigo-700 border border-indigo-200 px-6 py-3 rounded-xl font-bold hover:bg-indigo-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
                >
                  {isDownloadingSeparate ? (
                    <div className="w-5 h-5 border-2 border-indigo-200 border-t-indigo-700 rounded-full animate-spin"></div>
                  ) : (
                    <Download size={20} />
                  )}
                  {isDownloadingSeparate ? 'جاري التحميل...' : 'تحميل الملفات منفصلة'}
                </button>
                <button
                  onClick={handleMergeAndDownload}
                  disabled={isMerging || isDownloadingSeparate || mergeableFiles.filter(f => f.selected).length === 0}
                  className="flex-1 bg-indigo-600 text-white px-6 py-3 rounded-xl font-bold hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
                >
                  {isMerging ? (
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  ) : (
                    <Share2 size={20} />
                  )}
                  {isMerging ? 'جاري الدمج...' : 'دمج وتحميل الملف'}
                </button>
                <button
                  onClick={() => setShowMergeModal(false)}
                  disabled={isMerging}
                  className="px-6 py-3 rounded-xl font-bold text-gray-600 hover:bg-gray-200 transition-colors"
                >
                  إلغاء
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Edit Unit Modal */}
        {showEditModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
            <div className="bg-white rounded-2xl w-full max-w-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in duration-200">
              <div className="flex items-center justify-between p-6 border-b border-gray-100">
                <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                  <Edit2 size={24} className="text-blue-600" />
                  تعديل الوحدة
                </h3>
                <button
                  onClick={() => setShowEditModal(false)}
                  className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors"
                >
                  <X size={20} />
                </button>
              </div>
              
              <div className="p-6 max-h-[70vh] overflow-y-auto space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="block text-sm font-medium text-gray-700">رقم الوحدة</label>
                    <input
                      type="number"
                      value={editData.unit_number || ''}
                      onChange={(e) => setEditData({ ...editData, unit_number: Number(e.target.value) })}
                      className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="block text-sm font-medium text-gray-700">تسمية الطابق</label>
                    <input
                      type="text"
                      value={editData.floor_label || ''}
                      onChange={(e) => setEditData({ ...editData, floor_label: e.target.value })}
                      className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">الاتجاه / الوصف</label>
                  <input
                    type="text"
                    value={editData.direction_label || ''}
                    onChange={(e) => setEditData({ ...editData, direction_label: e.target.value })}
                    className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all"
                  />
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="block text-sm font-medium text-gray-700">المساحة (م²)</label>
                    <input
                      type="number"
                      value={editData.area_sqm || ''}
                      onChange={(e) => setEditData({ ...editData, area_sqm: e.target.value ? Number(e.target.value) : null })}
                      className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="block text-sm font-medium text-gray-700">الحالة</label>
                    <select
                      value={editData.status || 'available'}
                      onChange={(e) => setEditData({ ...editData, status: e.target.value as typeof editData.status })}
                      className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all bg-white"
                    >
                      <option value="available">غير مباعة</option>
                      <option value="sold">مباعة</option>
                      <option value="sold_to_other">مباعة لآخر</option>
                      <option value="resale">إعادة بيع</option>
                      <option value="pending_sale">بيع على الخارطة</option>
                    </select>
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">وصف الوحدة</label>
                  <textarea
                    value={editData.description || ''}
                    onChange={(e) => setEditData({ ...editData, description: e.target.value })}
                    rows={3}
                    className="w-full px-4 py-3 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all resize-none"
                    placeholder="وصف تفصيلي للوحدة..."
                  />
                </div>

                <div className="pt-4 border-t border-gray-200">
                  <h4 className="text-sm font-bold text-gray-700 mb-4">البيانات الإضافية</h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="block text-xs font-medium text-gray-600">رقم عداد الكهرباء</label>
                      <input
                        type="text"
                        value={editData.electricity_meter || ''}
                        onChange={(e) => setEditData({ ...editData, electricity_meter: e.target.value })}
                        className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all text-sm"
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="block text-xs font-medium text-gray-600">رقم عداد المياه</label>
                      <input
                        type="text"
                        value={editData.water_meter || ''}
                        onChange={(e) => setEditData({ ...editData, water_meter: e.target.value })}
                        className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition-all text-sm"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-6 border-t border-gray-100 bg-gray-50 flex gap-3">
                <button
                  onClick={handleSaveEdit}
                  disabled={isSavingEdit}
                  className="flex-1 bg-blue-600 text-white px-6 py-3 rounded-xl font-bold hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
                >
                  {isSavingEdit ? (
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  ) : (
                    <Save size={20} />
                  )}
                  {isSavingEdit ? 'جاري الحفظ...' : 'حفظ التغييرات'}
                </button>
                <button
                  onClick={() => setShowEditModal(false)}
                  disabled={isSavingEdit}
                  className="px-6 py-3 rounded-xl font-bold text-gray-600 hover:bg-gray-200 transition-colors"
                >
                  إلغاء
                </button>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
