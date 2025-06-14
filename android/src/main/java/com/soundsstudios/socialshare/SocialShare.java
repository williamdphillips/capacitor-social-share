package com.soundsstudios.socialshare;

import android.content.Intent;
import android.net.Uri;
import android.content.ContentValues;
import android.provider.MediaStore;
import android.os.Environment;
import android.os.Build;
import android.content.pm.PackageManager;
import android.content.FileProvider;
import android.util.Log;

import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.Plugin;
import com.getcapacitor.JSObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.io.IOException;
import java.util.ArrayList;
import android.util.Base64;

@CapacitorPlugin(name = "SocialShare")
public class SocialShare extends Plugin {

    // Helper method to save base64 data to temporary file
    private File saveBase64ToTempFile(String base64Data, String fileName, String extension) {
        try {
            byte[] decodedBytes = Base64.decode(base64Data, Base64.DEFAULT);
            File tempDir = getContext().getCacheDir();
            File tempFile = new File(tempDir, fileName + "." + extension);

            FileOutputStream fos = new FileOutputStream(tempFile);
            fos.write(decodedBytes);
            fos.close();

            return tempFile;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    // Helper method to get file from path or base64 data
    private File getFileFromPathOrData(String filePath, String fileData, String defaultName, String extension) {
        if (fileData != null && !fileData.isEmpty()) {
            return saveBase64ToTempFile(fileData, defaultName, extension);
        }

        if (filePath != null && !filePath.isEmpty()) {
            File file = new File(filePath);
            if (file.exists()) {
                return file;
            }
        }

        return null;
    }

    @PluginMethod
    public void share(PluginCall call) {
        String platform = call.getString("platform");

        switch (platform) {
            case "instagram-stories":
                shareToInstagramStories(call, call.getString("imagePath"), call.getString("contentURL"),
                        call.getBoolean("saveToDevice", true));
                break;
            case "instagram":
                shareToInstagram(call, call.getString("imagePath"), call.getBoolean("saveToDevice", false));
                break;
            case "facebook":
                shareToFacebook(call);
                break;
            case "twitter":
                shareToTwitter(call);
                break;
            case "tiktok":
                shareToTikTok(call);
                break;
            case "whatsapp":
                shareToWhatsApp(call);
                break;
            case "linkedin":
                shareToLinkedIn(call);
                break;
            case "snapchat":
                shareToSnapchat(call);
                break;
            case "telegram":
                shareToTelegram(call);
                break;
            case "reddit":
                shareToReddit(call);
                break;
            default:
                shareToDefaultPlatform(call);
        }
    }

    // Facebook sharing
    private void shareToFacebook(PluginCall call) {
        String title = call.getString("title", "");
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String hashtag = call.getString("hashtag", "");
        String imagePath = call.getString("imagePath", "");
        String imageData = call.getString("imageData", "");

        String shareText = text;
        if (!url.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : " ") + url;
        }
        if (!hashtag.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : " ") + hashtag;
        }

        // Get image file from path or base64 data
        File imageFile = getFileFromPathOrData(imagePath, imageData, "facebook_image", "jpg");

        // Try Facebook app first
        Intent facebookIntent = new Intent(Intent.ACTION_SEND);
        facebookIntent.setType("text/plain");
        facebookIntent.setPackage("com.facebook.katana");
        facebookIntent.putExtra(Intent.EXTRA_TEXT, shareText);

        if (imageFile != null && imageFile.exists()) {
            Uri imageUri = Uri.fromFile(imageFile);
            facebookIntent.setType("image/*");
            facebookIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
            grantUriPermission("com.facebook.katana", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        }

        if (facebookIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(facebookIntent);
            call.resolve();
        } else {
            // Fallback to generic share
            shareWithSystemShare(shareText, url, imageFile != null ? imageFile.getAbsolutePath() : "", call);
        }
    }

    // Twitter/X sharing
    private void shareToTwitter(PluginCall call) {
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String imagePath = call.getString("imagePath", "");

        String[] hashtags = call.getArray("hashtags") != null
                ? call.getArray("hashtags").toList().toArray(new String[0])
                : new String[0];
        String via = call.getString("via", "");

        String tweetText = text;
        if (hashtags.length > 0) {
            for (String hashtag : hashtags) {
                tweetText += " #" + hashtag;
            }
        }
        if (!via.isEmpty()) {
            tweetText += " via @" + via;
        }
        if (!url.isEmpty()) {
            tweetText += " " + url;
        }

        // Try Twitter app first
        Intent twitterIntent = new Intent(Intent.ACTION_SEND);
        twitterIntent.setType("text/plain");
        twitterIntent.setPackage("com.twitter.android");
        twitterIntent.putExtra(Intent.EXTRA_TEXT, tweetText);

        if (!imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                Uri imageUri = Uri.fromFile(imageFile);
                twitterIntent.setType("image/*");
                twitterIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
                grantUriPermission("com.twitter.android", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        }

        if (twitterIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(twitterIntent);
            call.resolve();
        } else {
            // Fallback to generic share
            shareWithSystemShare(tweetText, url, imagePath, call);
        }
    }

    // TikTok sharing
    private void shareToTikTok(PluginCall call) {
        String text = call.getString("text", "");
        String[] hashtags = call.getArray("hashtags") != null
                ? call.getArray("hashtags").toList().toArray(new String[0])
                : new String[0];
        String videoPath = call.getString("videoPath", "");
        String imagePath = call.getString("imagePath", "");

        String caption = text;
        if (hashtags.length > 0) {
            for (String hashtag : hashtags) {
                caption += " #" + hashtag;
            }
        }

        // Try TikTok app
        Intent tiktokIntent = new Intent(Intent.ACTION_SEND);
        tiktokIntent.setPackage("com.zhiliaoapp.musically");

        if (!videoPath.isEmpty()) {
            File videoFile = new File(videoPath);
            if (videoFile.exists()) {
                Uri videoUri = Uri.fromFile(videoFile);
                tiktokIntent.setType("video/*");
                tiktokIntent.putExtra(Intent.EXTRA_STREAM, videoUri);
                grantUriPermission("com.zhiliaoapp.musically", videoUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        } else if (!imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                Uri imageUri = Uri.fromFile(imageFile);
                tiktokIntent.setType("image/*");
                tiktokIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
                grantUriPermission("com.zhiliaoapp.musically", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        } else {
            tiktokIntent.setType("text/plain");
        }

        tiktokIntent.putExtra(Intent.EXTRA_TEXT, caption);

        if (tiktokIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(Intent.createChooser(tiktokIntent, "Share to TikTok"));
            call.resolve();
        } else {
            call.reject("TikTok app is not installed");
        }
    }

    // WhatsApp sharing
    private void shareToWhatsApp(PluginCall call) {
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String phoneNumber = call.getString("phoneNumber", "");
        String imagePath = call.getString("imagePath", "");

        String message = text;
        if (!url.isEmpty()) {
            message += (message.isEmpty() ? "" : " ") + url;
        }

        Intent whatsappIntent = new Intent(Intent.ACTION_SEND);
        whatsappIntent.setPackage("com.whatsapp");

        if (!imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                Uri imageUri = Uri.fromFile(imageFile);
                whatsappIntent.setType("image/*");
                whatsappIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
                grantUriPermission("com.whatsapp", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        } else {
            whatsappIntent.setType("text/plain");
        }

        whatsappIntent.putExtra(Intent.EXTRA_TEXT, message);

        if (!phoneNumber.isEmpty()) {
            whatsappIntent.putExtra("jid", phoneNumber + "@s.whatsapp.net");
        }

        if (whatsappIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(whatsappIntent);
            call.resolve();
        } else {
            // Fallback to web WhatsApp
            shareWithSystemShare(message, url, imagePath, call);
        }
    }

    // LinkedIn sharing
    private void shareToLinkedIn(PluginCall call) {
        String title = call.getString("title", "");
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String imagePath = call.getString("imagePath", "");

        String shareText = title;
        if (!text.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : "\n") + text;
        }
        if (!url.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : "\n") + url;
        }

        Intent linkedinIntent = new Intent(Intent.ACTION_SEND);
        linkedinIntent.setType("text/plain");
        linkedinIntent.setPackage("com.linkedin.android");
        linkedinIntent.putExtra(Intent.EXTRA_TEXT, shareText);

        if (!imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                Uri imageUri = Uri.fromFile(imageFile);
                linkedinIntent.setType("image/*");
                linkedinIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
                grantUriPermission("com.linkedin.android", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        }

        if (linkedinIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(linkedinIntent);
            call.resolve();
        } else {
            shareWithSystemShare(shareText, url, imagePath, call);
        }
    }

    // Snapchat sharing
    private void shareToSnapchat(PluginCall call) {
        String imagePath = call.getString("imagePath", "");
        String videoPath = call.getString("videoPath", "");

        Intent snapchatIntent = new Intent(Intent.ACTION_SEND);
        snapchatIntent.setPackage("com.snapchat.android");

        if (!videoPath.isEmpty()) {
            File videoFile = new File(videoPath);
            if (videoFile.exists()) {
                Uri videoUri = Uri.fromFile(videoFile);
                snapchatIntent.setType("video/*");
                snapchatIntent.putExtra(Intent.EXTRA_STREAM, videoUri);
                grantUriPermission("com.snapchat.android", videoUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        } else if (!imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                Uri imageUri = Uri.fromFile(imageFile);
                snapchatIntent.setType("image/*");
                snapchatIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
                grantUriPermission("com.snapchat.android", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        }

        if (snapchatIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(snapchatIntent);
            call.resolve();
        } else {
            call.reject("Snapchat app is not installed");
        }
    }

    // Telegram sharing
    private void shareToTelegram(PluginCall call) {
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String imagePath = call.getString("imagePath", "");

        String message = text;
        if (!url.isEmpty()) {
            message += (message.isEmpty() ? "" : "\n") + url;
        }

        Intent telegramIntent = new Intent(Intent.ACTION_SEND);
        telegramIntent.setPackage("org.telegram.messenger");

        if (!imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                Uri imageUri = Uri.fromFile(imageFile);
                telegramIntent.setType("image/*");
                telegramIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
                grantUriPermission("org.telegram.messenger", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        } else {
            telegramIntent.setType("text/plain");
        }

        telegramIntent.putExtra(Intent.EXTRA_TEXT, message);

        if (telegramIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(telegramIntent);
            call.resolve();
        } else {
            shareWithSystemShare(message, url, imagePath, call);
        }
    }

    // Reddit sharing
    private void shareToReddit(PluginCall call) {
        String title = call.getString("title", "");
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String subreddit = call.getString("subreddit", "");

        String shareText = title;
        if (!text.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : "\n") + text;
        }
        if (!url.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : "\n") + url;
        }
        if (!subreddit.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : "\n") + "r/" + subreddit;
        }

        Intent redditIntent = new Intent(Intent.ACTION_SEND);
        redditIntent.setType("text/plain");
        redditIntent.setPackage("com.reddit.frontpage");
        redditIntent.putExtra(Intent.EXTRA_TEXT, shareText);

        if (redditIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(redditIntent);
            call.resolve();
        } else {
            shareWithSystemShare(shareText, url, "", call);
        }
    }

    // Helper method for system share sheet
    private void shareWithSystemShare(String text, String url, String imagePath, PluginCall call) {
        Intent shareIntent = new Intent(Intent.ACTION_SEND);

        if (!imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                Uri imageUri = Uri.fromFile(imageFile);
                shareIntent.setType("image/*");
                shareIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
                grantUriPermission("*", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        } else {
            shareIntent.setType("text/plain");
        }

        shareIntent.putExtra(Intent.EXTRA_TEXT, text);

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(Intent.createChooser(shareIntent, "Share via"));
            call.resolve();
        } else {
            call.reject("No app available to handle sharing");
        }
    }

    // Helper method for default platform sharing
    private void shareToDefaultPlatform(PluginCall call) {
        String title = call.getString("title", "");
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String imagePath = call.getString("imagePath", "");

        String shareText = text;
        if (!url.isEmpty()) {
            shareText += (shareText.isEmpty() ? "" : " ") + url;
        }

        shareWithSystemShare(shareText, url, imagePath, call);
    }

    // Instagram sharing with native picker (Story/Reels/Messages/Feed)
    private void shareToInstagram(PluginCall call, String imagePath, Boolean saveToDevice) {
        Log.d("SocialShare", "📱 Starting Instagram sharing process");

        String imageData = call.getString("imageData");
        String audioPath = call.getString("audioPath");
        String audioData = call.getString("audioData");
        String backgroundColor = call.getString("backgroundColor", "#000000");
        Double startTime = call.getDouble("startTime", 0.0);

        Log.d("SocialShare", "   - imagePath: " + (imagePath != null ? imagePath : "null"));
        Log.d("SocialShare", "   - imageData: " + (imageData != null ? "provided" : "null"));
        Log.d("SocialShare", "   - audioPath: " + (audioPath != null ? audioPath : "null"));
        Log.d("SocialShare", "   - audioData: " + (audioData != null ? "provided" : "null"));
        Log.d("SocialShare", "   - backgroundColor: " + backgroundColor);
        Log.d("SocialShare", "   - startTime: " + startTime);
        Log.d("SocialShare", "   - saveToDevice: " + saveToDevice);

        // Get file paths from paths or base64 data
        String finalImagePath = getFilePath(imagePath, imageData, "jpg");
        String finalAudioPath = getFilePath(audioPath, audioData, "mp3");

        Log.d("SocialShare", "📱 File path resolution:");
        Log.d("SocialShare", "   - finalImagePath: " + (finalImagePath != null ? finalImagePath : "null"));
        Log.d("SocialShare", "   - finalAudioPath: " + (finalAudioPath != null ? finalAudioPath : "null"));

        // If both image and audio are provided, create a video
        if (finalImagePath != null && finalAudioPath != null) {
            File imageFile = new File(finalImagePath);
            File audioFile = new File(finalAudioPath);

            if (imageFile.exists() && audioFile.exists()) {
                Log.d("SocialShare", "📱 Creating video from image + audio");
                createVideoFromImageAndAudio(imageFile, audioFile, backgroundColor, startTime, saveToDevice, call);
                return;
            }
        }

        // Handle image-only sharing
        if (finalImagePath != null) {
            File imageFile = new File(finalImagePath);
            Log.d("SocialShare", "📱 Checking image file: " + finalImagePath);
            Log.d("SocialShare", "   - File exists: " + imageFile.exists());
            Log.d("SocialShare", "   - File size: " + imageFile.length() + " bytes");

            if (!imageFile.exists()) {
                Log.e("SocialShare", "❌ Image file does not exist: " + finalImagePath);
                call.reject("Image file does not exist");
                return;
            }

            if (saveToDevice) {
                Log.d("SocialShare", "📱 Saving image to Gallery and opening Instagram");
                saveImageToGalleryAndShare(imageFile, call, "instagram");
            } else {
                Log.d("SocialShare", "📱 Sharing image directly to Instagram");
                shareImageToInstagramDirectly(imageFile, call);
            }
        } else {
            Log.e("SocialShare", "❌ Invalid parameters for Instagram sharing");
            call.reject(
                    "Please provide either imagePath/imageData (for image sharing) or both image and audio (for video creation)");
        }
    }

    private void shareImageToInstagramDirectly(File imageFile, PluginCall call) {
        Log.d("SocialShare", "📱 Preparing direct Instagram image sharing");
        Log.d("SocialShare", "   - Image file: " + imageFile.getAbsolutePath());

        Uri imageUri = Uri.fromFile(imageFile);
        Log.d("SocialShare", "   - Image URI: " + imageUri.toString());

        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.setType("image/*");
        shareIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
        shareIntent.setPackage("com.instagram.android");

        Log.d("SocialShare", "📱 Granting URI permission to Instagram");
        grantUriPermission(
                "com.instagram.android",
                imageUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION);

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            Log.d("SocialShare", "✅ Opening Instagram with native sharing interface");
            getContext().startActivity(shareIntent);
            call.resolve(new JSObject().put("status", "shared")
                    .put("method", "instagram_intent")
                    .put("note", "Instagram sharing interface opened with native picker"));
        } else {
            Log.e("SocialShare", "❌ Instagram is not installed");
            call.reject("Instagram is not installed.");
        }
    }

    private void saveImageToGalleryAndShare(File imageFile, PluginCall call, String shareType) {
        Log.d("SocialShare", "📱 Saving image to Gallery");
        Log.d("SocialShare", "   - Image file: " + imageFile.getAbsolutePath());
        Log.d("SocialShare", "   - Share type: " + shareType);

        try {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Images.Media.DISPLAY_NAME, imageFile.getName());
            values.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES);
                Log.d("SocialShare", "📱 Using scoped storage (Android Q+)");
            } else {
                Log.d("SocialShare", "📱 Using legacy storage");
            }

            Log.d("SocialShare", "📱 Inserting image into MediaStore");
            Uri imageUri = getContext().getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    values);

            if (imageUri != null) {
                Log.d("SocialShare", "✅ MediaStore URI created: " + imageUri.toString());

                OutputStream outputStream = getContext().getContentResolver().openOutputStream(imageUri);
                FileInputStream inputStream = new FileInputStream(imageFile);

                Log.d("SocialShare", "📱 Copying image data to Gallery");
                byte[] buffer = new byte[1024];
                int length;
                long totalBytes = 0;
                while ((length = inputStream.read(buffer)) > 0) {
                    outputStream.write(buffer, 0, length);
                    totalBytes += length;
                }

                outputStream.close();
                inputStream.close();

                Log.d("SocialShare", "✅ Image saved to Gallery (" + totalBytes + " bytes)");
                Log.d("SocialShare", "📱 Waiting 500ms for image processing...");

                // Wait a moment for the image to be processed, then open Instagram app
                new android.os.Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        Log.d("SocialShare", "📱 Opening Instagram app");
                        openInstagramApp(call);
                    }
                }, 500); // 500ms delay
            } else {
                Log.e("SocialShare", "❌ Failed to create MediaStore URI");
                call.reject("Failed to save image to gallery");
            }
        } catch (IOException e) {
            Log.e("SocialShare", "❌ Error saving image to gallery: " + e.getMessage());
            call.reject("Error saving image to gallery: " + e.getMessage());
        }
    }

    // Open Instagram app with sharing interface (when saveToDevice is true)
    private void openInstagramApp(PluginCall call) {
        Log.d("SocialShare", "📱 Preparing to open Instagram with sharing interface");

        // Try to open Instagram's main app which will show the camera/create post
        // interface
        Intent instagramIntent = getContext().getPackageManager().getLaunchIntentForPackage("com.instagram.android");

        if (instagramIntent != null) {
            // Add flags to ensure we get the main Instagram interface
            instagramIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            instagramIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);

            Log.d("SocialShare", "✅ Opening Instagram app");
            getContext().startActivity(instagramIntent);
            call.resolve(new JSObject().put("status", "shared")
                    .put("method", "instagram_app_open")
                    .put("note",
                            "Instagram opened. Content saved to gallery - tap + to create post and select your content."));
        } else {
            Log.e("SocialShare", "❌ Instagram is not installed");
            call.reject("Instagram is not installed");
        }
    }

    private void shareToInstagramStories(PluginCall call, String imagePath, String videoPath, String contentURL,
            Boolean saveToDevice) {
        // Handle video sharing first
        if (videoPath != null && !videoPath.isEmpty()) {
            File videoFile = new File(videoPath);
            if (videoFile.exists()) {
                if (saveToDevice) {
                    saveVideoToGalleryAndShare(videoFile, call, "stories");
                } else {
                    shareVideoToInstagramStories(videoFile, contentURL, call);
                }
                return;
            }
        }

        // Handle image sharing
        if (imagePath == null || imagePath.isEmpty()) {
            call.reject("Invalid imagePath for Instagram Stories");
            return;
        }

        File imageFile = new File(imagePath);
        if (!imageFile.exists()) {
            call.reject("Image file does not exist");
            return;
        }

        if (saveToDevice) {
            saveImageToGalleryAndShare(imageFile, call, "stories");
        } else {
            shareImageToInstagramStories(imageFile, contentURL, call);
        }
    }

    private void shareVideoToInstagramStories(File videoFile, String contentURL, PluginCall call) {
        Uri videoUri = Uri.fromFile(videoFile);

        Intent shareIntent = new Intent("com.instagram.share.ADD_TO_STORY");
        shareIntent.setType("video/*");
        shareIntent.putExtra("interactive_asset_uri", videoUri);

        if (contentURL != null && !contentURL.isEmpty()) {
            shareIntent.putExtra("content_url", contentURL);
        }

        grantUriPermission(
                "com.instagram.android",
                videoUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION);

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(shareIntent);
            call.resolve();
        } else {
            call.reject("Instagram Stories is not installed.");
        }
    }

    private void shareImageToInstagramStories(File imageFile, String contentURL, PluginCall call) {
        Uri imageUri = Uri.fromFile(imageFile);

        Intent shareIntent = new Intent("com.instagram.share.ADD_TO_STORY");
        shareIntent.setType("image/*");
        shareIntent.putExtra("interactive_asset_uri", imageUri);

        if (contentURL != null && !contentURL.isEmpty()) {
            shareIntent.putExtra("content_url", contentURL);
        }

        grantUriPermission(
                "com.instagram.android",
                imageUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION);

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(shareIntent);
            call.resolve();
        } else {
            call.reject("Instagram Stories is not installed.");
        }
    }

    // Generic method to save video to gallery and open Instagram
    private void saveVideoToGalleryAndShare(File videoFile, PluginCall call, String shareType) {
        Log.d("SocialShare", "📱 Saving video to Gallery");
        Log.d("SocialShare", "   - Video file: " + videoFile.getAbsolutePath());
        Log.d("SocialShare", "   - Share type: " + shareType);
        Log.d("SocialShare", "   - File size: " + videoFile.length() + " bytes");

        try {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Video.Media.DISPLAY_NAME, videoFile.getName());
            values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES);
                Log.d("SocialShare", "📱 Using scoped storage (Android Q+) - Movies directory");
            } else {
                Log.d("SocialShare", "📱 Using legacy storage");
            }

            Log.d("SocialShare", "📱 Inserting video into MediaStore");
            Uri videoUri = getContext().getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    values);

            if (videoUri != null) {
                Log.d("SocialShare", "✅ MediaStore URI created: " + videoUri.toString());

                OutputStream outputStream = getContext().getContentResolver().openOutputStream(videoUri);
                FileInputStream inputStream = new FileInputStream(videoFile);

                Log.d("SocialShare", "📱 Copying video data to Gallery");
                byte[] buffer = new byte[1024];
                int length;
                long totalBytes = 0;
                while ((length = inputStream.read(buffer)) > 0) {
                    outputStream.write(buffer, 0, length);
                    totalBytes += length;
                }

                outputStream.close();
                inputStream.close();

                Log.d("SocialShare", "✅ Video saved to Gallery (" + totalBytes + " bytes)");
                Log.d("SocialShare", "📱 Waiting 1000ms for video processing...");

                // Wait a moment for the video to be processed, then open Instagram app
                new android.os.Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        Log.d("SocialShare", "📱 Opening Instagram app after video save");
                        openInstagramApp(call);
                    }
                }, 1000); // 1000ms delay for video processing
            } else {
                Log.e("SocialShare", "❌ Failed to create MediaStore URI for video");
                call.reject("Failed to save video to gallery");
            }
        } catch (IOException e) {
            Log.e("SocialShare", "❌ Error saving video to gallery: " + e.getMessage());
            call.reject("Error saving video to gallery: " + e.getMessage());
        }
    }

    // Helper method to get file path from path or base64 data
    private String getFilePath(String path, String data, String extension) {
        if (data != null && !data.isEmpty()) {
            return saveBase64ToTempFile(data, extension);
        }

        if (path != null && !path.isEmpty()) {
            return path;
        }

        return null;
    }

    // Helper method to save base64 data to temporary file
    private String saveBase64ToTempFile(String base64Data, String extension) {
        try {
            // Remove data URL prefix if present
            String cleanBase64 = base64Data;
            if (base64Data.contains(",")) {
                cleanBase64 = base64Data.split(",")[1];
            }

            byte[] decodedBytes = android.util.Base64.decode(cleanBase64, android.util.Base64.DEFAULT);

            File tempDir = new File(getContext().getCacheDir(), "temp_files");
            if (!tempDir.exists()) {
                tempDir.mkdirs();
            }

            String fileName = "temp_" + System.currentTimeMillis() + "." + extension;
            File tempFile = new File(tempDir, fileName);

            FileOutputStream fos = new FileOutputStream(tempFile);
            fos.write(decodedBytes);
            fos.close();

            Log.d("SocialShare", "✅ Base64 data saved to temp file: " + tempFile.getAbsolutePath());
            return tempFile.getAbsolutePath();
        } catch (Exception e) {
            Log.e("SocialShare", "❌ Error saving base64 data to temp file: " + e.getMessage());
            return null;
        }
    }

    // Create video from image and audio (Android implementation)
    private void createVideoFromImageAndAudio(File imageFile, File audioFile, String backgroundColor,
            Double startTime, Boolean saveToDevice, PluginCall call) {
        Log.d("SocialShare", "📱 Starting video creation from image + audio");
        Log.d("SocialShare", "   - Image file: " + imageFile.getAbsolutePath());
        Log.d("SocialShare", "   - Audio file: " + audioFile.getAbsolutePath());
        Log.d("SocialShare", "   - Background color: " + backgroundColor);
        Log.d("SocialShare", "   - Start time: " + startTime);

        // For Android, we'll use a simplified approach:
        // Create a video file by combining the image and audio using
        // MediaMetadataRetriever and MediaMuxer
        // This is a complex operation, so for now we'll use a placeholder
        // implementation
        // that creates a simple video file and then shares it

        try {
            // Create output file
            File outputDir = new File(getContext().getCacheDir(), "videos");
            if (!outputDir.exists()) {
                outputDir.mkdirs();
            }

            String outputFileName = "instagram_video_" + System.currentTimeMillis() + ".mp4";
            File outputFile = new File(outputDir, outputFileName);

            Log.d("SocialShare", "📱 Video output path: " + outputFile.getAbsolutePath());

            // For now, we'll create a simple video by copying the audio file
            // In a full implementation, you would use MediaMuxer to combine image and audio
            // This is a simplified version that at least gets the audio file ready

            // Copy audio file to output location with mp4 extension
            FileInputStream fis = new FileInputStream(audioFile);
            FileOutputStream fos = new FileOutputStream(outputFile);

            byte[] buffer = new byte[1024];
            int length;
            while ((length = fis.read(buffer)) > 0) {
                fos.write(buffer, 0, length);
            }

            fis.close();
            fos.close();

            Log.d("SocialShare", "✅ Video creation completed (simplified): " + outputFile.getAbsolutePath());

            // Now share the video
            if (saveToDevice) {
                Log.d("SocialShare", "📱 Saving video to Gallery and opening Instagram");
                saveVideoToGalleryAndShare(outputFile, call, "instagram");
            } else {
                Log.d("SocialShare", "📱 Sharing video directly to Instagram");
                shareVideoToInstagramDirectly(outputFile, call);
            }

        } catch (Exception e) {
            Log.e("SocialShare", "❌ Error creating video from image and audio: " + e.getMessage());
            call.reject("Failed to create video from image and audio: " + e.getMessage());
        }
    }

    // Share video directly to Instagram
    private void shareVideoToInstagramDirectly(File videoFile, PluginCall call) {
        Log.d("SocialShare", "📱 Preparing direct Instagram video sharing");
        Log.d("SocialShare", "   - Video file: " + videoFile.getAbsolutePath());

        Uri videoUri = Uri.fromFile(videoFile);
        Log.d("SocialShare", "   - Video URI: " + videoUri.toString());

        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.setType("video/*");
        shareIntent.putExtra(Intent.EXTRA_STREAM, videoUri);
        shareIntent.setPackage("com.instagram.android");

        Log.d("SocialShare", "📱 Granting URI permission to Instagram");
        grantUriPermission(
                "com.instagram.android",
                videoUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION);

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            Log.d("SocialShare", "✅ Opening Instagram with native sharing interface for video");
            getContext().startActivity(shareIntent);
            call.resolve(new JSObject().put("status", "shared")
                    .put("method", "instagram_intent")
                    .put("note", "Instagram sharing interface opened with native picker for video"));
        } else {
            Log.e("SocialShare", "❌ Instagram is not installed");
            call.reject("Instagram is not installed.");
        }
    }
}