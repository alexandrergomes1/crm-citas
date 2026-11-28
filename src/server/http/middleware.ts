// Middleware global do servidor (ADR 0018 · D10; spec RF-06, RF-10). Ligado em src/app/start.ts.
// - semCache: Cache-Control: no-store em toda resposta de página e de ação (ASVS V8.2.1): voltar no navegador
//   ou um cache no caminho não mostra dado de quem tinha sessão.
// - protecaoCsrf: pedido de ação (server function) só da mesma origem (Sec-Fetch-Site, Origin ou Referer; ASVS V4.2.2).
import { createCsrfMiddleware, createMiddleware } from '@tanstack/react-start'

export const CABECALHO_SEM_CACHE = 'no-store'

/** Põe no-store na resposta; se os cabeçalhos dela não aceitam mudança, cria uma cópia. */
export function semCacheNa(resposta: Response): Response {
  try {
    resposta.headers.set('Cache-Control', CABECALHO_SEM_CACHE)
    return resposta
  } catch {
    const copia = new Response(resposta.body, resposta)
    copia.headers.set('Cache-Control', CABECALHO_SEM_CACHE)
    return copia
  }
}

export const semCache = createMiddleware().server(async ({ next }) => {
  const resultado = await next()
  return { ...resultado, response: semCacheNa(resultado.response) }
})

export const protecaoCsrf = createCsrfMiddleware({ filter: (ctx) => ctx.handlerType === 'serverFn' })
