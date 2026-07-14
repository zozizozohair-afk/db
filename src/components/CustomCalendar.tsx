'use client';

import React, { useState, useEffect } from 'react';
import { ChevronLeft, ChevronRight, Calendar as CalendarIcon, Check } from 'lucide-react';

interface CustomCalendarProps {
  value?: string;
  onChange?: (date: string) => void;
  placeholder?: string;
  label?: string;
  disabled?: boolean;
  className?: string;
}

const CustomCalendar: React.FC<CustomCalendarProps> = ({
  value,
  onChange,
  placeholder = "اختر التاريخ...",
  label,
  disabled = false,
  className = "",
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [currentMonth, setCurrentMonth] = useState<Date>(new Date());
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);

  useEffect(() => {
    if (value) {
      const date = new Date(value);
      setSelectedDate(date);
      setCurrentMonth(new Date(date.getFullYear(), date.getMonth()));
    }
  }, [value]);

  const getDaysInMonth = (date: Date): Date[] => {
    const days: Date[] = [];
    const year = date.getFullYear();
    const month = date.getMonth();

    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);

    for (let i = 0; i < firstDay.getDay(); i++) {
      days.push(new Date(year, month, -i));
    }
    days.reverse();

    for (let i = 1; i <= lastDay.getDate(); i++) {
      days.push(new Date(year, month, i));
    }

    const remainingDays = 42 - days.length;
    for (let i = 1; i <= remainingDays; i++) {
      days.push(new Date(year, month + 1, i));
    }

    return days;
  };

  const formatDate = (date: Date): string => {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const formatDisplayDate = (date: Date): string => {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return `${months[date.getMonth()]} ${date.getFullYear()}`;
  };

  const isSameDate = (d1: Date, d2: Date): boolean => {
    return (
      d1.getDate() === d2.getDate() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getFullYear() === d2.getFullYear()
    );
  };

  const isCurrentMonth = (date: Date): boolean => {
    return date.getMonth() === currentMonth.getMonth() &&
           date.getFullYear() === currentMonth.getFullYear();
  };

  const handleDateSelect = (date: Date) => {
    setSelectedDate(date);
    onChange?.(formatDate(date));
    setIsOpen(false);
  };

  const days = getDaysInMonth(currentMonth);
  const weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

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
        <span className={`font-medium text-lg ${selectedDate ? 'text-gray-900' : 'text-gray-400'}`}>
          {selectedDate ? formatDisplayDate(selectedDate) : placeholder}
        </span>
        <CalendarIcon size={24} className="text-gray-500" />
      </button>

      {isOpen && (
        <>
          <div
            className="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm"
            onClick={() => setIsOpen(false)}
          />

          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl border border-gray-200 shadow-2xl p-6 w-full max-w-md animate-in fade-in zoom-in duration-200">
              <div className="flex items-center justify-between mb-6">
                <button
                  onClick={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1))}
                  className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                >
                  <ChevronRight size={24} className="text-gray-700" />
                </button>
                
                <h3 className="text-xl font-bold text-gray-900">
                  {formatDisplayDate(currentMonth)}
                </h3>
                
                <button
                  onClick={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1))}
                  className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                >
                  <ChevronLeft size={24} className="text-gray-700" />
                </button>
              </div>

              <div className="grid grid-cols-7 mb-3">
                {weekDays.map((day, i) => (
                  <div
                    key={i}
                    className="text-center text-sm font-semibold text-gray-500 py-2"
                  >
                    {day}
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-7 gap-2">
                {days.map((day, i) => {
                  const isSelected = selectedDate && isSameDate(day, selectedDate);
                  const isCurrent = isCurrentMonth(day);

                  return (
                    <button
                      key={i}
                      onClick={() => handleDateSelect(day)}
                      className={`
                        aspect-square rounded-xl flex items-center justify-center text-lg font-medium
                        transition-all duration-200
                        ${isSelected
                          ? 'bg-gradient-to-br from-blue-600 to-indigo-600 text-white shadow-lg'
                          : isCurrent
                          ? 'text-gray-900 hover:bg-blue-50 hover:text-blue-700'
                          : 'text-gray-400 hover:bg-gray-100'
                        }
                      `}
                    >
                      {day.getDate()}
                      {isSelected && <Check size={14} className="ml-1" />}
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

export default CustomCalendar;
