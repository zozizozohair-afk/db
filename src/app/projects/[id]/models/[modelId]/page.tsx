import ModelDetailsClient from './ModelDetailsClient';

export const dynamic = 'force-dynamic';
export const runtime = 'edge';

export default async function Page({ params }: { params: Promise<{ id: string; modelId: string }> }) {
  const { id, modelId } = await params;
  return <ModelDetailsClient projectId={id} modelId={modelId} />;
}

