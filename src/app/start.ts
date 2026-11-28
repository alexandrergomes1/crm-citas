// Instância do TanStack Start (start.ts em srcDirectory; ADR 0018 · D10). Com este arquivo, o CSRF é posto à mão.
// Ordem: CSRF primeiro (recusa cedo), depois no-store em toda resposta.
import { createStart } from '@tanstack/react-start'
import { protecaoCsrf, semCache } from '@/server/http/middleware'

export const startInstance = createStart(() => ({
  requestMiddleware: [protecaoCsrf, semCache],
}))
