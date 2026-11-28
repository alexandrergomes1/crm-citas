import { defineConfig } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react'

export default defineConfig({
  server: {
    port: 3000,
  },
  resolve: {
    tsconfigPaths: true,
  },
  plugins: [
    // telas, rotas e árvore gerada moram em src/app (ARCHITECTURE.md §3)
    tanstackStart({ srcDirectory: 'src/app' }),
    // o plugin do React vem depois do Start (doc oficial do TanStack Start)
    viteReact(),
  ],
})
