/// <reference types="vite/client" />
import type { ReactNode } from 'react'
import {
  Outlet,
  createRootRoute,
  HeadContent,
  Scripts,
} from '@tanstack/react-router'
import { IDIOMA_PADRAO } from '@/domain/idioma'
import { lerSessao, type SessaoLida } from '@/server/sessao/acoes'
// Folha única do design system (plan.md §5; molde ?url do TanStack Start)
import appCss from '../estilos/app.css?url'

const SEM_SESSAO: SessaoLida = { comSessao: false, comEstudio: false, idioma: IDIOMA_PADRAO, inicial: null }

export const Route = createRootRoute({
  // sessao.ler a cada carga de página ou navegação pedida pela pessoa; nunca por recarga automática (ADR 0018 · D5).
  // O que a tela sabe da sessão só desenha: a trava é a porta 1 em cada ação (plan.md §7).
  beforeLoad: async (): Promise<{ sessao: SessaoLida }> => {
    try {
      const lida = await lerSessao()
      return { sessao: lida.ok ? lida.valor : SEM_SESSAO }
    } catch {
      return { sessao: SEM_SESSAO }
    }
  },
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: 'crm-citas' },
    ],
    links: [{ rel: 'stylesheet', href: appCss }],
  }),
  component: RootComponent,
})

function RootComponent() {
  const { sessao } = Route.useRouteContext()
  return (
    <RootDocument idioma={sessao.idioma}>
      <Outlet />
    </RootDocument>
  )
}

function RootDocument({ idioma, children }: Readonly<{ idioma: string; children: ReactNode }>) {
  return (
    // idioma do estúdio depois de escolhido; antes, o do navegador (spec RF-34, RF-35)
    <html lang={idioma}>
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  )
}
