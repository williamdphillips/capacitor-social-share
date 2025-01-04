export enum SharePlatform {
    INSTAGRAM_STORIES = 'instagram-stories',
    INSTAGRAM_POST = 'instagram-post',
    FACEBOOK = 'facebook',
    TIKTOK = 'tiktok',
    TWITTER = 'twitter',
    WHATSAPP = 'whatsapp',
}

export interface InstagramShareOptions {
    platform: SharePlatform.INSTAGRAM_STORIES | SharePlatform.INSTAGRAM_POST;
    imagePath?: string; // Optional: Full-screen image to use as a background (if provided, overrides backgroundColor)
    audioPath?: string; // Optional: File URI for an audio track (used for stories with audio)
    contentURL?: string; // Optional: Link to add to the story
    linkURL?: string // Optional: Link to add to the story with a clickable button
    stickerImage?: string; // Optional: File URI for a sticker (includes song image or custom sticker)
    backgroundColor?: string; // Optional: Background color for the story/video
    startTime?: number; // Optional: Start time in seconds for the audio (defaults to 0)
}

export interface FacebookShareOptions {
    platform: SharePlatform.FACEBOOK;
    title?: string; // Optional: Title for the share
    text?: string; // Optional: Text for the share
    url: string; // Required: URL to share
    imagePath?: string; // Optional: File URI for an image
}

export interface TikTokShareOptions {
    platform: SharePlatform.TIKTOK;
    videoPath: string; // Required: File URI for the video
}

export interface TwitterShareOptions {
    platform: SharePlatform.TWITTER;
    text?: string; // Optional: Text for the tweet
    url?: string; // Optional: URL to include in the tweet
    imagePath?: string; // Optional: File URI for an image
}

export interface WhatsAppShareOptions {
    platform: SharePlatform.WHATSAPP;
    text: string; // Required: Message to send
    imagePath?: string; // Optional: File URI for an image
    url?: string;
}

export type ShareOptions =
    | InstagramShareOptions
    | FacebookShareOptions
    | TikTokShareOptions
    | TwitterShareOptions
    | WhatsAppShareOptions;

export interface SocialSharePlugin {
    share(options: ShareOptions): Promise<void>;
}