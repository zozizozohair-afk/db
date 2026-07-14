'use client';

import React, { useState } from 'react';
import { Home, Check } from 'lucide-react';
import { Unit } from '../types';

interface CustomUnitPickerProps {
  units: Unit[];
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  label?: string;
  disabled?: boolean;
  className?: string;
}

const CustomUnitPicker: React.FC<CustomUnitPickerProps> = ({
  units,
  value,
  onChange,
  placeholder = "اختر الوحدة...",
  label,
  disabled = false,
  className = "",
}) => {
  const [isOpen, setIsOpen] = useState(false);

  const selectedUnit = units.find(u => u.id === value);

  return (
    <div className={`relative w-full ${className}`}>
      {label && (
        <label className="block text-base font-semibold text-gray-700 mb-3">
          {label}
        </label>
      )}

      <button
        type="button"
        onClick={() => !disabled && setIsOpen(!isOpen)}
        disabled={disabled}
        className={`
          w-full px-5 py-4 rounded-2xl border-2 text-right transition-all duration-300
          flex items-center justify-between
          ${disabled
            ? 'border-gray-200 bg-gray-100 cursor-not-allowed opacity-70'
            : 'border-gray-200 bg-white hover:border-blue-400 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none'
          }
        `}
      >
        <span className={`font-medium text-lg ${selectedUnit ? 'text-gray-900' : 'text-gray-400'}`}>
          {selectedUnit ? `${selectedUnit.unit_number} - ${selectedUnit.direction_label}` : placeholder}
        </span>
        <Home size={24} className="text-gray-500" />
      </button>

      {isOpen && (
        <>
          <div
            className="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm"
            onClick={() => setIsOpen(false)}
          />

          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl border border-gray-200 shadow-2xl p-6 w-full max-w-lg animate-in fade-in zoom-in duration-200">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-gray-900">اختر الوحدة</h3>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 max-h-80 overflow-y-auto">
                {units.map((unit) => {
                  const isSelected = unit.id === value;

                  return (
                    <button
                      key={unit.id}
                      onClick={() => {
                        onChange(unit.id);
                        setIsOpen(false);
                      }}
                      className={`
                        p-4 rounded-2xl flex flex-col items-center justify-center text-center
                        transition-all duration-200
                        ${isSelected
                          ? 'bg-gradient-to-br from-blue-600 to-indigo-600 text-white shadow-lg'
                          : 'bg-gray-50 border border-gray-200 hover:border-blue-400 hover:bg-blue-50'
                        }
                      `}
                    >
                      <div className={`text-2xl font-extrabold mb-1 ${isSelected ? 'text-white' : 'text-blue-700'}`}>
                        {unit.unit_number}
                      </div>
                      <div className={`text-sm ${isSelected ? 'opacity-90' : 'text-gray-600'}`}>
                        {unit.direction_label}
                      </div>
                      {isSelected && <Check size={16} className="mt-1" />}
                    </button>
                  );
                })}
              </div>

              <button
                onClick={() => setIsOpen(false)}
                className="mt-6 w-full py-3 rounded-xl bg-gray-100 text-gray-700 font-semibold hover:bg-gray-200 transition-colors"
              >
                إلغاء
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default CustomUnitPicker;
