import React from 'react';
import { 
  User, 
  MessageCircle 
} from 'lucide-react';
import { Unit } from '../types';

export interface EnrichedUnit extends Unit {
  project_name: string;
  project_number: string;
}

interface DeedsTableProps {
  units: EnrichedUnit[];
  loading: boolean;
  onMessageClick: (unit: EnrichedUnit) => void;
  onStatusChange?: (unitId: string, newStatus: string) => Promise<void>;
}

const statusMap: Record<string, { label: string, color: string }> = {
  'available': { label: 'غير مفرغة', color: 'bg-green-100 text-green-700' },
  'sold': { label: 'مباعة', color: 'bg-red-100 text-red-700' },
  'pending_sale': { label: 'قيد البيع', color: 'bg-orange-100 text-orange-700' },
  'for_resale': { label: 'إعادة بيع', color: 'bg-purple-100 text-purple-700' },
  'sold_to_other': { label: 'مباعة لآخر', color: 'bg-gray-100 text-gray-700' },
};

export default function DeedsTable({ units, loading, onMessageClick, onStatusChange }: DeedsTableProps) {
  const [updatingId, setUpdatingId] = React.useState<string | null>(null);

  const handleStatusUpdate = async (e: React.ChangeEvent<HTMLSelectElement>, unitId: string) => {
    const newStatus = e.target.value;
    if (onStatusChange) {
      setUpdatingId(unitId);
      try {
        await onStatusChange(unitId, newStatus);
      } finally {
        setUpdatingId(null);
      }
    }
  };
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50 border-b border-gray-100">
            <tr>
              <th className="px-6 py-4 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">الوحدة</th>
              <th className="px-6 py-4 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">المشروع</th>
              <th className="px-6 py-4 text-right text-xs font-display font-bold text-gray-500 uppercase tracking-wider">المالك الحالي</th>
              <th className="px-6 py-4 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">الحالة</th>
              <th className="px-6 py-4 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">رقم الصك</th>
              <th className="px-6 py-4 text-center text-xs font-display font-bold text-gray-500 uppercase tracking-wider">إجراءات</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr>
                <td colSpan={6} className="p-8 text-center text-gray-500">جاري التحميل...</td>
              </tr>
            ) : units.length === 0 ? (
              <tr>
                <td colSpan={6} className="p-8 text-center text-gray-500">لا توجد وحدات مطابقة</td>
              </tr>
            ) : (
              units.map((unit) => (
                <tr 
                  key={unit.id} 
                  className="hover:bg-gray-50/50 transition-colors cursor-pointer"
                  onClick={() => onMessageClick(unit)}
                >
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-blue-50 rounded-lg flex items-center justify-center text-blue-700 font-display font-bold border border-blue-100">
                        {unit.unit_number}
                      </div>
                      <div className="flex flex-col">
                        <span className="text-sm font-bold text-gray-900">الدور {unit.floor_number}</span>
                        {unit.resale_agreed_amount && (
                          <span className="text-[10px] bg-purple-50 text-purple-600 px-1.5 py-0.5 rounded border border-purple-100 font-bold">
                            إعادة بيع: {unit.resale_agreed_amount.toLocaleString()} ر.س
                          </span>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex flex-col">
                      <span className="font-bold text-gray-900">{unit.project_name}</span>
                      <span className="text-xs text-gray-500">{unit.project_number}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex flex-col">
                      <div className="flex items-center gap-2">
                        <User size={14} className={unit.title_deed_owner ? "text-indigo-500" : "text-gray-400"} />
                        <span className={`text-sm font-bold ${unit.title_deed_owner ? "text-indigo-900" : "text-gray-900"}`}>
                          {unit.title_deed_owner || unit.client_name || '-'}
                        </span>
                      </div>
                      {(unit.client_phone || unit.title_deed_owner_phone) && (
                        <span className="text-xs text-gray-500 mr-5">
                          {unit.title_deed_owner_phone || unit.client_phone}
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    <div className="relative inline-block" onClick={(e) => e.stopPropagation()}>
                      <select
                        value={unit.status}
                        disabled={updatingId === unit.id}
                        onChange={(e) => handleStatusUpdate(e, unit.id)}
                        className={`
                          appearance-none px-3 py-1 pr-8 rounded-full text-xs font-display font-bold border-none cursor-pointer outline-none transition-all
                          ${statusMap[unit.status]?.color || 'bg-gray-100 text-gray-600'}
                          ${updatingId === unit.id ? 'opacity-50' : 'hover:brightness-95'}
                        `}
                      >
                        {Object.entries(statusMap).map(([value, info]) => (
                          <option key={value} value={value} className="bg-white text-gray-900">
                            {info.label}
                          </option>
                        ))}
                      </select>
                      <div className="absolute left-2 top-1/2 -translate-y-1/2 pointer-events-none opacity-50">
                        <svg className="w-3 h-3 fill-current" viewBox="0 0 20 20">
                          <path d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" />
                        </svg>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center font-mono text-sm text-gray-600">
                    {unit.deed_number || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    <button
                      onClick={(e) => { e.stopPropagation(); onMessageClick(unit); }}
                      className="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-50 text-blue-600 hover:bg-blue-100 transition-colors"
                      title="إرسال رسالة"
                    >
                      <MessageCircle size={18} />
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
