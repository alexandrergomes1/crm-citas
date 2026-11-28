// Vitrine do design system (spec RV-1 a RV-3; plan.md §6.3). Página interna, dados fictícios (vitrine-dados.ts).
// Cada quadro é uma região com título, sobre superfície branca, com no máximo uma ação preta.
import { useEffect, useId, useState, type ReactNode } from 'react'
import { Botao, BotaoIcone } from '@/app/ui/botao'
import { Contador } from '@/app/ui/contador'
import { Seletor } from '@/app/ui/seletor'
import {
  BuscaGeral,
  BuscaTela,
  CampoData,
  CampoMultilinha,
  CampoSelecao,
  CampoTexto,
  Caixinha,
  Interruptor,
} from '@/app/ui/campos'
import { BotaoStatus, Etiqueta, Status, StatusIcone } from '@/app/ui/etiqueta-status'
import { Bloco, CabecalhoGrupo, LinhaLista, Lista, ResumoValores, Tabela, categoriaDaOrdem } from '@/app/ui/bloco-lista'
import { Aviso, Folha, Janelinha, LinhaQueAbre, MenuAcoes, MenuAcoesLinha, Painel } from '@/app/ui/camadas'
import { Carregando, EstadoVazio, Erro, SemResultado } from '@/app/ui/estados'
import {
  Agendar,
  BarraBaixo,
  BarraTopo,
  CabecalhoCelular,
  ListaSecoes,
  MenuPrincipal,
  Submenu,
} from '@/app/ui/estrutura'
import { Bolinha, InicialEstudio, LinhaDoTempo, SuaConta } from '@/app/ui/conteudo'
import {
  acoesLinha,
  barraBaixo,
  clientes,
  linhaDoTempo,
  menuPrincipal,
  secoesCatalogo,
  secoesFormularios,
  servicos,
  tokensCor,
  tokensEspaco,
  tokensRaio,
  tokensSombra,
  tokensTexto,
} from './vitrine-dados'

function Quadro({ titulo, largo = false, children }: Readonly<{ titulo: string; largo?: boolean; children: ReactNode }>) {
  const id = useId()
  return (
    <section aria-labelledby={id} className={largo ? 'vt-quadro vt-quadro--largo' : 'vt-quadro'}>
      <h2 id={id} className="vt-quadro__titulo">
        {titulo}
      </h2>
      {children}
    </section>
  )
}

function Legenda({ children }: Readonly<{ children: ReactNode }>) {
  return <p className="vt-legenda">{children}</p>
}

function Fila({ children }: Readonly<{ children: ReactNode }>) {
  return <div className="vt-fila">{children}</div>
}

/** Valor do token lido do tokens.css (fonte única), sem cópia na vitrine */
function ValorToken({ nome }: Readonly<{ nome: string }>) {
  const [valor, setValor] = useState('')
  useEffect(() => {
    setValor(getComputedStyle(document.documentElement).getPropertyValue(`--${nome}`).trim())
  }, [nome])
  return <code className="vt-valor">{valor}</code>
}

function QuadroTokens() {
  return (
    <Quadro titulo="Tokens" largo>
      <h3 className="vt-subtitulo">Cores</h3>
      <ul className="vt-grade-cores">
        {tokensCor.map((nome) => (
          <li key={nome} className="vt-cor">
            <span className={`vt-cor__amostra vt-cor--${nome}`} aria-hidden="true" />
            <code className="vt-cor__nome">--{nome}</code>
            <ValorToken nome={nome} />
          </li>
        ))}
      </ul>
      <h3 className="vt-subtitulo">Texto</h3>
      <ul className="vt-lista-tokens">
        {tokensTexto.map((t) => (
          <li key={t.token} className={`vt-texto vt-texto--${t.token}${t.forte ? ' vt-texto--forte' : ''}`}>
            <span>Geist {t.token.replace('fs-', '')}</span>
            <span className="vt-legenda">{t.uso}</span>
          </li>
        ))}
      </ul>
      <h3 className="vt-subtitulo">Espaços</h3>
      <ul className="vt-lista-tokens">
        {tokensEspaco.map((t) => (
          <li key={t} className="vt-espaco">
            <span className={`vt-espaco__barra vt-espaco--${t}`} aria-hidden="true" />
            <code>--{t}</code>
          </li>
        ))}
      </ul>
      <h3 className="vt-subtitulo">Raios</h3>
      <ul className="vt-grade-formas">
        {tokensRaio.map((t) => (
          <li key={t} className="vt-forma">
            <span className={`vt-forma__amostra vt-raio--${t}`} aria-hidden="true" />
            <code>--{t}</code>
          </li>
        ))}
      </ul>
      <h3 className="vt-subtitulo">Sombras</h3>
      <ul className="vt-grade-formas">
        {tokensSombra.map((t) => (
          <li key={t} className="vt-forma">
            <span className={`vt-forma__amostra vt-sombra--${t}`} aria-hidden="true" />
            <code>--{t}</code>
          </li>
        ))}
      </ul>
    </Quadro>
  )
}

export function Vitrine() {
  const [janelinha, setJanelinha] = useState(false)
  const [folha, setFolha] = useState(false)
  const [painel, setPainel] = useState(false)

  const conteudoFiltros = (
    <>
      <LinhaQueAbre rotulo="Ordenar" valor="Última visita">
        <Caixinha rotulo="Última visita" defaultChecked />
        <Caixinha rotulo="Nome" />
      </LinhaQueAbre>
      <LinhaQueAbre rotulo="Etiquetas" valor={<Contador total={2} />} inicialAberta>
        <Caixinha rotulo="VIP" defaultChecked />
        <Caixinha rotulo="1ª visita" />
      </LinhaQueAbre>
      <LinhaQueAbre rotulo="Cadastro" valor="Ativos">
        <Interruptor rotulo="Só ativos" defaultChecked />
      </LinhaQueAbre>
    </>
  )
  const rodapeFiltros = (fechar: () => void) => (
    <>
      <Botao variante="claro" cheio onClick={fechar}>
        Limpar filtros
      </Botao>
      <Botao variante="principal" cheio onClick={fechar}>
        Mostrar 8 clientes
      </Botao>
    </>
  )

  const topo = (
    <>
      <BotaoIcone nome="Ajuda" icone="circle-question-mark" />
      <BotaoIcone nome="Notificações, 3 não lidas" icone="bell" contador={{ total: 3, pendente: 3 }} />
      <SuaConta nome="Sua conta" inicial="M" />
    </>
  )

  return (
    <main className="vt">
      <header className="vt-cabecalho">
        <h1 className="vt-cabecalho__titulo">Vitrine do design system</h1>
        <p className="vt-legenda">Página interna. Dados fictícios. Fonte: DESIGN.md.</p>
      </header>

      <div className="vt-grade">
        <QuadroTokens />

        <Quadro titulo="RC-1 · Botão">
          <Fila>
            <Botao variante="principal" icone="plus">
              Adicionar
            </Botao>
            <Botao variante="claro">Cancelar</Botao>
            <Botao variante="contorno" icone="plus">
              Adicionar
            </Botao>
            <Botao variante="excluir">Excluir</Botao>
          </Fila>
          <Legenda>Estados</Legenda>
          <Fila>
            <span className="vt-foco-demo">
              <Botao variante="claro">Salvar</Botao>
            </span>
            <Botao variante="claro" disabled>
              Salvar
            </Botao>
            <Botao variante="claro" disabled nota="em desenvolvimento">
              Exportar
            </Botao>
          </Fila>
          <Legenda>Foco (anel de 2 px) · desativado (60 %) · função que ainda não existe</Legenda>
        </Quadro>

        <Quadro titulo="RC-2 · Botão de ícone">
          <Fila>
            <BotaoIcone nome="Fechar" icone="x" />
            <BotaoIcone nome="Voltar" icone="chevron-left" />
            <BotaoIcone nome="Opções" icone="ellipsis-vertical" />
            <BotaoIcone nome="Ajuda" icone="circle-question-mark" />
            <BotaoIcone nome="Notificações" icone="bell" />
            <BotaoIcone nome="Filtros" icone="funnel" />
            <BotaoIcone nome="Recolher menu" icone="panel-left" />
          </Fila>
          <Legenda>Sem fundo</Legenda>
        </Quadro>

        <Quadro titulo="RC-3 · Botão com ícone e nome">
          <Fila>
            <Botao icone="funnel" seta>
              Filtros
            </Botao>
            <Botao icone="arrow-up-down" seta>
              Ordenar: Nome
            </Botao>
            <Botao seta>Categoria: Todas</Botao>
            <Botao seta>Modelo: Todos</Botao>
            <Botao icone="calendar-days" seta>
              Dia
            </Botao>
            <Botao>Equipe 2 de 3</Botao>
            <Botao>Lista de espera</Botao>
          </Fila>
          <Legenda>Só nome</Legenda>
          <Fila>
            <Botao seta>Opções</Botao>
            <Botao>Hoje</Botao>
          </Fila>
        </Quadro>

        <Quadro titulo="RC-4 · Contador">
          <Fila>
            <Contador total={11} />
            <Contador total={21} pendente={4} rotulo="21, 4 pendentes" />
            <span className="vt-legenda">
              Zero não aparece: [<Contador total={0} />]
            </span>
          </Fila>
          <p className="vt-subtexto">
            21 fichas · <span className="vt-pendentes">4 pendentes</span>
          </p>
          <Legenda>Em botão de ícone</Legenda>
          <Fila>
            <BotaoIcone nome="Filtros, 2 aplicados" icone="funnel" claro contador={{ total: 2 }} />
            <BotaoIcone nome="Notificações, 3 não lidas" icone="bell" contador={{ total: 3, pendente: 3 }} />
            <Botao icone="funnel" seta contador={{ total: 2, rotulo: '2 aplicados' }}>
              Filtros
            </Botao>
          </Fila>
        </Quadro>

        <Quadro titulo="RC-5 · Agendar">
          <Fila>
            <Agendar rotulo="Agendar" />
          </Fila>
          <Legenda>Círculo 52 preto, no meio da barra de baixo</Legenda>
        </Quadro>

        <Quadro titulo="RC-6 · Seletor">
          <Seletor
            nome="Abas do agendamento"
            abas={[
              { id: 'resumo', rotulo: 'Resumo', conteudo: <p className="vt-subtexto">Resumo do agendamento de exemplo.</p> },
              {
                id: 'notas',
                rotulo: 'Notas',
                conteudo: (
                  <EstadoVazio
                    icone="clipboard-list"
                    titulo="Ainda não há notas"
                    frase="Escreva o que for útil para o próximo atendimento."
                    rotuloAdicionar="Adicionar nota"
                  />
                ),
              },
              {
                id: 'formularios',
                rotulo: 'Formulários',
                total: 1,
                pendente: 1,
                rotuloContador: '1, com pendência',
                conteudo: <p className="vt-subtexto">Um formulário aguardando a cliente.</p>,
              },
              { id: 'atividade', rotulo: 'Atividade', conteudo: <p className="vt-subtexto">Sem atividade nova.</p> },
            ]}
          />
          <Legenda>Rola com esmaecido na ponta quando não cabe</Legenda>
          <Seletor
            nome="Categorias"
            rolavel
            abas={[
              { id: 'todas', rotulo: 'Todas', total: 11, conteudo: null },
              { id: 'sobrancelhas', rotulo: 'Sobrancelhas', total: 4, conteudo: null },
              { id: 'labios', rotulo: 'Lábios', total: 3, conteudo: null },
              { id: 'cilios', rotulo: 'Cílios', total: 2, conteudo: null },
              { id: 'pele', rotulo: 'Pele', total: 2, conteudo: null },
            ]}
          />
        </Quadro>

        <Quadro titulo="RC-7 · Campos">
          <div className="vt-pilha">
            <CampoTexto rotulo="Nome" obrigatorio defaultValue="Lia Moura" autoComplete="off" />
            <CampoTexto
              rotulo="Telefone"
              obrigatorio
              type="tel"
              defaultValue="+34"
              erro="Informe o telefone para enviar lembretes."
              autoComplete="off"
            />
            <CampoSelecao
              rotulo="Categoria"
              defaultValue="labios"
              opcoes={[
                { valor: 'labios', rotulo: 'Lábios' },
                { valor: 'cilios', rotulo: 'Cílios' },
              ]}
            />
            <CampoMultilinha rotulo="Nota" placeholder="Escreva a nota…" />
            <CampoData rotulo="Data" defaultValue="2026-12-04" />
            <CampoTexto rotulo="Código" disabled defaultValue="Gerado ao salvar" />
          </div>
        </Quadro>

        <Quadro titulo="RC-8 · Busca">
          <div className="ds-so-celular vt-coluna">
            <BuscaTela rotulo="Buscar serviço" filtro={{ nome: 'Filtros', icone: 'funnel' }} />
          </div>
          <div className="ds-so-computador vt-coluna">
            <BuscaTela rotulo="Buscar serviço" />
            <Legenda>Busca geral, no topo</Legenda>
            <BuscaGeral rotulo="Buscar no sistema" atalho="⌘K" />
          </div>
        </Quadro>

        <Quadro titulo="RC-9 · Caixinha e interruptor">
          <Fila>
            <Caixinha rotulo="Marcado" defaultChecked />
            <Caixinha rotulo="Desmarcado" />
            <Caixinha rotulo="Desativado" disabled />
          </Fila>
          <Fila>
            <Interruptor rotulo="Ligado" defaultChecked />
            <Interruptor rotulo="Desligado" />
          </Fila>
        </Quadro>

        <Quadro titulo="RC-10 · Etiqueta e status">
          <Legenda>Etiquetas</Legenda>
          <Fila>
            <Etiqueta tipo="primeira-visita" rotulo="1ª visita" />
            <Etiqueta tipo="vip" rotulo="VIP" />
            <Etiqueta tipo="recorrente" rotulo="Recorrente" />
            <Etiqueta tipo="retoque-pendente" rotulo="Retoque pendente" />
            <Etiqueta tipo="alergia" rotulo="Alergia" />
          </Fila>
          <Legenda>Status nas listas</Legenda>
          <Fila>
            <Status tipo="reservado" rotulo="Reservado" />
            <Status tipo="confirmado" rotulo="Confirmado" />
            <Status tipo="chegou" rotulo="Chegou" />
            <Status tipo="iniciado" rotulo="Iniciado" />
            <Status tipo="concluido" rotulo="Concluído" />
            <Status tipo="ausencia" rotulo="Ausência" />
            <Status tipo="cancelado" rotulo="Cancelado" />
            <Status tipo="bloqueio" rotulo="Bloqueio de horário" />
          </Fila>
          <Legenda>Situação de formulário</Legenda>
          <Fila>
            <Status tipo="aguardando-cliente" rotulo="Aguardando a cliente" />
            <Status tipo="bloqueia-checkout" rotulo="Bloqueia o checkout" />
            <Status tipo="formulario-concluido" rotulo="Concluída" />
          </Fila>
          <Legenda>No agendamento · só o ícone (nome no leitor)</Legenda>
          <Fila>
            <BotaoStatus tipo="confirmado" rotulo="Confirmado" nome="Confirmado. Trocar status" />
            <StatusIcone tipo="reservado" rotulo="Reservado" />
            <StatusIcone tipo="concluido" rotulo="Concluído" />
          </Fila>
        </Quadro>

        <Quadro titulo="RC-11 · Bloco">
          <div className="vt-fundo">
            <Bloco titulo="Bloco de conteúdo" acao={<Botao variante="claro">Ver serviço</Botao>}>
              <p className="vt-subtexto">Superfície branca, canto 20, sobre o fundo. Controle nunca direto sobre o fundo.</p>
            </Bloco>
          </div>
        </Quadro>

        <Quadro titulo="RC-12 · Lista e tabela">
          <CabecalhoGrupo titulo="Sobrancelhas" categoria={1} contador={{ total: 4 }} />
          <Lista nome="Serviços">
            {servicos.map((s) => (
              <LinhaLista
                key={s.id}
                titulo={s.nome}
                detalhe={s.detalhe}
                categoria={categoriaDaOrdem(s.categoria)}
                fim={s.valor}
                acoes={<MenuAcoesLinha nome={`Opções de ${s.nome}`} rotulos={acoesLinha} />}
              />
            ))}
          </Lista>
          <Legenda>Clientes</Legenda>
          <Lista nome="Clientes">
            {clientes.map((c) => (
              <LinhaLista key={c.id} titulo={c.nome} detalhe={c.detalhe} inicio={<Bolinha iniciais={c.iniciais} />} fim={c.valor} />
            ))}
          </Lista>
          <div className="ds-so-computador vt-coluna">
            <Legenda>Tabela do computador</Legenda>
            <Tabela
              nome="Clientes"
              colunas={[
                { id: 'nome', titulo: 'Nome' },
                { id: 'visita', titulo: 'Última visita' },
                { id: 'saldo', titulo: 'Saldo', numero: true },
              ]}
              linhas={clientes.map((c) => ({
                id: c.id,
                celulas: {
                  nome: (
                    <span className="vt-celula">
                      <Bolinha iniciais={c.iniciais} tamanho="tabela" />
                      {c.nome}
                    </span>
                  ),
                  visita: c.detalhe,
                  saldo: c.valor,
                },
              }))}
            />
          </div>
        </Quadro>

        <Quadro titulo="RC-13 · Menu aberto">
          <Fila>
            <MenuAcoes
              nome="Opções"
              gatilho="botao"
              itens={[
                { id: 'importar', rotulo: 'Importar' },
                { id: 'exportar', rotulo: 'Exportar' },
                { id: 'imprimir', rotulo: 'Imprimir' },
                { id: 'ordem', rotulo: 'Ajustar ordem' },
              ]}
            />
            <MenuAcoesLinha nome="Opções da linha" rotulos={acoesLinha} />
          </Fila>
          <Legenda>Opções e ⋮: branco com sombra; Editar · Duplicar · Arquivar · Excluir</Legenda>
        </Quadro>

        <Quadro titulo="RC-14 · Janelinha de confirmação">
          <Fila>
            <Botao variante="claro" onClick={() => setJanelinha(true)}>
              Abrir janelinha
            </Botao>
          </Fila>
          <Janelinha
            aberta={janelinha}
            onFechar={() => setJanelinha(false)}
            titulo={'Excluir "Limpeza simples"?'}
            texto="O serviço sai do catálogo. Agendamentos já feitos continuam."
            rotuloCancelar="Cancelar"
            rotuloConfirmar="Excluir"
            onConfirmar={() => undefined}
          />
        </Quadro>

        <Quadro titulo="RC-15 · Aviso">
          <Aviso mensagem="Serviço salvo" rotuloDesfazer="Desfazer" />
        </Quadro>

        <Quadro titulo="RC-16 · Folha e painel">
          <div className="ds-so-celular vt-coluna vt-coluna--inicio">
            <Botao variante="claro" icone="funnel" onClick={() => setFolha(true)}>
              Abrir folha
            </Botao>
            <Legenda>Folha de baixo (celular)</Legenda>
          </div>
          <div className="ds-so-computador vt-coluna vt-coluna--inicio">
            <Botao variante="claro" icone="funnel" onClick={() => setPainel(true)}>
              Abrir painel
            </Botao>
            <Legenda>Painel à direita (computador), 480</Legenda>
          </div>
          <Folha aberta={folha} onFechar={() => setFolha(false)} titulo="Filtros" nomeFechar="Fechar" rodape={rodapeFiltros(() => setFolha(false))}>
            {conteudoFiltros}
          </Folha>
          <Painel aberta={painel} onFechar={() => setPainel(false)} titulo="Filtros" nomeFechar="Fechar" rodape={rodapeFiltros(() => setPainel(false))}>
            {conteudoFiltros}
          </Painel>
        </Quadro>

        <Quadro titulo="RC-17 · Estados de tela">
          <EstadoVazio
            icone="tag"
            titulo="Ainda não há serviços"
            frase="Adicione o primeiro para poder agendar."
            rotuloAdicionar="Adicionar serviço"
          />
          <SemResultado
            titulo={'Nada encontrado para "lifting"'}
            frase="Confira o nome ou limpe os filtros."
            rotuloLimpar="Limpar filtros"
          />
          <Carregando rotulo="Carregando serviços" />
          <Erro titulo="Não foi possível carregar" frase="Verifique a conexão e tente de novo." rotuloTentar="Tentar de novo" />
          <Legenda>Sucesso: o aviso (RC-15)</Legenda>
        </Quadro>

        <Quadro titulo="RC-18 · Estrutura do computador" largo>
          <p className="ds-so-celular vt-legenda">Desenho só do computador.</p>
          <div className="ds-so-computador vt-coluna">
            <BarraTopo
              titulo="Catálogo"
              subtitulo="Serviços · 11"
              busca={{ rotulo: 'Buscar no sistema', atalho: '⌘K' }}
              opcoes={
                <MenuAcoes
                  nome="Opções"
                  gatilho="botao"
                  itens={[
                    { id: 'importar', rotulo: 'Importar' },
                    { id: 'exportar', rotulo: 'Exportar' },
                  ]}
                />
              }
              acao={
                <Botao variante="principal" icone="plus">
                  Adicionar
                </Botao>
              }
              topo={topo}
            />
            <div className="vt-estrutura">
              <MenuPrincipal nome="Menu principal aberto" itens={menuPrincipal} atual="clientes" rotuloAbrir="Abrir o menu" rotuloRecolher="Recolher menu" />
              <MenuPrincipal
                nome="Menu principal recolhido"
                itens={menuPrincipal}
                atual="catalogo"
                rotuloAbrir="Abrir o menu"
                rotuloRecolher="Recolher menu"
                inicialRecolhido
              />
              <Submenu nome="Seções do Catálogo" itens={secoesCatalogo} atual="servicos" />
            </div>
          </div>
        </Quadro>

        <Quadro titulo="RC-19 · Estrutura do celular">
          <p className="ds-so-computador vt-legenda">Desenho só do celular.</p>
          <div className="ds-so-celular vt-coluna vt-celular">
            <CabecalhoCelular
              titulo="Formulários"
              subtitulo="21 fichas · 4 pendentes"
              fim={
                <>
                  <BotaoIcone nome="Notificações, 3 não lidas" icone="bell" contador={{ total: 3, pendente: 3 }} />
                  <SuaConta nome="Sua conta" inicial="M" />
                </>
              }
            />
            <div className="vt-fundo">
              <Bloco semFolga>
                <ListaSecoes nome="Seções de Formulários" itens={secoesFormularios} />
              </Bloco>
            </div>
            <CabecalhoCelular
              titulo="Fichas"
              nomeVoltar="Voltar"
              fim={
                <>
                  <Botao variante="contorno" icone="plus">
                    Adicionar
                  </Botao>
                  <MenuAcoes nome="Opções" gatilho="icone" itens={[{ id: 'exportar', rotulo: 'Exportar' }]} />
                </>
              }
            />
            <BarraBaixo
              nome="Navegação principal"
              itens={barraBaixo}
              atual="clientes"
              agendar={{ rotulo: 'Agendar' }}
            />
          </div>
        </Quadro>

        <Quadro titulo="RC-20 · Bolinha e Sua conta">
          <Fila>
            <Bolinha iniciais="LM" />
            <Bolinha iniciais="TF" tamanho="tabela" />
            <SuaConta nome="Sua conta" inicial="M" />
            <InicialEstudio inicial="E" nome="Estúdio Exemplo" />
          </Fila>
          <Legenda>Bolinha 40 e 24, nunca colorida · Sua conta · inicial do estúdio</Legenda>
        </Quadro>

        <Quadro titulo="RC-21 · Linha do tempo">
          <LinhaDoTempo grupos={linhaDoTempo} rotuloNaoLido="Não lido" />
        </Quadro>

        <Quadro titulo="RC-22 · Resumo de valores">
          <ResumoValores
            rotulo="Total"
            valor="250,00 €"
            detalhe={
              <>
                <span>Serviços 210,00 €</span>
                <span>Produtos 40,00 €</span>
              </>
            }
          />
        </Quadro>
      </div>
    </main>
  )
}
