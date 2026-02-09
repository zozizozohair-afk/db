import UnitDetailsPageClient from './UnitDetailsPageClient';

export const dynamic = 'force-dynamic';
export const runtime = 'edge';

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <UnitDetailsPageClient params={{ id }} />;
}
