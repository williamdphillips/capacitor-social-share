import { WebPlugin } from '@capacitor/core';
import {
    SocialSharePlugin,
    ShareOptions,
    SharePlatform,
    NativeShareOptions,
    InstagramShareOptions,
    FacebookShareOptions,
    TwitterShareOptions,
    TikTokShareOptions,
    WhatsAppShareOptions,
    LinkedInShareOptions,
    SnapchatShareOptions,
    TelegramShareOptions,
    RedditShareOptions
} from './definitions';

interface WebShareData {
    title?: string;
    text?: string;
    url?: string;
    files?: File[];
}

export class SocialShareWeb extends WebPlugin implements SocialSharePlugin {
    async share(options: ShareOptions): Promise<void> {
        try {
            const platform = options.platform;
            switch (platform) {
                case SharePlatform.NATIVE:
                    await this.handleNativeSharing(options as NativeShareOptions);
                    break;
                case SharePlatform.INSTAGRAM_STORIES:
                case SharePlatform.INSTAGRAM:
                    await this.handleInstagramSharing(options as InstagramShareOptions);
                    break;

                case SharePlatform.FACEBOOK:
                    await this.handleFacebookSharing(options as FacebookShareOptions);
                    break;

                case SharePlatform.TWITTER:
                    await this.handleTwitterSharing(options as TwitterShareOptions);
                    break;

                case SharePlatform.TIKTOK:
                    await this.handleTikTokSharing(options as TikTokShareOptions);
                    break;

                case SharePlatform.WHATSAPP:
                    await this.handleWhatsAppSharing(options as WhatsAppShareOptions);
                    break;

                case SharePlatform.LINKEDIN:
                    await this.handleLinkedInSharing(options as LinkedInShareOptions);
                    break;

                case SharePlatform.SNAPCHAT:
                    await this.handleSnapchatSharing(options as SnapchatShareOptions);
                    break;

                case SharePlatform.TELEGRAM:
                    await this.handleTelegramSharing(options as TelegramShareOptions);
                    break;

                case SharePlatform.REDDIT:
                    await this.handleRedditSharing(options as RedditShareOptions);
                    break;

                default:
                    throw new Error(`Unsupported platform: ${platform}`);
            }
        } catch (error) {
            console.error('Error sharing content:', error);
            throw error;
        }
    }

    // Helper function to convert base64 to File/Blob
    private base64ToFile(base64: string, filename: string, mimeType: string): File {
        const byteCharacters = atob(base64.split(',')[1] || base64);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        return new File([byteArray], filename, { type: mimeType });
    }

    // Helper function to get file for sharing (from path or base64)
    private async getFileForSharing(filePath?: string, fileData?: string, defaultName: string = 'file', mimeType: string = 'application/octet-stream'): Promise<File | null> {
        if (fileData) {
            try {
                return this.base64ToFile(fileData, defaultName, mimeType);
            } catch (error) {
                console.warn('Failed to convert base64 to file:', error);
            }
        }

        if (filePath) {
            try {
                const response = await fetch(filePath);
                const blob = await response.blob();
                return new File([blob], defaultName, { type: blob.type || mimeType });
            } catch (error) {
                console.warn('Failed to load file from path:', error);
            }
        }

        return null;
    }

    // Native system sharing using Web Share API
    private async handleNativeSharing(options: NativeShareOptions): Promise<void> {
        const { title, text, url, imagePath, imageData, videoPath, videoData, files } = options;

        // Check if any content is provided before proceeding
        if (!title && !text && !url && !imagePath && !imageData && !videoPath && !videoData && (!files || files.length === 0)) {
            throw new Error('No content to share');
        }

        // Prepare share data
        const shareData: WebShareData = {};

        if (title) shareData.title = title;
        if (text) shareData.text = text;
        if (url) shareData.url = url;

        // Handle file sharing if supported
        const fileList: File[] = [];

        // Add image file if provided
        if (imagePath || imageData) {
            try {
                const imageFile = await this.createFileFromPath(imagePath, imageData, 'image', 'shared-image.jpg');
                if (imageFile) fileList.push(imageFile);
            } catch (error) {
                console.warn('Failed to process image for native sharing:', error);
            }
        }

        // Add video file if provided
        if (videoPath || videoData) {
            try {
                const videoFile = await this.createFileFromPath(videoPath, videoData, 'video', 'shared-video.mp4');
                if (videoFile) fileList.push(videoFile);
            } catch (error) {
                console.warn('Failed to process video for native sharing:', error);
            }
        }

        // Add additional files if provided
        if (files && files.length > 0) {
            for (const filePath of files) {
                try {
                    const file = await this.createFileFromPath(filePath, undefined, undefined, filePath.split('/').pop() || 'shared-file');
                    if (file) fileList.push(file);
                } catch (error) {
                    console.warn('Failed to process file for native sharing:', error);
                }
            }
        }

        // Add files to share data if supported and available
        if (fileList.length > 0) {
            // Check if browser supports file sharing
            if (navigator.canShare && navigator.canShare({ files: fileList })) {
                shareData.files = fileList;
            } else {
                console.warn('File sharing not supported in this browser, sharing URLs/text only');
            }
        }

        // Try native Web Share API first
        if (navigator.share) {
            try {
                await navigator.share(shareData);
                return;
            } catch (error) {
                // User cancelled or share failed, fall through to fallback
                console.warn('Native share cancelled or failed:', error);
            }
        }

        // Fallback for browsers without Web Share API
        await this.fallbackNativeShare(shareData);
    }

    private async fallbackNativeShare(shareData: WebShareData): Promise<void> {
        // Create a shareable text combination
        const parts = [];
        if (shareData.title) parts.push(shareData.title);
        if (shareData.text) parts.push(shareData.text);
        if (shareData.url) parts.push(shareData.url);

        const shareText = parts.join(' ');

        if (shareText) {
            // Try clipboard API as fallback
            if (navigator.clipboard && navigator.clipboard.writeText) {
                try {
                    await navigator.clipboard.writeText(shareText);
                    alert('Content copied to clipboard. You can now paste it in any app.');
                    return;
                } catch (error) {
                    console.warn('Clipboard write failed:', error);
                }
            }

            // Final fallback - show share text in an alert
            alert(`Share this content:\n\n${shareText}`);
        } else {
            throw new Error('No content to share');
        }
    }

    private async createFileFromPath(filePath?: string, fileData?: string, type?: string, defaultName?: string): Promise<File | null> {
        if (fileData) {
            // Handle base64 data
            try {
                const cleanBase64 = fileData.replace(/^data:[^;]+;base64,/, '');
                const binaryString = atob(cleanBase64);
                const bytes = new Uint8Array(binaryString.length);

                for (let i = 0; i < binaryString.length; i++) {
                    bytes[i] = binaryString.charCodeAt(i);
                }

                const mimeType = type === 'image' ? 'image/jpeg' : type === 'video' ? 'video/mp4' : 'application/octet-stream';
                const blob = new Blob([bytes], { type: mimeType });
                return new File([blob], defaultName || 'shared-file', { type: mimeType });
            } catch (error) {
                console.warn('Failed to process base64 data:', error);
                return null;
            }
        } else if (filePath) {
            // Handle file path - in web context, this is likely a URL
            try {
                const response = await fetch(filePath);
                if (!response.ok) throw new Error('Network error');

                const blob = await response.blob();
                const mimeType = blob.type || (type === 'image' ? 'image/jpeg' : type === 'video' ? 'video/mp4' : 'application/octet-stream');
                return new File([blob], defaultName || 'shared-file', { type: mimeType });
            } catch (error) {
                console.warn('Failed to load file from path:', error);
                return null;
            }
        }

        return null;
    }

    // Helper function to share with native Web Share API
    private async tryNativeShare(title: string, text: string, url: string, file?: File): Promise<boolean> {
        if (!navigator.share) return false;

        try {
            const shareData: WebShareData = {};
            if (title) shareData.title = title;
            if (text) shareData.text = text;
            if (url) shareData.url = url;
            if (file && 'canShare' in navigator && (navigator as Navigator & { canShare: (data: WebShareData) => boolean }).canShare({ files: [file] })) {
                shareData.files = [file];
            }

            await navigator.share(shareData);
            return true;
        } catch (error) {
            return false;
        }
    }

    private async handleInstagramSharing(options: InstagramShareOptions): Promise<void> {
        const { imagePath, imageData, videoPath, videoData, contentURL, text } = options;

        // Check if we have a video (either path or data)
        const hasVideo = !!(videoPath || videoData);

        // Get the appropriate file for sharing
        let mediaFile: File | null = null;
        let mediaType = '';

        if (hasVideo) {
            // Handle video
            mediaFile = await this.getFileForSharing(videoPath, videoData, 'video.webm', 'video/webm');
            mediaType = 'video';
        } else {
            // Handle image
            mediaFile = await this.getFileForSharing(imagePath, imageData, 'image.jpg', 'image/jpeg');
            mediaType = 'image';
        }

        // Create helpful content for clipboard
        let clipboardContent = '';
        if (text) clipboardContent += text + '\n';
        if (contentURL) clipboardContent += contentURL;

        // Copy content to clipboard if available
        let clipboardMessage = '';
        if (clipboardContent) {
            try {
                await navigator.clipboard.writeText(clipboardContent);
                clipboardMessage = '\n\nCaption and link copied to clipboard!';
            } catch (error) {
                // Clipboard access failed
            }
        }

        // Try native share first if we have media
        if (mediaFile) {
            const shared = await this.tryNativeShare(
                'Share to Instagram',
                text || '',
                contentURL || '',
                mediaFile
            );
            if (shared) return;
        }

        // If native share didn't work, download the file for manual upload
        if (mediaFile) {
            // Create download link
            const url = URL.createObjectURL(mediaFile);
            const a = document.createElement('a');
            a.href = url;
            a.download = mediaFile.name;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);

            // Show guidance message
            const fileType = hasVideo ? 'Video' : 'Image';
            alert(`${fileType} downloaded!${clipboardMessage}

To share on Instagram:
1. Open Instagram app or web
2. Create a new ${options.platform === SharePlatform.INSTAGRAM_STORIES ? 'Story' : 'Post'}
3. Upload the downloaded ${mediaType}
4. Paste the caption from your clipboard

Opening Instagram web...`);
        } else {
            // No media file available
            alert(`Instagram sharing options:
            
• Stories: Best on mobile app
• Posts: Available on web and mobile
• Direct messages: Available on web${clipboardMessage}

Opening Instagram web...`);
        }

        // Open Instagram web interface
        window.open('https://www.instagram.com/', '_blank');
    }

    private async handleFacebookSharing(options: FacebookShareOptions): Promise<void> {
        const { title, text, url, hashtag, imagePath, imageData } = options;

        // Try to get image file
        const imageFile = await this.getFileForSharing(imagePath, imageData, 'image.jpg', 'image/jpeg');

        let shareText = text || '';
        if (hashtag) shareText += (shareText ? ' ' : '') + hashtag;

        // Try native sharing first if available
        const shared = await this.tryNativeShare(title || '', shareText, url || '', imageFile || undefined);
        if (shared) return;

        // Facebook Sharer URL fallback
        const params = new URLSearchParams();
        if (url) params.append('u', url);
        if (title) params.append('title', title);
        if (shareText) params.append('description', shareText);
        if (hashtag) params.append('hashtag', hashtag);

        const facebookShareURL = `https://www.facebook.com/sharer/sharer.php?${params.toString()}`;
        window.open(facebookShareURL, '_blank', 'width=600,height=400');
    }

    private async handleTwitterSharing(options: TwitterShareOptions): Promise<void> {
        const { text, url, hashtags, via, imagePath, imageData } = options;

        // Try to get image file
        const imageFile = await this.getFileForSharing(imagePath, imageData, 'image.jpg', 'image/jpeg');

        let shareText = text || '';
        if (hashtags?.length) {
            shareText += (shareText ? ' ' : '') + hashtags.map(tag => `#${tag}`).join(' ');
        }
        if (via) {
            shareText += (shareText ? ' ' : '') + `via @${via}`;
        }

        // Try native sharing first if available
        const shared = await this.tryNativeShare('', shareText, url || '', imageFile || undefined);
        if (shared) return;

        // Twitter Web Intent URL fallback
        const params = new URLSearchParams();
        if (text) params.append('text', text);
        if (url) params.append('url', url);
        if (hashtags?.length) params.append('hashtags', hashtags.join(','));
        if (via) params.append('via', via);

        const twitterShareURL = `https://twitter.com/intent/tweet?${params.toString()}`;
        window.open(twitterShareURL, '_blank', 'width=600,height=400');
    }

    private async handleTikTokSharing(options: TikTokShareOptions): Promise<void> {
        const { text, hashtags, imagePath, imageData, videoPath, videoData } = options;

        // Try to get media file (prefer video for TikTok)
        const videoFile = await this.getFileForSharing(videoPath, videoData, 'tiktok_video.mp4', 'video/mp4');
        const imageFile = await this.getFileForSharing(imagePath, imageData, 'tiktok_image.jpg', 'image/jpeg');
        const mediaFile = videoFile || imageFile;
        const mediaType = videoFile ? 'video' : 'image';

        let caption = text || '';
        if (hashtags?.length) {
            caption += (caption ? ' ' : '') + hashtags.map(tag => `#${tag}`).join(' ');
        }

        // Try native share with media if available
        if (mediaFile) {
            const shared = await this.tryNativeShare('Share to TikTok', caption, '', mediaFile);
            if (shared) return;
        }

        // If native share didn't work, download the file for manual upload
        if (mediaFile) {
            // Create download link
            const url = URL.createObjectURL(mediaFile);
            const a = document.createElement('a');
            a.href = url;
            a.download = mediaFile.name;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);

            // Copy caption to clipboard
            let clipboardMessage = '';
            if (caption) {
                try {
                    await navigator.clipboard.writeText(caption);
                    clipboardMessage = '\n\nCaption copied to clipboard!';
                } catch (error) {
                    // Clipboard access failed
                }
            }

            // Show guidance message
            const fileType = videoFile ? 'Video' : 'Image';
            alert(`${fileType} downloaded!${clipboardMessage}

To share on TikTok:
1. Open TikTok app or web
2. Click the + button to create
3. Upload the downloaded ${mediaType}
4. Paste the caption from your clipboard

Opening TikTok upload page...`);
        } else {
            // No media file available
            let message = 'TikTok sharing is best done through the mobile app.';
            if (caption) {
                try {
                    await navigator.clipboard.writeText(caption);
                    message += '\n\nCaption copied to clipboard!';
                } catch (error) {
                    // Clipboard access failed
                }
            }
            alert(message);
        }

        // Open TikTok web upload page
        window.open('https://www.tiktok.com/upload', '_blank');
    }

    private async handleWhatsAppSharing(options: WhatsAppShareOptions): Promise<void> {
        const { text, url, phoneNumber, imagePath, imageData } = options;

        // Try to get image file
        const imageFile = await this.getFileForSharing(imagePath, imageData, 'image.jpg', 'image/jpeg');

        let message = text || '';
        if (url) {
            message += (message ? ' ' : '') + url;
        }

        // Try native share with image if available
        if (imageFile) {
            const shared = await this.tryNativeShare('', message, '', imageFile);
            if (shared) return;
        }

        // WhatsApp web URL fallback
        let whatsAppURL: string;
        if (phoneNumber) {
            whatsAppURL = `https://wa.me/${phoneNumber}?text=${encodeURIComponent(message)}`;
        } else {
            whatsAppURL = `https://wa.me/?text=${encodeURIComponent(message)}`;
        }

        window.open(whatsAppURL, '_blank');
    }

    private async handleLinkedInSharing(options: LinkedInShareOptions): Promise<void> {
        const { title, text, url, imagePath, imageData } = options;

        // Try to get image file
        const imageFile = await this.getFileForSharing(imagePath, imageData, 'image.jpg', 'image/jpeg');

        // Try native sharing first if available
        const shared = await this.tryNativeShare(title || '', text || '', url || '', imageFile || undefined);
        if (shared) return;

        // LinkedIn Share URL fallback
        const params = new URLSearchParams();
        if (url) params.append('url', url);
        if (title) params.append('title', title);
        if (text) params.append('summary', text);

        const linkedInShareURL = `https://www.linkedin.com/sharing/share-offsite/?${params.toString()}`;
        window.open(linkedInShareURL, '_blank', 'width=600,height=400');
    }

    private async handleSnapchatSharing(options: SnapchatShareOptions): Promise<void> {
        const { imagePath, imageData, videoPath, videoData } = options;

        // Try to get media file
        const imageFile = await this.getFileForSharing(imagePath, imageData, 'image.jpg', 'image/jpeg');
        const videoFile = await this.getFileForSharing(videoPath, videoData, 'video.mp4', 'video/mp4');
        const mediaFile = videoFile || imageFile;

        // Try native share with media if available
        if (mediaFile) {
            const shared = await this.tryNativeShare('', '', '', mediaFile);
            if (shared) return;
        }

        // Snapchat doesn't have web sharing API
        console.warn('Snapchat sharing is only available through the mobile app');
        alert('Snapchat sharing is only available through the mobile app. Please use the Snapchat mobile app to share content.');
    }

    private async handleTelegramSharing(options: TelegramShareOptions): Promise<void> {
        const { text, url, imagePath, imageData } = options;

        // Try to get image file
        const imageFile = await this.getFileForSharing(imagePath, imageData, 'image.jpg', 'image/jpeg');

        let message = text || '';
        if (url) {
            message += (message ? '\n' : '') + url;
        }

        // Try native share with image if available
        if (imageFile) {
            const shared = await this.tryNativeShare('', message, '', imageFile);
            if (shared) return;
        }

        // Telegram share URL fallback
        const telegramShareURL = `https://t.me/share/url?url=${encodeURIComponent(url || '')}&text=${encodeURIComponent(text || '')}`;
        window.open(telegramShareURL, '_blank');
    }

    private async handleRedditSharing(options: RedditShareOptions): Promise<void> {
        const { title, text, url, subreddit } = options;

        // Reddit Submit URL
        const params = new URLSearchParams();
        if (title) params.append('title', title);
        if (url) {
            params.append('url', url);
        } else if (text) {
            params.append('selftext', text);
        }
        if (subreddit) params.append('sr', subreddit);

        const redditShareURL = `https://www.reddit.com/submit?${params.toString()}`;
        window.open(redditShareURL, '_blank');
    }
}