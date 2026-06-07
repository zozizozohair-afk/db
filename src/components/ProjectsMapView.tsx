'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import type { LatLngLiteral, Map as LeafletMap } from 'leaflet';

type ProjectMapItem = {
  id: string;
  name: string;
  projectNumber: string;
  locationLat?: number | null;
  locationLng?: number | null;
  locationUrl?: string | null;
};

function FitBounds({ points }: { points: LatLngLiteral[] }) {
  return null;
}

export default function ProjectsMapView({ projects }: { projects: ProjectMapItem[] }) {
  const [map, setMap] = useState<LeafletMap | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<LeafletMap | null>(null);
  const [mapContainerKey] = useState(() => {
    if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  });
  const markersLayerRef = useRef<any | null>(null);
  const points = useMemo(
    () =>
      projects
        .filter((p) => typeof p.locationLat === 'number' && typeof p.locationLng === 'number')
        .map((p) => ({ lat: p.locationLat as number, lng: p.locationLng as number })),
    [projects]
  );

  useEffect(() => {
    let isCancelled = false;
    const init = async () => {
      if (!containerRef.current) return;
      if (mapRef.current) return;
      const L = await import('leaflet');
      if (isCancelled) return;

      const container = containerRef.current as any;
      if (container && container._leaflet_id) delete container._leaflet_id;

      const m = L.map(containerRef.current, { zoomControl: true, attributionControl: true });
      mapRef.current = m as any;
      setMap(m as any);

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
      }).addTo(m);

      markersLayerRef.current = L.layerGroup().addTo(m);
      m.setView([24.7136, 46.6753], 6);
      setTimeout(() => {
        try {
          m.invalidateSize?.();
        } catch {}
      }, 50);
    };

    init();
    return () => {
      isCancelled = true;
      const m = mapRef.current;
      if (!m) return;
      const container = containerRef.current as any;
      try {
        m.off();
      } catch {}
      try {
        m.remove();
      } catch {}
      try {
        if (container && container._leaflet_id) {
          delete container._leaflet_id;
        }
      } catch {}
      markersLayerRef.current = null;
      mapRef.current = null;
      setMap(null);
    };
  }, []);

  const markerHtmlByProjectId = useMemo(() => {
    const map = new Map<string, string>();
    for (const p of projects) {
      const label = String(p.projectNumber || '-');
      const html = `
        <div style="position:relative;width:36px;height:48px;">
          <div style="position:absolute;left:50%;top:0;transform:translate(-50%,-8px);background:#ffffff;border:1px solid #cbd5e1;border-radius:8px;padding:3px 8px;font-weight:800;font-size:12px;line-height:1;color:#0f172a;box-shadow:0 1px 2px rgba(15,23,42,0.12);white-space:nowrap;">
            ${label}
          </div>
          <div style="position:absolute;left:50%;top:18px;transform:translateX(-50%);width:18px;height:18px;background:#0f766e;border:2px solid #ffffff;border-radius:999px;box-shadow:0 2px 6px rgba(2,6,23,0.25);"></div>
          <div style="position:absolute;left:50%;top:28px;transform:translateX(-50%);width:0;height:0;border-left:10px solid transparent;border-right:10px solid transparent;border-top:18px solid #0f766e;filter:drop-shadow(0 2px 3px rgba(2,6,23,0.25));"></div>
        </div>
      `;
      map.set(p.id, html);
    }
    return map;
  }, [projects]);

  const withLocation = useMemo(
    () => projects.filter((p) => typeof p.locationLat === 'number' && typeof p.locationLng === 'number'),
    [projects]
  );
  const withoutLocation = useMemo(
    () => projects.filter((p) => !(typeof p.locationLat === 'number' && typeof p.locationLng === 'number')),
    [projects]
  );

  useEffect(() => {
    const run = async () => {
      const m = mapRef.current as any;
      const layer = markersLayerRef.current as any;
      if (!m || !layer) return;
      const L = await import('leaflet');

      layer.clearLayers();

      for (const p of withLocation) {
        const html = markerHtmlByProjectId.get(p.id) || '';
        const icon = L.divIcon({
          className: '',
          html,
          iconSize: [36, 48],
          iconAnchor: [18, 48],
          popupAnchor: [0, -46]
        });
        const marker = L.marker([p.locationLat as number, p.locationLng as number], { icon }).addTo(layer);
        const popupHtml = `
          <div dir="rtl" style="min-width:220px">
            <div style="font-weight:800;color:#0f172a;margin-bottom:6px;">${String(p.name || '')}</div>
            <div style="font-size:12px;font-weight:700;color:#475569;margin-bottom:10px;">
              رقم المشروع: <span style="color:#0f172a;">${String(p.projectNumber || '-')}</span>
            </div>
            <div style="display:flex;gap:8px;align-items:center;">
              <a href="/projects/${p.id}" style="display:inline-flex;align-items:center;justify-content:center;padding:8px 10px;border-radius:8px;border:1px solid #042f2e;background:linear-gradient(90deg,#064e3b,#0f766e,#1e3a8a);color:#fff;font-weight:800;font-size:12px;text-decoration:none;">عرض المشروع</a>
              ${
                p.locationUrl
                  ? `<a href="${p.locationUrl}" target="_blank" rel="noreferrer" style="display:inline-flex;align-items:center;justify-content:center;padding:8px 10px;border-radius:8px;border:1px solid #cbd5e1;background:#fff;color:#0f172a;font-weight:800;font-size:12px;text-decoration:none;">فتح بالخريطة</a>`
                  : ''
              }
            </div>
          </div>
        `;
        marker.bindPopup(popupHtml);
      }

      if (points.length === 1) {
        m.setView([points[0].lat, points[0].lng], Math.max(m.getZoom?.() ?? 16, 16), { animate: true });
      } else if (points.length > 1) {
        try {
          m.fitBounds(points.map((p) => [p.lat, p.lng]) as any, { padding: [30, 30] });
        } catch {}
      }

      setTimeout(() => {
        try {
          m.invalidateSize?.();
        } catch {}
      }, 50);
    };

    run();
  }, [map, markerHtmlByProjectId, points, withLocation]);

  return (
    <div className="bg-white rounded-md border border-slate-300 shadow-sm overflow-hidden">
      <div className="flex flex-col lg:flex-row">
        <div className="flex-1">
          <div className="h-[70vh] min-h-[420px]">
            <div key={mapContainerKey} ref={containerRef} className="w-full h-full" />
          </div>
        </div>

        <div className="w-full lg:w-[360px] border-t lg:border-t-0 lg:border-r border-slate-200 bg-slate-50">
          <div className="p-3 border-b border-slate-200">
            <div className="text-sm font-extrabold text-slate-900">المشاريع</div>
            <div className="text-xs font-bold text-slate-600 mt-0.5">
              على الخريطة: <span className="text-slate-900">{withLocation.length}</span> / {projects.length}
            </div>
          </div>

          <div className="max-h-[70vh] min-h-[420px] overflow-auto custom-scrollbar p-2 space-y-2">
            {withLocation.map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => {
                  const m = mapRef.current as any;
                  if (!m) return;
                  m.setView([p.locationLat as number, p.locationLng as number], Math.max(m.getZoom?.() ?? 16, 16), { animate: true });
                }}
                className="w-full text-right bg-white rounded-md border-2 border-slate-300 hover:border-slate-400 shadow-sm px-3 py-2"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="font-extrabold text-slate-900 truncate">{p.name}</div>
                  <div className="shrink-0 px-2 py-1 rounded-md bg-slate-900 text-white text-xs font-extrabold">
                    {p.projectNumber || '-'}
                  </div>
                </div>
                <div className="mt-1 text-[11px] font-bold text-slate-600 truncate">
                  {p.locationLat}, {p.locationLng}
                </div>
                <div className="mt-2 flex items-center justify-end">
                  <Link
                    href={`/projects/${p.id}`}
                    onClick={(e) => e.stopPropagation()}
                    className="inline-flex items-center justify-center px-3 py-2 rounded-md border border-teal-950 bg-gradient-to-l from-emerald-900 via-teal-900 to-blue-900 text-white text-[11px] font-extrabold"
                  >
                    عرض المشروع
                  </Link>
                </div>
              </button>
            ))}

            {withoutLocation.length > 0 && (
              <div className="pt-2">
                <div className="px-2 pb-2 text-xs font-extrabold text-slate-700">بدون موقع</div>
                <div className="space-y-2">
                  {withoutLocation.map((p) => (
                    <div key={p.id} className="bg-white rounded-md border border-slate-200 px-3 py-2">
                      <div className="flex items-center justify-between gap-2">
                        <div className="font-extrabold text-slate-900 truncate">{p.name}</div>
                        <div className="shrink-0 px-2 py-1 rounded-md bg-slate-100 text-slate-800 text-xs font-extrabold border border-slate-200">
                          {p.projectNumber || '-'}
                        </div>
                      </div>
                      <div className="mt-2 flex items-center justify-end">
                        <Link
                          href={`/projects/${p.id}`}
                          className="inline-flex items-center justify-center px-3 py-2 rounded-md border border-slate-300 bg-white text-slate-800 text-[11px] font-extrabold"
                        >
                          فتح المشروع
                        </Link>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="p-3 border-t border-slate-200 bg-slate-50 flex flex-col md:flex-row md:items-center justify-between gap-2">
        <div className="text-sm font-bold text-slate-800">
          مواقع على الخريطة: <span className="font-extrabold">{points.length}</span> / {projects.length}
        </div>
        <div className="text-xs text-slate-600 font-bold">المشاريع بدون موقع تظهر هنا فقط بعد إضافة الإحداثيات من تعديل المشروع</div>
      </div>
    </div>
  );
}
