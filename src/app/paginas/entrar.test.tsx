// Tela Entrar e campo Senha (spec RF-30 a RF-33, CA-18a, CA-20; ficha E41·1·A a E41·4·A). renderToString, sem jsdom.
import { renderToString } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { textosDe } from '@/app/i18n/textos'
import { CampoSenha, ErroFormulario } from '@/app/ui/campos'
import { Entrar, EntrarVista, type EstadoEntrar } from './entrar'

const nada = () => {}
const vista = (estado: EstadoEntrar, email = '', idioma: 'pt' | 'es' | 'en' = 'pt', interativa = true) =>
  renderToString(
    <EntrarVista textos={textosDe(idioma)} estado={estado} interativa={interativa} email={email} senha="" onEmail={nada} onSenha={nada} onEnviar={nada} />,
  )

describe('Entrar · vazio', () => {
  const html = vista('pronto')

  it('título, rótulos e uma só ação preta "Entrar" (DESIGN.md §5, §6)', () => {
    expect(html).toContain('<h1 class="tela-sem-menu__titulo">Entrar</h1>')
    expect(html).toContain('>E-mail<')
    expect(html).toContain('>Senha<')
    expect(html.match(/ds-botao--principal/g)).toHaveLength(1)
    expect(html).toMatch(/type="submit"[^>]*class="ds-botao ds-botao--principal/)
  })

  it('autocomplete de e-mail e senha atual (WCAG 1.3.5)', () => {
    expect(html).toMatch(/<input[^>]*type="email"[^>]*autoComplete="email"|<input[^>]*autoComplete="email"[^>]*type="email"/)
    expect(html).toContain('autoComplete="current-password"')
  })

  it('senha sem maxlength e sem bloqueio de colar (RF-32, WCAG 3.3.8)', () => {
    expect(html).not.toMatch(/maxLength|maxlength/)
    expect(html).not.toMatch(/onPaste|onpaste/)
    expect(html).toContain('type="password"')
  })

  it('envio por POST e sem validação do navegador: nada vai ao endereço (RF-33)', () => {
    expect(html).toMatch(/<form[^>]*noValidate=""/)
    expect(html).toMatch(/<form[^>]*method="post"/)
  })

  it('sem erro e sem estado de envio', () => {
    expect(html).not.toContain('role="alert"')
    expect(html).not.toContain('aria-busy')
    expect(html).not.toContain('readOnly')
  })
})

describe('Entrar · antes da hidratação (revisões R1 e R-B)', () => {
  it('o componente com estado desenha Entrar com disabled (o servidor manda a página assim)', () => {
    const html = renderToString(<Entrar textos={textosDe('pt')} entrar={async () => ({ ok: false })} aoEntrar={nada} />)
    expect(html).toMatch(/<button disabled=""[^>]*type="submit"/)
    // o envio continua por POST (nada no endereço, mesmo se o envio nativo acontecesse; RF-33)
    expect(html).toMatch(/<form[^>]*method="post"/)
  })

  it('a vista não interativa trava o botão; a interativa não', () => {
    expect(vista('pronto', '', 'pt', false)).toMatch(/<button disabled=""[^>]*type="submit"/)
    expect(vista('pronto')).not.toMatch(/\sdisabled=""/)
  })
})

describe('Entrar · erro (E41·3·A)', () => {
  const html = vista('erro', 'pessoa@exemplo.com')

  it('uma linha com ícone e a frase genérica, role="alert", acima de Entrar', () => {
    const t = textosDe('pt').entrar
    expect(html).toContain(`role="alert"`)
    expect(html).toContain(t.erro)
    expect(html.indexOf('role="alert"')).toBeLessThan(html.indexOf('type="submit"'))
  })

  it('sem contorno vermelho nos campos (não diz qual falhou: RF-02)', () => {
    expect(html).not.toContain('aria-invalid')
  })

  it('o e-mail continua escrito', () => {
    expect(html).toContain('value="pessoa@exemplo.com"')
  })
})

describe('Entrar · carregando (E41·3·A)', () => {
  const html = vista('enviando', 'pessoa@exemplo.com')

  it('botão "Entrando…" com aria-disabled e aria-busy, sem disabled', () => {
    expect(html).toMatch(/aria-disabled="true"[^>]*aria-busy="true"[^>]*>.*Entrando…/)
    expect(html).not.toMatch(/\sdisabled=""/)
  })

  it('"Entrando…" também na área de anúncio (role="status")', () => {
    expect(html).toContain('role="status" class="ds-so-leitor">Entrando…<')
  })

  it('campos só leitura e o olho travado', () => {
    expect(html.match(/readOnly=""/g)).toHaveLength(2)
    expect(html).toMatch(/aria-label="Mostrar senha"[^>]*aria-disabled="true"|aria-disabled="true"[^>]*aria-label="Mostrar senha"/)
  })
})

describe('Entrar · idiomas (CA-20)', () => {
  it.each(['es', 'en'] as const)('em %s usa os textos do arquivo do idioma', (idioma) => {
    const t = textosDe(idioma).entrar
    const html = vista('pronto', '', idioma)
    expect(html).toContain(`>${t.titulo}</h1>`)
    expect(html).toContain(`>${t.email}<`)
    expect(html).toContain(`aria-label="${t.mostrarSenha}"`)
  })
})

describe('Campo Senha (E41·2·A)', () => {
  const html = renderToString(<CampoSenha rotulo="Senha" rotuloMostrar="Mostrar senha" rotuloEsconder="Esconder senha" />)

  it('olho dentro do campo, com nome e sem aria-pressed (WCAG 4.1.2)', () => {
    expect(html).toContain('class="ds-campo__olho"')
    expect(html).toContain('aria-label="Mostrar senha"')
    expect(html).not.toContain('aria-pressed')
    expect(html).toContain('lucide-eye')
  })

  it('o rótulo aponta para o campo', () => {
    const id = /<label for="([^"]+)"/.exec(html)?.[1]
    expect(id).toBeTruthy()
    expect(html).toContain(`id="${id}"`)
    expect(html).toContain(`aria-controls="${id}"`)
  })
})

describe('Erro do formulário', () => {
  it('sem mensagem não desenha nada', () => {
    expect(renderToString(<ErroFormulario />)).toBe('')
  })
})
