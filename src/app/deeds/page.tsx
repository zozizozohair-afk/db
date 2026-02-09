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
  X
} from 'lucide-react';
import { Unit, Project } from '../../types';

import MessageModal from '../../components/MessageModal';
import DeedsTable, { EnrichedUnit } from '../../components/DeedsTable';

export default function DeedsPage() {
  const [units, setUnits] = useState<EnrichedUnit[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterProject, setFilterProject] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [selectedUnitForMessage, setSelectedUnitForMessage] = useState<EnrichedUnit | null>(null);

  // Status mapping
  const statusMap: Record<string, { label: string, color: string }> = {
    'available': { label: 'غير مباعة', color: 'bg-green-100 text-green-700' },
    'sold': { label: 'مباعة', color: 'bg-red-100 text-red-700' },
    'sold_to_other': { label: 'مباعة لآخر', color: 'bg-gray-100 text-gray-700' },
    'resale': { label: 'إعادة بيع', color: 'bg-purple-100 text-purple-700' },
    'pending_sale': { label: 'قيد البيع', color: 'bg-orange-100 text-orange-700' },
  };

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      
      // Fetch projects
      const { data: projectsData, error: projectsError } = await supabase
        .from('projects')
        .select('*')
        .order('created_at', { ascending: false });

      if (projectsError) throw projectsError;
      setProjects(projectsData || []);

      // Fetch units
      const { data: unitsData, error: unitsError } = await supabase
        .from('units')
        .select('*')
        .order('unit_number', { ascending: true });

      if (unitsError) throw unitsError;

      // Enrich units with project data
      const enrichedUnits = unitsData?.map(unit => {
        const project = projectsData?.find(p => p.id === unit.project_id);
        return {
          ...unit,
          project_name: project?.name || 'غير معروف',
          project_number: project?.project_number || '-'
        };
      }) || [];

      setUnits(enrichedUnits);
    } catch (error) {
      console.error('Error fetching deeds data:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredUnits = units.filter(unit => {
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
  });

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-600/20">
          <FileCheck size={24} />
        </div>
        <div>
          <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">مراجعة الصكوك</h1>
          <p className="text-gray-500 text-sm">إدارة ومتابعة صكوك الوحدات وحالاتها</p>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 space-y-4">
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
          <div className="flex-1">
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
