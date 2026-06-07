'use client';

import React, { useEffect, useMemo, useState } from 'react';
import dynamic from 'next/dynamic';
import Link from 'next/link';
import AddProjectModal from '../components/AddProjectModal';
import { 
  Building2, 
  Search, 
  Plus,
  ArrowUpRight,
  LayoutGrid,
  List,
  ChevronDown,
  Map
} from 'lucide-react';

import { supabase } from '../lib/supabaseClient';

type ProjectRow = {
  id: string;
  name: string;
  deedNumber: string;
  waterMeter: string;
  elecMeter: string;
  unitsCount: number;
  status: string;
  projectNumber: string;
  createdAt: string;
  lastUpdate: string;
  locationLat?: number | null;
  locationLng?: number | null;
  locationUrl?: string | null;
};

type SortKey = 'created_at' | 'name' | 'units';
type ViewMode = 'grid' | 'list' | 'map';

const ProjectsMapView = dynamic(() => import('../components/ProjectsMapView'), { ssr: false });

export default function ProjectsPage() {
  const [isAddProjectOpen, setIsAddProjectOpen] = useState(false);
  const [projects, setProjects] = useState<ProjectRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchText, setSearchText] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'under_construction' | 'completed' | 'sold'>('all');
  const [sortBy, setSortBy] = useState<SortKey>('created_at');
  const [viewMode, setViewMode] = useState<ViewMode>('grid');
  const [expandedProjectId, setExpandedProjectId] = useState<string | null>(null);

  const fetchProjects = async () => {
    try {
      setLoading(true);
      
      const { data: projectsData, error: projectsError } = await supabase
        .from('projects')
        .select(`
          *,
          units:units(count)
        `)
        .order('created_at', { ascending: false });

      if (projectsError) throw projectsError;

      if (projectsData) {
        const formattedProjects = projectsData.map((p: any) => ({
          id: p.id,
          name: p.name,
          deedNumber: p.deed_number || '-',
          waterMeter: p.water_meter || '-',
          elecMeter: p.electricity_meter || '-',
          unitsCount: p.units?.[0]?.count || 0,
          status: p.status,
          projectNumber: p.project_number,
          createdAt: p.created_at,
          lastUpdate: new Date(p.created_at).toLocaleDateString('ar-SA'),
          locationLat: typeof p.location_lat === 'number' ? p.location_lat : null,
          locationLng: typeof p.location_lng === 'number' ? p.location_lng : null,
          locationUrl: p.location_url || null
        }));
        setProjects(formattedProjects);
      }
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProjects();
  }, []);

  const getStatusColor = (status: string) => {
    switch(status) {
      case 'completed': return 'bg-green-100 text-green-700 border-green-200';
      case 'under_construction': return 'bg-blue-100 text-blue-700 border-blue-200';
      case 'sold': return 'bg-purple-100 text-purple-700 border-purple-200';
      default: return 'bg-gray-100 text-gray-700 border-gray-200';
    }
  };

  const getStatusLabel = (status: string) => {
    switch(status) {
      case 'completed': return 'مكتمل';
      case 'under_construction': return 'تحت الإنشاء';
      case 'sold': return 'مباع بالكامل';
      default: return status;
    }
  };

  const filteredProjects = useMemo(() => {
    const q = searchText.trim().toLowerCase();
    let list = [...projects];
    if (statusFilter !== 'all') list = list.filter((p) => p.status === statusFilter);
    if (q) {
      list = list.filter((p) => {
        const name = String(p.name || '').toLowerCase();
        const number = String(p.projectNumber || '').toLowerCase();
        const deed = String(p.deedNumber || '').toLowerCase();
        return name.includes(q) || number.includes(q) || deed.includes(q);
      });
    }
    list.sort((a, b) => {
      if (sortBy === 'name') return String(a.name).localeCompare(String(b.name), 'ar');
      if (sortBy === 'units') return (b.unitsCount || 0) - (a.unitsCount || 0);
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
    return list;
  }, [projects, searchText, sortBy, statusFilter]);

  return (
    <div className="min-h-screen font-sans" dir="rtl">
      <main className="p-4 md:p-8 max-w-7xl mx-auto space-y-8">
        
        <header className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-display text-gray-900 mb-2">المشاريع</h1>
            <p className="text-gray-500">عرض وإدارة المشاريع بشكل منظم</p>
          </div>
          
          <div className="flex items-center gap-3">
            <button 
              onClick={() => setIsAddProjectOpen(true)}
              className="bg-blue-600 hover:bg-blue-700 text-white px-5 py-2.5 rounded-xl flex items-center gap-2 transition-all shadow-lg shadow-blue-600/20 font-medium"
            >
              <Plus size={20} />
              <span>مشروع جديد</span>
            </button>
          </div>
        </header>

        <div className="bg-white/95 backdrop-blur rounded-xl shadow-sm border border-gray-200 p-4 md:p-5 space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-7 gap-3">
            <div className="md:col-span-3 relative">
              <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                placeholder="بحث باسم المشروع أو رقم المشروع أو رقم الصك..."
                className="w-full pr-10 pl-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
              />
            </div>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="all">كل الحالات</option>
              <option value="under_construction">تحت الإنشاء</option>
              <option value="completed">مكتمل</option>
              <option value="sold">مباع بالكامل</option>
            </select>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as any)}
              className="w-full py-2.5 px-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-sans"
            >
              <option value="created_at">الأحدث</option>
              <option value="name">حسب الاسم</option>
              <option value="units">حسب الوحدات</option>
            </select>
            <div className="rounded-xl border border-gray-200 bg-gray-50 p-1 flex items-center gap-1 overflow-x-auto whitespace-nowrap">
              <button
                type="button"
                onClick={() => setViewMode('grid')}
                className={[
                  'min-w-[110px] flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-sm font-bold transition-colors',
                  viewMode === 'grid' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600 hover:text-gray-900'
                ].join(' ')}
              >
                <LayoutGrid size={16} />
                شبكة
              </button>
              <button
                type="button"
                onClick={() => setViewMode('list')}
                className={[
                  'min-w-[110px] flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-sm font-bold transition-colors',
                  viewMode === 'list' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600 hover:text-gray-900'
                ].join(' ')}
              >
                <List size={16} />
                قائمة
              </button>
              <button
                type="button"
                onClick={() => setViewMode('map')}
                className={[
                  'min-w-[110px] flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-sm font-bold transition-colors',
                  viewMode === 'map' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600 hover:text-gray-900'
                ].join(' ')}
              >
                <Map size={16} />
                خريطة
              </button>
            </div>
            <div className="rounded-xl border border-gray-200 bg-gray-50 px-4 py-2.5 text-sm text-gray-700 flex items-center justify-between">
              <span className="font-bold">الإجمالي</span>
              <span className="font-extrabold">{filteredProjects.length}</span>
            </div>
          </div>
        </div>

        <div>
          {loading ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-44 bg-white/50 rounded-md animate-pulse border border-gray-100"></div>
              ))}
            </div>
          ) : (
            <>
              {viewMode === 'map' ? (
                <ProjectsMapView projects={filteredProjects} />
              ) : viewMode === 'grid' ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
                  {filteredProjects.map((project) => (
                    <Link 
                      href={`/projects/${project.id}`} 
                      key={project.id}
                      className="group bg-white rounded-md border border-slate-300 shadow-sm hover:shadow-md hover:border-blue-400 transition-all duration-200 overflow-hidden flex flex-col"
                    >
                      <div className="p-3 md:p-4 flex-1">
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <h3 className="text-base md:text-lg font-display font-extrabold text-gray-900 leading-6 truncate">
                              {project.name}
                            </h3>
                            <div className="mt-1 text-[11px] md:text-xs text-gray-600 font-bold">
                              رقم المشروع: <span className="font-extrabold text-gray-900">{project.projectNumber || '-'}</span>
                            </div>
                          </div>
                          <span className={`shrink-0 px-2 py-0.5 rounded-md text-[10px] md:text-xs font-extrabold border ${getStatusColor(project.status)}`}>
                            {getStatusLabel(project.status)}
                          </span>
                        </div>

                        <div className="mt-3 grid grid-cols-2 gap-2">
                          <div className="bg-gray-50 rounded-md p-2 border border-gray-100">
                            <div className="text-[10px] text-gray-500 font-bold">عدد الوحدات</div>
                            <div className="mt-0.5 text-sm md:text-base font-extrabold text-gray-900">{project.unitsCount}</div>
                          </div>
                          <div className="bg-gray-50 rounded-md p-2 border border-gray-100">
                            <div className="text-[10px] text-gray-500 font-bold">رقم الصك</div>
                            <div className="mt-0.5 text-[11px] md:text-sm font-extrabold text-gray-900 truncate">{project.deedNumber}</div>
                          </div>
                        </div>

                        <div className="mt-3">
                          <div className="inline-flex items-center justify-center w-full px-3 py-2 rounded-md border border-teal-950 bg-gradient-to-l from-emerald-900 via-teal-900 to-blue-900 text-white text-xs md:text-sm font-extrabold hover:from-emerald-950 hover:via-teal-950 hover:to-blue-950 transition-colors">
                            عرض المشروع
                          </div>
                        </div>
                      </div>

                      <div className="px-3 py-2 md:px-4 md:py-2.5 bg-gray-50 border-t border-slate-200 flex items-center justify-between">
                        <span className="text-[10px] md:text-xs text-gray-500 font-bold">
                          تحديث: {project.lastUpdate}
                        </span>
                        <span className="text-blue-600 opacity-0 group-hover:opacity-100 transition-opacity">
                          <ArrowUpRight size={16} />
                        </span>
                      </div>
                    </Link>
                  ))}

                  <button
                    onClick={() => setIsAddProjectOpen(true)}
                    className="group flex flex-col items-center justify-center gap-2 bg-white rounded-md border-2 border-dashed border-gray-200 hover:border-blue-300 hover:bg-blue-50/30 transition-colors min-h-[170px]"
                  >
                    <div className="w-11 h-11 rounded-md bg-white shadow-sm border border-gray-200 flex items-center justify-center text-gray-500 group-hover:text-blue-600 transition-colors">
                      <Plus size={22} />
                    </div>
                    <div className="text-center px-2">
                      <div className="text-sm font-extrabold text-gray-900 group-hover:text-blue-700 transition-colors">إضافة مشروع</div>
                      <div className="text-[11px] text-gray-500 font-bold mt-0.5">مشروع جديد</div>
                    </div>
                  </button>
                </div>
              ) : (
                <div className="space-y-2">
                  {filteredProjects.map((project) => (
                    <div
                      key={project.id}
                      role="button"
                      tabIndex={0}
                      onClick={() => setExpandedProjectId((prev) => (prev === project.id ? null : project.id))}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          setExpandedProjectId((prev) => (prev === project.id ? null : project.id));
                        }
                      }}
                      className={[
                        'group bg-white rounded-md border-2 border-slate-300 shadow-sm hover:shadow-md hover:border-slate-400 transition-all duration-200 px-4 py-3 overflow-hidden select-none',
                        expandedProjectId === project.id ? 'ring-2 ring-teal-200 border-slate-400' : ''
                      ].join(' ')}
                    >
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex items-center gap-3 min-w-0">
                          <div className="w-10 h-10 rounded-md bg-slate-50 border border-slate-200 text-slate-700 flex items-center justify-center shrink-0">
                            <Building2 size={18} />
                          </div>
                          <div className="min-w-0">
                            <div className="flex items-center gap-2 min-w-0">
                              <div className="font-extrabold text-gray-900 truncate">{project.name}</div>
                              <span className={`shrink-0 px-2 py-0.5 rounded-md text-[10px] font-extrabold border ${getStatusColor(project.status)}`}>
                                {getStatusLabel(project.status)}
                              </span>
                            </div>
                            <div className="mt-1 text-[11px] text-gray-600 font-bold truncate">
                              رقم المشروع: <span className="font-extrabold text-gray-900">{project.projectNumber || '-'}</span>
                            </div>
                          </div>
                        </div>

                        <div className="shrink-0">
                          <ChevronDown
                            size={18}
                            className={[
                              'text-slate-500 transition-transform',
                              expandedProjectId === project.id ? 'rotate-180' : ''
                            ].join(' ')}
                          />
                        </div>
                      </div>

                      {expandedProjectId === project.id && (
                        <div className="mt-3 pt-3 border-t border-slate-200">
                          <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                            <div className="rounded-md bg-slate-50 border border-slate-200 p-2">
                              <div className="text-[10px] text-slate-500 font-bold">رقم الصك</div>
                              <div className="mt-0.5 text-[11px] font-extrabold text-gray-900 truncate">{project.deedNumber}</div>
                            </div>
                            <div className="rounded-md bg-slate-50 border border-slate-200 p-2">
                              <div className="text-[10px] text-slate-500 font-bold">عدد الوحدات</div>
                              <div className="mt-0.5 text-[11px] font-extrabold text-gray-900">{project.unitsCount}</div>
                            </div>
                            <div className="rounded-md bg-slate-50 border border-slate-200 p-2">
                              <div className="text-[10px] text-slate-500 font-bold">عداد المياه</div>
                              <div className="mt-0.5 text-[11px] font-extrabold text-gray-900 truncate">{project.waterMeter}</div>
                            </div>
                            <div className="rounded-md bg-slate-50 border border-slate-200 p-2">
                              <div className="text-[10px] text-slate-500 font-bold">عداد الكهرباء</div>
                              <div className="mt-0.5 text-[11px] font-extrabold text-gray-900 truncate">{project.elecMeter}</div>
                            </div>
                          </div>

                          <div className="mt-3 flex items-center justify-between gap-2">
                            <div className="text-[11px] text-gray-500 font-bold">
                              آخر تحديث: <span className="font-extrabold text-gray-800">{project.lastUpdate}</span>
                            </div>
                            <Link
                              href={`/projects/${project.id}`}
                              onClick={(e) => e.stopPropagation()}
                              className="inline-flex items-center justify-center px-3 py-2 rounded-md border border-teal-950 bg-gradient-to-l from-emerald-900 via-teal-900 to-blue-900 text-white text-[11px] font-extrabold hover:from-emerald-950 hover:via-teal-950 hover:to-blue-950 transition-colors"
                            >
                              عرض المشروع
                            </Link>
                          </div>
                        </div>
                      )}
                    </div>
                  ))}

                  <button
                    onClick={() => setIsAddProjectOpen(true)}
                    className="w-full bg-white rounded-md border-2 border-dashed border-gray-200 hover:border-blue-300 hover:bg-blue-50/30 transition-colors px-3 py-3"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-md bg-white border border-gray-200 text-gray-600 flex items-center justify-center">
                          <Plus size={20} />
                        </div>
                        <div className="text-right">
                          <div className="font-extrabold text-gray-900">إضافة مشروع</div>
                          <div className="text-[11px] text-gray-500 font-bold mt-0.5">مشروع جديد</div>
                        </div>
                      </div>
                      <span className="text-blue-700 font-extrabold text-sm">فتح</span>
                    </div>
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </main>

      <AddProjectModal 
        isOpen={isAddProjectOpen} 
        onClose={() => setIsAddProjectOpen(false)} 
        onSave={fetchProjects}
      />
    </div>
  );
}
