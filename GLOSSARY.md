# Glossário

Termos que aparecem no projeto, em uma linha cada. Termo de tela e de negócio: ver também o registro de design.

## Trabalho e código
| Termo | O que é |
|---|---|
| Repositório | A pasta com todo o código e os documentos, guardada no GitHub |
| Branch | Uma cópia paralela do projeto para trabalhar sem mexer no principal. `previas` é a da prévia; `main`, a da produção |
| Commit | Um envio salvo, com a descrição do que mudou |
| PR (pull request) | O pacote de uma mudança, que pede para entrar na branch principal; é onde se revisa |
| Merge | Juntar o PR à branch, depois que o dono autoriza o pedido no chat. Na `previas`, atualiza a prévia |
| CI | As conferências automáticas do GitHub (testes, tipos, segredos) que rodam em cada PR, sem IA |
| Prévia | O site de teste. Cada branch tem o seu link, onde você confere a tela antes do merge; a `previas` junta tudo antes da produção |
| Produção | O site que as clientes usam. Só muda com "pode publicar" |
| Migration | Arquivo que muda a estrutura do banco de dados |
| RLS | Regra do banco que impede um estúdio de ver os dados de outro |
| Spec | Especificação: o que construir e como saber que ficou certo |
| ADR | Registro de uma decisão, com o porquê |
| Backlog | Lista de pendências em ordem |
| Roadmap | Mapa das grandes fases |
| Changelog | Registro do que mudou em cada publicação |
| Runbook | Manual de operação, passo a passo |
| Postmortem | Relato de um incidente: causa e o que muda |
| E2E (ponta a ponta) | Teste que abre o app como uma pessoa e clica |

## IA
| Termo | O que é |
|---|---|
| Skill | Manual de um assunto que a IA carrega só quando precisa |
| Plugin | Pacote de skills e agentes instalado na sua conta |
| Agente / subagente | Outra IA, com olhos de fora, chamada para revisar ou pesquisar |
| Hook | Script que roda sozinho em certos momentos (início de conversa, antes de um comando) |
| `/clear` | Apaga a conversa da memória da IA e começa a próxima tarefa limpa; o trabalho fica salvo no GitHub |
| Modelo | Qual IA responde (Opus é o mais forte; Sonnet, o do dia a dia). Troca-se só logo depois do `/clear` |
| Ficha de decisão | O quadro com opções desenhadas para você escolher algo de tela |
| Canvas | O quadro de desenho no claude.ai onde ficam as fichas |
