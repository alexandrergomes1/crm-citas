// Regras de envio (git push) que valem igual para a trava do Claude Code (guarda.mjs) e para o
// gancho de git das outras IAs (.githooks/pre-push.mjs). Spec: .claude/hooks/TRAVAS.md §2 e §7.
// Sem dependência: só funções puras, para os dois lados testarem o mesmo texto.

// Branches em que nada entra por envio direto: só por PR (integração e produção).
export const PROTEGIDAS = ['main', 'master', 'previas'];
export const ehProtegida = (b) => PROTEGIDAS.includes(String(b).replace(/^refs\/heads\//, ''));

// Padrão de nome (AGENTS.md §6): `tipo/area-assunto` (letras minúsculas, números e hífen; ao menos
// uma parte depois do hífen). `decisao/...` não é tipo de tarefa.
const TAREFA = /^[a-z]+\/[a-z0-9]+(-[a-z0-9]+)+$/;
export const nomeValido = (b) => !String(b).startsWith('decisao/') && TAREFA.test(b);
export const PADRAO_TEXTO = '`tipo/area-assunto` (ex.: `feat/agenda-filtro`)';
