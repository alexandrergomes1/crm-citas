// Tela Entrar (spec RF-30 a RF-33; ficha E41·1·A a E41·4·A; DESIGN.md §5, §6, §8, §8b "Tela sem menu").
// Só peças do item 4; textos do arquivo de idioma. Nada vai ao endereço (RF-33): o envio é pela ação do servidor.
import { useEffect, useRef, useState, type FormEvent, type Ref } from 'react'
import type { Textos } from '@/app/i18n/textos'
import { Bloco } from '@/app/ui/bloco-lista'
import { Botao } from '@/app/ui/botao'
import { CampoSenha, CampoTexto, ErroFormulario } from '@/app/ui/campos'

export type EstadoEntrar = 'pronto' | 'enviando' | 'erro'

export interface EntrarVistaProps {
  textos: Textos
  estado: EstadoEntrar
  email: string
  senha: string
  onEmail: (valor: string) => void
  onSenha: (valor: string) => void
  onEnviar: () => void
  refSenha?: Ref<HTMLInputElement>
}

/** O desenho da tela, sem estado próprio (testado por renderToString). */
export function EntrarVista({ textos, estado, email, senha, onEmail, onSenha, onEnviar, refSenha }: Readonly<EntrarVistaProps>) {
  const t = textos.entrar
  const enviando = estado === 'enviando'

  function enviar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    if (!enviando) onEnviar()
  }

  return (
    <main className="tela-sem-menu">
      <div className="tela-sem-menu__bloco">
        <Bloco>
          <h1 className="tela-sem-menu__titulo">{t.titulo}</h1>
          {/* noValidate: o servidor confere (porta 4); o balão do navegador não segue o DESIGN.md */}
          <form className="entrar__formulario" method="post" noValidate onSubmit={enviar}>
            <CampoTexto
              rotulo={t.email}
              type="email"
              name="email"
              autoComplete="email"
              inputMode="email"
              autoCapitalize="none"
              spellCheck={false}
              value={email}
              readOnly={enviando}
              onChange={(e) => onEmail(e.target.value)}
            />
            <CampoSenha
              ref={refSenha}
              rotulo={t.senha}
              name="senha"
              rotuloMostrar={t.mostrarSenha}
              rotuloEsconder={t.esconderSenha}
              travado={enviando}
              value={senha}
              onChange={(e) => onSenha(e.target.value)}
            />
            <ErroFormulario mensagem={estado === 'erro' ? t.erro : undefined} />
            <Botao
              variante="principal"
              type="submit"
              cheio
              aria-disabled={enviando ? true : undefined}
              aria-busy={enviando ? true : undefined}
            >
              {enviando ? t.entrando : t.entrar}
            </Botao>
            <span role="status" className="ds-so-leitor">
              {enviando ? t.entrando : ''}
            </span>
          </form>
        </Bloco>
      </div>
    </main>
  )
}

/** Resposta da ação sessao.entrar, como a tela a usa (o código do erro não muda a frase: RF-02, CA-14). */
export type RespostaDeEntrar = { readonly ok: true; readonly valor: { readonly destino: 'inicio' | 'escolher_estudio' } } | { readonly ok: false }

export interface EntrarProps {
  textos: Textos
  /** chama a ação do servidor (src/server/sessao/acoes.ts · entrar) */
  entrar: (email: string, senha: string) => Promise<RespostaDeEntrar>
  /** para onde ir depois de entrar (RF-11) */
  aoEntrar: (destino: 'inicio' | 'escolher_estudio') => void
}

/**
 * Entrar com estado: erro → senha limpa, e-mail fica, foco na Senha (ficha E41·3·A).
 * Qualquer falha (senha errada, sem conta, sem estúdio, limite, rede) dá a mesma frase (RF-02, CA-14).
 */
export function Entrar({ textos, entrar, aoEntrar }: Readonly<EntrarProps>) {
  const [estado, setEstado] = useState<EstadoEntrar>('pronto')
  const [email, setEmail] = useState('')
  const [senha, setSenha] = useState('')
  const [erros, setErros] = useState(0)
  const refSenha = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (erros > 0) refSenha.current?.focus()
  }, [erros])

  async function enviar() {
    setEstado('enviando')
    let resposta: RespostaDeEntrar
    try {
      resposta = await entrar(email, senha)
    } catch {
      resposta = { ok: false }
    }
    if (resposta.ok) {
      aoEntrar(resposta.valor.destino)
      return
    }
    setSenha('')
    setEstado('erro')
    setErros((n) => n + 1)
  }

  return (
    <EntrarVista
      textos={textos}
      estado={estado}
      email={email}
      senha={senha}
      onEmail={setEmail}
      onSenha={setSenha}
      onEnviar={() => void enviar()}
      refSenha={refSenha}
    />
  )
}
