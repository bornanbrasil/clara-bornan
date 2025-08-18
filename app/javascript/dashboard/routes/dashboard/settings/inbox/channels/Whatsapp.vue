<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
// Importações Bornan
import BornanQr from './whatsapp/BornanQr.vue';
import BornanBusiness from './whatsapp/BornanBusiness.vue';

const route = useRoute();
const router = useRouter();

const PROVIDER_TYPES = {
  BORNAN_QR: 'bornan_qr', // Bornan
  BORNAN_BUSINESS: 'bornan_business', // Bornan
};

const selectedProvider = computed(() => route.query.provider);

const showProviderSelection = computed(() => !selectedProvider.value);

const showConfiguration = computed(() => Boolean(selectedProvider.value));

const availableProviders = computed(() => [
  // Bornan - exibidos como WhatsApp para manter a experiência nativa
  {
    value: PROVIDER_TYPES.BORNAN_QR,
    label: 'WhatsApp – QR Code',
    description: 'Conexão via QR Code.',
    icon: '/assets/images/dashboard/channels/whatsapp.png',
  },
  {
    value: PROVIDER_TYPES.BORNAN_BUSINESS,
    label: 'Cloud API Business',
    description: 'Conexão via API Oficial (Token, Number ID e Business ID).',
    icon: '/assets/images/dashboard/channels/whatsapp.png',
  },
  // Até aqui
]);

const selectProvider = providerValue => {
  router.push({
    name: route.name,
    params: route.params,
    query: { provider: providerValue },
  });
};
</script>

<template>
  <div
    class="overflow-auto col-span-6 p-6 w-full h-full rounded-t-lg border border-b-0 border-n-weak bg-n-solid-1"
  >
    <div v-if="showProviderSelection">
      <div class="mb-10 text-left">
        <h1 class="mb-2 text-lg font-medium text-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.SELECT_PROVIDER.TITLE') }}
        </h1>
        <p class="text-sm leading-relaxed text-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.SELECT_PROVIDER.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex gap-6 justify-start">
        <div
          v-for="provider in availableProviders"
          :key="provider.value"
          class="gap-6 px-5 py-6 w-96 rounded-2xl border transition-all duration-200 cursor-pointer border-n-weak hover:bg-n-slate-3"
          @click="selectProvider(provider.value)"
        >
          <div class="flex justify-start mb-5">
            <div
              class="flex justify-center items-center rounded-full size-10 bg-n-alpha-2"
            >
              <img
                :src="provider.icon"
                :alt="provider.label"
                class="object-contain size-[26px]"
              />
            </div>
          </div>

          <div class="text-start">
            <h3 class="mb-1.5 text-sm font-medium text-slate-12">
              {{ provider.label }}
            </h3>
            <p class="text-sm text-slate-11">
              {{ provider.description }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <div v-else-if="showConfiguration">
      <div class="px-6 py-5 rounded-2xl border bg-n-solid-2 border-n-weak">
        <BornanQr v-if="selectedProvider === PROVIDER_TYPES.BORNAN_QR" />
        <BornanBusiness
          v-else-if="selectedProvider === PROVIDER_TYPES.BORNAN_BUSINESS"
        />
      </div>
    </div>
  </div>
</template>
