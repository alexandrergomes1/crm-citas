# Multi-idioma (pt-BR, English, Español) — estrutura futura

Status: **plano** (sem implementação). Hoje todo texto está em pt-BR direto nos componentes.
Objetivo: permitir interface e mensagens em **pt-BR (padrão), EN e ES** sem reescrever telas.

## 1. Três camadas de idioma (não confundir)
| Camada | O que é | Quem escolhe | Onde guarda |
|---|---|---|---|
| Interface do app | Menus, botões, avisos | Cada usuária | `profiles.locale` (fallback: `orgs.default_locale`) |
| Conteúdo da clínica | Nome de serviço, descrição, categorias, termos da ficha | Admin da org | tabelas `*_translations` |
| Comunicação com a cliente | WhatsApp, e-mail, reserva online, ficha digital | Cliente (preferência) | `clients.preferred_locale` |

## 2. Interface (catálogo de mensagens)
- Biblioteca: `next-intl` (App Router, Server Components) — validar compatibilidade com Next 16 antes de adotar.
- Arquivos `messages/pt-BR.json`, `en.json`, `es.json`, organizados por módulo (`agenda.*`, `ajustes.*`, `marketing.*`).
- Chaves semânticas (`agenda.slot.block`), nunca a frase como chave. Plurais e variáveis via ICU.
- **Sem prefixo de idioma na URL** no app interno (a usuária já escolhe no perfil); prefixo `/en`, `/es` só na reserva online pública (SEO).
- Fallback: chave ausente cai em pt-BR e registra aviso; teste unitário falha se EN/ES tiverem chaves a menos que pt-BR.
- Migração gradual: extrair módulo a módulo (Ajustes e Marketing primeiro, por serem novos), com lint proibindo string literal em JSX nos módulos já migrados.

## 3. Formatação
- Datas, números e moeda via `Intl` com o locale da usuária; moeda vem da org (EUR hoje), não do idioma.
- Fuso horário continua da org (`Europe/Madrid`), independente do idioma.
- `src/domain/` continua puro: recebe/produz dados e códigos; o texto final é montado na camada de apresentação.
- Rótulos de status, formas de pagamento e permissões hoje vivem em `src/domain/*-catalog.ts`: migrar para chaves (`status.confirmado`) resolvidas no catálogo de mensagens.

## 4. Conteúdo da clínica no banco
- Padrão `<tabela>_translations (org_id, <entidade>_id, locale, name, description)` com RLS por `org_id`.
- Se não há tradução para o idioma pedido, usa o campo base (pt-BR). Painel mostra "traduzir" com sugestão automática revisável.
- Prioridade: serviços, categorias, pacotes, termos da ficha (anamnese tem implicação legal — tradução revisada, versão do texto aceita fica gravada com o idioma).

## 5. Mensagens e comunicação
- Modelos de WhatsApp/e-mail por idioma: `message_templates (key, locale, body)`; WhatsApp exige template aprovado **por idioma** na Meta.
- Escolha do idioma do envio: `clients.preferred_locale` → idioma do primeiro contato → padrão da org.
- Fidelidade, campanhas e lembretes usam os mesmos modelos por idioma.

## 6. Estrutura de pastas prevista
```
messages/{pt-BR,en,es}/<modulo>.json
src/i18n/{config.ts,request.ts,format.ts}
supabase/migrations/*_locales.sql   # profiles.locale, orgs.default_locale, clients.preferred_locale, *_translations
```

## 7. Ordem de entrega sugerida
1. Fundação: `locale` em perfil/org/cliente + provider + seletor em Ajustes › Minha conta.
2. Extrair textos de Ajustes e Marketing; depois Agenda, Clientes, Financeiro.
3. Traduções de conteúdo (serviços/categorias) + reserva online pública com prefixo de idioma.
4. Modelos de mensagem por idioma (depende da integração WhatsApp).
5. EN e ES completos com revisão nativa antes de ativar para clientes.

## 8. Riscos
- Textos jurídicos (ficha, LGPD/GDPR) não podem ser traduzidos automaticamente sem revisão.
- Tamanho de texto: EN/ES costumam ser 15–30% maiores que pt-BR — os guards de layout (390px) devem rodar também nesses idiomas.
