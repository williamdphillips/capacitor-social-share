import { WebPlugin } from '@capacitor/core';
import { SocialSharePlugin, ShareOptions, SharePlatform, InstagramShareOptions, FacebookShareOptions, TwitterShareOptions, WhatsAppShareOptions } from './definitions';

export class SocialShareWeb extends WebPlugin implements SocialSharePlugin {
    async share(options: ShareOptions): Promise<void> {
        if (!navigator.share) {
            console.error('Web sharing is not supported on this platform.');
            return;
        }

        try {
            switch (options.platform) {
                case SharePlatform.INSTAGRAM_STORIES:
                case SharePlatform.INSTAGRAM_POST:
                    this.handleInstagramSharing(options as InstagramShareOptions);
                    break;

                case SharePlatform.FACEBOOK:
                    this.handleFacebookSharing(options as FacebookShareOptions);
                    break;

                case SharePlatform.TWITTER:
                    this.handleTwitterSharing(options as TwitterShareOptions);
                    break;

                case SharePlatform.WHATSAPP:
                    this.handleWhatsAppSharing(options as WhatsAppShareOptions);
                    break;

                default:
                    console.error(`Unsupported platform: ${options.platform}`);
            }
        } catch (error) {
            console.error('Error sharing content:', error);
        }
    }

    private async handleInstagramSharing(options: InstagramShareOptions): Promise<void> {
        console.error('Sharing to Instagram is not supported on the web. Use the mobile app.');
    }

    private async handleFacebookSharing(options: FacebookShareOptions): Promise<void> {
        try {
            if ('url' in options) {
                await navigator.share({
                    title: options.title ?? '',
                    text: options.text ?? '',
                    url: options.url,
                });
            } else {
                console.error('Facebook sharing requires a URL.');
            }
        } catch (error) {
            console.error('Error sharing to Facebook:', error);
        }
    }

    private async handleTwitterSharing(options: TwitterShareOptions): Promise<void> {
        try {
            const twitterShareURL = `https://twitter.com/intent/tweet?text=${encodeURIComponent(options.text ?? '')}&url=${encodeURIComponent(options.url ?? '')}`;
            window.open(twitterShareURL, '_blank');
        } catch (error) {
            console.error('Error sharing to Twitter:', error);
        }
    }

    private async handleWhatsAppSharing(options: WhatsAppShareOptions): Promise<void> {
        try {
            const whatsAppShareURL = `https://wa.me/?text=${encodeURIComponent(options.text + ' ' + (options.url ?? ''))}`;
            window.open(whatsAppShareURL, '_blank');
        } catch (error) {
            console.error('Error sharing to WhatsApp:', error);
        }
    }
}