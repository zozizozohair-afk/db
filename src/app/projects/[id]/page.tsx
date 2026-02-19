import ProjectDetailsClient from './ProjectDetailsClient';

export const dynamic = 'force-dynamic';
export const runtime = 'edge';

export default function Page({ params }: { params: { id: string } }) {
  const { id } = params;
  return <ProjectDetailsClient id={id} />;
}
