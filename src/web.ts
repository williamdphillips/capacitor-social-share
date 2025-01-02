import { WebPlugin } from '@capacitor/core';
import { SocialSharePlugin, ShareOptions } from './definitions';

export class SocialShareWeb extends WebPlugin implements SocialSharePlugin {
    async share(options: ShareOptions): Promise<void> {
        if (navigator.share) {
            try {
                await navigator.share({
                    title: options.title,
                    text: options.text,
                    url: options.url,
                });
            } catch (error) {
                console.error('Error sharing content:', error);
            }
        } else {
            console.error('Web sharing is not supported on this platform.');
        }
    }
}