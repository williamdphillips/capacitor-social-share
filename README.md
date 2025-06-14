# Capacitor Social Share Plugin

A comprehensive Capacitor plugin for sharing content across all major social media platforms with enhanced features including automatic video creation, native app integration, and web fallbacks.

## Supported Platforms

### 📱 **Mobile Apps (iOS & Android)**
- ✅ **Native Share Sheet** (System default sharing)
- ✅ **Instagram** (Stories, Posts, Native Picker)
- ✅ **Facebook** (Posts, Stories)
- ✅ **X/Twitter** (Posts with media)
- ✅ **TikTok** (Video & Image posts)
- ✅ **WhatsApp** (Messages with media)
- ✅ **LinkedIn** (Professional posts)
- ✅ **Snapchat** (Snaps with media)
- ✅ **Telegram** (Messages with media)
- ✅ **Reddit** (Text & Link posts)

### 🌐 **Web Support**
- ✅ **Native Share** (Web Share API)
- ✅ **Facebook** (Web sharer)
- ✅ **X/Twitter** (Web intents)
- ✅ **WhatsApp** (Web app)
- ✅ **LinkedIn** (Web sharer)
- ✅ **Telegram** (Web app)
- ✅ **Reddit** (Web submit)
- ✅ **TikTok** (Guidance + clipboard)
- ✅ **Instagram** (Web posts + guidance)
- ⚠️ **Snapchat** (Mobile app required)

## Features

- 🔄 **Native Sharing** - Use system's native share sheet
- 🎥 **Automatic Video Creation** - Creates videos from images and audio
- 📱 **Native App Integration** - Direct sharing to mobile apps
- 🌐 **Web Fallbacks** - Comprehensive web support
- 💾 **Save to Device** - Automatically save content before sharing
- 🎯 **Platform-Specific Features** - Optimized for each platform
- 📋 **Rich Media Support** - Images, videos, text, and links
- 🔧 **Binary Data Support** - Use file paths or base64 data
- 🌍 **Cross-Platform** - Works seamlessly across iOS, Android, and Web

## Installation

```bash
npm install @sounds/capacitor-social-share
npx cap sync
```

## Configuration

### iOS Setup

Add permissions and URL schemes to `ios/App/App/Info.plist`:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs access to photo library to save shared content</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to save shared content</string>

<!-- URL Schemes for social media apps -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>instagram</string>
    <string>instagram-stories</string>
    <string>fb</string>
    <string>twitter</string>
    <string>tiktok</string>
    <string>whatsapp</string>
    <string>linkedin</string>
    <string>snapchat</string>
    <string>tg</string>
</array>
```

Add Instagram App ID to `capacitor.config.ts`:

```typescript
export default {
  plugins: {
    SocialShare: {
      appId: "YOUR_INSTAGRAM_APP_ID"
    }
  }
}
```

### Android Setup

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## Usage Examples

### Instagram Sharing

```typescript
import { SocialShare, SharePlatform } from '@sounds/capacitor-social-share';

// Instagram Stories with auto video creation (using file paths)
await SocialShare.share({
  platform: SharePlatform.INSTAGRAM_STORIES,
  imagePath: '/path/to/background.jpg',
  audioPath: '/path/to/audio.mp3',
  stickerImage: '/path/to/sticker.png',
  contentURL: 'https://yourapp.com',
  startTime: 30,
  saveToDevice: true
});

// Instagram Stories with auto video creation (using base64 data)
await SocialShare.share({
  platform: SharePlatform.INSTAGRAM_STORIES,
  imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...',
  audioData: 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAP...',
  stickerImageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...',
  contentURL: 'https://yourapp.com',
  saveToDevice: true
});

// Share to Instagram with native picker (opens Story/Reels/Messages/Feed options)
await SocialShare.share({
  platform: SharePlatform.INSTAGRAM,
  imagePath: '/path/to/image.jpg',
  text: 'Check this out!'
});

// Save content to device first, then open Instagram (recommended for best UX)
await SocialShare.share({
  platform: SharePlatform.INSTAGRAM,
  imagePath: '/path/to/image.jpg',
  saveToDevice: true  // Saves to Photos/Gallery first, then opens Instagram
});

// Share to Instagram Stories specifically
await SocialShare.share({
  platform: SharePlatform.INSTAGRAM_STORIES,
  imagePath: '/path/to/background.jpg',
  stickerImage: '/path/to/sticker.png',
  contentURL: 'https://myapp.com'
});
```

#### 💡 **saveToDevice Option**

When `saveToDevice: true`:
- **iOS**: Content is saved to Photos library, then Instagram opens for user to select from camera roll
- **Android**: Content is saved to Gallery, then Instagram opens for user to select from gallery
- **Benefit**: Instagram can access the latest content from device storage, ensuring reliable sharing

When `saveToDevice: false` (default):
- Content is shared directly via temporary files and deep links
- Faster but may not work consistently across all Instagram versions

### Facebook Sharing

```typescript
// Facebook post with image (file path)
await SocialShare.share({
  platform: SharePlatform.FACEBOOK,
  title: 'Amazing Discovery!',
  text: 'Check out this incredible finding...',
  url: 'https://yourwebsite.com',
  imagePath: '/path/to/image.jpg',
  hashtag: '#innovation'
});

// Facebook post with image (base64 data)
await SocialShare.share({
  platform: SharePlatform.FACEBOOK,
  title: 'Amazing Discovery!',
  text: 'Check out this incredible finding...',
  url: 'https://yourwebsite.com',
  imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...',
  hashtag: '#innovation'
});

// Facebook text post
await SocialShare.share({
  platform: SharePlatform.FACEBOOK,
  text: 'Sharing some thoughts...',
  url: 'https://yourwebsite.com'
});
```

### X/Twitter Sharing

```typescript
// Tweet with image and hashtags
await SocialShare.share({
  platform: SharePlatform.TWITTER,
  text: 'Excited to share this update!',
  url: 'https://yourwebsite.com',
  imagePath: '/path/to/image.jpg',
  hashtags: ['tech', 'innovation', 'startup'],
  via: 'yourusername'
});

// Simple tweet
await SocialShare.share({
  platform: SharePlatform.TWITTER,
  text: 'Hello Twitter! 👋',
  hashtags: ['firsttweet']
});
```

### TikTok Sharing

```typescript
// TikTok video post
await SocialShare.share({
  platform: SharePlatform.TIKTOK,
  videoPath: '/path/to/video.mp4',
  text: 'Check out this amazing video!',
  hashtags: ['viral', 'amazing', 'trending']
});

// TikTok image post
await SocialShare.share({
  platform: SharePlatform.TIKTOK,
  imagePath: '/path/to/image.jpg',
  text: 'Beautiful photo to share',
  hashtags: ['photography', 'art']
});
```

### WhatsApp Sharing

```typescript
// WhatsApp message with image
await SocialShare.share({
  platform: SharePlatform.WHATSAPP,
  text: 'Hey! Check this out:',
  url: 'https://yourwebsite.com',
  imagePath: '/path/to/image.jpg'
});

// WhatsApp to specific contact
await SocialShare.share({
  platform: SharePlatform.WHATSAPP,
  text: 'Hi there! 👋',
  phoneNumber: '+1234567890'
});
```

### LinkedIn Sharing

```typescript
// LinkedIn professional post
await SocialShare.share({
  platform: SharePlatform.LINKEDIN,
  title: 'Industry Insights',
  text: 'Here are my thoughts on the latest industry trends...',
  url: 'https://yourblog.com/post',
  imagePath: '/path/to/professional-image.jpg'
});
```

### Snapchat Sharing

```typescript
// Snapchat snap with image
await SocialShare.share({
  platform: SharePlatform.SNAPCHAT,
  imagePath: '/path/to/image.jpg',
  attachmentUrl: 'https://yourwebsite.com'
});

// Snapchat video snap
await SocialShare.share({
  platform: SharePlatform.SNAPCHAT,
  videoPath: '/path/to/video.mp4',
  stickerImage: '/path/to/sticker.png'
});
```

### Telegram Sharing

```typescript
// Telegram message with image
await SocialShare.share({
  platform: SharePlatform.TELEGRAM,
  text: 'Sharing via Telegram! 🚀',
  url: 'https://yourwebsite.com',
  imagePath: '/path/to/image.jpg'
});
```

### Reddit Sharing

```typescript
// Reddit post to specific subreddit
await SocialShare.share({
  platform: SharePlatform.REDDIT,
  title: 'Interesting Discussion Topic',
  text: 'What do you think about this trend?',
  url: 'https://source-article.com',
  subreddit: 'technology'
});

// General Reddit post
await SocialShare.share({
  platform: SharePlatform.REDDIT,
  title: 'Check this out!',
  url: 'https://cool-website.com'
});
```

### Native System Sharing

```typescript
// Share text and URL using system's native share sheet
await SocialShare.share({
  platform: SharePlatform.NATIVE,
  title: 'Check this out!',
  text: 'I found something amazing...',
  url: 'https://example.com'
});

// Share image using native share sheet
await SocialShare.share({
  platform: SharePlatform.NATIVE,
  title: 'Beautiful Photo',
  imagePath: '/path/to/image.jpg', // or use imageData: 'base64string'
  text: 'Look at this amazing photo!'
});

// Share multiple files (iOS/Android only)
await SocialShare.share({
  platform: SharePlatform.NATIVE,
  text: 'Here are some files to review',
  files: [
    '/path/to/document.pdf',
    '/path/to/image.jpg',
    '/path/to/presentation.pptx'
  ]
});

// Share video with title
await SocialShare.share({
  platform: SharePlatform.NATIVE,
  title: 'Amazing Video',
  videoPath: '/path/to/video.mp4', // or use videoData: 'base64string'
  text: 'Watch this incredible video!'
});
```

The native sharing option provides several advantages:
- Uses the system's built-in share sheet
- Supports all installed apps on the device
- Handles multiple file types
- Falls back to Web Share API on web platforms
- Provides clipboard fallback when sharing is not available

On web platforms, the plugin will:
1. Try to use the Web Share API if available
2. Fall back to clipboard + alert if Web Share API is not available
3. Show guidance message if neither option is available

Note: File sharing support depends on the platform:
- iOS/Android: Supports all file types through the native share sheet
- Web: File sharing support varies by browser (uses Web Share API Level 2)

## API Reference

### Share Platforms
```typescript
enum SharePlatform {
    NATIVE = 'native',     // System's native share sheet
    INSTAGRAM_STORIES = 'instagram-stories',
    INSTAGRAM = 'instagram',     // Instagram with native picker (Story/Reels/Messages/Feed)
    FACEBOOK = 'facebook',
    TWITTER = 'twitter',
    TIKTOK = 'tiktok',
    WHATSAPP = 'whatsapp',
    LINKEDIN = 'linkedin',
    SNAPCHAT = 'snapchat',
    TELEGRAM = 'telegram',
    REDDIT = 'reddit'
}
```

### Share Options

#### Native Share Options
```typescript
interface NativeShareOptions {
    platform: SharePlatform.NATIVE;
    title?: string;        // Share sheet title
    text?: string;        // Text content
    url?: string;         // URL to share
    imagePath?: string;   // Image file path
    imageData?: string;   // Base64 image data
    videoPath?: string;   // Video file path
    videoData?: string;   // Base64 video data
    files?: string[];     // Array of file paths (iOS/Android)
}
```

#### Instagram Options
```typescript
interface InstagramShareOptions {
    platform: SharePlatform.INSTAGRAM_STORIES | SharePlatform.INSTAGRAM;
    text?: string; // Optional: Caption text for the post
    imagePath?: string; // Optional: Background image file path
    imageData?: string; // Optional: Background image as base64 string (alternative to imagePath)
    audioPath?: string; // Optional: Audio file path - if provided with imagePath/imageData, creates a video
    audioData?: string; // Optional: Audio as base64 string (alternative to audioPath)
    contentURL?: string; // Optional: Link to add to the story
    linkURL?: string // Optional: Link to add to the story with a clickable button
    stickerImage?: string; // Optional: File URI for a sticker
    stickerImageData?: string; // Optional: Sticker image as base64 string (alternative to stickerImage)
    backgroundColor?: string; // Optional: Background color (used if no imagePath/imageData provided)
    startTime?: number; // Optional: Start time in seconds for the audio (defaults to 0)
    saveToDevice?: boolean; // Optional: Save created content to device before sharing (default: false)
}
```

#### Facebook Options
```typescript
interface FacebookShareOptions {
  platform: SharePlatform.FACEBOOK;
  title?: string;           // Post title
  text?: string;           // Post content
  url?: string;            // Link to share
  imagePath?: string;      // Image attachment
  videoPath?: string;      // Video attachment
  hashtag?: string;        // Hashtag (e.g., "#tech")
}
```

#### Twitter Options
```typescript
interface TwitterShareOptions {
  platform: SharePlatform.TWITTER;
  text?: string;           // Tweet text (280 chars)
  url?: string;            // Link to include
  imagePath?: string;      // Image attachment
  videoPath?: string;      // Video attachment
  hashtags?: string[];     // Array of hashtags
  via?: string;           // Attribution username
}
```

#### TikTok Options
```typescript
interface TikTokShareOptions {
  platform: SharePlatform.TIKTOK;
  videoPath?: string;      // Video file
  imagePath?: string;      // Image file
  audioPath?: string;      // Audio file
  text?: string;          // Caption
  hashtags?: string[];    // Hashtags array
}
```

#### WhatsApp Options
```typescript
interface WhatsAppShareOptions {
  platform: SharePlatform.WHATSAPP;
  text?: string;          // Message text
  imagePath?: string;     // Image attachment
  videoPath?: string;     // Video attachment
  url?: string;          // Link to share
  phoneNumber?: string;   // Specific contact
}
```

#### LinkedIn Options
```typescript
interface LinkedInShareOptions {
  platform: SharePlatform.LINKEDIN;
  title?: string;         // Post title
  text?: string;         // Post content
  url?: string;          // Link to share
  imagePath?: string;    // Image attachment
}
```

#### Other Platform Options
```typescript
interface SnapchatShareOptions {
  platform: SharePlatform.SNAPCHAT;
  imagePath?: string;
  videoPath?: string;
  stickerImage?: string;
  attachmentUrl?: string;
}

interface TelegramShareOptions {
  platform: SharePlatform.TELEGRAM;
  text?: string;
  url?: string;
  imagePath?: string;
  videoPath?: string;
}

interface RedditShareOptions {
  platform: SharePlatform.REDDIT;
  title?: string;
  text?: string;
  url?: string;
  subreddit?: string;
}
```

## Platform Support Matrix

| Feature | iOS | Android | Web |
|---------|-----|---------|-----|
| **Native Share** |
| Text/URL | ✅ | ✅ | ✅ |
| Images | ✅ | ✅ | ⚠️* |
| Videos | ✅ | ✅ | ⚠️* |
| Multiple Files | ✅ | ✅ | ⚠️* |
| **Instagram** |
| Stories | ✅ | ✅ | ⚠️* |
| Posts | ✅ | ✅ | ✅ |
| Video Creation | ✅ | ❌ | ❌ |
| Native Picker | ✅ | ✅ | ❌ |
| **Facebook** |
| Posts | ✅ | ✅ | ✅ |
| Images | ✅ | ✅ | ❌ |
| **X/Twitter** |
| Posts | ✅ | ✅ | ✅ |
| Images | ✅ | ✅ | ❌ |
| Hashtags | ✅ | ✅ | ✅ |
| **TikTok** |
| Videos | ✅ | ✅ | ⚠️* |
| Images | ✅ | ✅ | ⚠️* |
| **WhatsApp** |
| Messages | ✅ | ✅ | ✅ |
| Images | ✅ | ✅ | ❌ |
| Specific Contact | ✅ | ✅ | ✅ |
| **LinkedIn** |
| Posts | ✅ | ✅ | ✅ |
| Images | ✅ | ✅ | ❌ |
| **Snapchat** |
| Snaps | ✅ | ✅ | ❌ |
| **Telegram** |
| Messages | ✅ | ✅ | ✅ |
| Images | ✅ | ✅ | ❌ |
| **Reddit** |
| Posts | ✅ | ✅ | ✅ |

*⚠️ Web provides guidance and clipboard support. Instagram Stories require mobile app for full features.

## How It Works

### Automatic Video Creation (iOS)
When you provide both `imagePath` and `audioPath`:
1. Plugin creates a 15-second video (Instagram Stories format)
2. Uses your image as background (1080x1920 resolution)
3. Syncs with your audio track
4. Saves to device photo library
5. Shares to platform

### Native App Integration
1. **First**: Tries to open specific app (e.g., Instagram, Twitter)
2. **Fallback**: Uses system share sheet
3. **Web**: Opens platform-specific share URLs

### Web Fallbacks
- **Native Web APIs**: Uses `navigator.share()` when available
- **Platform URLs**: Direct links to platform share pages
- **Clipboard**: Copies content for manual sharing (TikTok)

## Best Practices

### Content Optimization
- **Images**: Use 1080x1080 for posts, 1080x1920 for stories
- **Videos**: Keep under 15 seconds for stories
- **Text**: Respect platform character limits (Twitter: 280)

### File Handling
- **File Paths**: Use when you have local files accessible by the app
- **Base64 Data**: Use when working with dynamically generated content, web environments, or when file paths aren't accessible
- **Format**: Base64 strings can include data URL prefix (`data:image/jpeg;base64,`) or be raw base64
- **Size**: Be mindful of memory usage with large base64 strings

### Error Handling
```typescript
try {
  await SocialShare.share({
    platform: SharePlatform.TWITTER,
    text: 'Hello World!'
  });
  console.log('Shared successfully!');
} catch (error) {
  console.error('Share failed:', error);
}
```

### Platform Detection
```typescript
import { Capacitor } from '@capacitor/core';

const isNative = Capacitor.isNativePlatform();
const platform = Capacitor.getPlatform(); // 'ios', 'android', or 'web'

if (isNative) {
  // Use full native features
} else {
  // Use web fallbacks
}
```

## Troubleshooting

### Common Issues

**Instagram video closes instantly**
- Ensure `saveToDevice: true` (default)
- Check file paths are accessible
- Verify photo library permissions

**App not opening**
- Confirm app is installed on device
- Check platform-specific bundle IDs
- Verify URL scheme permissions

**Web sharing not working**
- Check browser support for `navigator.share()`
- Ensure HTTPS for secure contexts
- Test fallback URLs manually

### Platform-Specific Notes

**iOS**
- Requires photo library permissions for video creation
- Instagram App ID needed for Stories
- Some apps may require URL scheme allowlisting

**Android**
- Storage permissions needed for media saving
- Package names must match installed apps
- FileProvider may be required for newer Android versions

**Web**
- Limited to platform web APIs
- No media attachment support on most platforms
- Popup blockers may interfere with sharing windows

## License

MIT

---

## Contributing

Found a bug or want to add a platform? PRs welcome!

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## Support

- 📖 [Documentation](https://github.com/your-repo/capacitor-social-share)
- 🐛 [Report Issues](https://github.com/your-repo/capacitor-social-share/issues)
- 💬 [Discussions](https://github.com/your-repo/capacitor-social-share/discussions)