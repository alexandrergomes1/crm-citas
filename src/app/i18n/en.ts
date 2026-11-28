// English texts (ADR 0006 · D1). Same keys as pt.ts (checked by the type).
import type { Textos } from './pt'

export const en: Textos = {
  comum: {
    tentarDeNovo: 'Try again',
    fechar: 'Close',
    emDesenvolvimento: 'in development',
    sair: 'Sign out',
  },
  erros: {
    sem_login: 'Your session has ended. Please sign in again.',
    estudio_trocado: 'The studio changed on another device. The screen will reload.',
    sem_estudio: 'Choose a studio to continue.',
    sem_permissao: "You don't have permission to do this.",
    entrada_invalida: 'Check the details and try again.',
    conflito: 'This has already changed. Reload and try again.',
    limite: 'Too many attempts. Wait a moment and try again.',
    erro_interno: "Couldn't finish. Try again.",
  },
  entrar: {
    titulo: 'Sign in',
    email: 'Email',
    senha: 'Password',
    entrar: 'Sign in',
    entrando: 'Signing in…',
    mostrarSenha: 'Show password',
    esconderSenha: 'Hide password',
    erro: "Couldn't sign in. Check your email and password and try again.",
  },
  escolherEstudio: {
    titulo: 'Choose studio',
    quantos: { one: '{n} studio', other: '{n} studios' },
    carregando: 'Loading studios',
    erroTitulo: "Couldn't load",
  },
  suaConta: {
    nome: 'Your account',
    minhaConta: 'My account',
    preferencias: 'Preferences',
    meuFaturamento: 'My billing',
    trocarDeEstudio: 'Switch studio',
    sair: 'Sign out',
  },
}
