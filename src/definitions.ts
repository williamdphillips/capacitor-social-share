export enum SharePlatform {
    NATIVE = 'native', // Uses system's native share sheet (all available apps)
    INSTAGRAM_STORIES = 'instagram-stories',
    INSTAGRAM = 'instagram', // Opens Instagram with native picker (Message/Story/Feed/Reels)
    FACEBOOK = 'facebook',
    TWITTER = 'twitter', // X (formerly Twitter)
    TIKTOK = 'tiktok',
    WHATSAPP = 'whatsapp',
    LINKEDIN = 'linkedin',
    SNAPCHAT = 'snapchat',
    TELEGRAM = 'telegram',
    REDDIT = 'reddit'
}

export interface NativeShareOptions {
    platform: SharePlatform.NATIVE;
    title?: string; // Optional: Title for the share (iOS/Android share sheet title)
    text?: string; // Optional: Text content to share
    url?: string; // Optional: URL to share
    imagePath?: string; // Optional: Image file path
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
    videoPath?: string; // Optional: Video file path  
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
    files?: string[]; // Optional: Array of file paths to share (iOS/Android only)
}

export interface TextOverlay {
    text: string;
    x: number; // X position as percentage (0-100)
    y: number; // Y position as percentage (0-100)
    fontSize: number; // Font size in points
    color?: string; // Text color (hex or rgba), defaults to white
    fontFamily?: string; // Font family name, defaults to system font
}

export interface ImageOverlay {
    imagePath?: string; // Image file path
    imageData?: string; // Image as base64 string (alternative to imagePath)
    x: number; // X position as percentage (0-100)
    y: number; // Y position as percentage (0-100)
    width: number; // Width as percentage (0-100)
    height: number; // Height as percentage (0-100)
}

export interface InstagramShareOptions {
    platform: SharePlatform.INSTAGRAM_STORIES | SharePlatform.INSTAGRAM;
    text?: string; // Optional: Caption text for the post
    imagePath?: string; // Optional: Background image file path
    imageData?: string; // Optional: Background image as base64 string (alternative to imagePath)
    videoPath?: string; // Optional: Video file path (for direct video sharing or canvas-recorded videos)
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
    audioPath?: string; // Optional: Audio file path - if provided with imagePath/imageData, creates a video
    audioData?: string; // Optional: Audio as base64 string (alternative to audioPath)
    contentURL?: string; // Optional: Link to add to the story
    linkURL?: string // Optional: Link to add to the story with a clickable button
    stickerImage?: string; // Optional: File URI for a sticker
    stickerImageData?: string; // Optional: Sticker image as base64 string (alternative to stickerImage)
    backgroundColor?: string; // Optional: Background color (used if no imagePath/imageData provided)
    startTime?: number; // Optional: Start time in seconds for the audio (defaults to 0)
    duration?: number; // Optional: Duration in seconds for the video (if not specified, uses remaining audio duration)
    saveToDevice?: boolean; // Optional: Save created content to device before sharing (default: false)
    textOverlays?: TextOverlay[]; // Optional: Array of text overlays to add to the video/image
    imageOverlays?: ImageOverlay[]; // Optional: Array of image overlays to add to the video/image
}

export interface FacebookShareOptions {
    platform: SharePlatform.FACEBOOK;
    title?: string; // Optional: Title for the share
    text?: string; // Optional: Description text
    url?: string; // Optional: URL to share
    imagePath?: string; // Optional: Image file path
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
    videoPath?: string; // Optional: Video file path
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
    hashtag?: string; // Optional: Hashtag (e.g., "#MyApp")
}

export interface TwitterShareOptions {
    platform: SharePlatform.TWITTER;
    text?: string; // Optional: Tweet text (280 character limit)
    url?: string; // Optional: URL to include in the tweet
    imagePath?: string; // Optional: Image file path
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
    videoPath?: string; // Optional: Video file path
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
    hashtags?: string[]; // Optional: Array of hashtags (without #)
    via?: string; // Optional: Twitter username to attribute (without @)
}

export interface TikTokShareOptions {
    platform: SharePlatform.TIKTOK;
    videoPath?: string; // Optional: Video file path
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
    imagePath?: string; // Optional: Image file path (for photo posts)
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
    audioPath?: string; // Optional: Audio file path
    audioData?: string; // Optional: Audio as base64 string (alternative to audioPath)
    text?: string; // Optional: Caption text
    hashtags?: string[]; // Optional: Array of hashtags
}

export interface WhatsAppShareOptions {
    platform: SharePlatform.WHATSAPP;
    text?: string; // Optional: Message text
    imagePath?: string; // Optional: Image file path
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
    videoPath?: string; // Optional: Video file path
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
    url?: string; // Optional: URL to share
    phoneNumber?: string; // Optional: Specific phone number to send to
}

export interface LinkedInShareOptions {
    platform: SharePlatform.LINKEDIN;
    title?: string; // Optional: Post title
    text?: string; // Optional: Post content
    url?: string; // Optional: URL to share
    imagePath?: string; // Optional: Image file path
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
}

export interface SnapchatShareOptions {
    platform: SharePlatform.SNAPCHAT;
    imagePath?: string; // Optional: Image file path
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
    videoPath?: string; // Optional: Video file path
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
    stickerImage?: string; // Optional: Sticker overlay file path
    stickerImageData?: string; // Optional: Sticker image as base64 string (alternative to stickerImage)
    attachmentUrl?: string; // Optional: URL attachment
}

export interface TelegramShareOptions {
    platform: SharePlatform.TELEGRAM;
    text?: string; // Optional: Message text
    url?: string; // Optional: URL to share
    imagePath?: string; // Optional: Image file path
    imageData?: string; // Optional: Image as base64 string (alternative to imagePath)
    videoPath?: string; // Optional: Video file path
    videoData?: string; // Optional: Video as base64 string (alternative to videoPath)
}

export interface RedditShareOptions {
    platform: SharePlatform.REDDIT;
    title?: string; // Optional: Post title
    text?: string; // Optional: Post content (for text posts)
    url?: string; // Optional: URL to share (for link posts)
    subreddit?: string; // Optional: Specific subreddit (e.g., "reactjs")
}

export type ShareOptions =
    | NativeShareOptions
    | InstagramShareOptions
    | FacebookShareOptions
    | TwitterShareOptions
    | TikTokShareOptions
    | WhatsAppShareOptions
    | LinkedInShareOptions
    | SnapchatShareOptions
    | TelegramShareOptions
    | RedditShareOptions;

export interface SocialSharePlugin {
    share(options: ShareOptions): Promise<void>;
}