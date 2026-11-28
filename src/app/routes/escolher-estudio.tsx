import { createFileRoute, redirect } from '@tanstack/react-router'
import { textosDe } from '@/app/i18n/textos'
import { EscolherEstudio } from '@/app/paginas/escolher-estudio'
import type { ChamadaDaTela } from '@/server/portas/acao'
import { escolherEstudio, listarEstudios, sair, type entradaDeEscolher } from '@/server/sessao/acoes'
import entrarCss from '@/app/paginas/entrar.css?url'
import escolherCss from '@/app/paginas/escolher-estudio.css?url'

// Tela Escolher estúdio (spec RF-11 a RF-14). O estúdio vai no corpo da ação, nunca no endereço (RF-33).
const chamarEscolher: ChamadaDaTela<typeof escolherEstudio, typeof entradaDeEscolher, 'pessoa'> = escolherEstudio

/** Sair: encerra no servidor e volta a Entrar com a página recarregada (nada fica na memória; CA-13). */
async function sairEVoltar(): Promise<void> {
  try {
    await sair()
  } finally {
    window.location.replace('/entrar')
  }
}

const listar = () => listarEstudios()
const escolher = (orgId: string) => chamarEscolher({ data: { dados: { orgId } } })
// Recarrega a área com sessão: idioma e dados do estúdio novo (RF-35); nada do estúdio anterior fica na memória.
const aoEscolher = () => window.location.assign('/')
const aoPerderSessao = () => window.location.replace('/entrar')

export const Route = createFileRoute('/escolher-estudio')({
  beforeLoad: ({ context }) => {
    if (!context.sessao.comSessao) throw redirect({ to: '/entrar' })
  },
  head: () => ({
    links: [
      { rel: 'stylesheet', href: entrarCss },
      { rel: 'stylesheet', href: escolherCss },
    ],
  }),
  component: PaginaEscolherEstudio,
})

function PaginaEscolherEstudio() {
  const { sessao } = Route.useRouteContext()
  return (
    <EscolherEstudio
      textos={textosDe(sessao.idioma)}
      idioma={sessao.idioma}
      listar={listar}
      escolher={escolher}
      aoEscolher={aoEscolher}
      aoPerderSessao={aoPerderSessao}
      onSair={() => void sairEVoltar()}
    />
  )
}
