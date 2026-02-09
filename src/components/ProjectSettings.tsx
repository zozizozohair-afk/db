import React, { useState } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Project } from '../types';
import { Save, Plus, Trash2, Calendar, Zap, Droplets } from 'lucide-react';

interface ProjectSettingsProps {
  project: Project;
  onUpdate: () => void;
}

export default function ProjectSettings({ project, onUpdate }: ProjectSettingsProps) {
  const [loading, setLoading] = useState(false);
  const [waterMeter, setWaterMeter] = useState(project.water_meter || '');
  const [elecMeters, setElecMeters] = useState<string[]>(
    project.electricity_meters && project.electricity_meters.length > 0 
      ? project.electricity_meters 
      : (project.electricity_meter ? [project.electricity_meter] : [''])
  );
  const [hoaStart, setHoaStart] = useState(project.hoa_start_date || '');
  const [hoaEnd, setHoaEnd] = useState(project.hoa_end_date || '');

  const handleAddMeter = () => {
    setElecMeters([...elecMeters, '']);
  };

  const handleRemoveMeter = (index: number) => {
    const newMeters = elecMeters.filter((_, i) => i !== index);
    setElecMeters(newMeters.length ? newMeters : ['']);
  };

  const handleMeterChange = (index: number, value: string) => {
    const newMeters = [...elecMeters];
    newMeters[index] = value;
    setElecMeters(newMeters);
  };

  const handleSave = async () => {
    setLoading(true);
    try {
      const cleanMeters = elecMeters.filter(m => m.trim() !== '');
      
      const { error } = await supabase
        .from('projects')
        .update({
          water_meter: waterMeter,
          electricity_meters: cleanMeters,
          hoa_start_date: hoaStart || null,
          hoa_end_date: hoaEnd || null
        })
        .eq('id', project.id);

      if (error) throw error;
      onUpdate();
      alert('تم حفظ التغييرات بنجاح');
    } catch (error) {
      console.error('Error updating project:', error);
      alert('حدث خطأ أثناء الحفظ');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100 mb-6">
      <h3 className="text-lg font-bold text-gray-800 mb-4 flex items-center gap-2">
        <SettingsIcon className="w-5 h-5 text-blue-600" />
        إعدادات المشروع والخدمات
      </h3>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Utilities Section */}
        <div className="space-y-4">
          <h4 className="font-semibold text-gray-700 border-b pb-2">العدادات والخدمات</h4>
          
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1 flex items-center gap-2">
              <Droplets className="w-4 h-4" />
              رقم عداد المياه للمشروع
            </label>
            <input
              type="text"
              value={waterMeter}
              onChange={(e) => setWaterMeter(e.target.value)}
              className="w-full border rounded-md p-2 focus:ring-2 focus:ring-blue-500 outline-none"
              placeholder="مثال: 12345678"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1 flex items-center gap-2">
              <Zap className="w-4 h-4" />
              أرقام عدادات الكهرباء
            </label>
            {elecMeters.map((meter, index) => (
              <div key={index} className="flex gap-2 mb-2">
                <input
                  type="text"
                  value={meter}
                  onChange={(e) => handleMeterChange(index, e.target.value)}
                  className="flex-1 border rounded-md p-2 focus:ring-2 focus:ring-blue-500 outline-none"
                  placeholder={`عداد كهرباء ${index + 1}`}
                />
                <button
                  onClick={() => handleRemoveMeter(index)}
                  className="text-red-500 hover:bg-red-50 p-2 rounded-md transition-colors"
                  title="حذف"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
            <button
              onClick={handleAddMeter}
              className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1 mt-1"
            >
              <Plus className="w-4 h-4" />
              إضافة عداد كهرباء آخر
            </button>
          </div>
        </div>

        {/* Dates Section */}
        <div className="space-y-4">
          <h4 className="font-semibold text-gray-700 border-b pb-2">اتحاد الملاك والتواريخ</h4>
          
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1 flex items-center gap-2">
              <Calendar className="w-4 h-4" />
              تاريخ بداية اتحاد الملاك
            </label>
            <input
              type="date"
              value={hoaStart}
              onChange={(e) => setHoaStart(e.target.value)}
              className="w-full border rounded-md p-2 focus:ring-2 focus:ring-blue-500 outline-none"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1 flex items-center gap-2">
              <Calendar className="w-4 h-4" />
              تاريخ نهاية اتحاد الملاك
            </label>
            <input
              type="date"
              value={hoaEnd}
              onChange={(e) => setHoaEnd(e.target.value)}
              className="w-full border rounded-md p-2 focus:ring-2 focus:ring-blue-500 outline-none"
            />
          </div>
        </div>
      </div>

      <div className="mt-6 flex justify-end">
        <button
          onClick={handleSave}
          disabled={loading}
          className="bg-blue-600 text-white px-6 py-2 rounded-md hover:bg-blue-700 flex items-center gap-2 disabled:opacity-50 transition-colors"
        >
          <Save className="w-4 h-4" />
          {loading ? 'جاري الحفظ...' : 'حفظ التغييرات'}
        </button>
      </div>
    </div>
  );
}

function SettingsIcon({ className }: { className?: string }) {
  return (
    <svg 
      xmlns="http://www.w3.org/2000/svg" 
      width="24" 
      height="24" 
      viewBox="0 0 24 24" 
      fill="none" 
      stroke="currentColor" 
      strokeWidth="2" 
      strokeLinecap="round" 
      strokeLinejoin="round" 
      className={className}
    >
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.09a2 2 0 0 1-1-1.74v-.47a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.39a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"></path>
      <circle cx="12" cy="12" r="3"></circle>
    </svg>
  );
}
