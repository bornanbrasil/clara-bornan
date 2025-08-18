// Funções utilitárias isoladas da Bornan, para não conflitar com utils.js (Facebook)
export const buildBornanInstanceName = (inboxName, accountId) =>
  `${String(inboxName || '')
    .trim()
    .replace(/\s+/g, '')}-cwId-${accountId}`;
