import React, { useState, useEffect } from 'react';
import { 
  MessageCircle, 
  Send, 
  Copy, 
  Check, 
  ChevronRight, 
  X 
} from 'lucide-react';
import { Unit } from '../types';

type MessageType = 'deed_transfer' | 'resale_contract' | 'payment_reminder';

interface MessageModalProps {
  isOpen: boolean;
  onClose: () => void;
  unit: (Unit & { project_name: string, project_number: string }) | null;
}

export default function MessageModal({ isOpen, onClose, unit }: MessageModalProps) {
  const [step, setStep] = useState(1);
  const [recipient, setRecipient] = useState<'original' | 'current'>('current');
  const [messageType, setMessageType] = useState<MessageType | null>(null);
  const [copied, setCopied] = useState(false);
  const [mode, setMode] = useState<'custom' | 'template'>('custom');
  const [fields, setFields] = useState<Record<string, boolean>>({
    current_name: true,
    current_phone: false,
    original_name: false,
    original_phone: false,
    project_name: true,
    project_number: true,
    unit_number: true,
    floor_number: true,
    deed_number: true,
    resale_fee: false,
    marketing_fee: false,
    company_fee: false,
    lawyer_fee: false,
    resale_agreed_amount: false,
    resale_saved_at: false
  });

  useEffect(() => {
    if (isOpen) {
      setStep(1);
      setRecipient(unit?.title_deed_owner ? 'current' : 'original');
      setMessageType(null);
      setCopied(false);
      setMode('custom');
    }
  }, [isOpen, unit]);

  if (!isOpen || !unit) return null;

  const hasResaleData =
    unit.resale_fee != null ||
    unit.marketing_fee != null ||
    unit.company_fee != null ||
    unit.lawyer_fee != null ||
    unit.resale_agreed_amount != null ||
    unit.resale_saved_at != null ||
    unit.status === 'for_resale';

  const getRecipientName = () => {
    return recipient === 'current' 
      ? (unit.title_deed_owner || unit.client_name) 
      : unit.client_name;
  };

  const getRecipientPhone = () => {
    return recipient === 'current'
      ? (unit.title_deed_owner_phone || unit.client_phone)
      : unit.client_phone;
  };

  const generateMessage = () => {
    const name = getRecipientName();
    const unitNum = unit.unit_number;
    const project = unit.project_name;

    switch (messageType) {
      case 'deed_transfer':
        return `السلام عليكم ورحمة الله وبركاته،\n\nعزيزي العميل: ${name}\nنأمل منكم التكرم بزيارة مقر شركة مساكن الرفاهية للتطوير العقاري، وذلك لإتمام إجراءات إفراغ الصك الخاص بوحدتكم رقم ${unitNum} في مشروع ${project}.\n\nشاكرين لكم حسن تعاونكم.`;
      
      case 'resale_contract':
        return `السلام عليكم ورحمة الله وبركاته،\n\nعزيزي العميل: ${name}\nنأمل منكم التكرم بزيارة مقر شركة مساكن الرفاهية للتطوير العقاري، وذلك لتوقيع عقد إعادة البيع الخاص بوحدتكم رقم ${unitNum} في مشروع ${project}.\n\nشاكرين لكم حسن تعاونكم.`;
      
      case 'payment_reminder':
        return `السلام عليكم ورحمة الله وبركاته،\n\nعزيزي العميل: ${name}\nنود تذكيركم بموعد سداد الدفعة المتبقية المستحقة على وحدتكم رقم ${unitNum} في مشروع ${project}.\nنأمل منكم سرعة السداد لإتمام الإجراءات المتبقية.\n\nشاكرين لكم حسن تعاونكم مع شركة مساكن الرفاهية للتطوير العقاري.`;
      
      default:
        return '';
    }
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(generateMessage());
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const buildCustomMessage = () => {
    if (!unit) return '';
    const lines: string[] = [];
    lines.push('تفاصيل الوحدة المختارة:');
    if (fields.current_name && (unit.title_deed_owner || unit.client_name)) {
      lines.push(`المالك الحالي: ${unit.title_deed_owner || unit.client_name}`);
    }
    if (fields.current_phone && (unit.title_deed_owner_phone || unit.client_phone)) {
      lines.push(`جوال المالك الحالي: ${unit.title_deed_owner_phone || unit.client_phone}`);
    }
    if (fields.original_name && unit.client_name) {
      lines.push(`العميل الأصلي: ${unit.client_name}`);
    }
    if (fields.original_phone && unit.client_phone) {
      lines.push(`جوال العميل الأصلي: ${unit.client_phone}`);
    }
    if (fields.project_name) {
      lines.push(`المشروع: ${unit.project_name}`);
    }
    if (fields.project_number) {
      lines.push(`رقم المشروع: ${unit.project_number}`);
    }
    if (fields.unit_number) {
      lines.push(`رقم الوحدة: ${unit.unit_number}`);
    }
    if (fields.floor_number) {
      lines.push(`الدور: ${unit.floor_number}`);
    }
    if (fields.deed_number && unit.deed_number) {
      lines.push(`رقم الصك: ${unit.deed_number}`);
    }
    if (hasResaleData) {
      const rFee = unit.resale_fee;
      const mFee = unit.marketing_fee;
      const cFee = unit.company_fee;
      const lFee = unit.lawyer_fee;
      const total =
        (rFee ?? 0) +
        (mFee ?? 0) +
        (cFee ?? 0) +
        (lFee ?? 0);
      const parts: string[] = [];
      if (fields.resale_fee && rFee != null) parts.push(`رسوم إعادة بيع: ${rFee}`);
      if (fields.marketing_fee && mFee != null) parts.push(`رسوم تسويق: ${mFee}`);
      if (fields.company_fee && cFee != null) parts.push(`رسوم شركة: ${cFee}`);
      if (fields.lawyer_fee && lFee != null) parts.push(`رسوم محاماة: ${lFee}`);
      if (fields.resale_agreed_amount && unit.resale_agreed_amount != null) parts.push(`مبلغ البيع المتفق: ${unit.resale_agreed_amount}`);
      if (fields.resale_saved_at && unit.resale_saved_at) parts.push(`تاريخ حفظ إعادة البيع: ${new Date(unit.resale_saved_at).toLocaleString('ar-SA')}`);
      if (parts.length > 0) {
        lines.push('بيانات إعادة البيع:');
        lines.push(...parts);
        lines.push(`إجمالي الرسوم: ${total}`);
      }
    }
    return lines.join('\n');
  };

  const handleSendWhatsApp = () => {
    if (mode === 'custom') {
      const text = buildCustomMessage();
      const url = `https://wa.me/?text=${encodeURIComponent(text)}`;
      window.open(url, '_blank');
      return;
    }
    const phone = getRecipientPhone();
    if (!phone) {
      alert('لا يوجد رقم جوال مسجل لهذا العميل');
      return;
    }
    // Remove non-digits and ensure generic format
    const cleanPhone = phone.replace(/\D/g, '');
    const formattedPhone = cleanPhone.startsWith('0') ? '966' + cleanPhone.substring(1) : cleanPhone;
    
    const url = `https://wa.me/${formattedPhone}?text=${encodeURIComponent(generateMessage())}`;
    window.open(url, '_blank');
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-4xl max-h-[85vh] overflow-hidden animate-in fade-in zoom-in duration-200">
        {/* Header */}
        <div className="p-4 border-b border-gray-100 bg-gray-50">
          <div className="flex items-center justify-between">
            <h3 className="font-display font-bold text-lg text-gray-900 flex items-center gap-2">
              <MessageCircle size={20} className="text-blue-600" />
              مشاركة تفاصيل الوحدة
            </h3>
            <button onClick={onClose} className="p-1 hover:bg-gray-200 rounded-lg transition-colors">
              <X size={20} className="text-gray-500" />
            </button>
          </div>
          <div className="mt-3 inline-flex bg-white border border-gray-200 rounded-xl overflow-hidden">
            <button
              onClick={() => setMode('custom')}
              className={`px-3 py-1.5 text-sm font-bold ${mode === 'custom' ? 'bg-blue-600 text-white' : 'text-gray-600'}`}
            >
              مشاركة مخصصة
            </button>
            <button
              onClick={() => setMode('template')}
              className={`px-3 py-1.5 text-sm font-bold ${mode === 'template' ? 'bg-blue-600 text-white' : 'text-gray-600'}`}
            >
              رسائل جاهزة
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 max-h-[70vh] overflow-y-auto">
          {mode === 'custom' && unit && (
            <div className="space-y-6 lg:space-y-0 lg:grid lg:grid-cols-2 lg:gap-6">
              <div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.current_name} onChange={(e) => setFields({ ...fields, current_name: e.target.checked })} />
                    <span className="text-sm">المالك الحالي</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.current_phone} onChange={(e) => setFields({ ...fields, current_phone: e.target.checked })} />
                    <span className="text-sm">جوال المالك الحالي</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.original_name} onChange={(e) => setFields({ ...fields, original_name: e.target.checked })} />
                    <span className="text-sm">العميل الأصلي</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.original_phone} onChange={(e) => setFields({ ...fields, original_phone: e.target.checked })} />
                    <span className="text-sm">جوال العميل الأصلي</span>
                  </label>
                  <div className="col-span-full pt-2 text-xs font-bold text-gray-600">تفاصيل الوحدة</div>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.project_name} onChange={(e) => setFields({ ...fields, project_name: e.target.checked })} />
                    <span className="text-sm">اسم المشروع</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.project_number} onChange={(e) => setFields({ ...fields, project_number: e.target.checked })} />
                    <span className="text-sm">رقم المشروع</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.unit_number} onChange={(e) => setFields({ ...fields, unit_number: e.target.checked })} />
                    <span className="text-sm">رقم الوحدة</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.floor_number} onChange={(e) => setFields({ ...fields, floor_number: e.target.checked })} />
                    <span className="text-sm">الدور</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={fields.deed_number} onChange={(e) => setFields({ ...fields, deed_number: e.target.checked })} />
                    <span className="text-sm">رقم الصك</span>
                  </label>
                  {hasResaleData && (
                    <>
                      <div className="pt-3 text-xs font-bold text-gray-600">بيانات إعادة البيع</div>
                      {unit.resale_fee != null && (
                        <label className="flex items-center gap-2">
                          <input type="checkbox" checked={fields.resale_fee} onChange={(e) => setFields({ ...fields, resale_fee: e.target.checked })} />
                          <span className="text-sm">رسوم إعادة بيع</span>
                        </label>
                      )}
                      {unit.marketing_fee != null && (
                        <label className="flex items-center gap-2">
                          <input type="checkbox" checked={fields.marketing_fee} onChange={(e) => setFields({ ...fields, marketing_fee: e.target.checked })} />
                          <span className="text-sm">رسوم تسويق</span>
                        </label>
                      )}
                      {unit.company_fee != null && (
                        <label className="flex items-center gap-2">
                          <input type="checkbox" checked={fields.company_fee} onChange={(e) => setFields({ ...fields, company_fee: e.target.checked })} />
                          <span className="text-sm">رسوم شركة</span>
                        </label>
                      )}
                      {unit.lawyer_fee != null && (
                        <label className="flex items-center gap-2">
                          <input type="checkbox" checked={fields.lawyer_fee} onChange={(e) => setFields({ ...fields, lawyer_fee: e.target.checked })} />
                          <span className="text-sm">رسوم محاماة</span>
                        </label>
                      )}
                      {unit.resale_agreed_amount != null && (
                        <label className="flex items-center gap-2">
                          <input type="checkbox" checked={fields.resale_agreed_amount} onChange={(e) => setFields({ ...fields, resale_agreed_amount: e.target.checked })} />
                          <span className="text-sm">مبلغ البيع المتفق</span>
                        </label>
                      )}
                      {unit.resale_saved_at && (
                        <label className="flex items-center gap-2">
                          <input type="checkbox" checked={fields.resale_saved_at} onChange={(e) => setFields({ ...fields, resale_saved_at: e.target.checked })} />
                          <span className="text-sm">تاريخ حفظ إعادة البيع</span>
                        </label>
                      )}
                    </>
                  )}
                </div>
              </div>
              <div>
                <div className="bg-gray-50 p-4 rounded-xl border border-gray-200 text-sm leading-relaxed whitespace-pre-line text-gray-700 lg:sticky lg:top-0">
                  {buildCustomMessage()}
                </div>
              </div>
              <div className="flex gap-3">
                <button
                  onClick={handleSendWhatsApp}
                  className="flex-1 py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-bold transition-all flex items-center justify-center gap-2 shadow-lg shadow-green-600/20"
                >
                  <Send size={18} />
                  مشاركة عبر واتساب
                </button>
                <button
                  onClick={() => { navigator.clipboard.writeText(buildCustomMessage()); setCopied(true); setTimeout(() => setCopied(false), 2000); }}
                  className="px-4 py-3 bg-white border border-gray-200 text-gray-700 hover:bg-gray-50 rounded-xl font-bold transition-all flex items-center justify-center gap-2"
                >
                  {copied ? <Check size={18} className="text-green-600" /> : <Copy size={18} />}
                  {copied ? 'تم النسخ' : 'نسخ'}
                </button>
              </div>
            </div>
          )}
          {mode === 'template' && step === 1 && (
            <div className="space-y-6">
              <div>
                <h4 className="font-bold text-gray-900 mb-4">1. اختر المستلم</h4>
                <div className="space-y-3">
                  {unit.title_deed_owner && (
                    <label className={`flex items-center p-4 border rounded-xl cursor-pointer transition-all ${recipient === 'current' ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:bg-gray-50'}`}>
                      <input 
                        type="radio" 
                        name="recipient" 
                        checked={recipient === 'current'} 
                        onChange={() => setRecipient('current')}
                        className="w-4 h-4 text-blue-600 ml-3"
                      />
                      <div className="flex-1">
                        <div className="font-bold text-gray-900">المالك الحالي (المفرغ له)</div>
                        <div className="text-sm text-gray-500">{unit.title_deed_owner}</div>
                        <div dir="ltr" className="text-xs text-gray-400 mt-1">{unit.title_deed_owner_phone || 'لا يوجد جوال'}</div>
                      </div>
                    </label>
                  )}

                  <label className={`flex items-center p-4 border rounded-xl cursor-pointer transition-all ${recipient === 'original' ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:bg-gray-50'}`}>
                    <input 
                      type="radio" 
                      name="recipient" 
                      checked={recipient === 'original'} 
                      onChange={() => setRecipient('original')}
                      className="w-4 h-4 text-blue-600 ml-3"
                    />
                    <div className="flex-1">
                      <div className="font-bold text-gray-900">العميل الأصلي</div>
                      <div className="text-sm text-gray-500">{unit.client_name}</div>
                      <div dir="ltr" className="text-xs text-gray-400 mt-1">{unit.client_phone || 'لا يوجد جوال'}</div>
                    </div>
                  </label>
                </div>
              </div>

              <button 
                onClick={() => setStep(2)}
                className="w-full py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold transition-all flex items-center justify-center gap-2"
              >
                التالي
                <ChevronRight size={18} className="rotate-180" />
              </button>
            </div>
          )}

          {mode === 'template' && step === 2 && (
            <div className="space-y-6">
              <div>
                <h4 className="font-bold text-gray-900 mb-4">2. اختر نوع الرسالة</h4>
                <div className="grid gap-3">
                  <button 
                    onClick={() => { setMessageType('deed_transfer'); setStep(3); }}
                    className="p-4 border border-gray-200 rounded-xl hover:border-blue-500 hover:bg-blue-50 transition-all text-right group"
                  >
                    <div className="font-bold text-gray-900 group-hover:text-blue-700">طلب حضور للإفراغ</div>
                    <div className="text-xs text-gray-500 mt-1">دعوة العميل للحضور لمقر الشركة لإفراغ الصك</div>
                  </button>

                  <button 
                    onClick={() => { setMessageType('resale_contract'); setStep(3); }}
                    className="p-4 border border-gray-200 rounded-xl hover:border-blue-500 hover:bg-blue-50 transition-all text-right group"
                  >
                    <div className="font-bold text-gray-900 group-hover:text-blue-700">توقيع عقد إعادة بيع</div>
                    <div className="text-xs text-gray-500 mt-1">دعوة العميل لتوقيع عقد إعادة بيع الوحدة</div>
                  </button>

                  <button 
                    onClick={() => { setMessageType('payment_reminder'); setStep(3); }}
                    className="p-4 border border-gray-200 rounded-xl hover:border-blue-500 hover:bg-blue-50 transition-all text-right group"
                  >
                    <div className="font-bold text-gray-900 group-hover:text-blue-700">تذكير بالسداد</div>
                    <div className="text-xs text-gray-500 mt-1">تذكير العميل بسداد المبالغ المتبقية</div>
                  </button>
                </div>
              </div>

              <button 
                onClick={() => setStep(1)}
                className="w-full py-3 text-gray-600 hover:bg-gray-50 rounded-xl font-bold transition-all"
              >
                رجوع
              </button>
            </div>
          )}

          {mode === 'template' && step === 3 && (
            <div className="space-y-6">
              <div>
                <h4 className="font-bold text-gray-900 mb-2">معاينة الرسالة</h4>
                <div className="bg-gray-50 p-4 rounded-xl border border-gray-200 text-sm leading-relaxed whitespace-pre-line text-gray-700">
                  {generateMessage()}
                </div>
              </div>

              <div className="flex gap-3">
                <button 
                  onClick={handleSendWhatsApp}
                  className="flex-1 py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-bold transition-all flex items-center justify-center gap-2 shadow-lg shadow-green-600/20"
                >
                  <Send size={18} />
                  إرسال واتساب
                </button>
                
                <button 
                  onClick={handleCopy}
                  className="px-4 py-3 bg-white border border-gray-200 text-gray-700 hover:bg-gray-50 rounded-xl font-bold transition-all flex items-center justify-center gap-2"
                >
                  {copied ? <Check size={18} className="text-green-600" /> : <Copy size={18} />}
                  {copied ? 'تم النسخ' : 'نسخ'}
                </button>
              </div>

              <button 
                onClick={() => setStep(2)}
                className="w-full py-3 text-gray-600 hover:bg-gray-50 rounded-xl font-bold transition-all"
              >
                رجوع
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
