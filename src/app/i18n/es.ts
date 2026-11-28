// Textos en español (ADR 0006 · D1). Mismas claves que pt.ts (el tipo lo comprueba).
import type { Textos } from './pt'

export const es: Textos = {
  comum: {
    tentarDeNovo: 'Intentar de nuevo',
    fechar: 'Cerrar',
    emDesenvolvimento: 'en desarrollo',
    sair: 'Salir',
  },
  erros: {
    sem_login: 'Tu sesión ha terminado. Vuelve a entrar.',
    estudio_trocado: 'El estudio ha cambiado en otro dispositivo. La pantalla se va a recargar.',
    sem_estudio: 'Elige un estudio para continuar.',
    sem_permissao: 'No tienes permiso para hacer esto.',
    entrada_invalida: 'Revisa los datos e inténtalo de nuevo.',
    conflito: 'Esto ya ha cambiado. Recarga e inténtalo de nuevo.',
    limite: 'Demasiados intentos. Espera un poco e inténtalo de nuevo.',
    erro_interno: 'No se ha podido completar. Inténtalo de nuevo.',
  },
  entrar: {
    titulo: 'Entrar',
    email: 'Correo electrónico',
    senha: 'Contraseña',
    entrar: 'Entrar',
    entrando: 'Entrando…',
    mostrarSenha: 'Mostrar contraseña',
    esconderSenha: 'Ocultar contraseña',
    erro: 'No se ha podido entrar. Revisa el correo electrónico y la contraseña e inténtalo de nuevo.',
  },
  escolherEstudio: {
    titulo: 'Elegir estudio',
    quantos: { one: '{n} estudio', other: '{n} estudios' },
    carregando: 'Cargando estudios',
    erroTitulo: 'No se ha podido cargar',
  },
  suaConta: {
    nome: 'Tu cuenta',
    minhaConta: 'Mi cuenta',
    preferencias: 'Preferencias',
    meuFaturamento: 'Mi facturación',
    trocarDeEstudio: 'Cambiar de estudio',
    sair: 'Salir',
  },
}
