import { EnrichedUnit } from '../components/DeedsTable';

/**
 * Logic for "Number of Rooms" (عدد الغرف)
 * 
 * Logic depends on direction_label (اتجاه الوحدة):
 * - If contains "امامية":
 *   - Standard: 5 rooms
 *   - Project "115": 4 rooms
 * - If contains "خلفية":
 *   - Standard: 4 rooms
 *   - Project "115": 3 rooms
 * - Special for Project "115":
 *   - Annex (ملحق): 5 rooms
 */
export const getUnitRooms = (unit: EnrichedUnit): string => {
  const direction = unit.direction_label || '';
  const projectNum = unit.project_number || '';
  const isProject115 = projectNum.includes('115');

  // Annex check for 115
  if (isProject115 && (unit.type === 'annex' || direction.includes('ملحق'))) {
    return '5';
  }

  if (direction.includes('امامية') || direction.includes('أمامية')) {
    return isProject115 ? '4' : '5';
  }

  if (direction.includes('خلفية')) {
    return isProject115 ? '3' : '4';
  }

  return '-';
};

/**
 * Logic for "Facade" (الواجهة)
 * 
 * Logic depends on direction_label (اتجاه الوحدة):
 * - If contains "امامية" or "أمامية": "أمامية"
 * - If type is "annex" (ملحق): "أمامية"
 * - If contains "خلفية": "خلفية"
 */
export const getUnitFacade = (unit: EnrichedUnit): string => {
  const direction = unit.direction_label || '';
  
  if (direction.includes('امامية') || direction.includes('أمامية') || unit.type === 'annex' || direction.includes('ملحق')) {
    return 'أمامية';
  }

  if (direction.includes('خلفية')) {
    return 'خلفية';
  }

  return '-';
};
