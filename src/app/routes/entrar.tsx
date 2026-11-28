import { createFileRoute, redirect, useNavigate } from '@tanstack/react-router'
import { textosDe } from '@/app/i18n/textos'
import { Entrar } from '@/app/paginas/entrar'
import type { ChamadaDaTela } from '@/server/portas/acao'
import { entrar, type entradaDeEntrar } from '@/server/sessao/acoes'
import entrarCss from '@/app/paginas/entrar.css?url'

// Tela Entrar (spec RF-30 a RF-33). Só o caminho no endereço: nada de e-mail, estúdio nem motivo (RF-33).
const chamarEntrar: ChamadaDaTela<typeof entrar, typeof entradaDeEntrar, 'nenhuma'> = entrar

export const Route = createFileRoute('/entrar')({
  // Já com sessão: segue para onde ela está (RF-11); a trava real é a porta 1 de cada ação.
  beforeLoad: ({ context }) => {
    if (context.sessao.comSessao) throw redirect({ to: context.sessao.comEstudio ? '/' : '/escolher-estudio' })
  },
  head: () => ({ links: [{ rel: 'stylesheet', href: entrarCss }] }),
  component: PaginaEntrar,
})

function PaginaEntrar() {
  const { sessao } = Route.useRouteContext()
  const navegar = useNavigate()
  return (
    <Entrar
      textos={textosDe(sessao.idioma)}
      entrar={(email, senha) => chamarEntrar({ data: { dados: { email, senha } } })}
      aoEntrar={(destino) => void navegar({ to: destino === 'inicio' ? '/' : '/escolher-estudio', replace: true })}
    />
  )
}
