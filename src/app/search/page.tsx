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
    const timer = setTimeout(() => {
      // Always search if filters are active or search term exists
      // If everything is empty/all, we can fetch all or just wait (let's fetch all for "browse" feel)
      performSearch();
    }, 300); // Reduced debounce time for more "instant" feel

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

      // Optimize: If empty search and no specific filters, don't fetch all units
      // User prefers to start with empty state until typing
      if (!trimmedTerm && statusFilter === 'all' && projectFilter === 'all') {
        setResults([]);
        setFilteredResults([]);
        setLoading(false);
        return;
      }
      
      // Check for ProjectNumber-UnitNumber format (e.g. 101-5)
      // We allow partial matches like "101-" or "101-5"
      const codeMatch = trimmedTerm.match(/^(\d+)(?:-(\d+)?)?$/);
      
      let data;
      
      // Strategy 1: Explicit Code Search (contains hyphen or just numbers that might be project code)
      // But we also want to search client names even if it looks like a number.
      // So we will combine strategies or decide based on input.
      // The user wants: "start writing 1, show me..."
      
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
        // Sanitize term for .or() filter (commas break the syntax)
        const safeTerm = trimmedTerm.replace(/,/g, ' ');
        const searchConditions = [
          `client_name.ilike.%${safeTerm}%`,
          `phone_number.ilike.%${safeTerm}%`,
          `deed_number.ilike.%${safeTerm}%`,
          `projects.project_number.ilike.%${safeTerm}%` // Search project number partially
        ];

        // Handle Unit Number search
        // Since unit_number is integer, we can only do exact match or we need to rely on the specific code format
        
        // If the term has a hyphen, it's definitely a Code search intent
        if (trimmedTerm.includes('-')) {
            const parts = trimmedTerm.split('-');
            const pNum = parts[0];
            const uNum = parts[1];
            
            if (pNum && uNum) {
                // Exact project match (or partial) AND unit match
                // We'll treat this as a specific "Project-Unit" search
                // Overriding the generic search conditions for this specific pattern
                query = query
                  .ilike('projects.project_number', `%${pNum}%`)
                  .eq('unit_number', uNum); // Exact unit number if specified
                  
                // Clear generic conditions to focus on this specific intent
                // (Or we could add it as an OR condition, but usually "110-5" is specific)
            } else if (pNum) {
                // Just "110-" -> Search project number
                searchConditions.push(`projects.project_number.ilike.%${pNum}%`);
            }
        } else {
            // No hyphen, generic search
            // If it's a number, it could be a unit number
            if (!isNaN(Number(trimmedTerm))) {
               searchConditions.push(`unit_number.eq.${trimmedTerm}`);
            }
            
            // Apply OR filter
            query = query.or(searchConditions.join(','));
        }
      } else {
        // No search term, just filters
      }

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter);
      }

      if (projectFilter !== 'all') {
        query = query.eq('project_id', projectFilter);
      }

      const { data: unitsData, error } = await query;
      if (error) throw error;
      data = unitsData;

      // Process data to flatten project info
      const processedData: SearchResultUnit[] = (data || []).map((unit: any) => ({
        ...unit,
        project_name: unit.projects?.name || '',
        project_number: unit.projects?.project_number || '',
        // Ensure ModificationUnit fields are present (defaults)
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
      console.error('Error searching:', error.message || error, error.details || '', error.hint || '');
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
