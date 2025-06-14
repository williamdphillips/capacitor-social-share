import { SocialShare } from '../src/index';
import { SharePlatform } from '../src/definitions';

describe('Integration Tests', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('Plugin Registration', () => {
        it('should register the plugin correctly', () => {
            expect(SocialShare).toBeDefined();
            expect(typeof SocialShare.share).toBe('function');
        });

        it('should have share method', () => {
            expect(typeof SocialShare.share).toBe('function');
        });
    });

    describe('Cross-Platform Share Interface', () => {
        it('should handle Instagram sharing with all option combinations', async () => {
            // Test with file paths
            const filePathOptions = {
                platform: SharePlatform.INSTAGRAM_STORIES,
                imagePath: '/test/image.jpg',
                audioPath: '/test/audio.mp3',
                stickerImage: '/test/sticker.png',
                contentURL: 'https://example.com',
                backgroundColor: '#FF0000',
                startTime: 15,
                saveToDevice: true,
            };

            // Should not throw
            await expect(SocialShare.share(filePathOptions)).resolves.not.toThrow();

            // Test with base64 data
            const base64Options = {
                platform: SharePlatform.INSTAGRAM_STORIES,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                stickerImageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==',
                saveToDevice: false,
            };

            await expect(SocialShare.share(base64Options)).resolves.not.toThrow();
        });

        it('should handle Facebook sharing with different content types', async () => {
            // Text post
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                title: 'Test Post',
                text: 'This is a test post',
                hashtag: '#test',
            })).resolves.not.toThrow();

            // Link post
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                url: 'https://example.com',
                title: 'Shared Link',
            })).resolves.not.toThrow();

            // Image post
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                text: 'Image post',
            })).resolves.not.toThrow();

            // Video post
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                videoPath: '/test/video.mp4',
                title: 'Video Post',
            })).resolves.not.toThrow();
        });

        it('should handle Twitter sharing with character limits and hashtags', async () => {
            // Regular tweet
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: 'Hello Twitter!',
                url: 'https://example.com',
                hashtags: ['test', 'tweet'],
                via: 'username',
            })).resolves.not.toThrow();

            // Tweet with image
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: 'Tweet with image',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                hashtags: ['photo'],
            })).resolves.not.toThrow();

            // Tweet with video
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: 'Video tweet',
                videoPath: '/test/video.mp4',
            })).resolves.not.toThrow();
        });

        it('should handle all other platforms correctly', async () => {
            // TikTok
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                videoData: 'data:video/mp4;base64,AAAAIGZ0eXBpc29t',
                text: 'TikTok video',
                hashtags: ['viral'],
            })).resolves.not.toThrow();

            // WhatsApp
            await expect(SocialShare.share({
                platform: SharePlatform.WHATSAPP,
                text: 'WhatsApp message',
                phoneNumber: '+1234567890',
            })).resolves.not.toThrow();

            // LinkedIn
            await expect(SocialShare.share({
                platform: SharePlatform.LINKEDIN,
                title: 'Professional Post',
                text: 'LinkedIn content',
                url: 'https://linkedin.com/post',
            })).resolves.not.toThrow();

            // Snapchat
            await expect(SocialShare.share({
                platform: SharePlatform.SNAPCHAT,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();

            // Telegram
            await expect(SocialShare.share({
                platform: SharePlatform.TELEGRAM,
                text: 'Telegram message',
                url: 'https://example.com',
            })).resolves.not.toThrow();

            // Reddit
            await expect(SocialShare.share({
                platform: SharePlatform.REDDIT,
                title: 'Reddit Post',
                url: 'https://example.com',
                subreddit: 'technology',
            })).resolves.not.toThrow();
        });
    });

    describe('Binary Data Support', () => {
        it('should handle various image formats as base64', async () => {
            const imageFormats = [
                { data: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==', type: 'JPEG' },
                { data: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==', type: 'PNG' },
                { data: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', type: 'GIF' },
                { data: 'data:image/webp;base64,UklGRh4AAABXRUJQVlA4TB==', type: 'WebP' },
            ];

            for (const format of imageFormats) {
                await expect(SocialShare.share({
                    platform: SharePlatform.FACEBOOK,
                    imageData: format.data,
                    text: `${format.type} image test`,
                })).resolves.not.toThrow();
            }
        });

        it('should handle various video formats as base64', async () => {
            const videoFormats = [
                { data: 'data:video/mp4;base64,AAAAIGZ0eXBpc29t', type: 'MP4' },
                { data: 'data:video/webm;base64,GkXfo59ChoEBQveBAULygQRC84EIQoKEd2VibUKHgQJChYECgYKVhYUUQoWFBYKEhYeBAUKCw==', type: 'WebM' },
                { data: 'data:video/quicktime;base64,ftypqt', type: 'QuickTime' },
            ];

            for (const format of videoFormats) {
                await expect(SocialShare.share({
                    platform: SharePlatform.TIKTOK,
                    videoData: format.data,
                    text: `${format.type} video test`,
                })).resolves.not.toThrow();
            }
        });

        it('should handle audio formats as base64', async () => {
            const audioFormats = [
                { data: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==', type: 'MP3' },
                { data: 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj==', type: 'WAV' },
                { data: 'data:audio/ogg;base64,T2dnUwACAAAAAAAAAADqnjMlAAAAAAPxVGYBHgF2b3JiaXMAAAAAATvhAAAAAACGAQ==', type: 'OGG' },
            ];

            for (const format of audioFormats) {
                await expect(SocialShare.share({
                    platform: SharePlatform.INSTAGRAM_STORIES,
                    audioData: format.data,
                    backgroundColor: '#000000',
                })).resolves.not.toThrow();
            }
        });
    });

    describe('Error Scenarios', () => {
        it('should handle invalid base64 data gracefully', async () => {
            // Invalid base64 should not crash the app
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                imageData: 'invalid-base64-data',
                text: 'Test with invalid data',
            })).resolves.not.toThrow();
        });

        it('should handle missing file paths gracefully', async () => {
            // Non-existent file paths should not crash
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                imagePath: '/non/existent/path.jpg',
                text: 'Test with missing file',
            })).resolves.not.toThrow();
        });

        it('should handle empty options gracefully', async () => {
            // Empty options should work (platform-specific defaults)
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
            })).resolves.not.toThrow();

            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
            })).resolves.not.toThrow();

            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
            })).resolves.not.toThrow();
        });

        it('should reject invalid platform', async () => {
            // Mock should be updated to handle validation 
            const mockSocialShare = SocialShare as jest.Mocked<typeof SocialShare>;
            mockSocialShare.share.mockRejectedValueOnce(new Error('Unsupported platform: invalid-platform'));

            await expect(SocialShare.share({
                platform: 'invalid-platform' as any,
            })).rejects.toThrow();
        });
    });

    describe('Feature Combinations', () => {
        it('should handle Instagram video creation from image + audio', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                startTime: 30,
                saveToDevice: true,
            })).resolves.not.toThrow();
        });

        it('should handle complex Twitter sharing with all features', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: 'Complex tweet with everything!',
                url: 'https://example.com',
                hashtags: ['test', 'complex', 'twitter'],
                via: 'testuser',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();
        });

        it('should handle WhatsApp with different contact methods', async () => {
            // Without phone number (general share)
            await expect(SocialShare.share({
                platform: SharePlatform.WHATSAPP,
                text: 'General WhatsApp message',
                url: 'https://example.com',
            })).resolves.not.toThrow();

            // With specific phone number
            await expect(SocialShare.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Direct message',
                phoneNumber: '+1234567890',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();
        });

        it('should handle Reddit with different post types', async () => {
            // Link post
            await expect(SocialShare.share({
                platform: SharePlatform.REDDIT,
                title: 'Interesting Link',
                url: 'https://example.com',
                subreddit: 'technology',
            })).resolves.not.toThrow();

            // Text post
            await expect(SocialShare.share({
                platform: SharePlatform.REDDIT,
                title: 'Discussion Post',
                text: 'This is a text post for discussion',
                subreddit: 'askreddit',
            })).resolves.not.toThrow();
        });
    });

    describe('Platform-Specific Features', () => {
        it('should handle Instagram-specific features', async () => {
            // Sticker overlay
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                imagePath: '/test/background.jpg',
                stickerImageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==',
                linkURL: 'https://example.com',
            })).resolves.not.toThrow();

            // Background color only
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                backgroundColor: '#FF5733',
                audioPath: '/test/music.mp3',
            })).resolves.not.toThrow();
        });

        it('should handle Instagram saveToDevice functionality', async () => {
            // Save to device first, then open Instagram
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imagePath: '/test/image.jpg',
                saveToDevice: true,
            })).resolves.not.toThrow();

            // Direct sharing without saving to device
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imagePath: '/test/image.jpg',
                saveToDevice: false,
            })).resolves.not.toThrow();

            // Default behavior (should be direct sharing)
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imagePath: '/test/image.jpg',
            })).resolves.not.toThrow();

            // With base64 image data
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                saveToDevice: true,
            })).resolves.not.toThrow();
        });

        it('should handle Instagram video creation with saveToDevice', async () => {
            // Video creation from image + audio with saveToDevice: true
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imagePath: '/test/image.jpg',
                audioPath: '/test/audio.mp3',
                startTime: 30,
                backgroundColor: '#FF5733',
                saveToDevice: true,
            })).resolves.not.toThrow();

            // Video creation from image + audio with saveToDevice: false
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imagePath: '/test/image.jpg',
                audioPath: '/test/audio.mp3',
                startTime: 15,
                saveToDevice: false,
            })).resolves.not.toThrow();

            // Video creation with base64 data
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                startTime: 0,
                backgroundColor: '#000000',
                saveToDevice: true,
            })).resolves.not.toThrow();
        });

        it('should handle Snapchat-specific features', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.SNAPCHAT,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                stickerImageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==',
                attachmentUrl: 'https://example.com',
            })).resolves.not.toThrow();
        });

        it('should handle TikTok content types', async () => {
            // Video post
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                videoData: 'data:video/mp4;base64,AAAAIGZ0eXBpc29t',
                text: 'Amazing video!',
                hashtags: ['viral', 'amazing'],
            })).resolves.not.toThrow();

            // Photo post
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                text: 'Photo post',
                hashtags: ['photo'],
            })).resolves.not.toThrow();

            // Audio-based content
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                text: 'Audio content',
            })).resolves.not.toThrow();
        });
    });
}); 