import React, { useState } from 'react';
import { 
  X, 
  Copy, 
  Check, 
  FileText, 
  CheckSquare, 
  Square,
  LayoutGrid
} from 'lucide-react';
import { EnrichedUnit } from './DeedsTable';

interface ReportCopyModalProps {
  isOpen: boolean;
  onClose: () => void;
  units: EnrichedUnit[];
  filterProject?: string;
  filterStatus?: string;
}

interface FieldOption {
  id: string;
  label: string;
  defaultChecked: boolean;
}

const FIELD_OPTIONS: FieldOption[] = [
  { id: 'unit_info', label: 'رقم الوحدة والمشروع', defaultChecked: true },
  { id: 'floor', label: 'الدور', defaultChecked: true },
  { id: 'original_client', label: 'اسم العميل الأصلي', defaultChecked: true },
  { id: 'client_phone', label: 'رقم جوال العميل', defaultChecked: true },
  { id: 'current_client', label: 'اسم العميل الحالي (المفرغ له)', defaultChecked: true },
  { id: 'phone', label: 'رقم الجوال (الحالي)', defaultChecked: false },
  { id: 'deed_number', label: 'رقم الصك', defaultChecked: true },
  { id: 'resale_amount', label: 'مبلغ إعادة البيع', defaultChecked: false },
  { id: 'status', label: 'الحالة', defaultChecked: false },
];

export default function ReportCopyModal({ isOpen, onClose, units, filterProject, filterStatus }: ReportCopyModalProps) {
  const [selectedFields, setSelectedFields] = useState<Record<string, boolean>>(
    FIELD_OPTIONS.reduce((acc, field) => ({ ...acc, [field.id]: field.defaultChecked }), {})
  );
  const [groupByProject, setGroupByProject] = useState(true);
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const toggleField = (fieldId: string) => {
    setSelectedFields(prev => ({
      ...prev,
      [fieldId]: !prev[fieldId]
    }));
  };

  const handleCopy = () => {
    if (units.length === 0) return;

    let header = `*تقرير مراجعة الصكوك - ${new Date().toLocaleDateString('ar-SA')}*\n`;
    if (filterProject) header += `📁 *المشروع:* ${filterProject}\n`;
    if (filterStatus) header += `📍 *الحالة:* ${filterStatus}\n`;
    header += `\n`;
    
    let content = '';

    if (groupByProject) {
      // Group units by project
      const projects: Record<string, EnrichedUnit[]> = {};
      units.forEach(unit => {
        const projectName = unit.project_name;
        if (!projects[projectName]) projects[projectName] = [];
        projects[projectName].push(unit);
      });

      Object.entries(projects).forEach(([projectName, projectUnits]) => {
        content += `🏢 *مشروع: ${projectName}*\n`;
        content += `━━━━━━━━━━━━━━━━━━━\n\n`;
        
        content += projectUnits.map(unit => generateUnitText(unit)).join('\n-------------------\n\n');
        content += `\n\n`;
      });
    } else {
      content = units.map(unit => generateUnitText(unit)).join('\n-------------------\n\n');
    }

    const fullText = header + content;
    
    navigator.clipboard.writeText(fullText).then(() => {
      setCopied(true);
      setTimeout(() => {
        setCopied(false);
        onClose();
      }, 2000);
    }).catch(err => {
      console.error('Failed to copy: ', err);
      alert('حدث خطأ أثناء النسخ');
    });
  };

  const generateUnitText = (unit: EnrichedUnit) => {
    let msg = '';
    
    if (selectedFields.unit_info) {
      msg += `🏠 *الوحدة:* ${unit.unit_number} - ${unit.project_name} (${unit.project_number})\n`;
    }
    
    if (selectedFields.floor) {
      msg += `🏢 *الدور:* ${unit.floor_label || unit.floor_number || '-'}\n`;
    }
    
    if (selectedFields.original_client) {
      msg += `👤 *العميل الأصلي:* ${unit.client_name || '-'}\n`;
    }

    if (selectedFields.client_phone) {
      msg += `📞 *جوال العميل:* ${unit.client_phone || '-'}\n`;
    }
    
    if (selectedFields.current_client) {
      msg += `👤 *العميل الحالي:* ${unit.title_deed_owner || '-'}\n`;
    }
    
    if (selectedFields.phone) {
      msg += `📞 *جوال المالك الحالي:* ${unit.title_deed_owner_phone || '-'}\n`;
    }
    
    if (selectedFields.deed_number) {
      msg += `📄 *رقم الصك:* ${unit.deed_number || '-'}\n`;
    }

    if (selectedFields.resale_amount && unit.resale_agreed_amount) {
      msg += `💰 *إعادة بيع:* ${unit.resale_agreed_amount.toLocaleString('ar-SA')} ريال\n`;
    }

    if (selectedFields.status) {
      msg += `📍 *الحالة:* ${unit.status}\n`;
    }

    return msg.trim();
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md max-h-[90vh] flex flex-col animate-in fade-in zoom-in duration-200">
        {/* Header */}
        <div className="p-4 border-b border-gray-100 flex items-center justify-between bg-gray-50 rounded-t-2xl">
          <h3 className="font-display font-bold text-lg text-gray-900 flex items-center gap-2">
            <FileText size={20} className="text-blue-600" />
            تحديد بيانات التقرير للنسخ
          </h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-200 rounded-lg transition-colors">
            <X size={20} className="text-gray-500" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-4 overflow-y-auto">
          {/* Sorting Option */}
          <div className="mb-6 p-4 bg-blue-50/50 rounded-2xl border border-blue-100">
            <label className="flex items-center justify-between cursor-pointer">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-blue-100 rounded-lg text-blue-600">
                  <LayoutGrid size={18} />
                </div>
                <div>
                  <p className="font-bold text-sm text-gray-900">ترتيب وفصل بحسب المشروع</p>
                  <p className="text-xs text-gray-500">سيتم تجميع الوحدات تحت اسم كل مشروع</p>
                </div>
              </div>
              <button
                onClick={() => setGroupByProject(!groupByProject)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${groupByProject ? 'bg-blue-600' : 'bg-gray-200'}`}
              >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${groupByProject ? 'translate-x-6' : 'translate-x-1'}`} />
              </button>
            </label>
          </div>

          <p className="text-sm text-gray-500 mb-2">
            اختر الحقول التي ترغب في تضمينها:
          </p>
          
          <div className="grid grid-cols-1 gap-2">
            {FIELD_OPTIONS.map((field) => (
              <button
                key={field.id}
                onClick={() => toggleField(field.id)}
                className={`flex items-center justify-between p-3 rounded-xl border transition-all ${
                  selectedFields[field.id] 
                    ? 'border-blue-200 bg-blue-50 text-blue-700' 
                    : 'border-gray-100 bg-white text-gray-600 hover:border-gray-200'
                }`}
              >
                <span className="font-bold text-sm">{field.label}</span>
                {selectedFields[field.id] ? (
                  <CheckSquare size={18} className="text-blue-600" />
                ) : (
                  <Square size={18} className="text-gray-300" />
                )}
              </button>
            ))}
          </div>

          <div className="pt-4 border-t border-gray-100 mt-6">
            <div className="bg-blue-50 p-3 rounded-xl mb-4 text-xs text-blue-700 flex items-start gap-2">
              <div className="mt-0.5">ℹ️</div>
              <p>سيتم نسخ بيانات ({units.length}) وحدة بناءً على خياراتك.</p>
            </div>

            <button
              onClick={handleCopy}
              disabled={copied || Object.values(selectedFields).every(v => !v)}
              className={`w-full flex items-center justify-center gap-2 py-3 rounded-xl font-bold transition-all shadow-md ${
                copied 
                  ? 'bg-green-500 text-white' 
                  : 'bg-blue-600 text-white hover:bg-blue-700'
              } disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              {copied ? (
                <>
                  <Check size={20} />
                  تم النسخ بنجاح!
                </>
              ) : (
                <>
                  <Copy size={20} />
                  نسخ التقرير المخصص
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
