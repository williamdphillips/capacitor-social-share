import {
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
    RedditShareOptions,
    ShareOptions,
} from '../src/definitions';

describe('SharePlatform Enum', () => {
    it('should have correct platform values', () => {
        expect(SharePlatform.NATIVE).toBe('native');
        expect(SharePlatform.INSTAGRAM_STORIES).toBe('instagram-stories');
        expect(SharePlatform.INSTAGRAM).toBe('instagram');
        expect(SharePlatform.FACEBOOK).toBe('facebook');
        expect(SharePlatform.TWITTER).toBe('twitter');
        expect(SharePlatform.TIKTOK).toBe('tiktok');
        expect(SharePlatform.WHATSAPP).toBe('whatsapp');
        expect(SharePlatform.LINKEDIN).toBe('linkedin');
        expect(SharePlatform.SNAPCHAT).toBe('snapchat');
        expect(SharePlatform.TELEGRAM).toBe('telegram');
        expect(SharePlatform.REDDIT).toBe('reddit');
    });

    it('should have exactly 11 platforms', () => {
        const platforms = Object.values(SharePlatform);
        expect(platforms).toHaveLength(11);
    });
});

describe('Native Share Options', () => {
    it('should accept valid native share options with all fields', () => {
        const options: NativeShareOptions = {
            platform: SharePlatform.NATIVE,
            title: 'Share Title',
            text: 'Share this content',
            url: 'https://example.com',
            imagePath: '/path/to/image.jpg',
            videoPath: '/path/to/video.mp4',
            files: ['/path/to/file1.pdf', '/path/to/file2.doc']
        };

        expect(options.platform).toBe('native');
        expect(options.title).toBe('Share Title');
        expect(options.text).toBe('Share this content');
        expect(options.url).toBe('https://example.com');
        expect(options.files).toEqual(['/path/to/file1.pdf', '/path/to/file2.doc']);
    });

    it('should accept native share options with binary data', () => {
        const options: NativeShareOptions = {
            platform: SharePlatform.NATIVE,
            imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...',
            videoData: 'data:video/mp4;base64,AAAAIGZ0eXBpc29tAAACAGlzb21...'
        };

        expect(options.platform).toBe('native');
        expect(options.imageData).toContain('base64');
        expect(options.videoData).toContain('base64');
    });

    it('should accept minimal native share options', () => {
        const options: NativeShareOptions = {
            platform: SharePlatform.NATIVE,
            text: 'Simple text share'
        };

        expect(options.platform).toBe('native');
        expect(options.text).toBe('Simple text share');
    });

    it('should accept native share options with only URL', () => {
        const options: NativeShareOptions = {
            platform: SharePlatform.NATIVE,
            url: 'https://example.com'
        };

        expect(options.platform).toBe('native');
        expect(options.url).toBe('https://example.com');
    });
});

describe('Instagram Share Options', () => {
    it('should accept valid Instagram Stories options with file paths', () => {
        const options: InstagramShareOptions = {
            platform: SharePlatform.INSTAGRAM_STORIES,
            imagePath: '/path/to/image.jpg',
            audioPath: '/path/to/audio.mp3',
            contentURL: 'https://example.com',
            linkURL: 'https://link.com',
            stickerImage: '/path/to/sticker.png',
            backgroundColor: '#FF0000',
            startTime: 30,
            saveToDevice: true,
        };

        expect(options.platform).toBe('instagram-stories');
        expect(options.imagePath).toBe('/path/to/image.jpg');
        expect(options.audioPath).toBe('/path/to/audio.mp3');
        expect(options.saveToDevice).toBe(true);
    });

    it('should accept valid Instagram Stories options with base64 data', () => {
        const options: InstagramShareOptions = {
            platform: SharePlatform.INSTAGRAM_STORIES,
            imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...',
            audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP...',
            stickerImageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...',
            contentURL: 'https://example.com',
            saveToDevice: true,
        };

        expect(options.platform).toBe('instagram-stories');
        expect(options.imageData).toContain('base64');
        expect(options.audioData).toContain('base64');
        expect(options.stickerImageData).toContain('base64');
    });

    it('should accept valid Instagram native picker options', () => {
        const instagramOptions: InstagramShareOptions = {
            platform: SharePlatform.INSTAGRAM,
            imagePath: '/path/to/image.jpg',
            text: 'Check this out!',
            backgroundColor: '#FF0000',
            saveToDevice: true
        };

        expect(instagramOptions.platform).toBe('instagram');
        expect(instagramOptions.imagePath).toBe('/path/to/image.jpg');
        expect(instagramOptions.text).toBe('Check this out!');
        expect(instagramOptions.backgroundColor).toBe('#FF0000');
        expect(instagramOptions.saveToDevice).toBe(true);
    });
});

describe('Facebook Share Options', () => {
    it('should accept valid Facebook options with all fields', () => {
        const options: FacebookShareOptions = {
            platform: SharePlatform.FACEBOOK,
            title: 'Test Title',
            text: 'Test description',
            url: 'https://example.com',
            imagePath: '/path/to/image.jpg',
            videoPath: '/path/to/video.mp4',
            hashtag: '#test',
        };

        expect(options.platform).toBe('facebook');
        expect(options.title).toBe('Test Title');
        expect(options.hashtag).toBe('#test');
    });

    it('should accept Facebook options with binary data', () => {
        const options: FacebookShareOptions = {
            platform: SharePlatform.FACEBOOK,
            imageData: 'base64imagedata',
            videoData: 'base64videodata',
        };

        expect(options.imageData).toBe('base64imagedata');
        expect(options.videoData).toBe('base64videodata');
    });
});

describe('Twitter Share Options', () => {
    it('should accept valid Twitter options', () => {
        const options: TwitterShareOptions = {
            platform: SharePlatform.TWITTER,
            text: 'Hello Twitter!',
            url: 'https://example.com',
            hashtags: ['test', 'twitter'],
            via: 'username',
            imagePath: '/path/to/image.jpg',
        };

        expect(options.platform).toBe('twitter');
        expect(options.hashtags).toEqual(['test', 'twitter']);
        expect(options.via).toBe('username');
    });

    it('should accept Twitter options with binary data', () => {
        const options: TwitterShareOptions = {
            platform: SharePlatform.TWITTER,
            text: 'Tweet with image',
            imageData: 'base64imagedata',
            videoData: 'base64videodata',
        };

        expect(options.imageData).toBe('base64imagedata');
        expect(options.videoData).toBe('base64videodata');
    });
});

describe('TikTok Share Options', () => {
    it('should accept valid TikTok options', () => {
        const options: TikTokShareOptions = {
            platform: SharePlatform.TIKTOK,
            text: 'TikTok caption',
            hashtags: ['viral', 'trending'],
            videoPath: '/path/to/video.mp4',
        };

        expect(options.platform).toBe('tiktok');
        expect(options.hashtags).toEqual(['viral', 'trending']);
    });

    it('should accept TikTok options with binary data', () => {
        const options: TikTokShareOptions = {
            platform: SharePlatform.TIKTOK,
            videoData: 'base64videodata',
            imageData: 'base64imagedata',
            audioData: 'base64audiodata',
        };

        expect(options.videoData).toBe('base64videodata');
        expect(options.imageData).toBe('base64imagedata');
        expect(options.audioData).toBe('base64audiodata');
    });
});

describe('WhatsApp Share Options', () => {
    it('should accept valid WhatsApp options', () => {
        const options: WhatsAppShareOptions = {
            platform: SharePlatform.WHATSAPP,
            text: 'Hello WhatsApp!',
            url: 'https://example.com',
            phoneNumber: '+1234567890',
            imagePath: '/path/to/image.jpg',
        };

        expect(options.platform).toBe('whatsapp');
        expect(options.phoneNumber).toBe('+1234567890');
    });

    it('should accept WhatsApp options with binary data', () => {
        const options: WhatsAppShareOptions = {
            platform: SharePlatform.WHATSAPP,
            imageData: 'base64imagedata',
            videoData: 'base64videodata',
        };

        expect(options.imageData).toBe('base64imagedata');
        expect(options.videoData).toBe('base64videodata');
    });
});

describe('LinkedIn Share Options', () => {
    it('should accept valid LinkedIn options', () => {
        const options: LinkedInShareOptions = {
            platform: SharePlatform.LINKEDIN,
            title: 'Professional Post',
            text: 'LinkedIn content',
            url: 'https://example.com',
            imagePath: '/path/to/image.jpg',
        };

        expect(options.platform).toBe('linkedin');
        expect(options.title).toBe('Professional Post');
    });

    it('should accept LinkedIn options with binary data', () => {
        const options: LinkedInShareOptions = {
            platform: SharePlatform.LINKEDIN,
            imageData: 'base64imagedata',
        };

        expect(options.imageData).toBe('base64imagedata');
    });
});

describe('Snapchat Share Options', () => {
    it('should accept valid Snapchat options', () => {
        const options: SnapchatShareOptions = {
            platform: SharePlatform.SNAPCHAT,
            imagePath: '/path/to/image.jpg',
            videoPath: '/path/to/video.mp4',
            stickerImage: '/path/to/sticker.png',
            attachmentUrl: 'https://example.com',
        };

        expect(options.platform).toBe('snapchat');
        expect(options.attachmentUrl).toBe('https://example.com');
    });

    it('should accept Snapchat options with binary data', () => {
        const options: SnapchatShareOptions = {
            platform: SharePlatform.SNAPCHAT,
            imageData: 'base64imagedata',
            videoData: 'base64videodata',
            stickerImageData: 'base64stickerdata',
        };

        expect(options.imageData).toBe('base64imagedata');
        expect(options.videoData).toBe('base64videodata');
        expect(options.stickerImageData).toBe('base64stickerdata');
    });
});

describe('Telegram Share Options', () => {
    it('should accept valid Telegram options', () => {
        const options: TelegramShareOptions = {
            platform: SharePlatform.TELEGRAM,
            text: 'Telegram message',
            url: 'https://example.com',
            imagePath: '/path/to/image.jpg',
        };

        expect(options.platform).toBe('telegram');
        expect(options.text).toBe('Telegram message');
    });

    it('should accept Telegram options with binary data', () => {
        const options: TelegramShareOptions = {
            platform: SharePlatform.TELEGRAM,
            imageData: 'base64imagedata',
            videoData: 'base64videodata',
        };

        expect(options.imageData).toBe('base64imagedata');
        expect(options.videoData).toBe('base64videodata');
    });
});

describe('Reddit Share Options', () => {
    it('should accept valid Reddit options', () => {
        const options: RedditShareOptions = {
            platform: SharePlatform.REDDIT,
            title: 'Reddit Post Title',
            text: 'Reddit post content',
            url: 'https://example.com',
            subreddit: 'technology',
        };

        expect(options.platform).toBe('reddit');
        expect(options.subreddit).toBe('technology');
    });
});

describe('Share Options Union Type', () => {
    it('should accept all platform option types', () => {
        const instagramOptions: ShareOptions = {
            platform: SharePlatform.INSTAGRAM,
            imagePath: '/path/to/image.jpg',
        };

        const facebookOptions: ShareOptions = {
            platform: SharePlatform.FACEBOOK,
            title: 'Facebook Post',
        };

        const twitterOptions: ShareOptions = {
            platform: SharePlatform.TWITTER,
            text: 'Tweet',
        };

        expect(instagramOptions.platform).toBe('instagram');
        expect(facebookOptions.platform).toBe('facebook');
        expect(twitterOptions.platform).toBe('twitter');
    });

    it('should properly discriminate union types', () => {
        const options: ShareOptions = {
            platform: SharePlatform.INSTAGRAM_STORIES,
            imagePath: '/path/to/image.jpg',
            audioPath: '/path/to/audio.mp3',
        };

        if (options.platform === SharePlatform.INSTAGRAM_STORIES) {
            // TypeScript should know this is InstagramShareOptions
            expect(options.imagePath).toBe('/path/to/image.jpg');
            expect(options.audioPath).toBe('/path/to/audio.mp3');
        }
    });
}); 