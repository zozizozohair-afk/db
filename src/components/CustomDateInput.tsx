'use client';

import React from 'react';
import { Calendar as CalendarIcon } from 'lucide-react';

interface CustomDateInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  label?: string;
  disabled?: boolean;
  id?: string;
  className?: string;
}

const CustomDateInput = ({
  value,
  onChange,
  placeholder = "اختر التاريخ...",
  label,
  disabled = false,
  id,
  className = "",
}: CustomDateInputProps) => {
  return (
    <div className={`relative w-full ${className}`}>
      {label && (
        <label className="block text-base font-semibold text-gray-700 mb-3">
          {label}
        </label>
      )}
      
      <div className="relative">
        <div className="absolute inset-y-0 right-0 flex items-center pr-4 pointer-events-none">
          <CalendarIcon size={24} className="text-gray-500" />
        </div>
        <input
          type="date"
          id={id}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          disabled={disabled}
          className={`
            w-full px-5 py-4 rounded-2xl border-2 text-right transition-all duration-300
            ${disabled 
              ? 'border-gray-200 bg-gray-100 cursor-not-allowed opacity-70' 
              : 'border-gray-200 bg-white hover:border-blue-400 focus:border-blue-500 focus:ring-4 focus:ring-blue-100 outline-none text-lg'
            }
          `}
        />
      </div>
    </div>
  );
};

export default CustomDateInput;