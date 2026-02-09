'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import AddProjectModal from '../components/AddProjectModal';
import { 
  Building2, 
  FileText, 
  Users, 
  LayoutDashboard, 
  Settings, 
  Search, 
  Bell, 
  FolderOpen,
  Zap,
  Droplets,
  Plus,
  ChevronLeft,
  FileCheck,
  ArrowUpRight
} from 'lucide-react';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend
} from 'recharts';

import { supabase } from '../lib/supabaseClient';

// Colors for charts
const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6'];

export default function Dashboard() {
  const [isAddProjectOpen, setIsAddProjectOpen] = useState(false);
  const [projects, setProjects] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalProjects: 0,
    totalUnits: 0,
    archivedDeeds: 0,
    filesUnderReview: 0
  });

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      
      // 1. Fetch Projects with Unit Count
      const { data: projectsData, error: projectsError } = await supabase
        .from('projects')
        .select(`
          *,
          units:units(count)
        `)
        .order('created_at', { ascending: false });

      if (projectsError) throw projectsError;

      // 2. Fetch Total Stats
      const { count: projectsCount } = await supabase
        .from('projects')
        .select('*', { count: 'exact', head: true });
      
      const { count: unitsCount } = await supabase
        .from('units')
        .select('*', { count: 'exact', head: true });

      const { count: deedsCount } = await supabase
        .from('projects')
        .select('*', { count: 'exact', head: true })
        .not('deed_number', 'is', null);

      if (projectsData) {
        // Transform data for UI
        const formattedProjects = projectsData.map((p: any) => ({
          id: p.id,
          name: p.name,
          deedNumber: p.deed_number || '-',
          waterMeter: p.water_meter || '-',
          elecMeter: p.electricity_meter || '-',
          unitsCount: p.units?.[0]?.count || 0,
          status: p.status,
          projectNumber: p.project_number,
          lastUpdate: new Date(p.created_at).toLocaleDateString('ar-SA')
        }));
        setProjects(formattedProjects);
      }

      setStats({
        totalProjects: projectsCount || 0,
        totalUnits: unitsCount || 0,
        archivedDeeds: deedsCount || 0,
        filesUnderReview: 0 
      });

    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDashboardData();
  }, []);

  // Prepare Chart Data
  const statusData = [
    { name: 'تحت الإنشاء', value: projects.filter(p => p.status === 'under_construction').length },
    { name: 'مكتمل', value: projects.filter(p => p.status === 'completed').length },
    { name: 'مباع', value: projects.filter(p => p.status === 'sold').length },
  ].filter(item => item.value > 0);

  const unitsData = projects.slice(0, 5).map(p => ({
    name: p.name,
    units: p.unitsCount
  }));

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

  return (
    <div className="min-h-screen font-sans" dir="rtl">
      {/* Sidebar - Simplified for this view, usually in Layout but included here for visual context if needed, 
          but we'll assume a layout wrapper or just full page dashboard */}
      
      <main className="p-4 md:p-8 max-w-7xl mx-auto space-y-8">
        
        {/* Header */}
        <header className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-display text-gray-900 mb-2">لوحة المعلومات</h1>
            <p className="text-gray-500">مرحباً بك في نظام مساكن لإدارة المشاريع</p>
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

        {/* Stats Grid */}
        <div className="grid grid-cols-2 md:grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4">
          <StatCard 
            title="إجمالي المشاريع" 
            value={stats.totalProjects} 
            icon={<Building2 size={18} className="text-blue-600" />}
            trend="+2.5%"
            color="blue"
          />
          <StatCard 
            title="إجمالي الوحدات" 
            value={stats.totalUnits} 
            icon={<HomeIcon size={18} className="text-emerald-600" />}
            trend="+12%"
            color="emerald"
          />
          <StatCard 
            title="الصكوك المؤرشفة" 
            value={stats.archivedDeeds} 
            icon={<FileCheck size={18} className="text-purple-600" />}
            trend="+5%"
            color="purple"
          />
          <StatCard 
            title="ملفات تحت المراجعة" 
            value={stats.filesUnderReview} 
            icon={<FolderOpen size={18} className="text-amber-600" />}
            trend="0%"
            color="amber"
          />
        </div>

        {/* Projects Cards Grid */}
        <div>
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-2xl font-display text-gray-900">المشاريع الحديثة</h2>
            <button className="text-blue-600 hover:text-blue-700 text-sm font-medium flex items-center gap-1">
              عرض الكل
              <ChevronLeft size={16} />
            </button>
          </div>

          {loading ? (
            <div className="grid grid-cols-2 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-64 bg-white/50 rounded-2xl animate-pulse border border-gray-100"></div>
              ))}
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
              {projects.map((project) => (
                <Link 
                  href={`/projects/${project.id}`} 
                  key={project.id}
                  className="group bg-white rounded-2xl border border-gray-100 shadow-[0_2px_8px_rgba(0,0,0,0.04)] hover:shadow-[0_8px_24px_rgba(0,0,0,0.08)] hover:border-blue-100 hover:-translate-y-1 transition-all duration-300 overflow-hidden flex flex-col relative"
                >
                  <div className="absolute top-0 right-0 w-full h-1 bg-gradient-to-l from-blue-500 to-blue-600 opacity-0 group-hover:opacity-100 transition-opacity" />
                  
                  <div className="p-4 md:p-6 flex-1">
                    <div className="flex justify-between items-start mb-4">
                      <div className={`p-2.5 md:p-3 rounded-xl bg-blue-50 text-blue-600 group-hover:bg-blue-600 group-hover:text-white transition-colors duration-300`}>
                        <Building2 size={20} className="md:w-6 md:h-6" />
                      </div>
                      <span className={`px-2 py-0.5 md:px-3 md:py-1 rounded-full text-[10px] md:text-xs font-medium border ${getStatusColor(project.status)}`}>
                        {getStatusLabel(project.status)}
                      </span>
                    </div>

                    <h3 className="text-lg md:text-xl font-display font-bold text-gray-900 mb-2 group-hover:text-blue-600 transition-colors line-clamp-1">
                      {project.name}
                    </h3>
                    <p className="text-gray-500 text-xs md:text-sm mb-4 md:mb-6 line-clamp-2">
                      رقم المشروع: {project.projectNumber || '-'} | الصك: {project.deedNumber}
                    </p>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-2 md:gap-4">
                      <div className="bg-gray-50/80 rounded-lg p-2 md:p-3">
                        <span className="text-[10px] md:text-xs text-gray-500 block mb-1">عدد الوحدات</span>
                        <span className="text-sm md:text-lg font-bold text-gray-900">{project.unitsCount}</span>
                      </div>
                      <div className="bg-gray-50/80 rounded-lg p-2 md:p-3 hidden md:block">
                        <span className="text-xs text-gray-500 block mb-1">الكهرباء</span>
                        <span className="text-lg font-bold text-gray-900 font-mono text-sm truncate">
                          {project.elecMeter !== '-' ? 'متوفر' : '-'}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="px-4 py-3 md:px-6 md:py-4 bg-gray-50/50 border-t border-gray-50 flex items-center justify-between">
                    <span className="text-[10px] md:text-xs text-gray-500">
                      تحديث: {project.lastUpdate}
                    </span>
                    <span className="text-blue-600 opacity-0 group-hover:opacity-100 group-hover:-translate-x-1 transition-all duration-300 transform translate-x-2">
                      <ArrowUpRight size={16} className="md:w-[18px] md:h-[18px]" />
                    </span>
                  </div>
                </Link>
              ))}
              
              {/* Add New Project Card */}
              <button
                onClick={() => setIsAddProjectOpen(true)}
                className="group flex flex-col items-center justify-center gap-3 md:gap-4 bg-white/50 rounded-2xl border-2 border-dashed border-gray-200 hover:border-blue-400 hover:bg-blue-50/30 transition-all duration-300 min-h-[250px] md:min-h-[300px]"
              >
                <div className="w-12 h-12 md:w-16 md:h-16 rounded-full bg-white shadow-sm flex items-center justify-center text-gray-400 group-hover:text-blue-600 group-hover:scale-110 transition-all duration-300">
                  <Plus size={24} className="md:w-8 md:h-8" />
                </div>
                <div className="text-center px-2">
                  <h3 className="text-base md:text-lg font-bold text-gray-900 group-hover:text-blue-600 transition-colors">إضافة مشروع</h3>
                  <p className="text-xs md:text-sm text-gray-500 mt-1">مشروع جديد</p>
                </div>
              </button>
            </div>
          )}
        </div>

        {/* Charts Section */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Projects Chart */}
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm lg:col-span-2">
            <h3 className="text-lg font-display text-gray-900 mb-6">الوحدات لكل مشروع</h3>
            <div className="h-[300px] w-full" dir="ltr">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={unitsData}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f3f4f6" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: '#6b7280'}} dy={10} />
                  <YAxis axisLine={false} tickLine={false} tick={{fill: '#6b7280'}} />
                  <Tooltip 
                    cursor={{fill: '#f9fafb'}}
                    contentStyle={{borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)'}}
                  />
                  <Bar dataKey="units" fill="#3b82f6" radius={[6, 6, 0, 0]} barSize={40} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Status Chart */}
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
            <h3 className="text-lg font-display text-gray-900 mb-6">حالة المشاريع</h3>
            <div className="h-[300px] w-full flex items-center justify-center" dir="ltr">
              {statusData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={statusData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={100}
                      fill="#8884d8"
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {statusData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip contentStyle={{borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)'}} />
                    <Legend verticalAlign="bottom" height={36} iconType="circle" />
                  </PieChart>
                </ResponsiveContainer>
              ) : (
                <div className="text-gray-400 text-sm">لا توجد بيانات كافية</div>
              )}
            </div>
          </div>
        </div>
      </main>

      <AddProjectModal 
        isOpen={isAddProjectOpen} 
        onClose={() => setIsAddProjectOpen(false)} 
        onSave={fetchDashboardData}
      />
    </div>
  );
}

// Helper Component for Stats
function StatCard({ title, value, icon, trend, color }: { title: string, value: number, icon: React.ReactNode, trend: string, color: string }) {
  return (
    <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm hover:shadow-md transition-shadow">
      <div className="flex justify-between items-start mb-3">
        <div className={`p-2 rounded-lg bg-${color}-50`}>
          {icon}
        </div>
        <span className="flex items-center text-[10px] font-medium text-green-600 bg-green-50 px-1.5 py-0.5 rounded-full">
          {trend}
          <ArrowUpRight size={10} className="mr-1" />
        </span>
      </div>
      <div>
        <h3 className="text-gray-500 text-xs font-medium mb-1 truncate">{title}</h3>
        <p className="text-2xl font-display font-bold text-gray-900">{value}</p>
      </div>
    </div>
  );
}

// Icon wrapper for Home since we imported it but Lucide exports it as Home
function HomeIcon(props: any) {
  return <Building2 {...props} />;
}
