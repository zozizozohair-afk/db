'use client';

import React, { useState, useEffect, useRef } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { 
  Building2, 
  Layers,
  Search,
  Filter,
  UserCheck,
  HardHat,
  CheckCircle2,
  AlertCircle,
  X
} from 'lucide-react';
import FilePreviewModal from '../../components/FilePreviewModal';
import ModificationsList, { ProjectWithModifications, ModificationUnit } from '../../components/ModificationsList';

type FilterStatus = 'all' | 'client_confirmed' | 'engineer_reviewed' | 'completed' | 'pending';

export default function ModificationsPage() {
  const [projects, setProjects] = useState<ProjectWithModifications[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState<FilterStatus>('all');
  const [previewFileUrl, setPreviewFileUrl] = useState<string | null>(null);
  
  useEffect(() => {
    fetchModifications();
  }, []);

  const fetchModifications = async () => {
    try {
      setLoading(true);
      
      // Fetch projects first
      const { data: projectsData, error: projectsError } = await supabase
        .from('projects')
        .select('id, name, project_number')
        .order('created_at', { ascending: false });

      if (projectsError) throw projectsError;

      // Fetch units with modifications
      const { data: unitsData, error: unitsError } = await supabase
        .from('units')
        .select(`
          id, 
          unit_number, 
          floor_number, 
          modifications_file_url, 
          project_id,
          modification_client_confirmed,
          modification_engineer_reviewed,
          modification_completed
        `)
        .not('modifications_file_url', 'is', null)
        .order('unit_number', { ascending: true });

      if (unitsError) throw unitsError;

      // Group units by project
      const projectsWithMods = projectsData
        .map(project => ({
          ...project,
          units: unitsData?.filter(u => u.project_id === project.id) || []
        }))
        .filter(project => project.units.length > 0);

      setProjects(projectsWithMods);
    } catch (error: any) {
      console.error('Error fetching modifications detailed:', {
        message: error?.message,
        details: error?.details,
        hint: error?.hint,
        code: error?.code,
        fullError: error
      });
    } finally {
      setLoading(false);
    }
  };

  // Filter and Search Logic
  const getFilteredProjects = () => {
    return projects.map(project => {
      const filteredUnits = project.units.filter(unit => {
        // 1. Apply Search Filter
        let matchesSearch = true;
        if (searchQuery.trim()) {
          const query = searchQuery.trim();
          
          if (query.includes('-')) {
            // Exact Project-Unit match (e.g. 101-5)
            const [pNum, uNum] = query.split('-').map(s => s.trim());
            if (pNum && uNum) {
              matchesSearch = 
                project.project_number.toString() === pNum && 
                unit.unit_number.toString() === uNum;
            } else {
              // Partial match if user is typing "101-"
              matchesSearch = project.project_number.toString().includes(pNum || '');
            }
          } else {
            // Generic search
            matchesSearch = 
              project.name.toLowerCase().includes(query.toLowerCase()) ||
              project.project_number.toString().includes(query) ||
              unit.unit_number.toString().includes(query);
          }
        }

        // 2. Apply Status Filter
        let matchesStatus = true;
        switch (filterStatus) {
          case 'client_confirmed':
            matchesStatus = unit.modification_client_confirmed === true;
            break;
          case 'engineer_reviewed':
            matchesStatus = unit.modification_engineer_reviewed === true;
            break;
          case 'completed':
            matchesStatus = unit.modification_completed === true;
            break;
          case 'pending':
            matchesStatus = !unit.modification_completed;
            break;
          default:
            matchesStatus = true;
        }

        return matchesSearch && matchesStatus;
      });

      return {
        ...project,
        units: filteredUnits
      };
    }).filter(project => project.units.length > 0);
  };

  const filteredProjects = getFilteredProjects();

  const FilterButton = ({ status, label, icon: Icon }: { status: FilterStatus, label: string, icon?: any }) => (
    <button
      onClick={() => setFilterStatus(status)}
      className={`
        flex items-center gap-2 px-3 py-1.5 md:px-4 md:py-2 rounded-xl text-xs md:text-sm font-display font-bold transition-all whitespace-nowrap
        ${filterStatus === status 
          ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/20' 
          : 'bg-white text-gray-600 hover:bg-gray-50 border border-gray-200'
        }
      `}
    >
      {Icon && <Icon size={14} className="md:w-4 md:h-4" />}
      {label}
    </button>
  );

  return (
    <div className="p-4 md:p-8 space-y-6 md:space-y-8 min-h-screen max-w-7xl mx-auto">
      <FilePreviewModal url={previewFileUrl} onClose={() => setPreviewFileUrl(null)} />
      
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div className="flex flex-col gap-2">
          <h1 className="text-2xl md:text-3xl font-display font-bold text-gray-900">تعديلات الشقق</h1>
          <p className="text-sm md:text-base text-gray-500">إدارة ومتابعة التعديلات ومراحل إنجازها</p>
        </div>
      </div>

      {/* Filters and Search Bar */}
      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 space-y-4">
        {/* Search */}
        <div className="relative">
          <Search className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
          <input
            type="text"
            placeholder="بحث (مثال: 101-5) أو اسم المشروع..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pr-12 pl-4 py-2.5 md:py-3 bg-gray-50 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all text-sm md:text-base"
            dir="rtl"
          />
          {searchQuery && (
            <button 
              onClick={() => setSearchQuery('')}
              className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              <X size={16} />
            </button>
          )}
        </div>

        {/* Filter Tabs */}
        <div className="flex flex-wrap items-center gap-2 pb-2 md:pb-0 overflow-x-auto no-scrollbar">
          <div className="flex items-center gap-2 ml-2 md:ml-4 text-gray-400 shrink-0">
            <Filter size={16} />
            <span className="text-xs md:text-sm font-display font-bold">تصفية:</span>
          </div>
          <FilterButton status="all" label="الكل" icon={Layers} />
          <FilterButton status="client_confirmed" label="العميل" icon={UserCheck} />
          <FilterButton status="engineer_reviewed" label="المهندس" icon={HardHat} />
          <FilterButton status="completed" label="مكتمل" icon={CheckCircle2} />
          <FilterButton status="pending" label="قيد التنفيذ" icon={AlertCircle} />
        </div>
      </div>

      {/* Results List */}
      <ModificationsList 
        projects={filteredProjects} 
        loading={loading} 
        onProjectsUpdate={setProjects}
        onPreviewFile={setPreviewFileUrl}
      />
    </div>
  );
}
