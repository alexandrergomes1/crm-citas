// Textos em português (ADR 0006 · D1; ADR 0018 · D15; spec RF-34). As chaves deste arquivo são o tipo dos outros dois.
// Nomes das telas desta spec: DESIGN.md §6 e §8b (ficha E41·1·A). Os módulos só acrescentam blocos.
// Marcadores: {nome}. Plural: uma forma por categoria do Intl.PluralRules ("other" obrigatória).

export const pt = {
  comum: {
    tentarDeNovo: 'Tentar de novo',
    fechar: 'Fechar',
    emDesenvolvimento: 'em desenvolvimento',
    sair: 'Sair',
  },
  // Uma frase por código (spec RF-22). Nenhuma tela desta spec mostra estas frases: Entrar usa entrar.erro.
  erros: {
    sem_login: 'Sua sessão terminou. Entre de novo.',
    estudio_trocado: 'A empresa mudou em outro aparelho. A tela vai recarregar.',
    sem_estudio: 'Escolha uma empresa para continuar.',
    sem_permissao: 'Você não tem permissão para fazer isso.',
    entrada_invalida: 'Confira os dados e tente de novo.',
    conflito: 'Isso já mudou. Recarregue e tente de novo.',
    limite: 'Muitas tentativas. Espere um pouco e tente de novo.',
    erro_interno: 'Não foi possível concluir. Tente de novo.',
  },
  entrar: {
    titulo: 'Entrar',
    email: 'E-mail',
    senha: 'Senha',
    entrar: 'Entrar',
    entrando: 'Entrando…',
    mostrarSenha: 'Mostrar senha',
    esconderSenha: 'Esconder senha',
    erro: 'Não foi possível entrar. Confira o e-mail e a senha e tente de novo.',
  },
  escolherEstudio: {
    titulo: 'Escolher empresa',
    quantos: { one: '{n} empresa', other: '{n} empresas' },
    carregando: 'Carregando empresas',
    erroTitulo: 'Não foi possível carregar',
  },
  suaConta: {
    nome: 'Sua conta',
    minhaConta: 'Minha conta',
    preferencias: 'Preferências',
    meuFaturamento: 'Meu faturamento',
    trocarDeEstudio: 'Trocar de empresa',
    sair: 'Sair',
  },
}

/** Formato de todos os idiomas: as chaves do pt. */
export type Textos = typeof pt
