'use client';

import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { 
  FileCheck, 
  Building2, 
  Filter, 
  Search,
  MessageCircle,
  Send,
  Copy,
  Check,
  ChevronRight,
  User,
  X,
  Printer,
  ArrowUpDown,
  Upload,
  FileSpreadsheet,
  Trash2
} from 'lucide-react';
import { Unit, Project } from '../../types';
import * as XLSX from 'xlsx';

import MessageModal from '../../components/MessageModal';
import DeedsTable, { EnrichedUnit } from '../../components/DeedsTable';
import ReportCopyModal from '../../components/ReportCopyModal';
import ReportPrintModal from '../../components/ReportPrintModal';

export default function DeedsPage() {
  const [units, setUnits] = useState<EnrichedUnit[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterProject, setFilterProject] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [sortBy, setSortBy] = useState<'unit' | 'project'>('unit');
  const [selectedUnitForMessage, setSelectedUnitForMessage] = useState<EnrichedUnit | null>(null);
  const [isReportCopyModalOpen, setIsReportCopyModalOpen] = useState(false);
  const [isReportPrintModalOpen, setIsReportPrintModalOpen] = useState(false);
  
  // Excel search state
  const [excelSearchMode, setExcelSearchMode] = useState(false);
  const [excelDeedNumbers, setExcelDeedNumbers] = useState<string[]>([]);
  const [searchField, setSearchField] = useState<'deed_number' | 'client_id_number'>('deed_number');
  const [showExcelResults, setShowExcelResults] = useState(false);
  const [showResultBoxes, setShowResultBoxes] = useState(true);
  const [matchedUnits, setMatchedUnits] = useState<EnrichedUnit[]>([]);
  const [unmatchedNumbers, setUnmatchedNumbers] = useState<string[]>([]);

  // Status mapping
  const statusMap: Record<string, { label: string, color: string }> = {
    'available': { label: 'غير مفرغة', color: 'bg-green-100 text-green-700' },
    'sold': { label: 'مباعة', color: 'bg-red-100 text-red-700' },
    'sold_to_other': { label: 'مباعة لآخر', color: 'bg-gray-100 text-gray-700' },
    'for_resale': { label: 'إعادة بيع', color: 'bg-purple-100 text-purple-700' },
    'pending_sale': { label: 'قيد البيع', color: 'bg-orange-100 text-orange-700' },
  };

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      setErrorText(null);
      const withTimeoutAny = (p: any, ms = 15000) =>
        Promise.race<any>([
          p as any,
          new Promise<never>((_, rej) => setTimeout(() => rej(new Error('انتهت مهلة الاتصال بقاعدة البيانات')), ms)),
        ]) as Promise<any>;
      
      const { data: projectsData, error: projectsError } = await withTimeoutAny(
        supabase
        .from('projects')
        .select('*')
        .order('created_at', { ascending: false })
      );

      if (projectsError) throw projectsError;
      setProjects(projectsData || []);

      const { data: unitsData, error: unitsError } = await withTimeoutAny(
        supabase
        .from('units')
        .select('*')
      );

      if (unitsError) throw unitsError;

      const enrichedUnits = unitsData?.map((unit: Unit) => {
        const project = projectsData?.find((p: Project) => p.id === unit.project_id);
        return {
          ...unit,
          project_name: project?.name || 'غير معروف',
          project_number: project?.project_number || '-'
        };
      }) || [];

      setUnits(enrichedUnits);
    } catch (error) {
      console.error('Error fetching deeds data:', error);
      const msg = (error as any)?.message || 'تعذر تحميل البيانات';
      setErrorText(msg);
    } finally {
      setLoading(false);
    }
  };

  const filteredUnits = units
    .filter(unit => {
      const matchesProject = filterProject === 'all' || unit.project_id === filterProject;
      const matchesStatus = filterStatus === 'all' || unit.status === filterStatus;
      
      // Project Code: ProjectNumber-UnitNumber
      const projectCode = `${unit.project_number}-${unit.unit_number}`;
      
      const matchesSearch = 
        unit.unit_number.toString().includes(searchQuery) ||
        (unit.client_name && unit.client_name.includes(searchQuery)) ||
        (unit.title_deed_owner && unit.title_deed_owner.includes(searchQuery)) ||
        unit.project_name.includes(searchQuery) ||
        projectCode.includes(searchQuery);

      return matchesProject && matchesStatus && matchesSearch;
    })
    .sort((a, b) => {
      if (sortBy === 'project') {
        return a.project_name.localeCompare(b.project_name);
      }
      return a.unit_number - b.unit_number;
    });

  const handlePrint = () => {
    if (filteredUnits.length === 0) return;
    setIsReportPrintModalOpen(true);
  };

  const handleStatusChange = async (unitId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('units')
        .update({ status: newStatus })
        .eq('id', unitId);

      if (error) throw error;

      // Update local state
      setUnits(prev => prev.map(u => u.id === unitId ? { ...u, status: newStatus as any } : u));
    } catch (error: any) {
      console.error('Error updating status:', error);
      alert('حدث خطأ أثناء تحديث الحالة: ' + error.message);
    }
  };

  const handleCopyWhatsApp = () => {
    if (filteredUnits.length === 0) return;
    setIsReportCopyModalOpen(true);
  };

  // Excel processing functions
  const handleExcelUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const data = new Uint8Array(event.target?.result as ArrayBuffer);
        const workbook = XLSX.read(data, { type: 'array' });
        const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
        const jsonData = XLSX.utils.sheet_to_json(firstSheet, { header: 1 });

        // Extract all non-empty values from the first column
        const numbers = jsonData
          .flat()
          .filter((val): val is string | number => val != null && val !== '')
          .map(val => String(val).trim());

        setExcelDeedNumbers(numbers);
        setShowExcelResults(false);
      } catch (error) {
        console.error('Error reading Excel file:', error);
        alert('حدث خطأ أثناء قراءة ملف Excel');
      }
    };
    reader.readAsArrayBuffer(file);
  };

  const performExcelSearch = () => {
    if (excelDeedNumbers.length === 0) {
      alert('يرجى رفع ملف Excel أولاً');
      return;
    }

    const matched: EnrichedUnit[] = [];
    const unmatched: string[] = [];

    excelDeedNumbers.forEach(num => {
      const unit = units.find(u => {
        if (searchField === 'deed_number') {
          return u.deed_number === num;
        } else {
          return u.client_id_number === num;
        }
      });

      if (unit) {
        matched.push({ ...unit, excel_match_number: num });
      } else {
        unmatched.push(num);
      }
    });

    setMatchedUnits(matched);
    setUnmatchedNumbers(unmatched);
    setShowExcelResults(true);
    setShowResultBoxes(true);
  };

  const clearExcelSearch = () => {
    setExcelSearchMode(false);
    setExcelDeedNumbers([]);
    setShowExcelResults(false);
    setMatchedUnits([]);
    setUnmatchedNumbers([]);
  };

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-600/20">
            <FileCheck size={24} />
          </div>
          <div>
            <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">مراجعة الصكوك</h1>
            <p className="text-gray-500 text-sm">إدارة ومتابعة صكوك الوحدات وحالاتها</p>
          </div>
        </div>

        {/* Excel Search Toggle */}
        <button
          onClick={() => {
            if (excelSearchMode) {
              clearExcelSearch();
            } else {
              setExcelSearchMode(true);
            }
          }}
          className={`flex items-center justify-center gap-2 px-6 py-2.5 rounded-xl transition-all shadow-md hover:shadow-lg font-bold ${
            excelSearchMode
              ? 'bg-purple-600 text-white hover:bg-purple-700'
              : 'bg-purple-100 text-purple-700 hover:bg-purple-200'
          }`}
        >
          <FileSpreadsheet size={20} />
          {excelSearchMode ? 'إغلاق بحث Excel' : 'بحث من Excel'}
        </button>
        
        <div className="flex gap-2">
          <button
            onClick={handlePrint}
            className="flex items-center justify-center gap-2 px-6 py-2.5 bg-gray-900 text-white rounded-xl hover:bg-gray-800 transition-all shadow-md hover:shadow-lg font-bold"
          >
            <Printer size={20} />
            طباعة التقرير
          </button>

          <button
            onClick={handleCopyWhatsApp}
            className="flex items-center justify-center gap-2 px-6 py-2.5 bg-[#25D366] text-white rounded-xl hover:bg-[#20ba59] transition-all shadow-md hover:shadow-lg font-bold"
          >
            <MessageCircle size={20} />
            نسخ للواتساب
          </button>
        </div>
      </div>

      {/* Excel Search Interface */}
      {excelSearchMode && (
        <div className="bg-purple-50 border border-purple-200 p-6 rounded-2xl space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-bold text-purple-800 flex items-center gap-2">
              <FileSpreadsheet size={20} />
              بحث من ملف Excel
            </h3>
            <button
              onClick={clearExcelSearch}
              className="text-purple-600 hover:text-purple-800 transition-colors"
            >
              <Trash2 size={18} />
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Search Field Selection */}
            <div>
              <label className="block text-xs font-bold text-purple-700 mb-1.5">البحث حسب</label>
              <div className="flex p-1 bg-purple-100 rounded-xl">
                <button
                  onClick={() => setSearchField('deed_number')}
                  className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all ${
                    searchField === 'deed_number' ? 'bg-white text-purple-700 shadow-sm' : 'text-purple-500 hover:text-purple-700'
                  }`}
                >
                  رقم الصك
                </button>
                <button
                  onClick={() => setSearchField('client_id_number')}
                  className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all ${
                    searchField === 'client_id_number' ? 'bg-white text-purple-700 shadow-sm' : 'text-purple-500 hover:text-purple-700'
                  }`}
                >
                  رقم الهوية
                </button>
              </div>
            </div>

            {/* File Upload */}
            <div>
              <label className="block text-xs font-bold text-purple-700 mb-1.5">رفع ملف Excel</label>
              <label className="flex items-center justify-center gap-2 w-full p-2.5 bg-white border-2 border-dashed border-purple-300 rounded-xl cursor-pointer hover:border-purple-500 hover:bg-purple-50 transition-all">
                <Upload size={18} className="text-purple-600" />
                <span className="text-sm text-purple-700">اختر ملف Excel</span>
                <input
                  type="file"
                  accept=".xlsx,.xls,.csv"
                  onChange={handleExcelUpload}
                  className="hidden"
                />
              </label>
            </div>

            {/* Search Button */}
            <div className="flex items-end">
              <button
                onClick={performExcelSearch}
                disabled={excelDeedNumbers.length === 0}
                className="w-full flex items-center justify-center gap-2 px-6 py-2.5 bg-purple-600 text-white rounded-xl hover:bg-purple-700 transition-all shadow-md hover:shadow-lg font-bold disabled:opacity-50"
              >
                <Search size={20} />
                بحث ({excelDeedNumbers.length})
              </button>
            </div>
          </div>

          {/* Results */}
          {showExcelResults && (
            <div className="pt-4 border-t border-purple-200 space-y-4">
              <div className="flex justify-end gap-2">
                <button
                  onClick={() => {
                    // Prepare data for Excel
                    const data = matchedUnits.map(u => ({
                      'رقم الوحدة': u.unit_number,
                      'المشروع': u.project_name,
                      'رقم المشروع': u.project_number,
                      'رقم من Excel': u.excel_match_number || '',
                      'رقم الصك في النظام': u.deed_number || '',
                      'المالك': u.title_deed_owner || u.client_name || '',
                      'الحالة': statusMap[u.status]?.label || u.status
                    }));
                    
                    // Add unmatched numbers if any
                    if (unmatchedNumbers.length > 0) {
                      unmatchedNumbers.forEach(num => {
                        data.push({
                          'رقم الوحدة': '',
                          'المشروع': '',
                          'رقم المشروع': '',
                          'رقم من Excel': num,
                          'رقم الصك في النظام': '',
                          'المالك': '',
                          'الحالة': 'لم يتم العثور عليه'
                        });
                      });
                    }
                    
                    const ws = XLSX.utils.json_to_sheet(data);
                    const wb = XLSX.utils.book_new();
                    XLSX.utils.book_append_sheet(wb, ws, 'نتائج البحث');
                    XLSX.writeFile(wb, `نتائج_بحث_الصكوك_${new Date().toLocaleDateString('ar-SA').replace(/\//g, '-')}.xlsx`);
                  }}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-all text-sm font-bold"
                >
                  <FileSpreadsheet size={18} />
                  تحميل النتائج Excel
                </button>
                <button
                  onClick={() => setShowResultBoxes(!showResultBoxes)}
                  className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-all text-sm font-bold"
                >
                  {showResultBoxes ? 'إخفاء القوائم' : 'إظهار القوائم'}
                </button>
              </div>
              
              {showResultBoxes && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="bg-white p-4 rounded-xl border border-green-200">
                    <h4 className="font-bold text-green-700 mb-2">
                      تم العثور عليها: {matchedUnits.length}
                    </h4>
                    <div className="text-sm text-green-600">
                      {matchedUnits.map(u => (
                        <div key={u.id} className="py-1 border-b border-green-100 last:border-0">
                          وحدة {u.unit_number} - {u.project_name}
                        </div>
                      ))}
                    </div>
                  </div>
                  {unmatchedNumbers.length > 0 && (
                    <div className="bg-white p-4 rounded-xl border border-red-200">
                      <h4 className="font-bold text-red-700 mb-2">
                        لم يتم العثور عليها: {unmatchedNumbers.length}
                      </h4>
                      <div className="text-sm text-red-600">
                        {unmatchedNumbers.map((num, i) => (
                          <div key={i} className="py-1 border-b border-red-100 last:border-0">
                            {num}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Filters */}
      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 space-y-4">
        {errorText && (
          <div className="px-4 py-3 rounded-xl bg-red-50 text-red-700 border border-red-200 text-sm">
            {errorText}
          </div>
        )}
        <div className="flex flex-col md:flex-row gap-4">
          {/* Project Filter */}
          <div className="flex-1">
            <label className="block text-xs font-bold text-gray-500 mb-1.5">المشروع</label>
            <select
              value={filterProject}
              onChange={(e) => setFilterProject(e.target.value)}
              className="w-full p-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">جميع المشاريع</option>
              {projects.map(p => (
                <option key={p.id} value={p.id}>{p.name} ({p.project_number})</option>
              ))}
            </select>
          </div>

          {/* Search */}
          <div className="flex-[1.5]">
            <label className="block text-xs font-bold text-gray-500 mb-1.5">بحث</label>
            <div className="relative">
              <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input
                type="text"
                placeholder="ابحث برقم الوحدة، الكود (101-1)، اسم العميل..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
              />
            </div>
          </div>

          {/* Sort By */}
          <div className="flex-1">
            <label className="block text-xs font-bold text-gray-500 mb-1.5">ترتيب حسب</label>
            <div className="flex p-1 bg-gray-100 rounded-xl">
              <button
                onClick={() => setSortBy('unit')}
                className={`flex-1 flex items-center justify-center gap-2 py-1.5 rounded-lg text-xs font-bold transition-all ${sortBy === 'unit' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
              >
                <ArrowUpDown size={14} />
                رقم الوحدة
              </button>
              <button
                onClick={() => setSortBy('project')}
                className={`flex-1 flex items-center justify-center gap-2 py-1.5 rounded-lg text-xs font-bold transition-all ${sortBy === 'project' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
              >
                <ArrowUpDown size={14} />
                المشروع
              </button>
            </div>
          </div>
        </div>

        {/* Status Filter Tabs */}
        <div className="border-t border-gray-100 pt-4">
           <label className="block text-xs font-bold text-gray-500 mb-2">حالة الصك / الوحدة</label>
           <div className="flex flex-wrap gap-2">
             <button
                onClick={() => setFilterStatus('all')}
                className={`px-3 py-1.5 rounded-lg text-sm font-display font-bold transition-all ${filterStatus === 'all' ? 'bg-gray-800 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
             >
               الكل
             </button>
             {Object.entries(statusMap).map(([key, value]) => (
               <button
                 key={key}
                 onClick={() => setFilterStatus(key)}
                 className={`px-3 py-1.5 rounded-lg text-sm font-display font-bold transition-all ${filterStatus === key ? 'ring-2 ring-offset-1 ring-blue-500 ' + value.color : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'}`}
               >
                 {value.label}
               </button>
             ))}
           </div>
        </div>
      </div>

      {/* Results Table */}
      <DeedsTable 
        units={excelSearchMode && showExcelResults ? matchedUnits : filteredUnits} 
        loading={loading} 
        onMessageClick={setSelectedUnitForMessage} 
        onStatusChange={handleStatusChange}
      />

      {/* Message Modal */}
      <MessageModal 
        isOpen={!!selectedUnitForMessage} 
        onClose={() => setSelectedUnitForMessage(null)} 
        unit={selectedUnitForMessage} 
      />

      {/* Report Copy Modal */}
      <ReportCopyModal
        isOpen={isReportCopyModalOpen}
        onClose={() => setIsReportCopyModalOpen(false)}
        units={filteredUnits}
        filterProject={filterProject !== 'all' ? projects.find(p => p.id === filterProject)?.name : undefined}
        filterStatus={filterStatus !== 'all' ? statusMap[filterStatus]?.label : undefined}
      />

      {/* Report Print Modal */}
      <ReportPrintModal
        isOpen={isReportPrintModalOpen}
        onClose={() => setIsReportPrintModalOpen(false)}
        units={filteredUnits}
        filterProject={filterProject !== 'all' ? projects.find(p => p.id === filterProject)?.name : undefined}
        filterStatus={filterStatus !== 'all' ? statusMap[filterStatus]?.label : undefined}
      />
    </div>
  );
}
