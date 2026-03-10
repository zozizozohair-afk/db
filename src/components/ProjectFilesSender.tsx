'use client';

import React, { useState } from 'react';
import { Project, Unit } from '../types';
import { 
  FileText, 
  Share2, 
  Download, 
  CheckSquare, 
  Square,
  Loader2,
  ExternalLink
} from 'lucide-react';

interface ProjectFilesSenderProps {
  project: Project;
  units: Unit[];
}

type FileCategory = 'deed' | 'sorting_record' | 'modifications' | 'contract';

export default function ProjectFilesSender({ project, units }: ProjectFilesSenderProps) {
  const [selectedUnits, setSelectedUnits] = useState<string[]>([]);
  const [selectedCategories, setSelectedCategories] = useState<FileCategory[]>(['deed']);
  const [selectedStatuses, setSelectedStatuses] = useState<string[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);

  const categories: { id: FileCategory, label: string }[] = [
    { id: 'deed', label: 'الصك العقاري' },
    { id: 'sorting_record', label: 'محضر الفرز' },
    { id: 'modifications', label: 'ملف التعديلات' },
    { id: 'contract', label: 'عقد البيع' },
  ];

  const statusMap: Record<string, { label: string, color: string }> = {
    'available': { label: 'غير مفرغة', color: 'bg-green-100 text-green-700' },
    'sold': { label: 'مباعة', color: 'bg-red-100 text-red-700' },
    'pending_sale': { label: 'قيد البيع', color: 'bg-orange-100 text-orange-700' },
    'for_resale': { label: 'إعادة بيع', color: 'bg-purple-100 text-purple-700' },
    'sold_to_other': { label: 'مباعة لآخر', color: 'bg-gray-100 text-gray-700' },
  };

  const toggleStatusFilter = (status: string) => {
    setSelectedStatuses(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status) 
        : [...prev, status]
    );
  };

  const filteredUnits = units.filter(unit => 
    selectedStatuses.length === 0 || selectedStatuses.includes(unit.status)
  );

  const toggleUnit = (unitId: string) => {
    setSelectedUnits(prev => 
      prev.includes(unitId) 
        ? prev.filter(id => id !== unitId) 
        : [...prev, unitId]
    );
  };

  const toggleAll = () => {
    if (selectedUnits.length === filteredUnits.length) {
      setSelectedUnits([]);
    } else {
      setSelectedUnits(filteredUnits.map(u => u.id));
    }
  };

  const toggleCategory = (cat: FileCategory) => {
    setSelectedCategories(prev => 
      prev.includes(cat) 
        ? prev.filter(c => c !== cat) 
        : [...prev, cat]
    );
  };

  const getFileUrl = (unit: Unit, category: FileCategory) => {
    switch (category) {
      case 'deed': return unit.deed_file_url;
      case 'sorting_record': return unit.sorting_record_file_url;
      case 'modifications': return unit.modifications_file_url;
      default: return null;
    }
  };

  const handleDownloadAndShare = async () => {
    if (selectedUnits.length === 0 || selectedCategories.length === 0) {
      alert('يرجى اختيار وحدة واحدة على الأقل ونوع ملف واحد');
      return;
    }

    // Check for missing files
    const selectedUnitsData = units.filter(u => selectedUnits.includes(u.id));
    const missingFilesInfo: string[] = [];

    selectedUnitsData.forEach(unit => {
      selectedCategories.forEach(cat => {
        if (!getFileUrl(unit, cat)) {
          const catLabel = categories.find(c => c.id === cat)?.label || cat;
          missingFilesInfo.push(`وحدة ${unit.unit_number}: يفتقد ${catLabel}`);
        }
      });
    });

    if (missingFilesInfo.length > 0) {
      const confirmProceed = confirm(
        `تنبيه: توجد ملفات ناقصة للوحدات المختارة:\n\n${missingFilesInfo.join('\n')}\n\nهل تريد الاستمرار بتحميل الملفات المتوفرة فقط؟`
      );
      if (!confirmProceed) return;
    }

    setIsProcessing(true);
    try {
      const selectedUnitsData = units.filter(u => selectedUnits.includes(u.id));
      
      let downloadedCount = 0;
      for (const unit of selectedUnitsData) {
        for (const cat of selectedCategories) {
          const url = getFileUrl(unit, cat);
          if (url) {
            const catLabel = categories.find(c => c.id === cat)?.label || cat;
            const fileName = `وحدة_${unit.unit_number}_مشروع_${project.project_number}_${catLabel}.pdf`;
            
            // Download the file
            const response = await fetch(url);
            const blob = await response.blob();
            const link = document.createElement('a');
            link.href = window.URL.createObjectURL(blob);
            link.download = fileName;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            downloadedCount++;
          }
        }
      }
      
      if (downloadedCount > 0) {
        alert(`تم تحميل ${downloadedCount} ملف بنجاح. يمكنك الآن مشاركتها يدوياً عبر الواتساب.`);
      } else {
        alert('لم يتم العثور على أي ملفات لتحميلها.');
      }
    } catch (error) {
      console.error('Error downloading files:', error);
      alert('حدث خطأ أثناء تحميل الملفات');
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 space-y-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-gray-900 flex items-center gap-2">
            <Share2 size={24} className="text-blue-600" />
            إرسال ومشاركة ملفات الوحدات
          </h2>
          <p className="text-sm text-gray-500 mt-1">
            اختر الوحدات والملفات المطلوب تحميلها بأسماء منظمة للمشاركة
          </p>
        </div>
        
        <button
          onClick={handleDownloadAndShare}
          disabled={isProcessing || selectedUnits.length === 0}
          className="flex items-center justify-center gap-2 px-6 py-2.5 bg-green-600 text-white rounded-xl hover:bg-green-700 transition-all shadow-md hover:shadow-lg font-bold disabled:opacity-50 w-full md:w-auto"
        >
          {isProcessing ? <Loader2 size={20} className="animate-spin" /> : <Download size={20} />}
          تحميل ومشاركة
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {/* Categories Selection */}
        <div className="space-y-4">
          <h3 className="font-bold text-gray-800 border-b pb-2">1. اختر أنواع الملفات</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-1 gap-2">
            {categories.map(cat => (
              <button
                key={cat.id}
                onClick={() => toggleCategory(cat.id)}
                className={`w-full flex items-center justify-between p-3 rounded-xl border transition-all ${
                  selectedCategories.includes(cat.id)
                    ? 'border-blue-500 bg-blue-50 text-blue-700 shadow-sm'
                    : 'border-gray-100 hover:border-gray-200 text-gray-600'
                }`}
              >
                <span className="font-medium">{cat.label}</span>
                {selectedCategories.includes(cat.id) ? <CheckSquare size={18} /> : <Square size={18} />}
              </button>
            ))}
          </div>
        </div>

        {/* Units Selection */}
        <div className="md:col-span-1 lg:col-span-2 space-y-4">
          <div className="bg-gray-50 p-4 rounded-2xl border border-gray-100 space-y-3">
            <h4 className="text-xs font-bold text-gray-500 uppercase tracking-wider">تصفية بحالة الوحدة (مدمج):</h4>
            <div className="flex flex-wrap gap-2">
              {Object.entries(statusMap).map(([status, info]) => (
                <button
                  key={status}
                  onClick={() => toggleStatusFilter(status)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all border ${
                    selectedStatuses.includes(status)
                      ? info.color + ' border-current ring-2 ring-offset-1 ring-current'
                      : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  {info.label}
                </button>
              ))}
              {selectedStatuses.length > 0 && (
                <button
                  onClick={() => setSelectedStatuses([])}
                  className="px-3 py-1.5 rounded-lg text-xs font-bold text-red-600 hover:bg-red-50 transition-colors"
                >
                  إلغاء الفلترة
                </button>
              )}
            </div>
          </div>

          <div className="flex items-center justify-between border-b pb-2 pt-2">
            <h3 className="font-bold text-gray-800">2. اختر الوحدات ({selectedUnits.length})</h3>
            <button 
              onClick={toggleAll}
              className="text-xs text-blue-600 hover:underline font-bold"
            >
              {selectedUnits.length === filteredUnits.length ? 'إلغاء الكل' : 'تحديد الكل'}
            </button>
          </div>
          
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 max-h-[400px] overflow-y-auto p-1">
            {filteredUnits.length === 0 ? (
              <div className="col-span-full py-10 text-center text-gray-500 text-sm">
                لا توجد وحدات تطابق هذه الفلترة
              </div>
            ) : (
              filteredUnits.map(unit => {
                const hasFiles = selectedCategories.some(cat => getFileUrl(unit, cat));
                return (
                  <button
                    key={unit.id}
                    onClick={() => toggleUnit(unit.id)}
                    className={`flex flex-col items-center p-3 rounded-xl border transition-all relative ${
                      selectedUnits.includes(unit.id)
                        ? 'border-blue-500 bg-blue-50 text-blue-700'
                        : 'border-gray-100 hover:border-gray-200 text-gray-600'
                    } ${!hasFiles && selectedCategories.length > 0 ? 'opacity-50 grayscale' : ''}`}
                  >
                    <span className="text-lg font-bold">وحدة {unit.unit_number}</span>
                    <span className="text-[10px]">{unit.floor_label}</span>
                    <span className={`text-[9px] mt-1 px-1.5 py-0.5 rounded-full font-bold ${statusMap[unit.status]?.color || 'bg-gray-100 text-gray-600'}`}>
                      {statusMap[unit.status]?.label || unit.status}
                    </span>
                    {!hasFiles && selectedCategories.length > 0 && (
                      <span className="text-[9px] text-red-500 font-bold mt-1 italic">لا يوجد ملفات</span>
                    )}
                    {selectedUnits.includes(unit.id) && (
                      <div className="absolute top-1 right-1 text-blue-600">
                        <CheckSquare size={14} />
                      </div>
                    )}
                  </button>
                );
              })
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
