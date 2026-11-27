import { createFileRoute } from '@tanstack/react-router';
import { APP_NAME } from '@/domain';

export const Route = createFileRoute('/')({
  component: Home,
});

function Home() {
  return (
    <main className="inicio">
      <h1>{APP_NAME} · em construção</h1>
    </main>
  );
}
