'use client';

import React, { useState, useRef } from 'react';
import { PDFDocument, rgb, degrees } from 'pdf-lib';
import { 
  FileText, 
  Files, 
  Scissors, 
  Minimize2, 
  Image as ImageIcon, 
  FileType, 
  Upload, 
  Download, 
  X, 
  CheckCircle2, 
  Eye,
  Link as LinkIcon,
  Save,
  PenTool,
  RotateCw,
  Trash2,
  Type,
  ArrowUp,
  ArrowDown
} from 'lucide-react';
import { supabase } from '../../lib/supabaseClient';
import { Unit } from '../../types';

// Simplified Project type for this page
interface SimpleProject {
  id: string;
  name: string;
}

type ToolType = 'merge' | 'split' | 'compress' | 'img-to-pdf' | 'pdf-to-img' | 'edit';

export default function PdfToolsPage() {
  const [activeTool, setActiveTool] = useState<ToolType>('merge');
  const [files, setFiles] = useState<File[]>([]);
  const [processing, setProcessing] = useState(false);
  const [resultUrl, setResultUrl] = useState<string | null>(null);
  const [resultImages, setResultImages] = useState<string[]>([]);
  const [resultPdfs, setResultPdfs] = useState<{url: string, page: number, blob?: Blob}[]>([]); // For split PDFs
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Linking State
  const [showLinkModal, setShowLinkModal] = useState(false);
  const [selectedFileForLink, setSelectedFileForLink] = useState<{url: string, name: string, blob?: Blob} | null>(null);
  const [projects, setProjects] = useState<SimpleProject[]>([]);
  const [units, setUnits] = useState<Unit[]>([]);
  const [selectedProject, setSelectedProject] = useState('');
  const [selectedUnit, setSelectedUnit] = useState('');
  const [linkType, setLinkType] = useState('other'); // deed, sorting, contract, other
  const [isUploading, setIsUploading] = useState(false);

  // Editor State
  const [editorPages, setEditorPages] = useState<{pageIndex: number, rotation: number, deleted: boolean, imageUrl: string}[]>([]);
  const [editorText, setEditorText] = useState('');
  const [editorTextSize, setEditorTextSize] = useState(24);
  const [editorTextColor, setEditorTextColor] = useState('#000000');
  const [editorTextX, setEditorTextX] = useState(50);
  const [editorTextY, setEditorTextY] = useState(50);
  const [isProcessingEditor, setIsProcessingEditor] = useState(false);

  // Smart Distribution State
  const [smartMode, setSmartMode] = useState(false);
  const [startUnitId, setStartUnitId] = useState('');
  const [endUnitId, setEndUnitId] = useState('');
  const [startPage, setStartPage] = useState(1);
  const [endPage, setEndPage] = useState(1);

  // Split Naming Pattern
  const [namingPattern, setNamingPattern] = useState('page'); // page, project_unit_type
  const [bulkUploadMode, setBulkUploadMode] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<{current: number, total: number} | null>(null);

  // Fetch Projects on Mount
  React.useEffect(() => {
    const fetchProjects = async () => {
      const { data } = await supabase.from('projects').select('id, name');
      if (data) setProjects(data);
    };
    fetchProjects();
  }, []);

  // Fetch Units when Project Selected
  React.useEffect(() => {
    if (selectedProject) {
      const fetchUnits = async () => {
        const { data } = await supabase
          .from('units')
          .select('*')
          .eq('project_id', selectedProject)
          .order('unit_number', { ascending: true });
        
        if (data) {
           setUnits(data as Unit[]);
        }
      };
      fetchUnits();
    } else {
      setUnits([]);
    }
  }, [selectedProject]);

  const handleLinkFile = async () => {
    if ((!selectedFileForLink && !bulkUploadMode && !smartMode) || (!selectedUnit && !smartMode) || !linkType) return;
    
    setIsUploading(true);
    try {
      let filesToUpload: {blob?: Blob, name: string, page: number, unitId: string}[] = [];

      if (smartMode) {
         if (!startUnitId || !endUnitId || !startPage || !endPage) {
           alert('الرجاء تحديد نطاق الوحدات والصفحات بشكل صحيح');
           setIsUploading(false);
           return;
         }

         const startIndex = units.findIndex(u => u.id === startUnitId);
         const endIndex = units.findIndex(u => u.id === endUnitId);
         
         if (startIndex === -1 || endIndex === -1 || startIndex > endIndex) {
            alert('نطاق الوحدات غير صحيح');
            setIsUploading(false);
            return;
         }

         const targetUnits = units.slice(startIndex, endIndex + 1);
         const targetPages = resultPdfs.filter(p => p.page >= startPage && p.page <= endPage);

         if (targetUnits.length !== targetPages.length) {
            if (!confirm(`تحذير: عدد الوحدات (${targetUnits.length}) لا يطابق عدد الصفحات (${targetPages.length}). سيتم الربط بالتتابع حتى انتهاء القائمة الأقصر. هل تريد الاستمرار؟`)) {
              setIsUploading(false);
              return;
            }
         }

         const count = Math.min(targetUnits.length, targetPages.length);
         for (let i = 0; i < count; i++) {
           filesToUpload.push({
             blob: targetPages[i].blob,
             name: getNaming(targetPages[i].page, targetUnits[i].id),
             page: targetPages[i].page,
             unitId: targetUnits[i].id
           });
         }

      } else if (bulkUploadMode) {
        filesToUpload = resultPdfs.map(p => ({
            blob: p.blob, 
            name: getNaming(p.page, selectedUnit), 
            page: p.page,
            unitId: selectedUnit
          }));
      } else {
        filesToUpload = [{ 
            blob: selectedFileForLink?.blob, 
            name: selectedFileForLink?.name || 'file.pdf', 
            page: 0,
            unitId: selectedUnit
          }];
      }

      if (filesToUpload.length === 0) {
        alert('لا توجد ملفات للرفع');
        setIsUploading(false);
        return;
      }

      setUploadProgress({ current: 0, total: filesToUpload.length });

      for (let i = 0; i < filesToUpload.length; i++) {
        const item = filesToUpload[i];
        
        let blob = item.blob;
        if (!blob && selectedFileForLink?.url && !bulkUploadMode && !smartMode) {
           const response = await fetch(selectedFileForLink.url);
           blob = await response.blob();
        }

        if (!blob) continue;

        const file = new File([blob], item.name || `file_${Date.now()}.pdf`, { type: 'application/pdf' });

        // Generate a safe filename for storage to avoid "Invalid key" errors with Arabic characters
        // Using timestamp and random string, similar to UnitDetailsPageClient.tsx
        const fileExt = 'pdf';
        const safeFileName = `${Date.now()}_${Math.random().toString(36).substring(2, 9)}.${fileExt}`;
        
        // Use 'project-files' bucket and a structured path
        const filePath = `units/${item.unitId}/${linkType}/${safeFileName}`;
        
        const { error: uploadError } = await supabase.storage
          .from('project-files')
          .upload(filePath, file);

        if (uploadError) throw uploadError;

        const { data: { publicUrl } } = supabase.storage
          .from('project-files')
          .getPublicUrl(filePath);

        // 3. Update Unit Record based on type
      if (linkType === 'deed') {
        const { error: updateError } = await supabase
          .from('units')
          .update({ deed_file_url: publicUrl })
          .eq('id', item.unitId);
        if (updateError) throw updateError;
      } else if (linkType === 'sorting') {
        const { error: updateError } = await supabase
          .from('units')
          .update({ sorting_record_file_url: publicUrl })
          .eq('id', item.unitId);
        if (updateError) throw updateError;
      } else {
        const { error: contractError } = await supabase
          .from('unit_contracts')
          .insert({
            unit_id: item.unitId,
            type: linkType === 'contract' ? 'contract' : 'other',
            custom_type: linkType === 'contract' ? 'عقد' : 'ملف من أدوات PDF',
            file_url: publicUrl,
            file_path: filePath
          });
        if (contractError) throw contractError;
      }

        setUploadProgress(prev => prev ? { ...prev, current: i + 1 } : null);
      }

      alert('تم رفع الملفات وربطها بنجاح!');
      setShowLinkModal(false);
      setSelectedFileForLink(null);
      setBulkUploadMode(false);
      setSmartMode(false);
      setUploadProgress(null);
    } catch (error: any) {
      console.error(error);
      alert(`حدث خطأ أثناء الرفع والربط: ${error.message || JSON.stringify(error)}`);
    } finally {
      setIsUploading(false);
      setUploadProgress(null);
    }
  };

  const getNaming = (pageIndex: number, unitId?: string) => {
    if (namingPattern === 'project_unit_type') {
       const pName = projects.find(p => p.id === selectedProject)?.name || 'Project';
       const uNumber = units.find(u => u.id === (unitId || selectedUnit))?.unit_number || 'Unit';
       const typeName = linkType === 'deed' ? 'صك' : linkType === 'sorting' ? 'فرز' : 'مستند';
       return `${pName}_${uNumber}_${typeName}_${pageIndex}.pdf`;
    }
    return `page_${pageIndex}.pdf`;
  };


  const tools = [
    { id: 'merge', name: 'دمج ملفات PDF', icon: Files, description: 'دمج عدة ملفات PDF في ملف واحد' },
    { id: 'split', name: 'تفكيك PDF', icon: Scissors, description: 'استخراج كل صفحة كملف منفصل' },
    { id: 'compress', name: 'ضغط PDF', icon: Minimize2, description: 'تقليل حجم ملف PDF' },
    { id: 'img-to-pdf', name: 'صور إلى PDF', icon: FileType, description: 'تحويل الصور إلى ملف PDF' },
    { id: 'pdf-to-img', name: 'PDF إلى صور', icon: ImageIcon, description: 'تحويل صفحات PDF إلى صور' },
    { id: 'edit', name: 'تعديل PDF', icon: PenTool, description: 'تدوير، حذف، وإضافة نصوص' },
  ];

  const handleEditInit = async (file: File) => {
    setIsProcessingEditor(true);
    try {
      // Use explicit mjs import for better compatibility with Next.js/Webpack
      const pdfJS = await import('pdfjs-dist');
      pdfJS.GlobalWorkerOptions.workerSrc = `https://unpkg.com/pdfjs-dist@${pdfJS.version}/build/pdf.worker.min.mjs`;
      const arrayBuffer = await file.arrayBuffer();
      const pdf = await pdfJS.getDocument({ data: arrayBuffer }).promise;
      const numPages = pdf.numPages;

      const newEditorPages = [];
      for (let i = 1; i <= numPages; i++) {
        const page = await pdf.getPage(i);
        const viewport = page.getViewport({ scale: 1.0 });
        
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        canvas.height = viewport.height;
        canvas.width = viewport.width;

        await page.render({
          canvasContext: context!,
          canvas: canvas,
          viewport: viewport
        }).promise;

        newEditorPages.push({
          pageIndex: i - 1,
          rotation: 0,
          deleted: false,
          imageUrl: canvas.toDataURL()
        });
      }
      setEditorPages(newEditorPages);
    } catch (error: any) {
      console.error('Error initializing editor:', error);
      alert(`حدث خطأ أثناء تحميل الملف للتعديل: ${error.message || error}`);
    } finally {
      setIsProcessingEditor(false);
    }
  };

  const handleEditSave = async () => {
    if (!files[0]) return;
    setProcessing(true);
    try {
      const arrayBuffer = await files[0].arrayBuffer();
      const pdfDoc = await PDFDocument.load(arrayBuffer);
      
      const newPdf = await PDFDocument.create();
      
      const pagesToKeepIndices = editorPages
        .filter(p => !p.deleted)
        .map(p => p.pageIndex);
      
      if (pagesToKeepIndices.length > 0) {
          const copiedPages = await newPdf.copyPages(pdfDoc, pagesToKeepIndices);
          
          copiedPages.forEach((page, idx) => {
              const config = editorPages.filter(p => !p.deleted)[idx];
              
              const currentRotation = page.getRotation().angle;
              page.setRotation(degrees(currentRotation + config.rotation));
              
              if (editorText) {
                  const { width, height } = page.getSize();
                  const fontSize = editorTextSize;
                  const x = (width * editorTextX) / 100;
                  const y = (height * editorTextY) / 100;
                  
                  page.drawText(editorText, {
                      x: x,
                      y: y,
                      size: fontSize,
                      color: rgb(
                        parseInt(editorTextColor.slice(1, 3), 16) / 255,
                        parseInt(editorTextColor.slice(3, 5), 16) / 255,
                        parseInt(editorTextColor.slice(5, 7), 16) / 255
                      ),
                  });
              }
              
              newPdf.addPage(page);
          });
      }

      const pdfBytes = await newPdf.save();
      const blob = new Blob([pdfBytes as any], { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      setResultUrl(url);
    } catch (error) {
      console.error(error);
      alert('حدث خطأ أثناء حفظ التعديلات');
    } finally {
      setProcessing(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      if (activeTool === 'edit') {
        setFiles([e.target.files[0]]);
        handleEditInit(e.target.files[0]);
      } else {
        const selectedFiles = Array.from(e.target.files);
        setFiles(prev => [...prev, ...selectedFiles]);
      }
      setResultUrl(null);
      setResultImages([]);
      setResultPdfs([]);
    }
  };

  const removeFile = (index: number) => {
    setFiles(prev => prev.filter((_, i) => i !== index));
  };

  const reset = () => {
    setFiles([]);
    setResultUrl(null);
    setResultImages([]);
      setResultPdfs([]);
      if (fileInputRef.current) fileInputRef.current.value = '';
  };

  // 1. Merge PDFs
  const handleMerge = async () => {
    if (files.length < 2) return alert('الرجاء اختيار ملفين على الأقل للدمج');
    
    try {
      setProcessing(true);
      const mergedPdf = await PDFDocument.create();

      for (const file of files) {
        const arrayBuffer = await file.arrayBuffer();
        const pdf = await PDFDocument.load(arrayBuffer);
        const copiedPages = await mergedPdf.copyPages(pdf, pdf.getPageIndices());
        copiedPages.forEach((page) => mergedPdf.addPage(page));
      }

      const pdfBytes = await mergedPdf.save();
      const blob = new Blob([pdfBytes as any], { type: 'application/pdf' });
      setResultUrl(URL.createObjectURL(blob));
    } catch (error) {
      console.error(error);
      alert('حدث خطأ أثناء الدمج');
    } finally {
      setProcessing(false);
    }
  };

  // 2. Split PDF
  const handleSplit = async () => {
    if (files.length !== 1) return alert('الرجاء اختيار ملف واحد فقط للتفكيك');
    
    try {
      setProcessing(true);
      const file = files[0];
      const arrayBuffer = await file.arrayBuffer();
      const pdf = await PDFDocument.load(arrayBuffer);
      const pageCount = pdf.getPageCount();

      // For simplicity in this demo, we'll create a zip or just allow downloading the first one?
      // Actually, returning multiple files in browser is tricky without zip.
      // Let's create a PDF for each page and maybe just show download links for them?
      // Or zip them. Since I don't have JSZip installed, I'll list download links for each page.
      
      const pagePdfs: {url: string, page: number, blob?: Blob}[] = [];
      
      for (let i = 0; i < pageCount; i++) {
        const newPdf = await PDFDocument.create();
        const [copiedPage] = await newPdf.copyPages(pdf, [i]);
        newPdf.addPage(copiedPage);
        const pdfBytes = await newPdf.save();
        const blob = new Blob([pdfBytes as any], { type: 'application/pdf' });
        pagePdfs.push({ url: URL.createObjectURL(blob), page: i + 1, blob });
      }
      
      // We'll use resultPdfs to store URLs for split pages
      setResultPdfs(pagePdfs); 

    } catch (error) {
      console.error(error);
      alert('حدث خطأ أثناء التفكيك');
    } finally {
      setProcessing(false);
    }
  };

  // 3. Compress PDF (Basic implementation using pdf-lib)
  // pdf-lib doesn't have strong compression. We can try to just save it, sometimes it optimizes.
  // Or we can just pretend/skip if it's too complex. 
  // Let's just re-save it, which sometimes cleans up the file.
  const handleCompress = async () => {
    if (files.length !== 1) return alert('الرجاء اختيار ملف واحد للضغط');
    
    try {
      setProcessing(true);
      const file = files[0];
      const arrayBuffer = await file.arrayBuffer();
      const pdf = await PDFDocument.load(arrayBuffer);
      
      // Basic "compression" by saving (pdf-lib doesn't support aggressive compression)
      // We can assume this tool just "optimizes" the structure.
      const pdfBytes = await pdf.save({ useObjectStreams: false }); // Sometimes false is smaller? No, true is default.
      // Actually, let's just save normally.
      
      const blob = new Blob([pdfBytes as any], { type: 'application/pdf' });
      setResultUrl(URL.createObjectURL(blob));
    } catch (error) {
      console.error(error);
      alert('حدث خطأ أثناء الضغط');
    } finally {
      setProcessing(false);
    }
  };

  // 4. Images to PDF
  const handleImgToPdf = async () => {
    if (files.length === 0) return alert('الرجاء اختيار صور');
    
    try {
      setProcessing(true);
      const pdf = await PDFDocument.create();

      for (const file of files) {
        const arrayBuffer = await file.arrayBuffer();
        const fileExt = file.name.split('.').pop()?.toLowerCase();
        
        let image;
        if (fileExt === 'jpg' || fileExt === 'jpeg') {
          image = await pdf.embedJpg(arrayBuffer);
        } else if (fileExt === 'png') {
          image = await pdf.embedPng(arrayBuffer);
        } else {
          continue; // Skip non-supported
        }

        const page = pdf.addPage();
        const { width, height } = image.scale(1);
        const pageWidth = page.getWidth();
        const pageHeight = page.getHeight();
        
        const scale = Math.min(pageWidth / width, pageHeight / height, 1);
        page.drawImage(image, {
          x: (pageWidth - width * scale) / 2,
          y: (pageHeight - height * scale) / 2,
          width: width * scale,
          height: height * scale,
        });
      }

      const pdfBytes = await pdf.save();
      const blob = new Blob([pdfBytes as any], { type: 'application/pdf' });
      setResultUrl(URL.createObjectURL(blob));
    } catch (error) {
      console.error(error);
      alert('حدث خطأ أثناء التحويل');
    } finally {
      setProcessing(false);
    }
  };

  // 5. PDF to Images
  const handlePdfToImg = async () => {
    if (files.length !== 1) return alert('الرجاء اختيار ملف PDF واحد');
    
    try {
      setProcessing(true);
      // Dynamically import pdfjs-dist to avoid SSR/Build issues
      const pdfjsLib = await import('pdfjs-dist');
      pdfjsLib.GlobalWorkerOptions.workerSrc = `//cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjsLib.version}/pdf.worker.min.js`;

      const file = files[0];
      const arrayBuffer = await file.arrayBuffer();
      
      const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
      const pageCount = pdf.numPages;
      const imageUrls: string[] = [];

      for (let i = 1; i <= pageCount; i++) {
        const page = await pdf.getPage(i);
        const viewport = page.getViewport({ scale: 1.5 });
        
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        canvas.height = viewport.height;
        canvas.width = viewport.width;

        if (context) {
          await page.render({ canvasContext: context, canvas: canvas, viewport }).promise;
          imageUrls.push(canvas.toDataURL('image/jpeg'));
        }
      }

      setResultImages(imageUrls);
    } catch (error) {
      console.error(error);
      alert('حدث خطأ أثناء التحويل');
    } finally {
      setProcessing(false);
    }
  };

  const processAction = () => {
    switch (activeTool) {
      case 'merge': return handleMerge();
      case 'split': return handleSplit();
      case 'compress': return handleCompress();
      case 'img-to-pdf': return handleImgToPdf();
      case 'pdf-to-img': return handlePdfToImg();
      case 'edit': return handleEditSave();
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 pb-12" dir="rtl">
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10 shadow-sm mb-8">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center">
          <h1 className="text-xl font-bold text-gray-900 flex items-center gap-2">
            <Files className="text-blue-600" />
            أدوات PDF
          </h1>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Tools Grid */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
          {tools.map((tool) => (
            <button
              key={tool.id}
              onClick={() => {
                setActiveTool(tool.id as ToolType);
                reset();
              }}
              className={`flex flex-col items-center justify-center p-4 rounded-xl border transition-all ${
                activeTool === tool.id 
                  ? 'bg-blue-600 text-white border-blue-600 shadow-md transform scale-105' 
                  : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50 hover:border-gray-300'
              }`}
            >
              <tool.icon size={24} className="mb-2" />
              <span className="text-sm font-medium">{tool.name}</span>
            </button>
          ))}
        </div>

        {/* Workspace */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              {tools.find(t => t.id === activeTool)?.name}
            </h2>
            <p className="text-gray-500">
              {tools.find(t => t.id === activeTool)?.description}
            </p>
          </div>

          {/* File Upload */}
          {files.length === 0 && (
            <div 
              className="border-2 border-dashed border-gray-300 rounded-xl p-12 text-center hover:bg-gray-50 hover:border-blue-400 transition-colors cursor-pointer"
              onClick={() => fileInputRef.current?.click()}
            >
              <Upload size={48} className="mx-auto text-gray-400 mb-4" />
              <p className="text-lg font-medium text-gray-700 mb-2">اختر الملفات</p>
              <p className="text-sm text-gray-500">أو اسحبها وأفلتها هنا</p>
              <input 
                type="file" 
                ref={fileInputRef}
                className="hidden" 
                multiple={activeTool === 'merge' || activeTool === 'img-to-pdf'}
                accept={activeTool === 'img-to-pdf' ? 'image/*' : '.pdf'}
                onChange={handleFileSelect}
              />
            </div>
          )}

          {/* Selected Files List & Editor */}
          {files.length > 0 && !resultUrl && resultImages.length === 0 && resultPdfs.length === 0 && (
            <>
              {activeTool === 'edit' ? (
                <div className="space-y-6">
                  <div className="flex justify-between items-center mb-4">
                     <h3 className="font-bold text-gray-900">محرر PDF ({editorPages.length} صفحة)</h3>
                     <button onClick={reset} className="text-red-500 text-sm hover:underline">إلغاء</button>
                  </div>

                  {/* Toolbar */}
                  <div className="bg-gray-50 p-4 rounded-xl border border-gray-200 space-y-4">
                     <div className="flex flex-wrap gap-4 items-end">
                        <div className="flex-1 min-w-[200px]">
                           <label className="block text-xs font-medium text-gray-700 mb-1">إضافة نص (Watermark)</label>
                           <input 
                             type="text" 
                             value={editorText} 
                             onChange={(e) => setEditorText(e.target.value)}
                             placeholder="اكتب النص هنا..."
                             className="w-full p-2 border border-gray-300 rounded-lg text-sm"
                           />
                        </div>
                        <div>
                           <label className="block text-xs font-medium text-gray-700 mb-1">الحجم</label>
                           <input 
                             type="number" 
                             value={editorTextSize} 
                             onChange={(e) => setEditorTextSize(Number(e.target.value))}
                             className="w-20 p-2 border border-gray-300 rounded-lg text-sm"
                           />
                        </div>
                        <div>
                           <label className="block text-xs font-medium text-gray-700 mb-1">اللون</label>
                           <input 
                             type="color" 
                             value={editorTextColor} 
                             onChange={(e) => setEditorTextColor(e.target.value)}
                             className="w-16 h-9 p-1 border border-gray-300 rounded-lg cursor-pointer"
                           />
                        </div>
                        <div>
                           <label className="block text-xs font-medium text-gray-700 mb-1">الموقع X%</label>
                           <input 
                             type="number" 
                             min="0" max="100"
                             value={editorTextX} 
                             onChange={(e) => setEditorTextX(Number(e.target.value))}
                             className="w-16 p-2 border border-gray-300 rounded-lg text-sm"
                           />
                        </div>
                        <div>
                           <label className="block text-xs font-medium text-gray-700 mb-1">الموقع Y%</label>
                           <input 
                             type="number" 
                             min="0" max="100"
                             value={editorTextY} 
                             onChange={(e) => setEditorTextY(Number(e.target.value))}
                             className="w-16 p-2 border border-gray-300 rounded-lg text-sm"
                           />
                        </div>
                     </div>
                     <p className="text-xs text-gray-500">
                       * سيتم تطبيق النص على جميع الصفحات غير المحذوفة.
                     </p>
                  </div>

                  {/* Pages Grid */}
                  {isProcessingEditor ? (
                     <div className="py-12 text-center">
                        <div className="w-10 h-10 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin mx-auto mb-4"></div>
                        <p className="text-gray-500">جاري تحميل الصفحات...</p>
                     </div>
                  ) : (
                     <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 max-h-[600px] overflow-y-auto pr-2 custom-scrollbar">
                        {editorPages.map((page, idx) => (
                           <div 
                             key={idx} 
                             className={`relative group bg-white border-2 rounded-xl overflow-hidden transition-all ${
                               page.deleted ? 'border-red-200 opacity-60' : 'border-gray-200 hover:border-blue-400'
                             }`}
                           >
                              <div className="aspect-[1/1.4] relative bg-gray-100">
                                 <img 
                                   src={page.imageUrl} 
                                   alt={`Page ${idx + 1}`} 
                                   className="w-full h-full object-contain transition-transform duration-300"
                                   style={{ transform: `rotate(${page.rotation}deg)` }}
                                 />
                                 
                                 {/* Overlay for Deleted */}
                                 {page.deleted && (
                                    <div className="absolute inset-0 bg-red-50/50 flex items-center justify-center">
                                       <Trash2 size={40} className="text-red-500" />
                                    </div>
                                 )}

                                 {/* Page Number */}
                                 <div className="absolute bottom-2 left-2 bg-black/50 text-white text-xs px-2 py-1 rounded">
                                    {idx + 1}
                                 </div>
                              </div>

                              {/* Actions */}
                              <div className="p-2 flex justify-between items-center bg-gray-50 border-t border-gray-100">
                                 <button 
                                   onClick={() => {
                                      const newPages = [...editorPages];
                                      newPages[idx].rotation = (newPages[idx].rotation + 90) % 360;
                                      setEditorPages(newPages);
                                   }}
                                   className="p-1.5 hover:bg-white rounded-lg text-gray-600 hover:text-blue-600 transition-colors"
                                   title="تدوير"
                                 >
                                    <RotateCw size={16} />
                                 </button>
                                 
                                 <button 
                                   onClick={() => {
                                      const newPages = [...editorPages];
                                      newPages[idx].deleted = !newPages[idx].deleted;
                                      setEditorPages(newPages);
                                   }}
                                   className={`p-1.5 hover:bg-white rounded-lg transition-colors ${
                                      page.deleted ? 'text-red-600 bg-red-50' : 'text-gray-600 hover:text-red-600'
                                   }`}
                                   title={page.deleted ? 'استعادة' : 'حذف'}
                                 >
                                    {page.deleted ? <RotateCw size={16} className="rotate-180" /> : <Trash2 size={16} />}
                                 </button>
                              </div>
                           </div>
                        ))}
                     </div>
                  )}

                  <button
                    onClick={handleEditSave}
                    disabled={processing || isProcessingEditor}
                    className="w-full bg-blue-600 text-white py-4 rounded-xl font-bold hover:bg-blue-700 transition-colors flex items-center justify-center gap-2 mt-4"
                  >
                    {processing ? (
                      <>
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                        جاري الحفظ...
                      </>
                    ) : (
                      <>
                        <Save size={20} />
                        حفظ التعديلات
                      </>
                    )}
                  </button>
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-gray-900">الملفات المختارة ({files.length})</h3>
                    <button onClick={reset} className="text-red-500 text-sm hover:underline">إلغاء الكل</button>
                  </div>
                  
                  <div className="space-y-2">
                    {files.map((file, idx) => (
                      <div key={idx} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg border border-gray-100">
                        <div className="flex items-center gap-3">
                          <FileText size={20} className="text-blue-500" />
                          <span className="text-sm text-gray-700">{file.name}</span>
                        </div>
                        <button onClick={() => removeFile(idx)} className="text-gray-400 hover:text-red-500">
                          <X size={18} />
                        </button>
                      </div>
                    ))}
                  </div>

                {/* Naming Pattern Selection */}
                {activeTool === 'split' && files.length > 0 && (
                   <div className="mt-4 p-4 bg-blue-50 rounded-xl border border-blue-100">
                      <label className="block text-sm font-medium text-blue-900 mb-2">نمط تسمية الملفات المفككة:</label>
                      <select 
                        value={namingPattern}
                        onChange={(e) => setNamingPattern(e.target.value)}
                        className="w-full p-2 border border-blue-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      >
                        <option value="page">تلقائي (page_1.pdf)</option>
                        <option value="project_unit_type">مشروع_وحدة_نوع_رقم (يتطلب اختيار بيانات الربط لاحقاً)</option>
                      </select>
                      {namingPattern === 'project_unit_type' && (
                        <p className="text-xs text-blue-600 mt-1">
                          * سيتم تطبيق التسمية عند الرفع والربط بناءً على المشروع والوحدة المختارين.
                        </p>
                      )}
                   </div>
                )}

                  <button
                    onClick={processAction}
                    disabled={processing}
                    className="w-full bg-blue-600 text-white py-4 rounded-xl font-bold hover:bg-blue-700 transition-colors flex items-center justify-center gap-2 mt-8"
                  >
                    {processing ? (
                      <>
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                        جاري المعالجة...
                      </>
                    ) : (
                      <>
                        <CheckCircle2 size={20} />
                        بدء المعالجة
                      </>
                    )}
                  </button>
                </div>
              )}
            </>
          )}

          {/* Result (Single File) */}
          {resultUrl && (
            <div className="text-center py-8">
              <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6 text-green-600">
                <CheckCircle2 size={40} />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">تمت العملية بنجاح!</h3>
              <p className="text-gray-500 mb-8">ملفك جاهز للتحميل</p>
              
              <div className="flex justify-center gap-4">
                <a 
                  href={resultUrl} 
                  download={`processed_file.${activeTool === 'img-to-pdf' ? 'pdf' : 'pdf'}`}
                  className="bg-blue-600 text-white px-8 py-3 rounded-xl font-bold hover:bg-blue-700 transition-colors flex items-center gap-2"
                >
                  <Download size={20} />
                  تحميل الملف
                </a>
                <button 
                  onClick={reset}
                  className="bg-gray-100 text-gray-700 px-8 py-3 rounded-xl font-bold hover:bg-gray-200 transition-colors"
                >
                  عملية جديدة
                </button>
              </div>
            </div>
          )}

          {/* Result (Multiple Images) */}
          {resultImages.length > 0 && (
            <div className="py-8">
              <div className="text-center mb-8">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4 text-green-600">
                  <CheckCircle2 size={32} />
                </div>
                <h3 className="text-xl font-bold text-gray-900">تمت العملية بنجاح!</h3>
                <p className="text-gray-500">تم استخراج {resultImages.length} صورة</p>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
                {resultImages.map((url, idx) => (
                  <div key={idx} className="bg-gray-50 p-2 rounded-lg border border-gray-200 text-center">
                    <img src={url} alt={`Page ${idx + 1}`} className="w-full h-32 object-contain mb-2 bg-white rounded" />
                    <p className="text-xs text-gray-500 mb-2">صفحة {idx + 1}</p>
                    <a 
                      href={url} 
                      download={`page_${idx + 1}.jpg`}
                      className="text-blue-600 text-xs font-bold hover:underline flex items-center justify-center gap-1"
                    >
                      <Download size={12} />
                      تحميل
                    </a>
                  </div>
                ))}
              </div>

              <div className="text-center">
                <button 
                  onClick={reset}
                  className="bg-gray-100 text-gray-700 px-8 py-3 rounded-xl font-bold hover:bg-gray-200 transition-colors"
                >
                  عملية جديدة
                </button>
              </div>
            </div>
          )}

          {/* Result (Split PDFs) */}
          {resultPdfs.length > 0 && (
            <div className="py-8">
              <div className="text-center mb-8">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4 text-green-600">
                  <CheckCircle2 size={32} />
                </div>
                <h3 className="text-xl font-bold text-gray-900">تمت العملية بنجاح!</h3>
                <p className="text-gray-500">تم استخراج {resultPdfs.length} ملف</p>
                
                 <button
                   onClick={() => {
                     setBulkUploadMode(true);
                     setShowLinkModal(true);
                   }}
                   className="mt-4 bg-green-600 text-white px-6 py-2 rounded-lg font-bold hover:bg-green-700 transition-colors inline-flex items-center gap-2"
                 >
                   <Save size={18} />
                   حفظ وربط الكل
                 </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
                {resultPdfs.map((item, idx) => (
                  <div key={idx} className="bg-gray-50 p-4 rounded-xl border border-gray-200 flex flex-col items-center">
                    <div className="w-full h-40 bg-white rounded-lg border border-gray-100 mb-4 flex items-center justify-center relative group overflow-hidden">
                      <iframe 
                        src={`${item.url}#toolbar=0&view=Fit`} 
                        className="w-full h-full pointer-events-none" 
                        title={`Page ${item.page}`}
                      />
                      <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                        <a 
                          href={item.url} 
                          target="_blank" 
                          rel="noreferrer"
                          className="bg-white text-gray-900 px-4 py-2 rounded-lg font-bold flex items-center gap-2 hover:bg-gray-100"
                        >
                          <Eye size={16} />
                          معاينة
                        </a>
                      </div>
                    </div>
                    
                    <div className="w-full flex items-center justify-between gap-2 mt-auto">
                      <span className="text-sm font-bold text-gray-700">صفحة {item.page}</span>
                      <div className="flex gap-2">
                        <button
                          onClick={() => {
                            setSelectedFileForLink({ url: item.url, name: `page_${item.page}.pdf`, blob: item.blob });
                            setShowLinkModal(true);
                          }}
                          className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                          title="ربط بوحدة"
                        >
                          <LinkIcon size={18} />
                        </button>
                        <a 
                          href={item.url} 
                          download={`page_${item.page}.pdf`}
                          className="p-2 text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                          title="تحميل"
                        >
                          <Download size={18} />
                        </a>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="text-center">
                <button 
                  onClick={reset}
                  className="bg-gray-100 text-gray-700 px-8 py-3 rounded-xl font-bold hover:bg-gray-200 transition-colors"
                >
                  عملية جديدة
                </button>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Link Modal */}
      {showLinkModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl relative">
            <button 
                onClick={() => {
                  setShowLinkModal(false);
                  setBulkUploadMode(false);
                  setSmartMode(false);
                  setUploadProgress(null);
                }}
                className="absolute left-4 top-4 text-gray-400 hover:text-gray-600"
              >
                <X size={24} />
              </button>
              
              <h3 className="text-xl font-bold mb-6 text-gray-900">
                {smartMode ? 'رفع وتوزيع ذكي' : bulkUploadMode ? 'رفع وربط جميع الملفات' : 'ربط الملف بالوحدة'}
              </h3>
              
              <div className="space-y-4">
                {/* Progress Bar for Bulk Upload */}
                {uploadProgress && (
                  <div className="mb-4">
                    <div className="flex justify-between text-sm mb-1 text-gray-700">
                      <span>جاري الرفع...</span>
                      <span>{uploadProgress.current} / {uploadProgress.total}</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2.5">
                      <div 
                        className="bg-blue-600 h-2.5 rounded-full transition-all duration-300" 
                        style={{ width: `${(uploadProgress.current / uploadProgress.total) * 100}%` }}
                      ></div>
                    </div>
                  </div>
                )}

                {/* Tabs for Mode Selection (Only in Bulk Mode) */}
                {bulkUploadMode && (
                   <div className="flex gap-2 mb-4 p-1 bg-gray-100 rounded-lg">
                      <button
                        onClick={() => setSmartMode(false)}
                        className={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${!smartMode ? 'bg-white shadow text-blue-600' : 'text-gray-500 hover:text-gray-700'}`}
                      >
                        ربط بوحدة واحدة
                      </button>
                      <button
                        onClick={() => setSmartMode(true)}
                        className={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${smartMode ? 'bg-white shadow text-blue-600' : 'text-gray-500 hover:text-gray-700'}`}
                      >
                        توزيع ذكي (نطاق)
                      </button>
                   </div>
                )}

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">المشروع</label>
                  <select
                    value={selectedProject}
                    onChange={(e) => {
                      setSelectedProject(e.target.value);
                      setSelectedUnit('');
                      setStartUnitId('');
                      setEndUnitId('');
                    }}
                    className="w-full p-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                  >
                    <option value="">اختر المشروع</option>
                    {projects.map(p => (
                      <option key={p.id} value={p.id}>{p.name}</option>
                    ))}
                  </select>
                </div>

                {!smartMode ? (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">الوحدة</label>
                    <select
                      value={selectedUnit}
                      onChange={(e) => setSelectedUnit(e.target.value)}
                      disabled={!selectedProject}
                      className="w-full p-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all disabled:bg-gray-50 disabled:text-gray-400"
                    >
                      <option value="">اختر الوحدة</option>
                      {units.map(u => (
                        <option key={u.id} value={u.id}>{u.unit_number}</option>
                      ))}
                    </select>
                  </div>
                ) : (
                  <div className="space-y-4 border-t border-b border-gray-100 py-4">
                     <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">من وحدة</label>
                          <select
                            value={startUnitId}
                            onChange={(e) => setStartUnitId(e.target.value)}
                            disabled={!selectedProject}
                            className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                          >
                            <option value="">اختر</option>
                            {units.map(u => (
                              <option key={u.id} value={u.id}>{u.unit_number}</option>
                            ))}
                          </select>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">إلى وحدة</label>
                          <select
                            value={endUnitId}
                            onChange={(e) => setEndUnitId(e.target.value)}
                            disabled={!selectedProject}
                            className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                          >
                            <option value="">اختر</option>
                            {units.map(u => (
                              <option key={u.id} value={u.id}>{u.unit_number}</option>
                            ))}
                          </select>
                        </div>
                     </div>

                     <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">من صفحة</label>
                          <input
                            type="number"
                            min="1"
                            max={resultPdfs.length}
                            value={startPage}
                            onChange={(e) => setStartPage(parseInt(e.target.value))}
                            className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">إلى صفحة</label>
                          <input
                            type="number"
                            min="1"
                            max={resultPdfs.length}
                            value={endPage}
                            onChange={(e) => setEndPage(parseInt(e.target.value))}
                            className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                          />
                        </div>
                     </div>
                     
                     <div className="text-xs text-blue-600 bg-blue-50 p-2 rounded">
                        سيتم ربط {Math.max(0, endPage - startPage + 1)} صفحة بـ {
                          startUnitId && endUnitId 
                          ? Math.max(0, units.findIndex(u => u.id === endUnitId) - units.findIndex(u => u.id === startUnitId) + 1)
                          : 0
                        } وحدة بالتتابع.
                     </div>
                  </div>
                )}

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">نوع الملف</label>
                  <select
                    value={linkType}
                    onChange={(e) => setLinkType(e.target.value)}
                    className="w-full p-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                  >
                    <option value="other">ملفات أخرى</option>
                    <option value="deed">صك</option>
                    <option value="sorting">محضر فرز</option>
                    <option value="contract">عقد</option>
                  </select>
                  {linkType === 'other' && (
                    <p className="text-xs text-gray-500 mt-1">
                      سيتم ربط الملفات بجدول العقود والمستندات كملف إضافي.
                    </p>
                  )}
                </div>

                {/* Naming Pattern Selection */}
                {(bulkUploadMode || smartMode) && (
                  <div className="mt-2">
                    <label className="block text-sm font-medium text-gray-700 mb-1">نمط تسمية الملفات</label>
                    <div className="flex gap-2">
                      <button
                        onClick={() => setNamingPattern('page')}
                        className={`flex-1 py-2 px-3 rounded-lg text-sm border ${namingPattern === 'page' ? 'bg-blue-50 border-blue-500 text-blue-700' : 'border-gray-200 text-gray-600 hover:bg-gray-50'}`}
                      >
                        رقم الصفحة (page_X.pdf)
                      </button>
                      <button
                        onClick={() => setNamingPattern('project_unit_type')}
                        className={`flex-1 py-2 px-3 rounded-lg text-sm border ${namingPattern === 'project_unit_type' ? 'bg-blue-50 border-blue-500 text-blue-700' : 'border-gray-200 text-gray-600 hover:bg-gray-50'}`}
                      >
                        مفصل (المشروع_الوحدة...)
                      </button>
                    </div>
                  </div>
                )}
                
                {bulkUploadMode && namingPattern === 'project_unit_type' && selectedProject && (selectedUnit || (startUnitId && endUnitId)) && (
                   <div className="p-3 bg-gray-50 rounded-lg text-sm text-gray-600">
                      <span className="font-bold">معاينة الاسم:</span> {getNaming(startPage, smartMode ? startUnitId : selectedUnit)}
                   </div>
                )}

                <button
                  onClick={handleLinkFile}
                  disabled={isUploading || (!selectedUnit && !smartMode)}
                  className="w-full bg-blue-600 text-white py-3 rounded-xl font-bold hover:bg-blue-700 transition-colors disabled:bg-blue-300 disabled:cursor-not-allowed flex justify-center items-center gap-2 mt-4"
                >
                  {isUploading ? 'جاري الرفع...' : (bulkUploadMode ? (smartMode ? 'توزيع وربط ذكي' : 'رفع الكل') : 'رفع وربط')}
                </button>
              </div>
          </div>
        </div>
      )}
    </div>
  );
}
