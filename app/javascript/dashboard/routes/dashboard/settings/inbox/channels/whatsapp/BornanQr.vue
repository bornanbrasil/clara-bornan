<script setup>
// eslint-disable vue/no-bare-strings-in-template
// eslint-disable @intlify/vue-i18n/no-raw-text
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import ApiClient from 'dashboard/api/ApiClient';
import { useAlert } from 'dashboard/composables';
import { buildBornanInstanceName } from './bornanUtils';

const route = useRoute();
const router = useRouter();
const accountId = route.params.accountId;

const name = ref('');
const loading = ref(false);
const error = ref('');

async function onSubmit() {
  try {
    loading.value = true;
    error.value = '';

    const instanceName = buildBornanInstanceName(name.value, accountId);

    // 1) Provisiona na Evolution
    const provisionApi = new ApiClient('integrations/bornan/provision');
    await provisionApi.create({
      account_id: accountId,
      payload: {
        mode: 'qrcode',
        chatwootNameInbox: name.value,
        instanceName,
      },
    });

    // 2) Mensagem de sucesso + redirect para lista de inboxes
    useAlert(
      '✅ Instância criada com sucesso. O QR Code será enviado automaticamente na conversa do contato do Bot BornanChat para leitura. Você será redirecionado para a lista de caixas de entrada.'
    );
    router.push({ path: `/app/accounts/${accountId}/settings/inboxes/list` });
  } catch (e) {
    error.value = 'Falha ao provisionar conexão. Tente novamente.';
    useAlert(error.value);
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <!-- TODO: migrar textos para i18n futuramente -->
  <div>
    <h3 class="mb-3 text-base font-medium">Bornan – QR Code (Baileys)</h3>
    <p class="mb-6 text-sm text-slate-11">
      Informe o nome da caixa de entrada e clique no botão criar! Em seguida
      você poderá acessar diretamente a conversa do Bot-BornanChat e efetuar a
      leitura do seu QR Code!
    </p>

    <form class="space-y-4 max-w-lg" @submit.prevent="onSubmit">
      <label class="block text-sm">
        Nome da Inbox
        <input v-model="name" class="cw-input mt-1 w-full" required />
      </label>

      <div class="flex items-center gap-3">
        <button class="button button--primary" :disabled="loading">
          {{ loading ? 'Criando…' : 'Criar' }}
        </button>
        <span v-if="error" class="text-danger">{{ error }}</span>
      </div>
    </form>
  </div>
  <!-- eslint-enable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
</template>
