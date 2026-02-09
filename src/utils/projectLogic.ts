
export type Direction = 'North' | 'South' | 'East' | 'West' | 'NorthEast' | 'NorthWest' | 'SouthEast' | 'SouthWest';

export const DIRECTIONS_AR = {
  North: 'شمال',
  South: 'جنوب',
  East: 'شرق',
  West: 'غرب',
  NorthEast: 'شمالي شرقي',
  NorthWest: 'شمالي غربي',
  SouthEast: 'جنوبي شرقي',
  SouthWest: 'جنوبي غربي',
};

// Helper to get Arabic name
export const getDirAr = (dir: string) => DIRECTIONS_AR[dir as keyof typeof DIRECTIONS_AR] || dir;

// Logic to calculate relative directions based on Project Orientation
// Assuming a standard layout where:
// 1. Front Right (Project Dir + Right)
// 2. Front Left (Project Dir + Left)
// 3. Rear Left (Opposite Dir + Left)
// 4. Rear Right (Opposite Dir + Right)
// *Note: "Left" and "Right" are relative to standing facing the direction.
// But typically in real estate:
// If Project is North:
// Right is East, Left is West.
// Front is North. Rear is South.

const RIGHT_OF: Record<string, Direction> = {
  North: 'East',
  South: 'West',
  East: 'South',
  West: 'North',
};

const LEFT_OF: Record<string, Direction> = {
  North: 'West',
  South: 'East',
  East: 'North',
  West: 'South',
};

const OPPOSITE_OF: Record<string, Direction> = {
  North: 'South',
  South: 'North',
  East: 'West',
  West: 'East',
};

export interface GeneratedUnit {
  unitNumber: number;
  floorNumber: number; // 0 for Ground, etc. Or just 1..N
  floorLabel: string;
  directionLabel: string;
  type: 'apartment' | 'annex';
}

export const generateUnitsLogic = (
  projectOrientation: 'North' | 'South' | 'East' | 'West',
  floorsCount: number,
  unitsPerFloor: number,
  hasAnnex: boolean,
  annexCount: number, // 1 or 2
  customFloorDirections: string[] = [] // Used if unitsPerFloor != 4
): GeneratedUnit[] => {
  const units: GeneratedUnit[] = [];
  let currentUnitNumber = 1;

  // 1. Generate Regular Floors
  for (let floor = 1; floor <= floorsCount; floor++) {
    for (let i = 0; i < unitsPerFloor; i++) {
      let dirLabel = '';

      if (unitsPerFloor === 4) {
        // Strict 4-unit logic as requested
        // Unit 1: Project Dir + Right + Front
        // Unit 2: Project Dir + Left + Front
        // Unit 3: Opposite Dir + Left + Rear
        // Unit 4: Opposite Dir + Right + Rear
        
        const frontDir = projectOrientation;
        const rearDir = OPPOSITE_OF[frontDir];
        const rightDir = RIGHT_OF[frontDir];
        const leftDir = LEFT_OF[frontDir];

        // We need to combine these into the specific Arabic string format requested:
        // "شمالية شرقية امامية" (North East Front)
        
        if (i === 0) {
          // Unit 1: Front Right
          dirLabel = `${getDirAr(frontDir)}ية ${getDirAr(rightDir)}ية أمامية`; 
        } else if (i === 1) {
          // Unit 2: Front Left
          dirLabel = `${getDirAr(frontDir)}ية ${getDirAr(leftDir)}ية أمامية`;
        } else if (i === 2) {
          // Unit 3: Rear Left (Uses Opposite direction as base)
          
           // Note: LEFT_OF[rearDir] is actually the same absolute direction as Right of Front.
           // Let's trace: If North. Rear is South. Left of South is East.
           // So South-East Rear.
           
           // Wait, user said: "South West Rear" for 3rd.
           // If Proj North: 
           // 1. North East Front
           // 2. North West Front
           // 3. South West Rear (User example) -> South is Rear. West is Left of North.
           // So user logic for 3 is: Rear + Left (relative to project front).
           
           dirLabel = `${getDirAr(rearDir)}ية ${getDirAr(leftDir)}ية خلفية`;

        } else if (i === 3) {
          // Unit 4: Rear Right
           dirLabel = `${getDirAr(rearDir)}ية ${getDirAr(rightDir)}ية خلفية`; // e.g., South East Rear
        }

      } else {
        // Use custom template
        dirLabel = customFloorDirections[i] || `اتجاه ${i + 1}`;
      }

      units.push({
        unitNumber: currentUnitNumber++,
        floorNumber: floor,
        floorLabel: `الدور ${floor}`,
        directionLabel: dirLabel,
        type: 'apartment',
      });
    }
  }

  // 2. Generate Annex (if exists)
  if (hasAnnex) {
    const annexFloorLabel = 'دور الملاحق';
    
    // Logic: "ان كان عددها 2 يسيمها باسماء الاتجاهات التي عن يمني وشمال الاتجاه الاصلي"
    if (annexCount === 2) {
      // Annex 1: Right of Project
      const rightDir = RIGHT_OF[projectOrientation];
      units.push({
        unitNumber: currentUnitNumber++,
        floorNumber: floorsCount + 1,
        floorLabel: annexFloorLabel,
        directionLabel: `ملحق ${getDirAr(rightDir)}ي`, // e.g. ملحق شرقي
        type: 'annex',
      });

      // Annex 2: Left of Project
      const leftDir = LEFT_OF[projectOrientation];
      units.push({
        unitNumber: currentUnitNumber++,
        floorNumber: floorsCount + 1,
        floorLabel: annexFloorLabel,
        directionLabel: `ملحق ${getDirAr(leftDir)}ي`, // e.g. ملحق غربي
        type: 'annex',
      });
    } else {
      // If 1 Annex, usually just "Annex" or based on project dir?
      // User said: "The number of annexes is 1 or 2". Didn't specify naming for 1.
      // We will assume "ملحق" + Project Direction or just "ملحق علوي"
      // Let's use "ملحق" + Project Direction for consistency
      units.push({
        unitNumber: currentUnitNumber++,
        floorNumber: floorsCount + 1,
        floorLabel: annexFloorLabel,
        directionLabel: `ملحق ${getDirAr(projectOrientation)}ي`,
        type: 'annex',
      });
    }
  }

  return units;
};
