'use client';

import React, { useState } from 'react';
import { ChevronDown, Check } from 'lucide-react';

interface Option {
  value: string;
  label: string;
}

interface CustomSelectProps {
  options: Option[];
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  label?: string;
  disabled?: boolean;
  id?: string;
  className?: string;
}

const CustomSelect = ({
  options,
  value,
  onChange,
  placeholder = "اختر من القائمة...",
  label,
  disabled = false,
  id,
  className = "",
}: CustomSelectProps) => {
  const [isOpen, setIsOpen] = useState(false);

  const selectedOption = options.find(opt => opt.value === value);

  return (
    <div className={`relative w-full ${className}`}>
      {label && (
        <label className="block text-base font-semibold text-gray-700 mb-3">
          {label}
        </label>
      )}
      
      <button
        type="button"
        id={id}
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
        <span className={`font-medium text-lg ${selectedOption ? 'text-gray-900' : 'text-gray-400'}`}>
          {selectedOption ? selectedOption.label : placeholder}
        </span>
        <ChevronDown 
          size={24} 
          className={`text-gray-500 transition-all duration-300 ${isOpen ? 'rotate-180 text-blue-600' : ''}`}
        />
      </button>

      {isOpen && (
        <div className="absolute z-50 w-full mt-2 bg-white rounded-2xl border border-gray-200 shadow-xl overflow-hidden">
          <div className="max-h-72 overflow-y-auto py-2">
            {options.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => {
                  onChange(option.value);
                  setIsOpen(false);
                }}
                className={`
                  w-full px-5 py-4 text-right transition-all duration-200 flex items-center justify-between
                  ${value === option.value 
                    ? 'bg-blue-50 text-blue-700 font-semibold' 
                    : 'text-gray-700 hover:bg-gray-50'
                  }
                `}
              >
                {option.label}
                {value === option.value && (
                  <Check size={20} className="text-blue-600" />
                )}
              </button>
            ))}
          </div>
        </div>
      )}

      {isOpen && (
        <div 
          className="fixed inset-0 z-40" 
          onClick={() => setIsOpen(false)}
        />
      )}
    </div>
  );
};

export default CustomSelect;