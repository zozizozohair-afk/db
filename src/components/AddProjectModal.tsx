'use client';

import React, { useState, useEffect } from 'react';
import { X, Plus, Save, RefreshCw, ArrowRight, Check, Loader2 } from 'lucide-react';
import { generateUnitsLogic, GeneratedUnit } from '../utils/projectLogic';
import { supabase } from '../lib/supabaseClient';

interface AddProjectModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave?: (projectData: any) => void;
  onSuccess?: () => void;
}

export default function AddProjectModal({ isOpen, onClose, onSave, onSuccess }: AddProjectModalProps) {
  // --- State ---
  const [step, setStep] = useState(1); // 1: Info, 2: Custom Dirs (if needed), 3: Preview
  const [isSaving, setIsSaving] = useState(false);
  
  // Basic Info
  const [projectName, setProjectName] = useState('');
  const [deedNumber, setDeedNumber] = useState('');
  const [projectNumber, setProjectNumber] = useState('');
  const [orientation, setOrientation] = useState<'North' | 'South' | 'East' | 'West'>('North');
  
  // Structure Info
  const [floorsCount, setFloorsCount] = useState(1);
  const [unitsPerFloor, setUnitsPerFloor] = useState(4);
  const [hasAnnex, setHasAnnex] = useState(false);
  const [annexCount, setAnnexCount] = useState(1); // 1 or 2

  // Custom Directions (for non-4 units)
  const [customDirections, setCustomDirections] = useState<string[]>([]);

  // Generated Units Preview
  const [generatedUnits, setGeneratedUnits] = useState<GeneratedUnit[]>([]);

  // --- Effects ---

  // Initialize custom directions array when unitsPerFloor changes
  useEffect(() => {
    if (unitsPerFloor !== 4) {
      setCustomDirections(new Array(unitsPerFloor).fill(''));
    }
  }, [unitsPerFloor]);

  // --- Handlers ---

  const handleNext = () => {
    if (step === 1) {
      if (!projectName) {
        alert('الرجاء إدخال اسم المشروع');
        return;
      }
      if (unitsPerFloor !== 4) {
        setStep(2); // Go to custom directions
      } else {
        generateAndPreview();
        setStep(3); // Go directly to preview
      }
    } else if (step === 2) {
      generateAndPreview();
      setStep(3);
    }
  };

  const generateAndPreview = () => {
    const units = generateUnitsLogic(
      orientation,
      Number(floorsCount),
      Number(unitsPerFloor),
      hasAnnex,
      Number(annexCount),
      customDirections
    );
    setGeneratedUnits(units);
  };

  const handleCustomDirectionChange = (index: number, value: string) => {
    const newDirs = [...customDirections];
    newDirs[index] = value;
    setCustomDirections(newDirs);
  };

  const handleSave = async () => {
    try {
      setIsSaving(true);
      
      // 1. Insert Project
      const { data: projectData, error: projectError } = await supabase
        .from('projects')
        .insert({
          name: projectName,
          project_number: projectNumber,
          deed_number: deedNumber,
          orientation: orientation,
          floors_count: floorsCount,
          units_per_floor: unitsPerFloor,
          has_annex: hasAnnex,
          annex_count: annexCount,
          status: 'under_construction' // Default status
        })
        .select()
        .single();

      if (projectError) throw projectError;
      if (!projectData) throw new Error('Failed to create project');

      const projectId = projectData.id;

      // 2. Prepare Units
      const unitsToInsert = generatedUnits.map(unit => ({
        project_id: projectId,
        unit_number: unit.unitNumber,
        floor_number: unit.floorNumber,
        floor_label: unit.floorLabel,
        direction_label: unit.directionLabel,
        type: unit.type,
        status: 'available' // Default status
      }));

      // 3. Insert Units
      const { error: unitsError } = await supabase
        .from('units')
        .insert(unitsToInsert);

      if (unitsError) throw unitsError;

      // Success
      if (onSuccess) onSuccess();
      if (onSave) onSave(projectData);
      
      // Reset and close
      resetForm();
      onClose();

    } catch (error: any) {
      console.error('Error saving project:', error);
      alert('حدث خطأ أثناء حفظ المشروع: ' + (error.message || 'خطأ غير معروف'));
    } finally {
      setIsSaving(false);
    }
  };

  const resetForm = () => {
    setStep(1);
    setProjectName('');
    setProjectNumber('');
    setDeedNumber('');
    setOrientation('North');
    setFloorsCount(1);
    setUnitsPerFloor(4);
    setHasAnnex(false);
    setAnnexCount(1);
    setCustomDirections([]);
    setGeneratedUnits([]);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col overflow-hidden">
        
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between bg-gray-50">
          <h2 className="text-xl font-bold text-gray-800">إضافة مشروع جديد</h2>
          <button onClick={onClose} className="p-2 hover:bg-gray-200 rounded-full text-gray-500 transition-colors">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-6">
          
          {/* Steps Indicator */}
          <div className="flex items-center justify-center mb-8">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${step >= 1 ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-500'}`}>1</div>
            <div className={`w-16 h-1 bg-gray-200 ${step >= 2 ? 'bg-blue-600' : ''}`}></div>
            {unitsPerFloor !== 4 && (
              <>
                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${step >= 2 ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-500'}`}>2</div>
                <div className={`w-16 h-1 bg-gray-200 ${step >= 3 ? 'bg-blue-600' : ''}`}></div>
              </>
            )}
            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${step === 3 ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-500'}`}>{unitsPerFloor !== 4 ? 3 : 2}</div>
          </div>

          {/* STEP 1: Basic Information */}
          {step === 1 && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                
                {/* Project Name */}
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">اسم المشروع <span className="text-red-500">*</span></label>
                  <input 
                    type="text" 
                    value={projectName}
                    onChange={(e) => setProjectName(e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="مثال: أبراج العليا"
                  />
                </div>

                {/* Project Number */}
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">رقم المشروع</label>
                  <input 
                    type="text" 
                    value={projectNumber}
                    onChange={(e) => setProjectNumber(e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="رقم المشروع"
                  />
                </div>

                {/* Deed Number */}
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">رقم الصك</label>
                  <input 
                    type="text" 
                    value={deedNumber}
                    onChange={(e) => setDeedNumber(e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="رقم الصك الإلكتروني"
                  />
                </div>

                {/* Orientation - CRITICAL */}
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">اتجاه المشروع (الواجهة الرئيسية)</label>
                  <select 
                    value={orientation}
                    onChange={(e) => setOrientation(e.target.value as any)}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                  >
                    <option value="North">شمال</option>
                    <option value="South">جنوب</option>
                    <option value="East">شرق</option>
                    <option value="West">غرب</option>
                  </select>
                </div>

                {/* Floors Count */}
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">عدد الأدوار</label>
                  <input 
                    type="number" 
                    min="1"
                    value={floorsCount}
                    onChange={(e) => setFloorsCount(Number(e.target.value))}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                  />
                </div>

                {/* Units Per Floor */}
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">عدد الوحدات في الدور</label>
                  <input 
                    type="number" 
                    min="1"
                    value={unitsPerFloor}
                    onChange={(e) => setUnitsPerFloor(Number(e.target.value))}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                  />
                  <p className="text-xs text-gray-500">
                    {unitsPerFloor === 4 
                      ? "سيتم تسمية الاتجاهات تلقائياً حسب النظام (4 شقق)." 
                      : "سيطلب منك تحديد اتجاهات الوحدات يدوياً في الخطوة التالية."}
                  </p>
                </div>
              </div>

              {/* Annex Section */}
              <div className="bg-blue-50 p-4 rounded-xl border border-blue-100">
                <div className="flex items-center gap-3 mb-4">
                  <input 
                    type="checkbox" 
                    id="hasAnnex"
                    checked={hasAnnex}
                    onChange={(e) => setHasAnnex(e.target.checked)}
                    className="w-5 h-5 text-blue-600 rounded focus:ring-blue-500"
                  />
                  <label htmlFor="hasAnnex" className="font-bold text-gray-800">هل يوجد ملحق؟</label>
                </div>

                {hasAnnex && (
                  <div className="mr-8 space-y-2">
                    <label className="block text-sm font-medium text-gray-700">عدد الملاحق</label>
                    <div className="flex gap-4">
                      <label className="flex items-center gap-2 cursor-pointer bg-white px-4 py-2 rounded-lg border border-gray-200 hover:border-blue-500 transition-colors">
                        <input 
                          type="radio" 
                          name="annexCount" 
                          value="1" 
                          checked={annexCount === 1}
                          onChange={() => setAnnexCount(1)}
                          className="text-blue-600"
                        />
                        <span>1 ملحق</span>
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer bg-white px-4 py-2 rounded-lg border border-gray-200 hover:border-blue-500 transition-colors">
                        <input 
                          type="radio" 
                          name="annexCount" 
                          value="2" 
                          checked={annexCount === 2}
                          onChange={() => setAnnexCount(2)}
                          className="text-blue-600"
                        />
                        <span>2 ملاحق</span>
                      </label>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* STEP 2: Custom Directions (Only if unitsPerFloor != 4) */}
          {step === 2 && unitsPerFloor !== 4 && (
            <div className="space-y-6">
              <div className="bg-yellow-50 p-4 rounded-lg border border-yellow-100 text-yellow-800 text-sm mb-4">
                بما أن عدد الوحدات ليس 4، يرجى تحديد اتجاهات الوحدات للدور الواحد، وسيتم تكرارها لجميع الأدوار.
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {customDirections.map((dir, idx) => (
                  <div key={idx} className="space-y-2">
                    <label className="block text-sm font-medium text-gray-700">
                      اتجاه الوحدة رقم {idx + 1}
                    </label>
                    <input 
                      type="text" 
                      value={dir}
                      onChange={(e) => handleCustomDirectionChange(idx, e.target.value)}
                      placeholder={`مثال: شمالية شرقية`}
                      className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* STEP 3: Preview */}
          {step === 3 && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-bold text-gray-900">معاينة الوحدات التي سيتم توليدها</h3>
                <div className="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm font-bold">
                  العدد الكلي: {generatedUnits.length} وحدة
                </div>
              </div>

              <div className="border border-gray-200 rounded-lg overflow-hidden max-h-[400px] overflow-y-auto">
                <table className="w-full text-right">
                  <thead className="bg-gray-50 text-gray-500 text-sm sticky top-0">
                    <tr>
                      <th className="px-6 py-3 font-medium">رقم الوحدة</th>
                      <th className="px-6 py-3 font-medium">الدور</th>
                      <th className="px-6 py-3 font-medium">الاتجاه / الوصف</th>
                      <th className="px-6 py-3 font-medium">النوع</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {generatedUnits.map((unit) => (
                      <tr key={unit.unitNumber} className="hover:bg-gray-50">
                        <td className="px-6 py-3 font-mono font-bold text-blue-600">#{unit.unitNumber}</td>
                        <td className="px-6 py-3">{unit.floorLabel}</td>
                        <td className="px-6 py-3 font-medium">{unit.directionLabel}</td>
                        <td className="px-6 py-3">
                          <span className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium ${
                            unit.type === 'annex' ? 'bg-purple-100 text-purple-700' : 'bg-green-100 text-green-700'
                          }`}>
                            {unit.type === 'annex' ? 'ملحق' : 'شقة سكنية'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

        </div>

        {/* Footer */}
        <div className="p-6 border-t border-gray-100 bg-gray-50 flex items-center justify-between">
          <button 
            onClick={() => step > 1 ? setStep(step - 1) : onClose()}
            className="px-6 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-100 font-medium transition-colors"
            disabled={isSaving}
          >
            {step > 1 ? 'رجوع' : 'إلغاء'}
          </button>

          {step === 3 ? (
            <button 
              onClick={handleSave}
              disabled={isSaving}
              className={`px-6 py-2 rounded-lg text-white font-bold flex items-center gap-2 shadow-sm transition-colors ${
                isSaving ? 'bg-green-400 cursor-not-allowed' : 'bg-green-600 hover:bg-green-700'
              }`}
            >
              {isSaving ? (
                <>
                  <Loader2 size={18} className="animate-spin" />
                  جاري الحفظ...
                </>
              ) : (
                <>
                  <Save size={18} />
                  حفظ المشروع والوحدات
                </>
              )}
            </button>
          ) : (
            <button 
              onClick={handleNext}
              className="px-6 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 font-bold flex items-center gap-2 shadow-sm transition-colors"
            >
              التالي
              <ArrowRight size={18} />
            </button>
          )}
        </div>

      </div>
    </div>
  );
}
