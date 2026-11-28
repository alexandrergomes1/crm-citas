// Comparação da matriz do código com a cópia do teste do banco (ADR 0020 · D8; ADR 0019 · D21).
// Roda no `pnpm db:test` (job `banco` da CI), antes do pgTAP: código = 110_ (aqui) e 110_ = banco (pgTAP).
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['supabase/matriz/**/*.test.ts'],
    environment: 'node',
  },
})
