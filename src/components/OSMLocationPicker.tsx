'use client';

import React, { useEffect, useMemo, useRef } from 'react';
import type { LatLngLiteral, LeafletMouseEvent, Map as LeafletMap } from 'leaflet';

type LocationValue = {
  lat: number | null;
  lng: number | null;
};

type OSMLocationPickerProps = {
  value: LocationValue;
  onChange: (next: LocationValue) => void;
  heightClassName?: string;
  readOnly?: boolean;
};

function MapClickHandler({
  readOnly,
  onPick
}: {
  readOnly?: boolean;
  onPick: (p: LatLngLiteral) => void;
}) {
  return null;
}

function CenterOnValue({ center }: { center: LatLngLiteral }) {
  return null;
}

export default function OSMLocationPicker({
  value,
  onChange,
  heightClassName = 'h-64',
  readOnly
}: OSMLocationPickerProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<LeafletMap | null>(null);
  const markerRef = useRef<any | null>(null);
  const mapContainerKey = useMemo(() => {
    if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }, []);
  const fallbackCenter = useMemo<LatLngLiteral>(() => ({ lat: 24.7136, lng: 46.6753 }), []);
  const hasValue = typeof value.lat === 'number' && typeof value.lng === 'number';
  const center = hasValue ? ({ lat: value.lat as number, lng: value.lng as number } as LatLngLiteral) : fallbackCenter;

  useEffect(() => {
    let isCancelled = false;
    const init = async () => {
      if (!containerRef.current) return;
      if (mapRef.current) return;
      const L = await import('leaflet');
      if (isCancelled) return;

      const container = containerRef.current as any;
      if (container && container._leaflet_id) delete container._leaflet_id;

      const map = L.map(containerRef.current, {
        zoomControl: true,
        attributionControl: true
      });
      mapRef.current = map as any;

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
      }).addTo(map);

      map.setView([center.lat, center.lng], hasValue ? 16 : 6);

      if (!readOnly) {
        map.on('click', (e: LeafletMouseEvent) => {
          const lat = Number(e.latlng.lat.toFixed(6));
          const lng = Number(e.latlng.lng.toFixed(6));
          onChange({ lat, lng });
        });
      }
    };

    init();
    return () => {
      isCancelled = true;
      const map = mapRef.current as any;
      const container = containerRef.current as any;
      try {
        map?.off?.();
      } catch {}
      try {
        map?.remove?.();
      } catch {}
      try {
        if (container && container._leaflet_id) {
          delete container._leaflet_id;
        }
      } catch {}
      markerRef.current = null;
      mapRef.current = null;
    };
  }, [center.lat, center.lng, hasValue, onChange, readOnly]);

  useEffect(() => {
    const run = async () => {
      const map = mapRef.current as any;
      if (!map) return;
      const L = await import('leaflet');

      map.setView([center.lat, center.lng], hasValue ? Math.max(map.getZoom?.() ?? 16, 16) : 6, { animate: true });

      if (hasValue) {
        if (!markerRef.current) {
          markerRef.current = L.circleMarker([center.lat, center.lng], {
            radius: 9,
            color: '#0f766e',
            fillColor: '#0f766e',
            fillOpacity: 0.85
          }).addTo(map);
        } else {
          markerRef.current.setLatLng([center.lat, center.lng]);
        }
      } else if (markerRef.current) {
        try {
          markerRef.current.remove();
        } catch {}
        markerRef.current = null;
      }

      setTimeout(() => {
        try {
          map.invalidateSize?.();
        } catch {}
      }, 50);
    };
    run();
  }, [center.lat, center.lng, hasValue]);

  return (
    <div className={`w-full overflow-hidden rounded-md border-2 border-slate-300 ${heightClassName}`}>
      <div key={mapContainerKey} ref={containerRef} className="w-full h-full" />
    </div>
  );
}
