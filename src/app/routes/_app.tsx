import { Outlet, createFileRoute, redirect, useNavigate } from '@tanstack/react-router'
import { textosDe } from '@/app/i18n/textos'
import { BarraSuaConta } from '@/app/paginas/sua-conta'
import { listarEstudios, sair } from '@/server/sessao/acoes'
import suaContaCss from '@/app/paginas/sua-conta.css?url'

// Área com sessão (plan.md §7): sem sessão → Entrar; sem estúdio → Escolher estúdio. Isto só desenha: a trava real é a
// porta 1 em cada ação (guia SSR do Supabase).
export const Route = createFileRoute('/_app')({
  beforeLoad: ({ context }) => {
    if (!context.sessao.comSessao) throw redirect({ to: '/entrar' })
    if (!context.sessao.comEstudio) throw redirect({ to: '/escolher-estudio' })
  },
  // Quantos estúdios ativos: "Trocar de estúdio" só com mais de um (RF-14). Só na carga pedida pela pessoa (D5).
  loader: async (): Promise<{ quantosEstudios: number }> => {
    try {
      const lista = await listarEstudios()
      return { quantosEstudios: lista.ok ? lista.valor.length : 0 }
    } catch {
      return { quantosEstudios: 0 }
    }
  },
  head: () => ({ links: [{ rel: 'stylesheet', href: suaContaCss }] }),
  component: AreaComSessao,
})

/** Sair: encerra no servidor e volta a Entrar com a página recarregada (nada fica na memória; CA-13). */
async function sairEVoltar(): Promise<void> {
  try {
    await sair()
  } finally {
    window.location.replace('/entrar')
  }
}

function AreaComSessao() {
  const { sessao } = Route.useRouteContext()
  const { quantosEstudios } = Route.useLoaderData()
  const navegar = useNavigate()
  return (
    <>
      <BarraSuaConta
        textos={textosDe(sessao.idioma)}
        // PENDENTE: sessao.ler ainda não devolve a inicial do e-mail (DESIGN.md §8b); fora dos arquivos da T2
        inicial=""
        quantosEstudios={quantosEstudios}
        onTrocar={() => void navegar({ to: '/escolher-estudio' })}
        onSair={() => void sairEVoltar()}
      />
      <Outlet />
    </>
  )
}
