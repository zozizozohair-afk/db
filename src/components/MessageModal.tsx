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

  useEffect(() => {
    if (isOpen) {
      setStep(1);
      setRecipient(unit?.title_deed_owner ? 'current' : 'original');
      setMessageType(null);
      setCopied(false);
    }
  }, [isOpen, unit]);

  if (!isOpen || !unit) return null;

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

  const handleSendWhatsApp = () => {
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
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg overflow-hidden animate-in fade-in zoom-in duration-200">
        {/* Header */}
        <div className="p-4 border-b border-gray-100 flex items-center justify-between bg-gray-50">
          <h3 className="font-display font-bold text-lg text-gray-900 flex items-center gap-2">
            <MessageCircle size={20} className="text-blue-600" />
            إرسال رسالة للعميل
          </h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-200 rounded-lg transition-colors">
            <X size={20} className="text-gray-500" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          {step === 1 && (
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

          {step === 2 && (
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

          {step === 3 && (
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
