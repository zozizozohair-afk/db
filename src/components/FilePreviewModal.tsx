import React from 'react';
import { FileText, Layers, Maximize2, X } from 'lucide-react';

const FilePreviewModal = ({ url, onClose }: { url: string | null, onClose: () => void }) => {
  if (!url) return null;

  const isPDF = url.toLowerCase().endsWith('.pdf') || url.includes('.pdf');

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="relative w-full max-w-5xl h-[85vh] bg-white rounded-2xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 bg-gray-50 border-b border-gray-100">
          <h3 className="font-display font-bold text-gray-900 flex items-center gap-2">
            {isPDF ? <FileText size={20} className="text-red-500" /> : <Layers size={20} className="text-blue-500" />}
            معاينة الملف
          </h3>
          <div className="flex items-center gap-2">
            <a 
              href={url} 
              target="_blank" 
              rel="noopener noreferrer"
              className="p-2 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
              title="فتح في نافذة جديدة"
            >
              <Maximize2 size={20} />
            </a>
            <button 
              onClick={onClose}
              className="p-2 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
            >
              <X size={24} />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 bg-gray-100 overflow-hidden relative">
          {isPDF ? (
            <iframe 
              src={`${url}#toolbar=0&navpanes=0`}
              className="w-full h-full" 
              title="PDF Preview"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center overflow-auto p-4">
              <img 
                src={url} 
                alt="Preview" 
                className="max-w-full max-h-full object-contain rounded shadow-lg"
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default FilePreviewModal;
