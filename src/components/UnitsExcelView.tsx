import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Unit } from '../types';
import { Save, X, FileText, Upload, Loader2, Link as LinkIcon, ExternalLink, Camera, Image as ImageIcon } from 'lucide-react';

interface UnitsExcelViewProps {
  units: Unit[];
  onUpdate: () => void;
  onCancel: () => void;
}

export default function UnitsExcelView({ units: initialUnits, onUpdate, onCancel }: UnitsExcelViewProps) {
  const [localUnits, setLocalUnits] = useState<Unit[]>(initialUnits);
  const [loading, setLoading] = useState(false);
  const [uploadingRows, setUploadingRows] = useState<Record<string, boolean>>({});
  const [modifiedIds, setModifiedIds] = useState<Set<string>>(new Set());
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [activeColumn, setActiveColumn] = useState<string | null>(null);
  const [activeUploadCell, setActiveUploadCell] = useState<{unitId: string, field: keyof Unit} | null>(null);
  const [bulkStatus, setBulkStatus] = useState<string>('');
  
  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const toggleSelection = (id: string) => {
    const newSelected = new Set(selectedIds);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedIds(newSelected);
  };

  const toggleSelectAll = () => {
    if (selectedIds.size === localUnits.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(localUnits.map(u => u.id)));
    }
  };

  const handleBulkStatusUpdate = () => {
    if (!bulkStatus || selectedIds.size === 0) return;
    
    setLocalUnits(prev => prev.map(u => {
      if (selectedIds.has(u.id)) {
        return { ...u, status: bulkStatus as Unit['status'] };
      }
      return u;
    }));
    
    setModifiedIds(prev => {
      const next = new Set(prev);
      selectedIds.forEach(id => next.add(id));
      return next;
    });
    
    setSelectedIds(new Set());
    setBulkStatus('');
  };
  const cameraInputRef = React.useRef<HTMLInputElement>(null);

  // Update local state when prop changes
  useEffect(() => {
    setLocalUnits(initialUnits);
  }, [initialUnits]);

  const getColumnClass = (colKey: string, defaultWidth: string) => {
    const baseTransition = "transition-all duration-300 ease-in-out";
    
    if (!activeColumn) {

      return `${defaultWidth} text-sm ${baseTransition}`;
    }
    
    if (activeColumn === colKey) {
      return `min-w-[250px] text-base ${baseTransition}`;
    }
    
    return `w-24 text-[10px] text-gray-400 ${baseTransition}`;
  };

  const handleColumnFocus = (colKey: string) => {
    setActiveColumn(colKey);
  };

  const handleChange = (id: string, field: keyof Unit, value: any) => {
    setLocalUnits(prev => prev.map(u => {

      if (u.id === id) {
        return { ...u, [field]: value };
      }
      return u;
    }));
    setModifiedIds(prev => new Set(prev).add(id));
  };

  const handlePaste = (e: React.ClipboardEvent, startIndex: number, field: keyof Unit) => {
    // Check if files are being pasted
    if ((field === 'deed_file_url' || field === 'sorting_record_file_url' || field === 'modifications_file_url') && e.clipboardData.files.length > 0) {
        handleFilePaste(e, startIndex, field);
        return;
    }

    e.preventDefault();
    const pastedData = e.clipboardData.getData('text');
    const rows = pastedData.split(/\r\n|\n|\r/);

    if (rows.length === 0) return;

    const idsToUpdate = new Set<string>();
    
    setLocalUnits(prev => {
      const newUnits = [...prev];
      rows.forEach((value, i) => {
        const targetIndex = startIndex + i;
        if (targetIndex < newUnits.length) {
          const cleanValue = value.trim();
          newUnits[targetIndex] = {
            ...newUnits[targetIndex],
            [field]: cleanValue
          };
          idsToUpdate.add(newUnits[targetIndex].id);
        }
      });
      return newUnits;
    });

    setModifiedIds(prev => {
      const next = new Set(prev);
      idsToUpdate.forEach(id => next.add(id));
      return next;
    });
  };

  const handleFilePaste = async (e: React.ClipboardEvent, startIndex: number, field: keyof Unit = 'deed_file_url') => {
    e.preventDefault();
    const files = Array.from(e.clipboardData.files);
    
    if (files.length === 0) return;

    // Mark rows as uploading
    setUploadingRows(prev => {
        const next = { ...prev };
        files.forEach((_, i) => {
            const targetIndex = startIndex + i;
            if (targetIndex < localUnits.length) {
                // Use a composite key for loading state to support multiple file columns
                next[`${localUnits[targetIndex].id}_${field}`] = true;
            }
        });
        return next;
    });

    // Upload files
    // We process them one by one or in parallel. Parallel is better but let's be careful.
    const uploadPromises = files.map(async (file, i) => {
        const targetIndex = startIndex + i;
        if (targetIndex >= localUnits.length) return;

        const unit = localUnits[targetIndex];
        const loadingKey = `${unit.id}_${field}`;
        
        try {
            // Create a unique path: deeds/project_id/unit_id_filename
            // Using timestamp to avoid cache issues if re-uploaded
            const fileExt = file.name.split('.').pop();
            
            let prefix = 'deeds';
            if (field === 'sorting_record_file_url') prefix = 'sorting_records';
            else if (field === 'modifications_file_url') prefix = 'modifications';
            
            const fileName = `${prefix}/${unit.project_id}/${unit.id}_${Date.now()}.${fileExt}`;
            
            const { error: uploadError } = await supabase.storage
                .from('project-files')
                .upload(fileName, file, { upsert: true });

            if (uploadError) throw uploadError;

            const { data: { publicUrl } } = supabase.storage
                .from('project-files')
                .getPublicUrl(fileName);

            handleChange(unit.id, field, publicUrl);
        } catch (error) {
            console.error('Upload failed for unit ' + unit.unit_number, error);
            // Optionally set an error state for this row
        } finally {
            setUploadingRows(prev => {
                const next = { ...prev };
                delete next[loadingKey];
                return next;
            });
        }
    });

    await Promise.all(uploadPromises);
  };

  const triggerFileUpload = (unitId: string, field: keyof Unit, mode: 'file' | 'camera') => {
    setActiveUploadCell({ unitId, field });
    if (mode === 'camera' && cameraInputRef.current) {
      cameraInputRef.current.click();
    } else if (mode === 'file' && fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0 || !activeUploadCell) return;
    
    const fileList = Array.from(files);
    const { unitId, field } = activeUploadCell;
    const startIndex = localUnits.findIndex(u => u.id === unitId);
    
    if (startIndex === -1) return;
    
    // Reset input
    e.target.value = '';
    
    // Mark rows as uploading
    setUploadingRows(prev => {
        const next = { ...prev };
        fileList.forEach((_, i) => {
            const targetIndex = startIndex + i;
            if (targetIndex < localUnits.length) {
                const unit = localUnits[targetIndex];
                next[`${unit.id}_${field}`] = true;
            }
        });
        return next;
    });
    
    // Upload files
    const uploadPromises = fileList.map(async (file, i) => {
        const targetIndex = startIndex + i;
        if (targetIndex >= localUnits.length) return;

        const unit = localUnits[targetIndex];
        const loadingKey = `${unit.id}_${field}`;
        
        try {
            const fileExt = file.name.split('.').pop();
            
            let prefix = 'deeds';
            if (field === 'sorting_record_file_url') prefix = 'sorting_records';
            else if (field === 'modifications_file_url') prefix = 'modifications';
            
            const fileName = `${prefix}/${unit.project_id}/${unit.id}_${Date.now()}.${fileExt}`;
            
            const { error: uploadError } = await supabase.storage
                .from('project-files')
                .upload(fileName, file, { upsert: true });

            if (uploadError) throw uploadError;

            const { data: { publicUrl } } = supabase.storage
                .from('project-files')
                .getPublicUrl(fileName);

            handleChange(unit.id, field, publicUrl);
        } catch (error) {
            console.error('Upload failed', error);
        } finally {
            setUploadingRows(prev => {
                const next = { ...prev };
                delete next[loadingKey];
                return next;
            });
        }
    });

    try {
        await Promise.all(uploadPromises);
    } catch (error) {
        console.error('Some uploads failed', error);
        alert('حدث خطأ أثناء رفع بعض الملفات');
    } finally {
        setActiveUploadCell(null);
    }
  };

  const handleSave = async () => {
    if (modifiedIds.size === 0) {
      onCancel();
      return;
    }

    setLoading(true);
    try {
      const updates = localUnits.filter(u => modifiedIds.has(u.id)).map(u => ({
        id: u.id,
        project_id: u.project_id,
        unit_number: u.unit_number,
        floor_number: u.floor_number,
        type: u.type,
        floor_label: u.floor_label,
        direction_label: u.direction_label,
        electricity_meter: u.electricity_meter,
        deed_number: u.deed_number,
        client_name: u.client_name,
        title_deed_owner: u.title_deed_owner,
        title_deed_owner_id: u.title_deed_owner_id,
        title_deed_owner_phone: u.title_deed_owner_phone,
        status: u.status,
        client_id_number: u.client_id_number,
        client_phone: u.client_phone,
        deed_file_url: u.deed_file_url,
        sorting_record_file_url: u.sorting_record_file_url,
        modifications_file_url: u.modifications_file_url,
      }));

      const { error } = await supabase
        .from('units')
        .upsert(updates);

      if (error) throw error;

      alert('تم حفظ البيانات بنجاح');
      onUpdate();
    } catch (error: any) {
      console.error('Error saving units:', error);
      alert(`حدث خطأ أثناء الحفظ: ${error.message || 'خطأ غير معروف'}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden flex flex-col h-[calc(100vh-200px)]">
      {/* Toolbar */}
      <div className="p-4 border-b border-gray-200 flex justify-between items-center bg-gray-50">
        <div className="flex flex-col">
            <h3 className="font-bold text-gray-900">تعديل البيانات (وضع الإكسل)</h3>
            <p className="text-xs text-gray-500 mt-1">يمكنك نسخ ولصق النصوص، أو نسخ ملفات PDF ولصقها في عمود "ملف الصك"</p>
        </div>
        
        {selectedIds.size > 0 && (
          <div className="flex items-center gap-2 bg-blue-50 px-3 py-1 rounded-md border border-blue-100 mx-4">
            <span className="text-xs font-bold text-blue-800">{selectedIds.size} محدد</span>
            <select
              value={bulkStatus}
              onChange={(e) => setBulkStatus(e.target.value)}
              className="text-sm border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 p-1"
            >
              <option value="">اختر الحالة للتغيير...</option>
              <option value="available">غير مباعة</option>
              <option value="sold">مباعة</option>
              <option value="sold_to_other">مباعة لآخر</option>
              <option value="resale">إعادة بيع</option>
              <option value="pending_sale">قيد البيع</option>
            </select>
            <button
              onClick={handleBulkStatusUpdate}
              disabled={!bulkStatus}
              className="px-3 py-1 text-xs text-white bg-blue-600 rounded hover:bg-blue-700 disabled:opacity-50"
            >
              تطبيق
            </button>
          </div>
        )}

        <div className="flex gap-2">
          <button
            onClick={onCancel}
            className="px-4 py-2 text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 flex items-center gap-2"
          >
            <X size={16} />
            إلغاء
          </button>
          <button
            onClick={handleSave}
            disabled={loading}
            className="px-4 py-2 text-white bg-green-600 rounded-md hover:bg-green-700 flex items-center gap-2 disabled:opacity-50"
          >
            {loading ? (
              <span className="animate-spin w-4 h-4 border-2 border-white border-t-transparent rounded-full"></span>
            ) : (
              <Save size={16} />
            )}
            حفظ التغييرات
          </button>
        </div>
      </div>

      {/* Table Container */}
      <div className="flex-1 overflow-auto">
        <table className="w-full text-sm text-right border-collapse">
          <thead className="bg-gray-100 text-gray-900 sticky top-0 z-10 shadow-sm">
            <tr>
              <th className="p-3 border-b border-gray-300 w-10 text-center bg-gray-100">
                <input 
                  type="checkbox" 
                  checked={selectedIds.size === localUnits.length && localUnits.length > 0}
                  onChange={toggleSelectAll}
                  className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
              </th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold w-12 text-center bg-gray-100 cursor-pointer hover:bg-gray-200 transition-colors`}
                onClick={() => setActiveColumn(null)}
                title="إعادة تعيين العرض"
              >#</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-gray-100 cursor-pointer ${getColumnClass('unit_number', 'w-20')}`}
                onClick={() => handleColumnFocus('unit_number')}
              >رقم الوحدة</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-gray-100 cursor-pointer ${getColumnClass('floor_label', 'w-20')}`}
                onClick={() => handleColumnFocus('floor_label')}
              >الدور</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-gray-100 cursor-pointer ${getColumnClass('direction_label', 'w-28')}`}
                onClick={() => handleColumnFocus('direction_label')}
              >الاتجاه</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('deed_file_url', 'w-32')}`}
                onClick={() => handleColumnFocus('deed_file_url')}
              >ملف الصك</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('sorting_record_file_url', 'w-32')}`}
                onClick={() => handleColumnFocus('sorting_record_file_url')}
              >ملف محضر الفرز</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-orange-50 text-orange-900 cursor-pointer ${getColumnClass('modifications_file_url', 'w-32')}`}
                onClick={() => handleColumnFocus('modifications_file_url')}
              >تعديلات الشقق</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('electricity_meter', 'w-32')}`}
                onClick={() => handleColumnFocus('electricity_meter')}
              >رقم العداد</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('deed_number', 'w-32')}`}
                onClick={() => handleColumnFocus('deed_number')}
              >رقم الصك</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('client_name', 'w-40')}`}
                onClick={() => handleColumnFocus('client_name')}
              >اسم العميل</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('title_deed_owner', 'w-40')}`}
                onClick={() => handleColumnFocus('title_deed_owner')}
              >المفرغ له (المالك)</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('title_deed_owner_id', 'w-32')}`}
                onClick={() => handleColumnFocus('title_deed_owner_id')}
              >رقم هوية المفرغ له</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('title_deed_owner_phone', 'w-32')}`}
                onClick={() => handleColumnFocus('title_deed_owner_phone')}
              >جوال المفرغ له</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('status', 'w-32')}`}
                onClick={() => handleColumnFocus('status')}
              >حالة الوحدة</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('client_id_number', 'w-32')}`}
                onClick={() => handleColumnFocus('client_id_number')}
              >رقم الهوية</th>
              <th 
                className={`p-3 border-b border-gray-300 font-bold bg-blue-50 text-blue-900 cursor-pointer ${getColumnClass('client_phone', 'w-32')}`}
                onClick={() => handleColumnFocus('client_phone')}
              >رقم الجوال</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {localUnits.map((unit, index) => (
              <tr key={unit.id} className={`hover:bg-blue-50 transition-colors group ${selectedIds.has(unit.id) ? 'bg-blue-50' : ''}`}>
                <td className="p-2 border-r border-gray-200 text-center bg-gray-50">
                  <input 
                    type="checkbox" 
                    checked={selectedIds.has(unit.id)}
                    onChange={() => toggleSelection(unit.id)}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                </td>
                <td className="p-2 border-r border-gray-200 text-center text-gray-900 font-medium bg-gray-50" onClick={() => setActiveColumn(null)}>{index + 1}</td>
                <td 
                  className={`p-2 border-r border-gray-200 font-bold cursor-pointer ${!activeColumn ? 'text-black' : activeColumn === 'unit_number' ? 'text-black text-base' : 'text-gray-400 text-[10px]'} transition-all duration-300`}
                  onClick={() => handleColumnFocus('unit_number')}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span>{unit.unit_number}</span>
                    <a href={`/units/${unit.id}`} target="_blank" className="opacity-0 group-hover:opacity-100 text-blue-600 hover:text-blue-800 transition-opacity p-1" title="عرض التفاصيل">
                      <ExternalLink size={14} />
                    </a>
                  </div>
                </td>
                <td 
                  className={`p-2 border-r border-gray-200 cursor-pointer ${!activeColumn ? 'text-black' : activeColumn === 'floor_label' ? 'text-black text-base' : 'text-gray-400 text-[10px]'} transition-all duration-300`}
                  onClick={() => handleColumnFocus('floor_label')}
                >
                  {unit.floor_label}
                </td>
                <td 
                  className={`p-2 border-r border-gray-200 cursor-pointer truncate max-w-[150px] ${!activeColumn ? 'text-black text-xs' : activeColumn === 'direction_label' ? 'text-black text-base' : 'text-gray-400 text-[10px]'} transition-all duration-300`}
                  title={unit.direction_label}
                  onClick={() => handleColumnFocus('direction_label')}
                >
                  {unit.direction_label}
                </td>

                {/* File Upload Column: Deed File */}
                <td className="p-0 border-r border-gray-200 relative">
                    <div 
                        className={`w-full h-full min-h-[40px] flex items-center justify-center p-2 focus:bg-blue-100 outline-none cursor-pointer hover:bg-gray-50 ${!activeColumn ? '' : activeColumn === 'deed_file_url' ? '' : 'opacity-50 scale-90'} transition-all duration-300`}
                        tabIndex={0}
                        onPaste={(e) => handlePaste(e, index, 'deed_file_url')}
                        onFocus={() => handleColumnFocus('deed_file_url')}
                        onClick={() => handleColumnFocus('deed_file_url')}
                    >
                        {uploadingRows[`${unit.id}_deed_file_url`] ? (
                            <div className="flex items-center gap-1 text-blue-600 text-xs">
                                <Loader2 size={14} className="animate-spin" />
                                <span>جاري الرفع...</span>
                            </div>
                        ) : unit.deed_file_url ? (
                            <div className="flex items-center gap-2">
                                <a 
                                    href={unit.deed_file_url} 
                                    target="_blank" 
                                    rel="noopener noreferrer"
                                    className="text-blue-600 hover:text-blue-800 flex items-center gap-1 text-xs font-medium"
                                    onClick={(e) => e.stopPropagation()}
                                >
                                    <FileText size={14} />
                                    <span>عرض الملف</span>
                                </a>
                                <button 
                                    onClick={() => handleChange(unit.id, 'deed_file_url', null)}
                                    className="text-red-500 hover:text-red-700 p-1"
                                    title="حذف الملف"
                                >
                                    <X size={12} />
                                </button>
                            </div>
                        ) : (
                            <div 
                                className="text-gray-300 flex items-center justify-center p-2 rounded-full hover:bg-blue-50 hover:text-blue-600 transition-colors cursor-pointer"
                                onClick={(e) => { e.stopPropagation(); triggerFileUpload(unit.id, 'deed_file_url', 'file'); }}
                                title="انقر لرفع ملف"
                            >
                                <Upload size={14} />
                            </div>
                        )}
                    </div>
                </td>

                {/* File Upload Column: Sorting Record File */}
                <td className="p-0 border-r border-gray-200 relative">
                    <div 
                        className={`w-full h-full min-h-[40px] flex items-center justify-center p-2 focus:bg-blue-100 outline-none cursor-pointer hover:bg-gray-50 ${!activeColumn ? '' : activeColumn === 'sorting_record_file_url' ? '' : 'opacity-50 scale-90'} transition-all duration-300`}
                        tabIndex={0}
                        onPaste={(e) => handlePaste(e, index, 'sorting_record_file_url')}
                        onFocus={() => handleColumnFocus('sorting_record_file_url')}
                        onClick={() => handleColumnFocus('sorting_record_file_url')}
                    >
                        {uploadingRows[`${unit.id}_sorting_record_file_url`] ? (
                            <div className="flex items-center gap-1 text-blue-600 text-xs">
                                <Loader2 size={14} className="animate-spin" />
                                <span>جاري الرفع...</span>
                            </div>
                        ) : unit.sorting_record_file_url ? (
                            <div className="flex items-center gap-2">
                                <a 
                                    href={unit.sorting_record_file_url} 
                                    target="_blank" 
                                    rel="noopener noreferrer"
                                    className="text-blue-600 hover:text-blue-800 flex items-center gap-1 text-xs font-medium"
                                    onClick={(e) => e.stopPropagation()}
                                >
                                    <FileText size={14} />
                                    <span>عرض الملف</span>
                                </a>
                                <button 
                                    onClick={() => handleChange(unit.id, 'sorting_record_file_url', null)}
                                    className="text-red-500 hover:text-red-700 p-1"
                                    title="حذف الملف"
                                >
                                    <X size={12} />
                                </button>
                            </div>
                        ) : (
                            <div 
                                className="text-gray-300 flex items-center justify-center w-full h-full"
                                onClick={(e) => { e.stopPropagation(); triggerFileUpload(unit.id, 'sorting_record_file_url', 'file'); }}
                                title="انقر لرفع ملف"
                            >
                                <Upload size={14} />
                            </div>
                        )}
                    </div>
                </td>

                {/* File Upload Column: Modifications File */}
                <td className="p-0 border-r border-gray-200 relative">
                    <div 
                        className={`w-full h-full min-h-[40px] flex items-center justify-center p-2 focus:bg-orange-100 outline-none cursor-pointer hover:bg-gray-50 ${!activeColumn ? '' : activeColumn === 'modifications_file_url' ? '' : 'opacity-50 scale-90'} transition-all duration-300`}
                        tabIndex={0}
                        onPaste={(e) => handlePaste(e, index, 'modifications_file_url')}
                        onFocus={() => handleColumnFocus('modifications_file_url')}
                        onClick={() => handleColumnFocus('modifications_file_url')}
                    >
                        {uploadingRows[`${unit.id}_modifications_file_url`] ? (
                            <div className="flex items-center gap-1 text-orange-600 text-xs">
                                <Loader2 size={14} className="animate-spin" />
                                <span>جاري الرفع...</span>
                            </div>
                        ) : unit.modifications_file_url ? (
                            <div className="flex items-center gap-2">
                                <a 
                                    href={unit.modifications_file_url} 
                                    target="_blank" 
                                    rel="noopener noreferrer"
                                    className="text-orange-600 hover:text-orange-800 flex items-center gap-1 text-xs font-medium"
                                    onClick={(e) => e.stopPropagation()}
                                >
                                    <FileText size={14} />
                                    <span>عرض التعديل</span>
                                </a>
                                <button 
                                    onClick={() => handleChange(unit.id, 'modifications_file_url', null)}
                                    className="text-red-500 hover:text-red-700 p-1"
                                    title="حذف الملف"
                                >
                                    <X size={12} />
                                </button>
                            </div>
                        ) : (
                            <div className="flex gap-2">
                                <button
                                    onClick={(e) => { e.stopPropagation(); triggerFileUpload(unit.id, 'modifications_file_url', 'camera'); }}
                                    className="text-gray-400 hover:text-orange-600 p-1 rounded-full hover:bg-orange-50 transition-colors"
                                    title="تصوير بالكاميرا"
                                >
                                    <Camera size={16} />
                                </button>
                                <button
                                    onClick={(e) => { e.stopPropagation(); triggerFileUpload(unit.id, 'modifications_file_url', 'file'); }}
                                    className="text-gray-400 hover:text-blue-600 p-1 rounded-full hover:bg-blue-50 transition-colors"
                                    title="رفع ملف/صورة"
                                >
                                    <Upload size={16} />
                                </button>
                            </div>
                        )}
                    </div>
                </td>
                
                {/* Editable Fields with Paste Support */}
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.electricity_meter || ''}
                    onChange={(e) => handleChange(unit.id, 'electricity_meter', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'electricity_meter')}
                    onFocus={() => handleColumnFocus('electricity_meter')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'electricity_meter' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="-"
                  />
                </td>
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.deed_number || ''}
                    onChange={(e) => handleChange(unit.id, 'deed_number', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'deed_number')}
                    onFocus={() => handleColumnFocus('deed_number')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'deed_number' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="-"
                  />
                </td>
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.client_name || ''}
                    onChange={(e) => handleChange(unit.id, 'client_name', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'client_name')}
                    onFocus={() => handleColumnFocus('client_name')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'client_name' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="اسم العميل"
                  />
                </td>
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.title_deed_owner || ''}
                    onChange={(e) => handleChange(unit.id, 'title_deed_owner', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'title_deed_owner')}
                    onFocus={() => handleColumnFocus('title_deed_owner')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'title_deed_owner' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="المالك"
                  />
                </td>
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.title_deed_owner_id || ''}
                    onChange={(e) => handleChange(unit.id, 'title_deed_owner_id', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'title_deed_owner_id')}
                    onFocus={() => handleColumnFocus('title_deed_owner_id')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'title_deed_owner_id' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="رقم الهوية"
                  />
                </td>
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.title_deed_owner_phone || ''}
                    onChange={(e) => handleChange(unit.id, 'title_deed_owner_phone', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'title_deed_owner_phone')}
                    onFocus={() => handleColumnFocus('title_deed_owner_phone')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'title_deed_owner_phone' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="جوال المفرغ له"
                  />
                </td>
                <td className="p-0 border-r border-gray-200">
                  <select
                    value={unit.status || 'available'}
                    onChange={(e) => handleChange(unit.id, 'status', e.target.value)}
                    onFocus={() => handleColumnFocus('status')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 cursor-pointer font-bold transition-all duration-300
                      ${!activeColumn ? 'text-xs' : activeColumn === 'status' ? 'text-base' : 'text-[10px]'}
                      ${unit.status === 'available' ? 'text-green-600' : 
                        unit.status === 'sold' ? 'text-red-600' : 
                        unit.status === 'sold_to_other' ? 'text-gray-600' :
                        unit.status === 'resale' ? 'text-purple-600' :
                        unit.status === 'pending_sale' ? 'text-orange-600' :
                        'text-gray-600'}
                    `}
                  >
                    <option value="available" className="text-green-600">غير مباعة</option>
                    <option value="sold" className="text-red-600">مباعة</option>
                    <option value="sold_to_other" className="text-gray-600">مباعة لآخر</option>
                    <option value="resale" className="text-purple-600">إعادة بيع</option>
                    <option value="pending_sale" className="text-orange-600">قيد البيع</option>
                  </select>
                </td>
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.client_id_number || ''}
                    onChange={(e) => handleChange(unit.id, 'client_id_number', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'client_id_number')}
                    onFocus={() => handleColumnFocus('client_id_number')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'client_id_number' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="رقم الهوية"
                  />
                </td>
                <td className="p-0 border-r border-gray-200">
                  <input
                    type="text"
                    value={unit.client_phone || ''}
                    onChange={(e) => handleChange(unit.id, 'client_phone', e.target.value)}
                    onPaste={(e) => handlePaste(e, index, 'client_phone')}
                    onFocus={() => handleColumnFocus('client_phone')}
                    className={`w-full h-full p-2 border-0 outline-none bg-transparent focus:bg-white focus:ring-2 focus:ring-inset focus:ring-blue-500 font-medium placeholder-gray-400 transition-all duration-300 ${!activeColumn ? 'text-black' : activeColumn === 'client_phone' ? 'text-black text-base' : 'text-gray-400 text-[10px]'}`}
                    placeholder="05xxxxxxxx"
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        
        <div className="p-6 bg-gray-50 border-t border-gray-200">
          {/* ProjectPlansManager removed from here */}
        </div>
      </div>
      
      {/* Hidden File Inputs */}
      <input
        type="file"
        ref={fileInputRef}
        className="hidden"
        onChange={handleFileSelect}
        accept=".pdf,image/*"
        multiple
      />
      <input
        type="file"
        ref={cameraInputRef}
        className="hidden"
        onChange={handleFileSelect}
        accept="image/*"
        capture="environment"
      />
    </div>
  );
}
