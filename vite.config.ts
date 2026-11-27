import { defineConfig } from 'vite';
import { tanstackStart } from '@tanstack/react-start/plugin/vite';
import { cloudflare } from '@cloudflare/vite-plugin';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';

// Carimbo da versão (BuildStamp): commit do Workers Builds ou do GitHub Actions; "local" fora deles.
const sha = (process.env.WORKERS_CI_COMMIT_SHA ?? process.env.GITHUB_SHA ?? '').slice(0, 7);
const buildDate = sha ? new Date().toISOString().slice(0, 16).replace('T', ' ') : '';

// Ordem do guia da Cloudflare: cloudflare → tanstackStart → react. Porta 3000 (mesma dos E2E).
export default defineConfig({
  define: {
    'import.meta.env.VITE_BUILD_SHA': JSON.stringify(sha),
    'import.meta.env.VITE_BUILD_DATE': JSON.stringify(buildDate),
  },
  server: { port: 3000 },
  preview: { port: 3000 },
  resolve: { tsconfigPaths: true },
  // Pacote do Worker minificado (o Vite não minifica o servidor por padrão): menos bytes para o isolate
  // ler e compilar no arranque a frio. O código do navegador já sai minificado.
  environments: { ssr: { build: { minify: true } } },
  plugins: [
    cloudflare({ viteEnvironment: { name: 'ssr' } }),
    tailwindcss(),
    tanstackStart(),
    react(),
  ],
});
