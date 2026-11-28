# ADR 0014 · Formulários: cifra por envelope, token do link no fragmento, função do link sem chave de serviço e imutabilidade

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-021500-formularios/spec.md` for aprovada pelo dono. **D6 está bloqueada**: depende da resposta do dono
  sobre o cofre (`plan.md` §0).
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; OWASP ASVS 4.0.3 V3.5, V6.1.2, V6.2.7, V6.3.1, V6.4.1,
  V6.4.2, V8.2.1, V8.3.1, V11.1.4; RGPD art. 5(1)(f), 25 e 32; boas práticas Postgres e Supabase.
- **Conferência (CA-13):** pendente · Auditor de risco; Engenheiro de segurança. D3 e D4 também Engenheiro de dados.
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 regra 3).
- **Detalhe:** `specs/20261128-021500-formularios/plan.md` §0, §3.4 a §3.7 e §4.2 a §4.5.

## Contexto
A spec pede respostas e assinatura cifradas com integridade (RNF-01), chave fora do banco num cofre que cifra e decifra
ele mesmo (RNF-02), link sem login com token de 128 bits ou mais, só o resumo no banco e fora do endereço registrado
(RNF-04), função do banco presa ao resumo e sem chave de serviço (RF-14), e ficha assinada que não muda (RF-09, CA-03).
A E23·3·A permite só o gratuito.

## Decisões
| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | **Cifra por envelope:** cada ficha tem chave própria AES-256-GCM (Web Crypto), IV de 12 bytes aleatório, AAD = `formato|org_id|ficha_id|versao`; a chave da ficha é embrulhada pelo cofre e só o embrulho vai ao banco, com o nome da versão da chave mestra | GCM dá integridade (V6.2.7: dado alterado é recusado); o AAD impede mover a cifra para outra linha; o cofre tem limite de tamanho por operação e as respostas podem passar de centenas de KB, por isso envelope, o modo padrão de KMS. A chave mestra nunca sai do cofre; a chave da ficha vive só na memória durante o pedido. **Leitura da RNF-02 a confirmar pelo Auditor** |
| D2 | **Token no fragmento** (`/f#<token>`), mandado ao servidor no corpo de um POST; não se usa troca por cookie | o fragmento não vai ao servidor nem ao `Referer`, então nenhum registro de endereço o vê (RNF-04 b; V8.3.1). A troca por cookie exigiria que o primeiro pedido levasse o token no endereço, que a borda registra antes da troca. Custo: a página precisa de JavaScript (lacuna L-3) |
| D3 | Token de 32 bytes de `crypto.getRandomValues`, base64url (43 caracteres); no banco só `sha256` (núcleo do Postgres, doc oficial 17 "Binary String Functions"), sem hash lento; 7 dias até a assinatura | 256 bits > 128 (RNF-04 a, V6.3.1); para segredo aleatório de alta entropia o hash rápido basta (não há dicionário a testar). O servidor manda ao banco só o resumo ao criar; ao abrir, a função calcula o resumo do que recebe |
| D4 | Link: esquema próprio `ficha_link` (fora da API) com 2 funções `security definer`, `search_path` vazio; passagem `security invoker` em `public`; `anon` executa só essas 2; nenhuma recebe id de ficha ou de estúdio; chave de serviço nunca | RF-14; ADR 0005 D1 (definer fora do esquema exposto); `app` continua sem nada para `anon` (teste 010). Risco R-4 do plano: a passagem é alcançável com a chave pública; protegida pelo token e pelo limite por estúdio no banco |
| D5 | Limite: por estúdio dentro da função (tabela de contagem por minuto, sem IP) e por endereço no limitador do servidor da E36·A | RNF-04b, V11.1.4; o estúdio só é conhecido depois de achar o resumo; o IP não vai ao banco (minimização) |
| D6 | **Cofre:** porta `CofreDeChaves` no servidor; cofre local falso só para teste; o cofre real **espera o dono** (nenhuma opção gratuita cumpre RNF-02, fontes no `plan.md` §0). Recomendação: Google Cloud KMS, chave SOFTWARE, na UE | E23·3·A; V6.4.1 e V6.4.2. A porta deixa trocar de cofre sem tocar no resto |
| D7 | Imutabilidade por gatilho que recusa `update`/`delete` em versões de modelo e respostas, e em ficha concluída (salvo `substituida_por` uma vez), além de nenhum privilégio de gravação | CA-03 pede recusa "pelo banco, não só pela tela"; o gatilho vale até para a dona da tabela, o privilégio não |
| D8 | Conteúdo do modelo (título, perguntas, termo) em claro; tudo o que a cliente escreve, cifrado | o modelo é do estúdio, sem dado de cliente; cifrá-lo não protege ninguém e impediria `check` e busca por título (RF-13) |

## Consequências
- Ler respostas custa uma ida ao cofre por ficha; listas nunca decifram.
- Trocar a chave mestra não reescreve fichas: cada uma guarda a versão; recifrar as antigas é tarefa futura, opcional.
- Quem tiver a credencial do Worker **e** uma cópia do banco decifra: a credencial fica no cofre da Cloudflare, com
  permissão só de cifrar e decifrar a chave do módulo (R-5).
- "Copiar link" depois de criado vira "gerar link novo" (lacuna L-1 ao Analista), porque o token não fica guardado.
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo. D6 será substituída pelo ADR do cofre (tarefa 24).
