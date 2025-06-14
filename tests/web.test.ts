import { SocialShareWeb } from '../src/web';
import { SharePlatform, InstagramShareOptions } from '../src/definitions';

describe('SocialShareWeb', () => {
    let socialShareWeb: SocialShareWeb;
    let mockFetch: jest.MockedFunction<typeof fetch>;
    let mockNavigatorShare: jest.MockedFunction<typeof navigator.share>;
    let mockNavigatorClipboard: jest.MockedFunction<typeof navigator.clipboard.writeText>;
    let mockWindowOpen: jest.MockedFunction<typeof window.open>;
    let mockAlert: jest.MockedFunction<typeof alert>;

    beforeEach(() => {
        socialShareWeb = new SocialShareWeb();

        // Set up properly typed mocks
        mockFetch = global.fetch as jest.MockedFunction<typeof fetch>;
        mockNavigatorClipboard = global.navigator.clipboard.writeText as jest.MockedFunction<typeof navigator.clipboard.writeText>;
        mockWindowOpen = global.window.open as jest.MockedFunction<typeof window.open>;
        mockAlert = global.alert as jest.MockedFunction<typeof alert>;

        // Properly mock navigator.share with jest functions
        mockNavigatorShare = jest.fn();
        (global.navigator as any).share = mockNavigatorShare;

        // Reset all mocks
        jest.clearAllMocks();
    });

    describe('Helper Functions', () => {
        describe('base64ToFile', () => {
            it('should convert base64 data to File object', () => {
                const base64Data = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
                const file = (socialShareWeb as any).base64ToFile(base64Data, 'test.jpg', 'image/jpeg');

                expect(file).toBeInstanceOf(File);
                expect(file.name).toBe('test.jpg');
                expect(file.type).toBe('image/jpeg');
            });

            it('should handle base64 without data URL prefix', () => {
                const base64Data = '/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
                const file = (socialShareWeb as any).base64ToFile(base64Data, 'test.jpg', 'image/jpeg');

                expect(file).toBeInstanceOf(File);
                expect(file.name).toBe('test.jpg');
            });
        });

        describe('getFileForSharing', () => {
            it('should return File from base64 data when provided', async () => {
                const base64Data = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
                const file = await (socialShareWeb as any).getFileForSharing(null, base64Data, 'image.jpg', 'image/jpeg');

                expect(file).toBeInstanceOf(File);
                expect(file.name).toBe('image.jpg');
            });

            it('should fetch file from path when provided', async () => {
                const mockBlob = new Blob(['test'], { type: 'image/jpeg' });
                mockFetch.mockResolvedValueOnce({
                    blob: () => Promise.resolve(mockBlob),
                } as Response);

                const file = await (socialShareWeb as any).getFileForSharing('/path/to/image.jpg', null, 'image.jpg', 'image/jpeg');

                expect(mockFetch).toHaveBeenCalledWith('/path/to/image.jpg');
                expect(file).toBeInstanceOf(File);
            });

            it('should return null when no data provided', async () => {
                const file = await (socialShareWeb as any).getFileForSharing(null, null, 'image.jpg', 'image/jpeg');
                expect(file).toBeNull();
            });

            it('should handle fetch errors gracefully', async () => {
                mockFetch.mockRejectedValueOnce(new Error('Network error'));
                const file = await (socialShareWeb as any).getFileForSharing('/path/to/image.jpg', null, 'image.jpg', 'image/jpeg');
                expect(file).toBeNull();
            });
        });

        describe('tryNativeShare', () => {
            it('should use native share API when available', async () => {
                mockNavigatorShare.mockResolvedValueOnce(undefined);
                const result = await (socialShareWeb as any).tryNativeShare('Title', 'Text', 'https://example.com');

                expect(mockNavigatorShare).toHaveBeenCalledWith({
                    title: 'Title',
                    text: 'Text',
                    url: 'https://example.com',
                });
                expect(result).toBe(true);
            });

            it('should return false when navigator.share is not available', async () => {
                (global.navigator as any).share = undefined;
                const result = await (socialShareWeb as any).tryNativeShare('Title', 'Text', 'https://example.com');
                expect(result).toBe(false);
            });

            it('should handle share errors gracefully', async () => {
                mockNavigatorShare.mockRejectedValueOnce(new Error('User cancelled'));
                const result = await (socialShareWeb as any).tryNativeShare('Title', 'Text', 'https://example.com');
                expect(result).toBe(false);
            });

            it('should include files when supported', async () => {
                const mockFile = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
                (global.navigator as any).canShare = jest.fn().mockReturnValue(true);
                mockNavigatorShare.mockResolvedValueOnce(undefined);

                const result = await (socialShareWeb as any).tryNativeShare('Title', 'Text', 'https://example.com', mockFile);

                expect(mockNavigatorShare).toHaveBeenCalledWith({
                    title: 'Title',
                    text: 'Text',
                    url: 'https://example.com',
                    files: [mockFile],
                });
                expect(result).toBe(true);
            });
        });
    });

    describe('Instagram Sharing', () => {
        it('should handle Instagram Stories sharing with guidance', async () => {
            mockNavigatorClipboard.mockResolvedValueOnce();
            mockWindowOpen.mockReturnValueOnce(null);

            await socialShareWeb.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                contentURL: 'https://example.com',
            });

            expect(mockNavigatorClipboard).toHaveBeenCalledWith('https://example.com');
            expect(mockAlert).toHaveBeenCalledWith(expect.stringContaining('Instagram Stories sharing is best done through the mobile app'));
            expect(mockWindowOpen).toHaveBeenCalledWith('https://www.instagram.com/', '_blank');
        });

        it('should handle Instagram sharing', async () => {
            const options: InstagramShareOptions = {
                platform: SharePlatform.INSTAGRAM,
                imagePath: '/path/to/image.jpg',
                text: 'Check this out!'
            };

            await socialShareWeb.share(options);
            // Instagram sharing on web shows alert and opens Instagram web
        });

        it('should try native share with image data', async () => {
            const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.INSTAGRAM,
                imageData: base64Image,
            });

            expect(mockNavigatorShare).toHaveBeenCalled();
        });

        it('should handle clipboard errors gracefully', async () => {
            mockNavigatorClipboard.mockRejectedValueOnce(new Error('Clipboard error'));

            await socialShareWeb.share({
                platform: SharePlatform.INSTAGRAM_STORIES,
                contentURL: 'https://example.com',
            });

            expect(mockAlert).toHaveBeenCalledWith(expect.not.stringContaining('copied to clipboard'));
        });
    });

    describe('Facebook Sharing', () => {
        it('should use native share when available', async () => {
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.FACEBOOK,
                title: 'Test Title',
                text: 'Test text',
                url: 'https://example.com',
                hashtag: '#test',
            });

            expect(mockNavigatorShare).toHaveBeenCalledWith({
                title: 'Test Title',
                text: 'Test text #test',
                url: 'https://example.com',
            });
        });

        it('should fallback to Facebook sharer URL', async () => {
            mockNavigatorShare.mockRejectedValueOnce(new Error('Not supported'));

            await socialShareWeb.share({
                platform: SharePlatform.FACEBOOK,
                title: 'Test Title',
                text: 'Test text',
                url: 'https://example.com',
                hashtag: '#test',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                expect.stringContaining('facebook.com/sharer/sharer.php'),
                '_blank',
                'width=600,height=400'
            );
        });

        it('should handle image data', async () => {
            const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.FACEBOOK,
                imageData: base64Image,
                text: 'Post with image',
            });

            expect(mockNavigatorShare).toHaveBeenCalled();
        });
    });

    describe('Twitter Sharing', () => {
        it('should use native share when available', async () => {
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.TWITTER,
                text: 'Hello Twitter!',
                url: 'https://example.com',
                hashtags: ['test', 'tweet'],
                via: 'username',
            });

            expect(mockNavigatorShare).toHaveBeenCalledWith({
                text: 'Hello Twitter! #test #tweet via @username',
                url: 'https://example.com',
            });
        });

        it('should fallback to Twitter web intent', async () => {
            (global.navigator as any).share = undefined;

            await socialShareWeb.share({
                platform: SharePlatform.TWITTER,
                text: 'Hello Twitter!',
                url: 'https://example.com',
                hashtags: ['test'],
                via: 'username',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                expect.stringContaining('twitter.com/intent/tweet'),
                '_blank',
                'width=600,height=400'
            );
        });

        it('should handle image data', async () => {
            const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.TWITTER,
                text: 'Tweet with image',
                imageData: base64Image,
            });

            expect(mockNavigatorShare).toHaveBeenCalled();
        });
    });

    describe('TikTok Sharing', () => {
        it('should provide guidance and copy caption to clipboard', async () => {
            mockNavigatorClipboard.mockResolvedValueOnce();

            await socialShareWeb.share({
                platform: SharePlatform.TIKTOK,
                text: 'TikTok caption',
                hashtags: ['viral', 'trending'],
            });

            expect(mockNavigatorClipboard).toHaveBeenCalledWith('TikTok caption #viral #trending');
            expect(mockAlert).toHaveBeenCalledWith(expect.stringContaining('Caption copied to clipboard!'));
            expect(mockWindowOpen).toHaveBeenCalledWith('https://www.tiktok.com/upload', '_blank');
        });

        it('should try native share with media', async () => {
            const base64Video = 'data:video/mp4;base64,AAAAIGZ0eXBpc29t';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.TIKTOK,
                videoData: base64Video,
                text: 'Video caption',
            });

            expect(mockNavigatorShare).toHaveBeenCalled();
        });
    });

    describe('WhatsApp Sharing', () => {
        it('should open WhatsApp web with message', async () => {
            await socialShareWeb.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Hello WhatsApp!',
                url: 'https://example.com',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                'https://wa.me/?text=Hello%20WhatsApp!%20https%3A%2F%2Fexample.com',
                '_blank'
            );
        });

        it('should open WhatsApp with specific phone number', async () => {
            await socialShareWeb.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Hello!',
                phoneNumber: '+1234567890',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                'https://wa.me/+1234567890?text=Hello!',
                '_blank'
            );
        });

        it('should try native share with image', async () => {
            const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.WHATSAPP,
                text: 'Message with image',
                imageData: base64Image,
            });

            expect(mockNavigatorShare).toHaveBeenCalled();
        });
    });

    describe('LinkedIn Sharing', () => {
        it('should use native share when available', async () => {
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.LINKEDIN,
                title: 'Professional Post',
                text: 'LinkedIn content',
                url: 'https://example.com',
            });

            expect(mockNavigatorShare).toHaveBeenCalledWith({
                title: 'Professional Post',
                text: 'LinkedIn content',
                url: 'https://example.com',
            });
        });

        it('should fallback to LinkedIn share URL', async () => {
            (global.navigator as any).share = undefined;

            await socialShareWeb.share({
                platform: SharePlatform.LINKEDIN,
                title: 'Professional Post',
                text: 'Content',
                url: 'https://example.com',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                expect.stringContaining('linkedin.com/sharing/share-offsite'),
                '_blank',
                'width=600,height=400'
            );
        });
    });

    describe('Snapchat Sharing', () => {
        it('should show mobile app required message', async () => {
            await socialShareWeb.share({
                platform: SharePlatform.SNAPCHAT,
            });

            expect(mockAlert).toHaveBeenCalledWith(
                'Snapchat sharing is only available through the mobile app. Please use the Snapchat mobile app to share content.'
            );
        });

        it('should try native share with media', async () => {
            const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.SNAPCHAT,
                imageData: base64Image,
            });

            expect(mockNavigatorShare).toHaveBeenCalled();
        });
    });

    describe('Native System Sharing', () => {
        beforeEach(() => {
            // Reset mocks for each test
            mockNavigatorShare.mockClear();
            mockNavigatorClipboard.mockClear();
            mockWindowOpen.mockClear();
            mockAlert.mockClear();
        });

        it('should use Web Share API when available', async () => {
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.NATIVE,
                title: 'Test Title',
                text: 'Test message',
                url: 'https://example.com'
            });

            expect(mockNavigatorShare).toHaveBeenCalledWith({
                title: 'Test Title',
                text: 'Test message',
                url: 'https://example.com'
            });
        });

        it('should handle image sharing with Web Share API', async () => {
            // Mock canShare to return true for files
            (global.navigator as any).canShare = jest.fn().mockReturnValue(true);
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.NATIVE,
                title: 'Image Share',
                imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAAAAAAAD'
            });

            expect(mockNavigatorShare).toHaveBeenCalledWith(
                expect.objectContaining({
                    title: 'Image Share',
                    files: expect.any(Array)
                })
            );
        });

        it('should fallback to clipboard when Web Share API is not available', async () => {
            // Mock navigator.share as undefined
            (global.navigator as any).share = undefined;
            mockNavigatorClipboard.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.NATIVE,
                text: 'Test message',
                url: 'https://example.com'
            });

            expect(mockNavigatorClipboard).toHaveBeenCalledWith('Test message https://example.com');
            expect(mockAlert).toHaveBeenCalledWith('Content copied to clipboard. You can now paste it in any app.');
        });

        it('should show alert fallback when clipboard fails', async () => {
            (global.navigator as any).share = undefined;
            mockNavigatorClipboard.mockRejectedValueOnce(new Error('Clipboard failed'));

            await socialShareWeb.share({
                platform: SharePlatform.NATIVE,
                title: 'Test Title',
                text: 'Test message'
            });

            expect(mockAlert).toHaveBeenCalledWith('Share this content:\n\nTest Title Test message');
        });

        it('should handle user cancellation gracefully', async () => {
            mockNavigatorShare.mockRejectedValueOnce(new Error('AbortError'));
            mockNavigatorClipboard.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.NATIVE,
                text: 'Test message'
            });

            // Should fall back to clipboard after user cancellation
            expect(mockNavigatorClipboard).toHaveBeenCalledWith('Test message');
        });

        it('should throw error when no content is provided', async () => {
            await expect(socialShareWeb.share({
                platform: SharePlatform.NATIVE
            })).rejects.toThrow('No content to share');
        });
    });

    describe('Telegram Sharing', () => {
        it('should open Telegram share URL', async () => {
            await socialShareWeb.share({
                platform: SharePlatform.TELEGRAM,
                text: 'Telegram message',
                url: 'https://example.com',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                'https://t.me/share/url?url=https%3A%2F%2Fexample.com&text=Telegram%20message',
                '_blank'
            );
        });

        it('should try native share with image', async () => {
            const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.TELEGRAM,
                text: 'Message with image',
                imageData: base64Image,
            });

            expect(mockNavigatorShare).toHaveBeenCalled();
        });
    });

    describe('Reddit Sharing', () => {
        it('should open Reddit submit URL with title and URL', async () => {
            await socialShareWeb.share({
                platform: SharePlatform.REDDIT,
                title: 'Reddit Post',
                url: 'https://example.com',
                subreddit: 'technology',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                expect.stringContaining('reddit.com/submit'),
                '_blank'
            );
        });

        it('should handle text posts', async () => {
            await socialShareWeb.share({
                platform: SharePlatform.REDDIT,
                title: 'Text Post',
                text: 'Post content',
            });

            expect(mockWindowOpen).toHaveBeenCalledWith(
                expect.stringContaining('selftext=Post%20content'),
                '_blank'
            );
        });
    });

    describe('Error Handling', () => {
        it('should throw error for unsupported platform', async () => {
            await expect(socialShareWeb.share({
                platform: 'unsupported' as any,
            })).rejects.toThrow('Unsupported platform: unsupported');
        });

        it('should handle and rethrow errors', async () => {
            // Test with an unsupported platform to trigger the error in the main share method
            await expect(socialShareWeb.share({
                platform: 'unsupported-platform' as any,
            })).rejects.toThrow('Unsupported platform: unsupported-platform');
        });
    });

    describe('File Handling', () => {
        it('should prioritize base64 data over file path', async () => {
            const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//2Q==';
            mockNavigatorShare.mockResolvedValueOnce(undefined);

            await socialShareWeb.share({
                platform: SharePlatform.FACEBOOK,
                imagePath: '/path/to/image.jpg',
                imageData: base64Image,
            });

            expect(mockFetch).not.toHaveBeenCalled(); // Should use base64, not fetch path
        });

        it('should handle invalid base64 data gracefully', async () => {
            const invalidBase64 = 'invalid-base64-data';

            // Make sure native share is not available so it falls back to window.open
            (global.navigator as any).share = undefined;

            // Ensure window.open works normally for this test
            mockWindowOpen.mockReturnValue(null);

            await socialShareWeb.share({
                platform: SharePlatform.FACEBOOK,
                imageData: invalidBase64,
                text: 'Test post',
            });

            // Should not throw an error, should continue with sharing via fallback URL
            expect(mockWindowOpen).toHaveBeenCalled();
        });
    });
}); 