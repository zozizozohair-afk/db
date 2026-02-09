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
}

const statusMap: Record<string, { label: string, color: string }> = {
  'available': { label: 'متاح', color: 'bg-green-100 text-green-700' },
  'sold': { label: 'مباع', color: 'bg-red-100 text-red-700' },
  'rented': { label: 'مؤجر', color: 'bg-orange-100 text-orange-700' },
  'for_resale': { label: 'إعادة بيع', color: 'bg-yellow-100 text-yellow-700' },
  'under_construction': { label: 'تحت الإنشاء', color: 'bg-gray-100 text-gray-700' },
  'deed_completed': { label: 'تم الإفراغ', color: 'bg-blue-100 text-blue-700' },
  'resold': { label: 'تم إعادة البيع', color: 'bg-purple-100 text-purple-700' },
  'transferred_to_other': { label: 'نقل لآخر', color: 'bg-indigo-100 text-indigo-700' }
};

export default function DeedsTable({ units, loading, onMessageClick }: DeedsTableProps) {
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
                <tr key={unit.id} className="hover:bg-gray-50/50 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-blue-50 rounded-lg flex items-center justify-center text-blue-700 font-display font-bold border border-blue-100">
                        {unit.unit_number}
                      </div>
                      <span className="text-sm text-gray-500">الدور {unit.floor_number}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex flex-col">
                      <span className="font-bold text-gray-900">{unit.project_name}</span>
                      <span className="text-xs text-gray-500">{unit.project_number}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-2" title={unit.title_deed_owner ? `العميل الأصلي: ${unit.client_name}` : ''}>
                      <User size={16} className={unit.title_deed_owner ? "text-indigo-500" : "text-gray-400"} />
                      <span className={`text-sm font-medium ${unit.title_deed_owner ? "text-indigo-900" : "text-gray-900"}`}>
                        {unit.title_deed_owner || unit.client_name || '-'}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-display font-bold ${statusMap[unit.status]?.color || 'bg-gray-100 text-gray-600'}`}>
                      {statusMap[unit.status]?.label || unit.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center font-mono text-sm text-gray-600">
                    {unit.deed_number || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    <button
                      onClick={() => onMessageClick(unit)}
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
