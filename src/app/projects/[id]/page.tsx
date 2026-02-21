import ProjectDetailsClient from './ProjectDetailsClient';
 
export const dynamic = 'force-dynamic';
export const runtime = 'edge';
 
export default async function Page(props: { params: { id: string } }) {
  const { params } = await props;
  const { id } = params;
  return <ProjectDetailsClient id={id} />;
}
