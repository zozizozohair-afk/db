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
  ArrowUpDown
} from 'lucide-react';
import { Unit, Project } from '../../types';

import MessageModal from '../../components/MessageModal';
import DeedsTable, { EnrichedUnit } from '../../components/DeedsTable';

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
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    const html = `
      <html dir="rtl" lang="ar">
        <head>
          <title>تقرير مراجعة الصكوك - ${new Date().toLocaleDateString('ar-SA')}</title>
          <style>
            @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap');
            body { font-family: 'Cairo', sans-serif; padding: 20px; color: #333; }
            h1 { text-align: center; color: #2563eb; margin-bottom: 30px; }
            table { width: 100%; border-collapse: collapse; margin-top: 20px; }
            th, td { border: 1px solid #e5e7eb; padding: 12px 8px; text-align: right; font-size: 14px; }
            th { background-color: #f9fafb; color: #374151; font-weight: bold; }
            tr:nth-child(even) { background-color: #fcfcfc; }
            .badge { padding: 4px 8px; border-radius: 9999px; font-size: 12px; font-weight: bold; }
            .available { background-color: #d1fae5; color: #065f46; }
            .sold { background-color: #fee2e2; color: #991b1b; }
            @media print {
              .no-print { display: none; }
              body { padding: 0; }
              table { page-break-inside: auto; }
              tr { page-break-inside: avoid; page-break-after: auto; }
            }
          </style>
        </head>
        <body>
          <h1>تقرير مراجعة الصكوك</h1>
          <p>تاريخ التقرير: ${new Date().toLocaleDateString('ar-SA')}</p>
          <table>
            <thead>
              <tr>
                <th>رقم الوحدة</th>
                <th>المشروع</th>
                <th>العميل الأصلي</th>
                <th>رقم الجوال</th>
                <th>قيمة إعادة البيع</th>
                <th>رقم الصك</th>
                <th>الحالة</th>
              </tr>
            </thead>
            <tbody>
              ${filteredUnits.map(unit => `
                <tr>
                  <td>${unit.unit_number}</td>
                  <td>${unit.project_name} (${unit.project_number})</td>
                  <td>${unit.client_name || '-'}</td>
                  <td>${unit.client_phone || '-'}</td>
                  <td>${unit.resale_agreed_amount ? unit.resale_agreed_amount.toLocaleString('ar-SA') + ' ريال' : '-'}</td>
                  <td>${unit.deed_number || '-'}</td>
                  <td>${statusMap[unit.status]?.label || unit.status}</td>
                </tr>
              `).join('')}
            </tbody>
          </table>
          <script>
            window.onload = () => {
              window.print();
              setTimeout(() => window.close(), 500);
            };
          </script>
        </body>
      </html>
    `;

    printWindow.document.write(html);
    printWindow.document.close();
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

    let header = `*تقرير مراجعة الصكوك - ${new Date().toLocaleDateString('ar-SA')}*\n`;
    
    // Add filters to header if active
    if (filterProject !== 'all') {
      const project = projects.find(p => p.id === filterProject);
      if (project) {
        header += `📁 *المشروع:* ${project.name}\n`;
      }
    }
    
    if (filterStatus !== 'all') {
      header += `📍 *الحالة:* ${statusMap[filterStatus]?.label || filterStatus}\n`;
    }
    
    header += `\n`;

    const body = filteredUnits.map(unit => {
      let msg = `👤 *العميل:* ${unit.client_name || '-'}\n`;
      msg += `🏠 *الوحدة:* ${unit.unit_number} - ${unit.project_name} (${unit.project_number})\n`;
      msg += `🧭 *الاتجاه:* ${unit.direction_label || '-'}\n`;
      msg += `📄 *رقم الصك:* ${unit.deed_number || '-'}\n`;
      if (unit.resale_agreed_amount) {
        msg += `💰 *إعادة بيع:* ${unit.resale_agreed_amount.toLocaleString('ar-SA')} ريال\n`;
      }
      msg += `📞 *الجوال:* ${unit.client_phone || '-'}\n`;
      return msg;
    }).join('\n-------------------\n\n');

    const fullText = header + body;
    
    navigator.clipboard.writeText(fullText).then(() => {
      alert('تم نسخ التقرير بصيغة واتساب بنجاح!');
    }).catch(err => {
      console.error('Failed to copy: ', err);
      alert('حدث خطأ أثناء النسخ');
    });
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
        units={filteredUnits} 
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
    </div>
  );
}
