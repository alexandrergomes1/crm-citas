# Spec 27 — Anamnese Legal, Idioma e Auditoria

Status: backlog / planned
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-19

## Objetivo

Registrar decisões e pendências para concluir a Anamnese como módulo clínico/documental, com foco em validade operacional, consentimentos, idioma, termos por país e auditoria.

Este documento não autoriza implementação imediata. Serve para impedir perda de contexto e orientar futuras tarefas técnicas/UX.

## 1. País/jurisdição

A Anamnese deve suportar termos por país/jurisdição.

Fase atual:

- Espanha como país principal.

Fases futuras:

- Portugal;
- Brasil;
- outras jurisdições, se o sistema virar SaaS multi-país.

Regra de produto:

- termos legais/clínicos não devem depender de tradução automática livre em tempo real;
- usar modelos/termos versionados por país e idioma;
- cada organização deve poder configurar seus próprios textos, quando permitido.

## 2. Termos e consentimentos

A ficha deve evoluir para aceitar múltiplos termos/consentimentos.

Exemplos:

- termo geral de anamnese;
- consentimento informado do procedimento;
- consentimento de tratamento de dados;
- consentimento de imagem separado;
- termo de responsabilidade/cuidados pré e pós;
- termos específicos por procedimento.

Regras:

- consentimento de imagem deve ter aceite separado;
- termos sensíveis devem ter aceite individual quando necessário;
- aceite deve registrar data/hora, versão do termo e identificação da ficha;
- texto do termo deve ser auditável posteriormente.

## 3. Exibição do termo na ficha

O texto do termo não deve ficar como bloco aberto gigante quando prejudicar a leitura.

Possíveis padrões UX:

- acordeão/menu expansível;
- botão `Ver termo completo` em modal/sheet;
- bloco resumido com link para detalhes;
- área fixa de aceite com resumo + termo expansível.

Regra:

- o cliente precisa conseguir ler o termo completo antes de aceitar;
- a visualização interna/auditoria precisa mostrar qual termo foi aceito.

## 4. Idioma da anamnese

Decisão recomendada:

- cada modelo de ficha deve existir por idioma/país quando o conteúdo for jurídico/clínico;
- o sistema pode sugerir idioma pelo cliente/organização;
- para envio manual, o profissional pode escolher o modelo/idioma adequado;
- tradução automática pode ajudar na criação futura, mas não deve substituir versão validada.

Opções avaliadas:

### Opção A — Modelo por idioma

Exemplo:

- Remoción Láser — Español;
- Laser Removal — English;
- Remoção a Laser — Português.

Vantagens:

- maior controle jurídico;
- auditoria mais clara;
- conteúdo revisável.

Desvantagens:

- exige manutenção de mais modelos.

### Opção B — Um modelo com seletor de idioma no cliente

Vantagens:

- UX simples para o cliente.

Riscos:

- tradução clínica/legal pode ficar inconsistente;
- difícil auditar versão aceita;
- risco jurídico se houver tradução automática não validada.

Recomendação atual: Opção A como base.

## 5. Assinatura e auditoria

A assinatura do cliente deve ficar visível quando necessário para validação/auditoria.

A ficha assinada deve permitir visualizar:

- nome do cliente;
- data/hora de assinatura;
- versão/modelo da ficha;
- idioma/país;
- respostas;
- termos aceitos;
- assinatura;
- IP/user-agent se já houver coleta ou se for implementado futuramente;
- vínculo com atendimento, quando existir.

## 6. Cabeçalho fixo da ficha

A visualização da ficha deve manter contexto sem prejudicar leitura.

Problema observado:

- cabeçalho fixo/sticky pode deixar conteúdo rolando por trás, gerando leitura ruim.

Direção UX:

- cabeçalho deve ocupar bloco fixo real;
- conteúdo deve começar abaixo do cabeçalho;
- se usar sticky, aplicar background sólido, z-index correto e offset/padding adequado;
- tabs de ficha cliente/profissional não devem esconder conteúdo;
- em modal/sheet, header e footer podem ser fixos, mas o body deve ter área de scroll própria.

## 7. Ficha cliente e ficha profissional

A ficha deve separar claramente:

- respostas do cliente;
- avaliação/notas profissionais;
- sessões do procedimento;
- fotos/anexos futuros;
- status de pendência/assinatura/conclusão.

A parte profissional deve ser discreta quando não for necessária, mas muito clara quando bloquear fechamento da comanda.

## 8. Futuro configurador de termos

Futuro módulo/configuração:

- configurar termo por país;
- configurar termo por procedimento;
- versionar termo;
- ativar/desativar consentimento de imagem;
- definir aceite obrigatório/opcional;
- definir idioma padrão.

## 9. Fora do escopo imediato

- parecer jurídico final;
- tradução automática validada;
- upload/anexo completo;
- motor multi-país completo;
- assinatura digital avançada;
- integrações externas de assinatura.

## 10. Próxima implementação recomendada

Quando o layout da Anamnese estabilizar, a próxima frente técnica deve ser:

`ANAMNESE-LEGAL-01 — Termos versionados por país/idioma e consentimento de imagem separado`

Pré-condição:

- visual da ficha aprovado;
- fluxo atual de gerar link/modelos estabilizado;
- decisão inicial: Espanha como jurisdição principal.