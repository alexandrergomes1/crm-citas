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
    estudio_trocado: 'La empresa ha cambiado en otro dispositivo. La pantalla se va a recargar.',
    sem_estudio: 'Elige una empresa para continuar.',
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
    titulo: 'Elegir empresa',
    quantos: { one: '{n} empresa', other: '{n} empresas' },
    carregando: 'Cargando empresas',
    erroTitulo: 'No se ha podido cargar',
  },
  suaConta: {
    nome: 'Tu cuenta',
    minhaConta: 'Mi cuenta',
    preferencias: 'Preferencias',
    meuFaturamento: 'Mi facturación',
    trocarDeEstudio: 'Cambiar de empresa',
    sair: 'Salir',
  },
}
