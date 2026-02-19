import UnitDetailsPageClient from './UnitDetailsPageClient';

export const dynamic = 'force-dynamic';
export const runtime = 'edge';

export default function Page({ params }: { params: { id: string } }) {
  const { id } = params;
  return <UnitDetailsPageClient params={{ id }} />;
}
