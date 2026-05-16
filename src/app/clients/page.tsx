'use client';

import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { 
  Users, 
  Search, 
  Plus, 
  Building2, 
  History, 
  Phone, 
  IdCard, 
  Edit2, 
  X 
} from 'lucide-react';
import { Client, Project, Unit, UnitOwnershipHistory } from '../../types';

export default function ClientsPage() {
  const [clients, setClients] = useState<Client[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [units, setUnits] = useState<Unit[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedClient, setSelectedClient] = useState<Client | null>(null);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isMergeModalOpen, setIsMergeModalOpen] = useState(false);
  const [merging, setMerging] = useState(false);
  const [duplicates, setDuplicates] = useState<{ [key: string]: Client[] }>({});
  const [newClient, setNewClient] = useState({
    name: '',
    id_number: '',
    phone: '',
    notes: ''
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      
      const [clientsRes, projectsRes, unitsRes] = await Promise.all([
        supabase.from('clients').select('*').order('created_at', { ascending: false }),
        supabase.from('projects').select('*'),
        supabase.from('units').select('*')
      ]);

      if (clientsRes.error) throw clientsRes.error;
      if (projectsRes.error) throw projectsRes.error;
      if (unitsRes.error) throw unitsRes.error;

      setClients(clientsRes.data || []);
      setProjects(projectsRes.data || []);
      setUnits(unitsRes.data || []);
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getClientUnits = (clientId: string) => {
    const clientUnits = units.filter(u => 
      u.title_deed_owner_id === clientId || 
      (u.client_id_number && clients.find(c => c.id === clientId)?.id_number === u.client_id_number)
    );

    return clientUnits.map(unit => {
      const project = projects.find(p => p.id === unit.project_id);
      return { unit, project };
    });
  };

  const addClient = async () => {
    try {
      const { error } = await supabase.from('clients').insert([newClient]);
      if (error) throw error;
      setIsAddModalOpen(false);
      setNewClient({ name: '', id_number: '', phone: '', notes: '' });
      fetchData();
    } catch (error) {
      console.error('Error adding client:', error);
      alert('حدث خطأ أثناء إضافة العميل');
    }
  };

  const findDuplicates = () => {
    const duplicatesMap: { [key: string]: Client[] } = {};
    
    clients.forEach(client => {
      if (client.id_number) {
        const key = `${client.name.trim().toLowerCase()}-${client.id_number.trim()}`;
        if (!duplicatesMap[key]) {
          duplicatesMap[key] = [];
        }
        duplicatesMap[key].push(client);
      }
    });

    const filteredDuplicates: { [key: string]: Client[] } = {};
    Object.entries(duplicatesMap).forEach(([key, list]) => {
      if (list.length > 1) {
        filteredDuplicates[key] = list;
      }
    });

    setDuplicates(filteredDuplicates);
    setIsMergeModalOpen(true);
  };

  const mergeDuplicates = async () => {
    if (Object.keys(duplicates).length === 0) {
      alert('لا يوجد عملاء مكررين');
      return;
    }

    if (!confirm('هل أنت متأكد من دمج العملاء المكررين؟')) {
      return;
    }

    try {
      setMerging(true);

      for (const [key, duplicateList] of Object.entries(duplicates)) {
        const mainClient = duplicateList[0];
        const otherClients = duplicateList.slice(1);

        for (const clientToMerge of otherClients) {
          await supabase
            .from('units')
            .update({ original_client_id: mainClient.id })
            .eq('original_client_id', clientToMerge.id);

          await supabase
            .from('units')
            .update({ current_client_id: mainClient.id })
            .eq('current_client_id', clientToMerge.id);

          await supabase
            .from('unit_ownership_history')
            .update({ client_id: mainClient.id })
            .eq('client_id', clientToMerge.id);

          await supabase
            .from('unit_ownership_history')
            .update({ previous_client_id: mainClient.id })
            .eq('previous_client_id', clientToMerge.id);

          await supabase
            .from('clients')
            .delete()
            .eq('id', clientToMerge.id);
        }

        if (otherClients.some(c => c.phone && !mainClient.phone)) {
          const clientWithPhone = otherClients.find(c => c.phone);
          if (clientWithPhone) {
            await supabase
              .from('clients')
              .update({ phone: clientWithPhone.phone })
              .eq('id', mainClient.id);
          }
        }
      }

      alert('تم دمج العملاء المكررين بنجاح!');
      setIsMergeModalOpen(false);
      setDuplicates({});
      fetchData();
    } catch (error) {
      console.error('Error merging clients:', error);
      alert('حدث خطأ أثناء دمج العملاء');
    } finally {
      setMerging(false);
    }
  };

  const filteredClients = clients.filter(client =>
    client.name.includes(searchQuery) ||
    (client.id_number && client.id_number.includes(searchQuery)) ||
    (client.phone && client.phone.includes(searchQuery))
  );

  return (
    <div className="p-4 md:p-8 space-y-6 min-h-screen max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-indigo-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-indigo-600/20">
            <Users size={24} />
          </div>
          <div>
            <h1 className="font-display font-bold text-2xl md:text-3xl text-gray-900">إدارة العملاء</h1>
            <p className="text-gray-500 text-sm">عرض شجرة العملاء والوحدات التي اشتروها</p>
          </div>
        </div>

        <div className="flex gap-2">
          <button
            onClick={findDuplicates}
            className="flex items-center justify-center gap-2 px-6 py-2.5 bg-orange-600 text-white rounded-xl hover:bg-orange-700 transition-all shadow-md hover:shadow-lg font-bold"
          >
            <Users size={20} />
            فحص العملاء المكررين
          </button>
          <button
            onClick={() => setIsAddModalOpen(true)}
            className="flex items-center justify-center gap-2 px-6 py-2.5 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 transition-all shadow-md hover:shadow-lg font-bold"
          >
            <Plus size={20} />
            إضافة عميل
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100">
        <div className="relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
          <input
            type="text"
            placeholder="ابحث باسم العميل، رقم الهوية أو رقم الهاتف..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pr-10 pl-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition-all font-sans"
          />
        </div>
      </div>

      {/* Clients List */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {loading ? (
          Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm animate-pulse">
              <div className="w-12 h-12 bg-gray-200 rounded-xl mb-4" />
              <div className="h-4 bg-gray-200 rounded w-3/4 mb-2" />
              <div className="h-3 bg-gray-200 rounded w-1/2" />
            </div>
          ))
        ) : filteredClients.length === 0 ? (
          <div className="col-span-full text-center py-12">
            <Users size={48} className="mx-auto text-gray-300 mb-4" />
            <p className="text-gray-500">لا يوجد عملاء</p>
          </div>
        ) : (
          filteredClients.map((client) => {
            const clientUnits = getClientUnits(client.id);
            return (
              <div
                key={client.id}
                onClick={() => setSelectedClient(client)}
                className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm hover:shadow-md transition-all cursor-pointer"
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="w-12 h-12 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl flex items-center justify-center text-white font-bold text-lg">
                    {client.name.charAt(0)}
                  </div>
                  <span className="text-xs text-gray-400">
                    {clientUnits.length} وحدات
                  </span>
                </div>

                <h3 className="font-bold text-gray-900 mb-2">{client.name}</h3>
                
                {client.id_number && (
                  <div className="flex items-center gap-2 text-sm text-gray-600 mb-1">
                    <IdCard size={14} />
                    <span>{client.id_number}</span>
                  </div>
                )}

                {client.phone && (
                  <div className="flex items-center gap-2 text-sm text-gray-600">
                    <Phone size={14} />
                    <span>{client.phone}</span>
                  </div>
                )}

                {clientUnits.length > 0 && (
                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <div className="flex flex-wrap gap-1">
                      {clientUnits.slice(0, 3).map(({ unit, project }) => (
                        <span
                          key={unit.id}
                          className="px-2 py-1 bg-indigo-50 text-indigo-700 text-xs rounded-lg font-bold"
                        >
                          {project?.name || 'غير معروف'} - {unit.unit_number}
                        </span>
                      ))}
                      {clientUnits.length > 3 && (
                        <span className="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded-lg font-bold">
                          +{clientUnits.length - 3}
                        </span>
                      )}
                    </div>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* Client Details Modal */}
      {selectedClient && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-100 flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-2xl flex items-center justify-center text-white font-bold text-2xl">
                  {selectedClient.name.charAt(0)}
                </div>
                <div>
                  <h2 className="font-bold text-xl text-gray-900">{selectedClient.name}</h2>
                  {selectedClient.id_number && (
                    <p className="text-gray-500 text-sm">رقم الهوية: {selectedClient.id_number}</p>
                  )}
                </div>
              </div>
              <button
                onClick={() => setSelectedClient(null)}
                className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
              >
                <X size={24} className="text-gray-500" />
              </button>
            </div>

            <div className="p-6 space-y-6">
              {/* Client Info */}
              <div className="grid grid-cols-2 gap-4">
                {selectedClient.phone && (
                  <div className="p-4 bg-gray-50 rounded-xl">
                    <div className="flex items-center gap-2 text-gray-500 text-sm mb-1">
                      <Phone size={16} />
                      رقم الهاتف
                    </div>
                    <p className="font-bold text-gray-900">{selectedClient.phone}</p>
                  </div>
                )}
                {selectedClient.notes && (
                  <div className="p-4 bg-gray-50 rounded-xl col-span-2">
                    <p className="text-gray-500 text-sm mb-1">ملاحظات</p>
                    <p className="text-gray-900">{selectedClient.notes}</p>
                  </div>
                )}
              </div>

              {/* Client Units */}
              <div>
                <h3 className="font-bold text-lg text-gray-900 mb-4 flex items-center gap-2">
                  <Building2 size={20} />
                  الوحدات الخاصة بالعميل
                </h3>
                {(() => {
                  const clientUnits = getClientUnits(selectedClient.id);
                  if (clientUnits.length === 0) {
                    return (
                      <div className="text-center py-8 bg-gray-50 rounded-xl">
                        <Building2 size={40} className="mx-auto text-gray-300 mb-2" />
                        <p className="text-gray-500">لا يوجد وحدات لهذا العميل</p>
                      </div>
                    );
                  }
                  return (
                    <div className="space-y-3">
                      {clientUnits.map(({ unit, project }) => (
                        <div key={unit.id} className="p-4 bg-white border border-gray-200 rounded-xl">
                          <div className="flex items-center justify-between mb-3">
                            <div>
                              <span className="font-bold text-gray-900">
                                {project?.name || 'غير معروف'}
                              </span>
                              <span className="mx-2 text-gray-400">•</span>
                              <span className="font-bold text-indigo-600">وحدة {unit.unit_number}</span>
                            </div>
                            <span className={`px-3 py-1 rounded-full text-xs font-bold ${
                              unit.status === 'sold' ? 'bg-red-100 text-red-700' :
                              unit.status === 'available' ? 'bg-green-100 text-green-700' :
                              'bg-gray-100 text-gray-700'
                            }`}>
                              {unit.status === 'sold' ? 'مباعة' : 
                               unit.status === 'available' ? 'غير مفرغة' : 
                               unit.status}
                            </span>
                          </div>
                          {unit.floor_number && (
                            <p className="text-sm text-gray-600">الدور: {unit.floor_number}</p>
                          )}
                          {unit.title_deed_owner && (
                            <p className="text-sm text-gray-600">مالك الصك: {unit.title_deed_owner}</p>
                          )}
                        </div>
                      ))}
                    </div>
                  );
                })()}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Add Client Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full">
            <div className="p-6 border-b border-gray-100 flex items-center justify-between">
              <h2 className="font-bold text-xl text-gray-900">إضافة عميل جديد</h2>
              <button
                onClick={() => setIsAddModalOpen(false)}
                className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
              >
                <X size={24} className="text-gray-500" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">اسم العميل *</label>
                <input
                  type="text"
                  value={newClient.name}
                  onChange={(e) => setNewClient({ ...newClient, name: e.target.value })}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  placeholder="أدخل اسم العميل"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">رقم الهوية</label>
                <input
                  type="text"
                  value={newClient.id_number}
                  onChange={(e) => setNewClient({ ...newClient, id_number: e.target.value })}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  placeholder="أدخل رقم الهوية"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">رقم الهاتف</label>
                <input
                  type="text"
                  value={newClient.phone}
                  onChange={(e) => setNewClient({ ...newClient, phone: e.target.value })}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  placeholder="أدخل رقم الهاتف"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">ملاحظات</label>
                <textarea
                  value={newClient.notes}
                  onChange={(e) => setNewClient({ ...newClient, notes: e.target.value })}
                  className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  rows={3}
                  placeholder="أدخل ملاحظات"
                />
              </div>
              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setIsAddModalOpen(false)}
                  className="flex-1 py-3 bg-gray-100 text-gray-700 rounded-xl font-bold hover:bg-gray-200 transition-colors"
                >
                  إلغاء
                </button>
                <button
                  onClick={addClient}
                  disabled={!newClient.name}
                  className="flex-1 py-3 bg-indigo-600 text-white rounded-xl font-bold hover:bg-indigo-700 transition-colors disabled:opacity-50"
                >
                  إضافة العميل
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Merge Duplicates Modal */}
      {isMergeModalOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full max-h-[80vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white">
              <h2 className="font-bold text-xl text-gray-900">العملاء المكررين</h2>
              <button
                onClick={() => setIsMergeModalOpen(false)}
                className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
              >
                <X size={24} className="text-gray-500" />
              </button>
            </div>
            <div className="p-6 space-y-6">
              {Object.keys(duplicates).length === 0 ? (
                <div className="text-center py-8">
                  <Users size={48} className="mx-auto text-gray-300 mb-4" />
                  <p className="text-gray-500">لا يوجد عملاء مكررين</p>
                </div>
              ) : (
                <>
                  <div className="space-y-4">
                    {Object.entries(duplicates).map(([key, clientList]) => (
                      <div key={key} className="bg-orange-50 border border-orange-200 rounded-xl p-4">
                        <div className="flex items-center justify-between mb-3">
                          <h3 className="font-bold text-orange-800">
                            {clientList[0].name}
                          </h3>
                          <span className="text-sm bg-orange-200 text-orange-800 px-2 py-1 rounded-full font-bold">
                            {clientList.length} نسخ
                          </span>
                        </div>
                        <div className="space-y-2">
                          {clientList.map((client, index) => (
                            <div key={client.id} className="bg-white rounded-lg p-3 border border-orange-100">
                              <div className="flex items-center justify-between">
                                <div>
                                  <p className="text-sm font-medium text-gray-900">
                                    {index === 0 ? '✓ العميل الرئيسي' : `النسخة ${index}`}
                                  </p>
                                  {client.id_number && (
                                    <p className="text-xs text-gray-500">هوية: {client.id_number}</p>
                                  )}
                                  {client.phone && (
                                    <p className="text-xs text-gray-500">هاتف: {client.phone}</p>
                                  )}
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                  <div className="flex gap-3 pt-4 border-t border-gray-100">
                    <button
                      onClick={() => setIsMergeModalOpen(false)}
                      className="flex-1 py-3 bg-gray-100 text-gray-700 rounded-xl font-bold hover:bg-gray-200 transition-colors"
                    >
                      إلغاء
                    </button>
                    <button
                      onClick={mergeDuplicates}
                      disabled={merging}
                      className="flex-1 py-3 bg-orange-600 text-white rounded-xl font-bold hover:bg-orange-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
                    >
                      {merging ? (
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      ) : (
                        <Users size={20} />
                      )}
                      {merging ? 'جاري الدمج...' : 'دمج العملاء'}
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
