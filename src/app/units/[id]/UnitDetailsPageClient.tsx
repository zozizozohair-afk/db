'use client';

import React, { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { Unit, Project, ProjectDocument, UnitModel, DOCUMENT_TYPES } from '../../../types';
import Link from 'next/link';
import { 
  ArrowRight, 
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
  Image as ImageIcon
} from 'lucide-react';

export default function UnitDetailsPage({ params }: { params: { id: string } }) {
  const { id } = params;
  
  const [unit, setUnit] = useState<Unit | null>(null);
  const [project, setProject] = useState<Project | null>(null);
  const [projectDocuments, setProjectDocuments] = useState<ProjectDocument[]>([]);
  const [unitModel, setUnitModel] = useState<UnitModel | null>(null);
  const [loading, setLoading] = useState(true);

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

        // Fetch Project
        if (unitData.project_id) {
          const { data: projectData, error: projectError } = await supabase
            .from('projects')
            .select('*')
            .eq('id', unitData.project_id)
            .single();
            
          if (!projectError) {
            setProject(projectData);

            // Fetch Project Documents
            const { data: docsData, error: docsError } = await supabase
              .from('project_documents')
              .select('*')
              .eq('project_id', unitData.project_id);
              
            if (!docsError && docsData) {
              setProjectDocuments(docsData);
            }

            // Fetch Unit Model (based on direction_label)
            if (unitData.direction_label) {
              const { data: modelData, error: modelError } = await supabase
                .from('unit_models')
                .select('*')
                .eq('project_id', unitData.project_id)
                .eq('name', unitData.direction_label)
                .maybeSingle();
                
              if (!modelError && modelData) {
                setUnitModel(modelData);
              }
            }
          }
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
      resale: 'bg-purple-100 text-purple-800 border-purple-200',
      pending_sale: 'bg-orange-100 text-orange-800 border-orange-200',
    };

    const labels = {
      available: 'غير مباعة',
      sold: 'مباعة',
      sold_to_other: 'مباعة لآخر',
      resale: 'إعادة بيع',
      pending_sale: 'قيد البيع',
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
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
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
          <div className="flex items-center gap-3">
            <button 
              onClick={() => window.print()}
              className="p-2 text-gray-600 hover:bg-gray-100 rounded-md transition-colors hidden sm:flex"
              title="طباعة"
            >
              <Printer size={20} />
            </button>
            {getStatusBadge(unit.status)}
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
              <div className="flex items-center gap-4 text-gray-500 text-sm">
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
            </div>
            
            <div className="flex gap-4">
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
        <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
          <FileText size={24} className="text-blue-600" />
          الملفات والمستندات
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          
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
        </div>

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

      </main>
    </div>
  );
}
