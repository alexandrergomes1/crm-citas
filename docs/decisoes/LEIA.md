# Decisões do dono

Aqui ficam só as respostas do dono **fora de spec**, um arquivo por resposta, no molde `docs/moldes/decisao.md`, gravado no PR da tarefa em curso (nunca em PR à parte, menos a autorização de publicação):
- **ficha curta do módulo** (`AAAA-MM-DD-base-<módulo>.md`): o "sim" ou "não" que fecha o passado de um módulo antes do primeiro trabalho nele. Antes de começar num módulo, a IA procura este arquivo; se existe, não pergunta de novo;
- ordem da fila e regra geral;
- autorização de publicação (`AAAA-MM-DD-publicacao-pr-N.md`, N = nº do PR de publicação, com o SHA autorizado): num PR pequeno próprio à `previas`, só com esse arquivo (`docs/guias/git-e-deploy.md` §Publicação).

Resposta sobre uma tarefa fica na spec dela (`specs/AAAAMMDD-HHMMSS-nome/spec.md`: "Clarifications", "Aprovação do dono" e "Aprovação do merge"). Arquivo juntado não se apaga nem se reescreve: mudança é decisão nova com "Substitui" (a CI confere: `.claude/hooks/TRAVAS.md` §4). As decisões até 27/11/2026 ficam no repositório antigo `crm-agenda` e valem como estão; este repositório começa em `2026-11-27-projeto-novo.md`.
