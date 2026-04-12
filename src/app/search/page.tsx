'use client';

import React, { useState, useEffect } from 'react';
import { 
  Search, 
  Filter, 
  LayoutGrid, 
  FileText, 
  Hammer,
  X,
  Loader2
} from 'lucide-react';
import { supabase } from '../../lib/supabaseClient';
import UnitCard from '../../components/UnitCard';
import DeedsTable, { EnrichedUnit } from '../../components/DeedsTable';
import ModificationsList, { ProjectWithModifications, ModificationUnit } from '../../components/ModificationsList';
import MessageModal from '../../components/MessageModal';
import FilePreviewModal from '../../components/FilePreviewModal';

// Combined type for search results to satisfy all components
interface SearchResultUnit extends EnrichedUnit {
  // Fields needed for ModificationUnit
  modifications_file_url: string;
  modification_client_confirmed: boolean;
  modification_engineer_reviewed: boolean;
  modification_completed: boolean;
  project_id: string;
  // Fields from EnrichedUnit (already included via extends)
  // project_name: string;
  // project_number: string;
}

export default function SearchPage() {
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<'all' | 'units' | 'deeds' | 'modifications'>('all');
  
  // Data state
  const [results, setResults] = useState<SearchResultUnit[]>([]);
  const [filteredResults, setFilteredResults] = useState<SearchResultUnit[]>([]);
  
  // Filter state
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [projectFilter, setProjectFilter] = useState<string>('all');
  const [projectsList, setProjectsList] = useState<{id: string, name: string}[]>([]);

  // Modal state
  const [selectedUnitForMessage, setSelectedUnitForMessage] = useState<EnrichedUnit | null>(null);
  const [previewFileUrl, setPreviewFileUrl] = useState<string | null>(null);

  // Initial load - fetch projects for filter
  useEffect(() => {
    fetchProjects();
  }, []);

  // Search effect with debounce
  useEffect(() => {
    // Dynamic debounce: Wait longer for numeric inputs (unit/project codes) to allow finishing typing
    const isNumeric = /^\d/.test(searchTerm.trim());
    const delay = isNumeric ? 800 : 300; 

    const timer = setTimeout(() => {
      // Always search if filters are active or search term exists
      // If everything is empty/all, we can fetch all or just wait (let's fetch all for "browse" feel)
      performSearch();
    }, delay);

    return () => clearTimeout(timer);
  }, [searchTerm, statusFilter, projectFilter]);

  const fetchProjects = async () => {
    const { data } = await supabase.from('projects').select('id, name');
    if (data) setProjectsList(data);
  };

 const performSearch = async () => {
  setLoading(true);

  try {
    const trimmedTerm = searchTerm.trim();

    if (!trimmedTerm && statusFilter === 'all' && projectFilter === 'all') {
      setResults([]);
      setFilteredResults([]);
      setLoading(false);
      return;
    }

    let query = supabase
      .from('units')
      .select(`
        *,
        projects!inner (
          id,
          name,
          project_number
        )
      `);

    if (trimmedTerm) {
      const safeTerm = trimmedTerm.replace(/,/g, ' ').trim();

      const { data: projectMatches } = await supabase
        .from('projects')
        .select('id')
        .ilike('project_number', `%${safeTerm}%`);

      const matchedProjectIds = projectMatches?.map((p) => p.id) || [];

      const searchConditions: string[] = [
        `client_name.ilike.%${safeTerm}%`,
        `client_phone.ilike.%${safeTerm}%`
      ];

      // دعم البحث برقم الصك
      // إذا كان الإدخال رقمياً نضيف eq
      if (!isNaN(Number(safeTerm))) {
        searchConditions.push(`deed_number.eq.${safeTerm}`);
      }

      // إذا كان deed_number مخزن كنص، هذا يفيد للبحث الجزئي
      searchConditions.push(`deed_number.ilike.%${safeTerm}%`);

      if (matchedProjectIds.length > 0) {
        searchConditions.push(`project_id.in.(${matchedProjectIds.join(',')})`);
      }

      const codeMatch = safeTerm.match(/^(\d+)(?:-(\d+)?)?$/);

      if (safeTerm.includes('-') && codeMatch) {
        const pNum = codeMatch[1];
        const uNum = codeMatch[2];

        if (pNum && uNum) {
          const { data: exactProjectMatches } = await supabase
            .from('projects')
            .select('id')
            .ilike('project_number', `%${pNum}%`);

          const exactProjectIds = exactProjectMatches?.map((p) => p.id) || [];

          if (exactProjectIds.length > 0) {
            query = query
              .in('project_id', exactProjectIds)
              .eq('unit_number', Number(uNum));
          } else {
            query = query.eq('unit_number', Number(uNum));
          }
        } else if (pNum) {
          const { data: onlyProjectMatches } = await supabase
            .from('projects')
            .select('id')
            .ilike('project_number', `%${pNum}%`);

          const onlyProjectIds = onlyProjectMatches?.map((p) => p.id) || [];

          if (onlyProjectIds.length > 0) {
            query = query.in('project_id', onlyProjectIds);
          } else {
            setResults([]);
            setFilteredResults([]);
            setLoading(false);
            return;
          }
        }
      } else {
        // إذا كان الإدخال رقمياً، نضيف أيضاً رقم الوحدة
        if (!isNaN(Number(safeTerm))) {
          searchConditions.push(`unit_number.eq.${safeTerm}`);
        }

        if (searchConditions.length > 0) {
          query = query.or(searchConditions.join(','));
        }
      }
    }

    if (statusFilter !== 'all') {
      query = query.eq('status', statusFilter);
    }

    if (projectFilter !== 'all') {
      query = query.eq('project_id', projectFilter);
    }

    const { data: unitsData, error } = await query;

    if (error) throw error;

    const processedData: SearchResultUnit[] = (unitsData || []).map((unit: any) => ({
      ...unit,
      project_name: unit.projects?.name || '',
      project_number: unit.projects?.project_number || '',
      modifications_file_url: unit.modifications_file_url || '',
      modification_client_confirmed: unit.modification_client_confirmed || false,
      modification_engineer_reviewed: unit.modification_engineer_reviewed || false,
      modification_completed: unit.modification_completed || false,
      floor_number: unit.floor_number || 0,
      project_id: unit.project_id || unit.projects?.id
    }));

    setResults(processedData);
    setFilteredResults(processedData);
  } catch (error: any) {
    console.error(
      'Error searching:',
      error.message || error,
      error.details || '',
      error.hint || ''
    );
  } finally {
    setLoading(false);
  }
};

  // Prepare data for ModificationsList
  const getModificationsData = (): ProjectWithModifications[] => {
    // Group results by project
    const projectsMap = new Map<string, ProjectWithModifications>();

    filteredResults.forEach(unit => {
      // Filter: Only show units with modifications (file uploaded)
      // The user specifically asked to only see units with modifications in this view
      if (!unit.modifications_file_url) return;

      if (!projectsMap.has(unit.project_id)) {
        projectsMap.set(unit.project_id, {
          id: unit.project_id,
          name: unit.project_name,
          project_number: unit.project_number,
          units: []
        });
      }
      
      const project = projectsMap.get(unit.project_id)!;
      project.units.push({
        id: unit.id,
        unit_number: String(unit.unit_number),
        floor_number: String(unit.floor_number),
        modifications_file_url: unit.modifications_file_url,
        project_id: unit.project_id,
        modification_client_confirmed: unit.modification_client_confirmed,
        modification_engineer_reviewed: unit.modification_engineer_reviewed,
        modification_completed: unit.modification_completed
      });
    });

    return Array.from(projectsMap.values());
  };

  // Handler for modification updates
  const handleModificationsUpdate = (updatedProjects: ProjectWithModifications[]) => {
    // Optimistic update of local state
    const newResults = [...results];
    updatedProjects.forEach(p => {
        p.units.forEach(u => {
            const index = newResults.findIndex(r => r.id === u.id);
            if (index !== -1) {
                newResults[index] = {
                    ...newResults[index],
                    ...u,
                    unit_number: newResults[index].unit_number,
                    floor_number: newResults[index].floor_number
                };
            }
        });
    });
    setResults(newResults);
    setFilteredResults(newResults);
  };

  return (
    <div className="p-6 max-w-[1920px] mx-auto space-y-8" dir="rtl">
      {/* Header & Search */}
      <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
        <h1 className="text-2xl font-bold font-display text-gray-900 mb-6">البحث الشامل</h1>
        
        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="ابحث برقم الوحدة، اسم العميل، رقم الجوال، أو رقم الصك..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pr-12 pl-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            />
          </div>
          
          <div className="flex gap-4">
            <select
              value={projectFilter}
              onChange={(e) => setProjectFilter(e.target.value)}
              className="px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none"
            >
              <option value="all">كل المشاريع</option>
              {projectsList.map(p => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
            
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none"
            >
              <option value="all">كل الحالات</option>
              <option value="available">غير مباعة</option>
              <option value="sold">مباعة</option>
              <option value="sold_to_other">مباعة لآخر</option>
              <option value="resale">إعادة بيع</option>
              <option value="pending_sale">قيد البيع</option>
            </select>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 mt-6 border-b border-gray-100">
          <button
            onClick={() => setActiveTab('all')}
            className={`px-6 py-3 font-medium text-sm transition-colors relative ${
              activeTab === 'all' ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            الكل
            {activeTab === 'all' && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600 rounded-t-full" />}
          </button>
          <button
            onClick={() => setActiveTab('units')}
            className={`px-6 py-3 font-medium text-sm transition-colors relative flex items-center gap-2 ${
              activeTab === 'units' ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            <LayoutGrid className="w-4 h-4" />
            الوحدات
            {activeTab === 'units' && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600 rounded-t-full" />}
          </button>
          <button
            onClick={() => setActiveTab('deeds')}
            className={`px-6 py-3 font-medium text-sm transition-colors relative flex items-center gap-2 ${
              activeTab === 'deeds' ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            <FileText className="w-4 h-4" />
            الصكوك
            {activeTab === 'deeds' && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600 rounded-t-full" />}
          </button>
          <button
            onClick={() => setActiveTab('modifications')}
            className={`px-6 py-3 font-medium text-sm transition-colors relative flex items-center gap-2 ${
              activeTab === 'modifications' ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            <Hammer className="w-4 h-4" />
            التعديلات
            {activeTab === 'modifications' && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600 rounded-t-full" />}
          </button>
        </div>
      </div>

      {/* Content */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-8 h-8 animate-spin text-blue-600" />
        </div>
      ) : filteredResults.length === 0 ? (
        <div className="text-center py-12 text-gray-500 bg-white rounded-2xl border border-gray-100 border-dashed">
          لا توجد نتائج مطابقة للبحث
        </div>
      ) : (
        <div className="space-y-8">
          
          {/* Units Section */}
          {(activeTab === 'all' || activeTab === 'units') && (
            <section>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
                  <LayoutGrid className="w-5 h-5 text-blue-600" />
                  الوحدات
                  <span className="text-sm font-normal text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full">
                    {filteredResults.length}
                  </span>
                </h2>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                {filteredResults.map(unit => (
                  <div key={unit.id} className="h-full">
                    <UnitCard 
                      unit={unit} 
                      showProjectName={true} 
                      projectName={unit.project_name} 
                    />
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* Deeds Section */}
          {(activeTab === 'all' || activeTab === 'deeds') && (
            <section>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
                  <FileText className="w-5 h-5 text-blue-600" />
                  الصكوك
                </h2>
              </div>
              <DeedsTable 
                units={filteredResults} 
                loading={false} 
                onMessageClick={setSelectedUnitForMessage} 
              />
            </section>
          )}

          {/* Modifications Section */}
          {(activeTab === 'all' || activeTab === 'modifications') && (
            <section>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
                  <Hammer className="w-5 h-5 text-blue-600" />
                  التعديلات
                </h2>
              </div>
              <ModificationsList 
                projects={getModificationsData()} 
                loading={false} 
                onProjectsUpdate={handleModificationsUpdate}
                onPreviewFile={setPreviewFileUrl}
              />
            </section>
          )}
        </div>
      )}

      {/* Modals */}
      {selectedUnitForMessage && (
        <MessageModal
          isOpen={!!selectedUnitForMessage}
          onClose={() => setSelectedUnitForMessage(null)}
          unit={selectedUnitForMessage}
        />
      )}

      {previewFileUrl && (
        <FilePreviewModal
          url={previewFileUrl}
          onClose={() => setPreviewFileUrl(null)}
        />
      )}
    </div>
  );
}
