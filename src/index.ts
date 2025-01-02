import { registerPlugin } from '@capacitor/core';
import type { SocialSharePlugin } from './definitions';

const SocialShare = registerPlugin<SocialSharePlugin>('SocialShare', {
    web: () => import('./web').then((m) => new m.SocialShareWeb()),
});

export * from './definitions';
export { SocialShare };