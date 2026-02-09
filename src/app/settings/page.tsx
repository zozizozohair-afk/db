/** @jsxImportSource react */
'use client';

import React, { useState } from 'react';
import { Settings, Server, KeyRound, CheckCircle2, AlertCircle } from 'lucide-react';
import { supabase } from '../../lib/supabaseClient';

export default function SettingsPage() {
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{ ok: boolean; message: string } | null>(null);

  const envUrl = typeof process !== 'undefined' ? process.env.NEXT_PUBLIC_SUPABASE_URL || '' : '';
  const envAnon = typeof process !== 'undefined' ? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '' : '';

  const handleTestConnection = async () => {
    setTesting(true);
    setTestResult(null);
    try {
      const { error } = await supabase.from('projects').select('*', { head: true, count: 'estimated' });
      if (error) throw error;
      setTestResult({ ok: true, message: 'الاتصال ناجح وتم الوصول لقاعدة البيانات' });
    } catch (e: any) {
      setTestResult({ ok: false, message: e?.message || 'تعذر الاتصال بقاعدة البيانات' });
    } finally {
      setTesting(false);
    }
  };

  return (
    <div className="p-6">
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 bg-blue-600 text-white rounded-xl flex items-center justify-center">
            <Settings size={22} />
          </div>
          <h1 className="font-display font-bold text-xl text-gray-900">الإعدادات</h1>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="border border-gray-100 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-3 text-gray-800 font-bold">
              <Server size={18} className="text-blue-600" />
              Supabase URL
            </div>
            <div className="text-sm font-mono bg-gray-50 rounded-lg p-3 text-gray-700 break-all">
              {envUrl ? envUrl : 'غير مضبوط'}
            </div>
          </div>

          <div className="border border-gray-100 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-3 text-gray-800 font-bold">
              <KeyRound size={18} className="text-blue-600" />
              Supabase Anon Key
            </div>
            <div className="text-sm font-mono bg-gray-50 rounded-lg p-3 text-gray-700 break-all">
              {envAnon ? '******' : 'غير مضبوط'}
            </div>
          </div>
        </div>

        <div className="mt-6 flex items-center gap-3">
          <button
            onClick={handleTestConnection}
            disabled={testing}
            className={`px-4 py-2 rounded-lg text-white font-bold ${testing ? 'bg-blue-400' : 'bg-blue-600 hover:bg-blue-700'}`}
          >
            {testing ? 'جاري الاختبار...' : 'اختبار الاتصال بـ Supabase'}
          </button>
          {testResult && (
            <div
              className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-bold ${
                testResult.ok ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'
              }`}
            >
              {testResult.ok ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
              {testResult.message}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
