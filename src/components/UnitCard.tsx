import React from 'react';
import Link from 'next/link';
import { Unit } from '../types';

interface UnitCardProps {
  unit: Unit;
  showProjectName?: boolean;
  projectName?: string;
}

export default function UnitCard({ unit, showProjectName = false, projectName }: UnitCardProps) {
  return (
    <Link 
      href={`/units/${unit.id}`}
      className="bg-white rounded-xl shadow-sm border border-gray-200 hover:shadow-md transition-shadow p-4 relative group cursor-pointer block h-full"
    >
      <div className="absolute top-4 left-4">
        <span className={`w-2 h-2 rounded-full block ${
          unit.status === 'available' ? 'bg-green-500' : 
          unit.status === 'sold' ? 'bg-red-500' :
          unit.status === 'sold_to_other' ? 'bg-gray-500' :
          unit.status === 'resale' ? 'bg-purple-500' :
          unit.status === 'pending_sale' ? 'bg-orange-500' :
          'bg-gray-300'
        }`}></span>
      </div>

      <div className="flex items-center gap-3 mb-3">
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center text-white font-bold shadow-sm ${
          unit.type === 'annex' ? 'bg-purple-600' : 'bg-blue-600'
        }`}>
          {unit.unit_number}
        </div>
        <div>
          <p className="text-xs text-gray-500 font-medium">{unit.floor_label}</p>
          <p className="text-sm font-bold text-gray-900">
            {unit.type === 'annex' ? 'ملحق علوي' : 'شقة سكنية'}
          </p>
        </div>
      </div>

      <div className="space-y-2 pt-2 border-t border-gray-50">
        {showProjectName && projectName && (
          <div className="flex items-center justify-between text-xs">
            <span className="text-gray-500">المشروع:</span>
            <span className="font-medium text-blue-600">{projectName}</span>
          </div>
        )}
        
        <div className="flex items-center justify-between text-xs">
          <span className="text-gray-500">الاتجاه:</span>
          <span className="font-medium text-gray-900 text-left" title={unit.direction_label}>
            {unit.direction_label?.length > 20 
              ? unit.direction_label.substring(0, 20) + '...' 
              : unit.direction_label || '-'}
          </span>
        </div>
        
        {unit.client_name && (
          <div className="flex items-center justify-between text-xs">
            <span className="text-gray-500">العميل:</span>
            <span className="font-medium text-gray-900">{unit.client_name}</span>
          </div>
        )}
        {unit.deed_number && (
          <div className="flex items-center justify-between text-xs">
            <span className="text-gray-500">الصك:</span>
            <span className="font-mono text-gray-900">{unit.deed_number}</span>
          </div>
        )}
      </div>

      {/* Hover Action */}
      <div className="absolute inset-0 bg-blue-600/5 opacity-0 group-hover:opacity-100 transition-opacity rounded-xl pointer-events-none" />
    </Link>
  );
}
