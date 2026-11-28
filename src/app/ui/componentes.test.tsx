// Componentes base por renderToString (plan.md §7; ambiente node, sem jsdom).
import { describe, expect, it } from 'vitest'
import { renderToString } from 'react-dom/server'
import { Contador } from './contador'
import { Botao, BotaoIcone } from './botao'
import { MenuAcoesLinha } from './camadas'
import { StatusIcone, Status, status } from './etiqueta-status'
import { Seletor } from './seletor'
import { EstadoVazio } from './estados'
import { categoriaDaOrdem } from './bloco-lista'
import { nomesIcones } from './icone'
import { dataPorExtenso } from './campos'

describe('Contador (RC-4)', () => {
  it('zero não desenha nada', () => {
    expect(renderToString(<Contador total={0} />)).toBe('')
  })

  it('total sem pendência é a pílula cinza', () => {
    const html = renderToString(<Contador total={11} />)
    expect(html).toContain('class="ds-contador"')
    expect(html).toContain('11')
  })

  it('pendência usa a classe âmbar e o nome acessível recebido', () => {
    const html = renderToString(<Contador total={21} pendente={4} rotulo="21, 4 pendentes" />)
    expect(html).toContain('ds-contador--pendente')
    expect(html).toContain('ds-so-leitor">21, 4 pendentes<')
  })
})

describe('Menu da linha (RC-13)', () => {
  it('fica na ordem Editar · Duplicar · Arquivar · Excluir, com Excluir em vermelho', () => {
    // a ordem vem do componente, não de quem chama: os rótulos chegam fora de ordem
    const html = renderToString(
      <MenuAcoesLinha nome="Opções" rotulos={{ excluir: 'E4', arquivar: 'E3', duplicar: 'E2', editar: 'E1' }} />,
    )
    const ordem = [...html.matchAll(/role="menuitem"[^>]*>(E\d)</g)].map((m) => m[1])
    expect(ordem).toEqual(['E1', 'E2', 'E3', 'E4'])
    expect(html).toMatch(/ds-menu__item--perigo"[^>]*>E4</)
  })

  it('o botão ⋮ segue o padrão Menu Button', () => {
    const html = renderToString(<MenuAcoesLinha nome="Opções" rotulos={{ editar: 'a', duplicar: 'b', arquivar: 'c', excluir: 'd' }} />)
    expect(html).toContain('aria-haspopup="menu"')
    expect(html).toContain('aria-expanded="false"')
    expect(html).toContain('aria-label="Opções"')
  })
})

describe('Status (RC-10)', () => {
  it('só ícone tem nome para o leitor', () => {
    const html = renderToString(<StatusIcone tipo="reservado" rotulo="Reservado" />)
    expect(html).toContain('role="img"')
    expect(html).toContain('aria-label="Reservado"')
  })

  it('nas listas é ícone + palavra', () => {
    expect(renderToString(<Status tipo="concluido" rotulo="Concluído" />)).toContain('Concluído')
  })

  it('cada status usa um ícone que existe no icone.tsx', () => {
    for (const s of Object.values(status)) expect(nomesIcones).toContain(s.icone)
  })
})

describe('Seletor (RC-6)', () => {
  it('tem tablist, tab e aria-selected; a aba vazia fica no lugar', () => {
    const html = renderToString(
      <Seletor
        nome="Abas"
        abas={[
          { id: 'a', rotulo: 'Resumo', conteudo: 'x' },
          { id: 'b', rotulo: 'Notas', total: 0, conteudo: 'y' },
        ]}
      />,
    )
    expect(html).toContain('role="tablist"')
    expect(html.match(/role="tab"/g)).toHaveLength(2)
    expect(html).toContain('aria-selected="true"')
    expect(html).toContain('aria-selected="false"')
    expect(html).toContain('Notas')
  })
})

describe('Botões (RC-1, RC-2)', () => {
  it('botão de ícone sem nome não compila (nome obrigatório)', () => {
    // @ts-expect-error: falta "nome" (nome acessível obrigatório, RA-5)
    const html = renderToString(<BotaoIcone icone="x" />)
    expect(html).toContain('<button')
  })

  it('botão de ícone leva o nome em aria-label e o ícone fica escondido do leitor', () => {
    const html = renderToString(<BotaoIcone nome="Fechar" icone="x" />)
    expect(html).toContain('aria-label="Fechar"')
    expect(html).toContain('aria-hidden="true"')
  })

  it('desativado com nota liga a nota ao botão', () => {
    const html = renderToString(
      <Botao disabled nota="em desenvolvimento">
        Exportar
      </Botao>,
    )
    const id = /aria-describedby="([^"]+)"/.exec(html)?.[1]
    expect(id).toBeTruthy()
    expect(html).toContain(`id="${id}"`)
    expect(html).toContain('disabled')
  })
})

describe('Sem texto fixo de módulo (RC-23)', () => {
  it('o estado vazio mostra só os textos recebidos', () => {
    const html = renderToString(<EstadoVazio icone="tag" titulo="T1" frase="F1" rotuloAdicionar="A1" />)
    const textos = [...html.matchAll(/>([^<>]+)</g)].map((m) => m[1]?.trim()).filter(Boolean)
    expect(textos).toEqual(['T1', 'F1', 'A1'])
  })

  it('a quinta categoria volta à primeira (DESIGN.md §3)', () => {
    expect([1, 2, 3, 4, 5, 6].map(categoriaDaOrdem)).toEqual([1, 2, 3, 4, 1, 2])
  })
})

describe('Campo de data (RC-7)', () => {
  it('mostra a data por extenso no idioma do estúdio, como na imagem 06', () => {
    expect(dataPorExtenso('2026-12-04', 'pt')).toBe('sex, 4 dez 2026')
    expect(dataPorExtenso('2026-12-04', 'es-ES')).toBe('vie, 4 dic 2026')
  })

  it('data inválida ou vazia não mostra nada', () => {
    expect(dataPorExtenso('', 'pt-PT')).toBe('')
    expect(dataPorExtenso('04/12/2026', 'pt-PT')).toBe('')
  })
})
