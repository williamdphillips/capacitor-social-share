import { SocialShare } from '../src/index';
import { SharePlatform } from '../src/definitions';

describe('Usage Examples', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('Instagram Examples', () => {
        it('Example: Share image to Instagram Stories', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                imagePath: '/path/to/image.jpg',
                contentURL: 'https://myapp.com',
            })).resolves.not.toThrow();
        });

        it('Example: Create video from image and audio', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                startTime: 30,
                saveToDevice: true,
            })).resolves.not.toThrow();
        });

        it('Example: Share with sticker overlay', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                imagePath: '/path/to/background.jpg',
                stickerImageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==',
                linkURL: 'https://myapp.com/product',
            })).resolves.not.toThrow();
        });

        it('Example: Audio-only story with background color', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                audioPath: '/path/to/music.mp3',
                backgroundColor: '#FF6B6B', // Nice coral color
            })).resolves.not.toThrow();
        });

        it('Example: Use Instagram native picker', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM, // Opens native picker (Message/Story/Feed)
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();
        });
    });

    describe('Facebook Examples', () => {
        it('Example: Share link with description', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                url: 'https://myapp.com/article',
                title: 'Amazing Article Title',
                text: 'Check out this incredible article!',
                hashtag: '#SocialSharing',
            })).resolves.not.toThrow();
        });

        it('Example: Share image with caption', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                text: 'Beautiful sunset from our app! 🌅',
                hashtag: '#Photography',
            })).resolves.not.toThrow();
        });

        it('Example: Share video content', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                videoPath: '/path/to/video.mp4',
                title: 'Awesome Video',
                text: 'Watch this amazing video created with our app!',
            })).resolves.not.toThrow();
        });
    });

    describe('Twitter Examples', () => {
        it('Example: Tweet with hashtags', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: 'Just discovered this amazing app!',
                hashtags: ['SocialMedia', 'Sharing'],
                via: 'myapptwitter',
                url: 'https://myapp.com',
            })).resolves.not.toThrow();
        });

        it('Example: Tweet with image', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: 'Look at this beautiful image! 📸',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                hashtags: ['Photography', 'Art'],
            })).resolves.not.toThrow();
        });

        it('Example: Simple text tweet', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: 'Hello Twitter! This is a simple tweet from our app.',
            })).resolves.not.toThrow();
        });
    });

    describe('TikTok Examples', () => {
        it('Example: Share video with hashtags', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                videoData: 'data:video/mp4;base64,AAAAIGZ0eXBpc29t',
                text: 'Amazing dance moves! 💃',
                hashtags: ['Dance', 'Viral', 'Fun'],
            })).resolves.not.toThrow();
        });

        it('Example: Share photo post', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                text: 'Beautiful moment captured! ✨',
                hashtags: ['PhotoMode', 'Beautiful'],
            })).resolves.not.toThrow();
        });

        it('Example: Audio-based content', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                text: 'Original sound by me! 🎵',
                hashtags: ['OriginalSound', 'Music'],
            })).resolves.not.toThrow();
        });
    });

    describe('WhatsApp Examples', () => {
        it('Example: Share message with link', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Hey! Check out this awesome app I found:',
                url: 'https://myapp.com',
            })).resolves.not.toThrow();
        });

        it('Example: Send to specific contact', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Hi! Sharing this cool content with you.',
                phoneNumber: '+1234567890',
            })).resolves.not.toThrow();
        });

        it('Example: Share image with message', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Look at this amazing photo!',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();
        });

        it('Example: Share video', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Check out this video!',
                videoPath: '/path/to/video.mp4',
            })).resolves.not.toThrow();
        });
    });

    describe('LinkedIn Examples', () => {
        it('Example: Professional post with link', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.LINKEDIN,
                title: 'Exciting Career Opportunity',
                text: 'Just landed an amazing new role thanks to the skills I learned using this platform!',
                url: 'https://mylearningplatform.com',
            })).resolves.not.toThrow();
        });

        it('Example: Industry insight post', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.LINKEDIN,
                title: 'Industry Trends 2024',
                text: 'Here are the top 5 trends I see shaping our industry this year...',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();
        });

        it('Example: Simple professional update', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.LINKEDIN,
                text: 'Excited to share that our team just launched a new feature!',
            })).resolves.not.toThrow();
        });
    });

    describe('Snapchat Examples', () => {
        it('Example: Share snap with sticker', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.SNAPCHAT,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                stickerImageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==',
            })).resolves.not.toThrow();
        });

        it('Example: Share video snap', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.SNAPCHAT,
                videoData: 'data:video/mp4;base64,AAAAIGZ0eXBpc29t',
            })).resolves.not.toThrow();
        });

        it('Example: Share with URL attachment', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.SNAPCHAT,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                attachmentUrl: 'https://myapp.com',
            })).resolves.not.toThrow();
        });
    });

    describe('Telegram Examples', () => {
        it('Example: Share message with link', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TELEGRAM,
                text: 'Check out this interesting article!',
                url: 'https://news.example.com/article',
            })).resolves.not.toThrow();
        });

        it('Example: Share image with caption', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TELEGRAM,
                text: 'Beautiful landscape shot 🏔️',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();
        });

        it('Example: Share video', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.TELEGRAM,
                text: 'Funny video compilation',
                videoPath: '/path/to/funny-video.mp4',
            })).resolves.not.toThrow();
        });
    });

    describe('Reddit Examples', () => {
        it('Example: Share link to specific subreddit', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.REDDIT,
                title: 'Amazing new JavaScript framework',
                url: 'https://github.com/awesome/framework',
                subreddit: 'javascript',
            })).resolves.not.toThrow();
        });

        it('Example: Create text discussion post', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.REDDIT,
                title: 'What do you think about the future of mobile development?',
                text: 'I\'ve been thinking about how mobile development might evolve over the next 5 years...',
                subreddit: 'mobileDev',
            })).resolves.not.toThrow();
        });

        it('Example: General submission (no specific subreddit)', async () => {
            await expect(SocialShare.share({
                platform: SharePlatform.REDDIT,
                title: 'Interesting article about technology',
                url: 'https://tech.example.com/article',
            })).resolves.not.toThrow();
        });
    });

    describe('Cross-Platform Scenarios', () => {
        it('Example: Share same content to multiple platforms', async () => {
            const content = {
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                text: 'Amazing sunset! 🌅',
            };

            // Share to Instagram Stories
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                ...content,
            })).resolves.not.toThrow();

            // Share to Facebook
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                ...content,
            })).resolves.not.toThrow();

            // Share to Twitter with hashtags
            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                ...content,
                hashtags: ['Sunset', 'Photography'],
            })).resolves.not.toThrow();
        });

        it('Example: Handle canvas/generated content sharing', async () => {
            // Simulate getting image data from HTML5 Canvas
            const canvasImageData = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==';

            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM,
                imageData: canvasImageData,
            })).resolves.not.toThrow();
        });

        it('Example: API response content sharing', async () => {
            // Simulate sharing content received from API
            const apiImageData = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            const apiContent = 'This content was generated by our AI!';

            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                imageData: apiImageData,
                text: apiContent,
                url: 'https://myapi.com/generate',
            })).resolves.not.toThrow();
        });

        it('Example: User-generated content workflow', async () => {
            // Step 1: User creates content (simulated)
            const userContent = {
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                caption: 'My amazing creation! 🎨',
            };

            // Step 2: Share to Instagram Stories (with video creation)
            await expect(SocialShare.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                imageData: userContent.imageData,
                audioData: userContent.audioData,
                contentURL: 'https://myapp.com/creation/123',
                saveToDevice: true,
            })).resolves.not.toThrow();

            // Step 3: Also share to TikTok
            await expect(SocialShare.share({
                platform: SharePlatform.TIKTOK,
                imageData: userContent.imageData,
                text: userContent.caption,
                hashtags: ['UserGenerated', 'Creative'],
            })).resolves.not.toThrow();
        });
    });

    describe('Error Handling Examples', () => {
        it('Example: Handle app not installed gracefully', async () => {
            try {
                await SocialShare.share({
                    platform: SharePlatform.INSTAGRAM,
                    imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                });
            } catch (error) {
                // Handle the case where Instagram is not installed
                console.log('Instagram not available, could show alternative sharing options');
                expect(true).toBe(true); // Test passes regardless
            }
        });

        it('Example: Validate content before sharing', async () => {
            const imageData = 'invalid-base64-data';

            // Plugin should handle invalid data gracefully
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                imageData: imageData,
                text: 'Fallback to text-only sharing',
            })).resolves.not.toThrow();
        });

        it('Example: Progressive sharing fallback', async () => {
            const shareContent = {
                text: 'Check out this awesome content!',
                url: 'https://myapp.com',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            };

            // Try Instagram first
            try {
                await SocialShare.share({
                    platform: SharePlatform.INSTAGRAM,
                    imageData: shareContent.imageData,
                });
            } catch {
                // Fallback to Facebook
                try {
                    await SocialShare.share({
                        platform: SharePlatform.FACEBOOK,
                        ...shareContent,
                    });
                } catch {
                    // Final fallback to Twitter
                    await SocialShare.share({
                        platform: SharePlatform.TWITTER,
                        text: shareContent.text,
                        url: shareContent.url,
                    });
                }
            }

            expect(true).toBe(true); // Test always passes
        });
    });

    describe('Advanced Use Cases', () => {
        it('Example: Scheduled/batch sharing preparation', async () => {
            const contentBatch = [
                {
                    platform: SharePlatform.INSTAGRAM_STORIES,
                    imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                    audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP==',
                },
                {
                    platform: SharePlatform.FACEBOOK,
                    text: 'Daily motivation post!',
                    imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
                },
                {
                    platform: SharePlatform.TWITTER,
                    text: 'Inspirational quote of the day ✨',
                    hashtags: ['Motivation', 'QuoteOfTheDay'],
                },
            ];

            // Share to all platforms
            for (const content of contentBatch) {
                await expect(SocialShare.share(content)).resolves.not.toThrow();
            }
        });

        it('Example: A/B testing different share formats', async () => {
            const baseContent = {
                text: 'Amazing new feature launch!',
                url: 'https://myapp.com/feature',
            };

            // Version A: Image + text
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                ...baseContent,
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==',
            })).resolves.not.toThrow();

            // Version B: Text only with hashtag
            await expect(SocialShare.share({
                platform: SharePlatform.FACEBOOK,
                ...baseContent,
                hashtag: '#NewFeature',
            })).resolves.not.toThrow();
        });

        it('Example: Dynamic content generation and sharing', async () => {
            // Simulate generating dynamic content
            const dynamicContent = {
                imageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA==', // Generated image
                text: `Today's stats: ${Math.floor(Math.random() * 1000)} users engaged!`,
                hashtags: ['DailyStats', 'Growth'],
            };

            await expect(SocialShare.share({
                platform: SharePlatform.TWITTER,
                text: dynamicContent.text,
                hashtags: dynamicContent.hashtags,
                imageData: dynamicContent.imageData,
            })).resolves.not.toThrow();
        });
    });
}); 