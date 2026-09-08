package com.soundsstudios.socialshare;

import android.app.Activity;
import android.content.ClipData;
import android.content.ContentValues;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.util.Base64;
import android.util.Log;

import androidx.core.content.FileProvider;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import org.json.JSONArray;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

@CapacitorPlugin(name = "SocialShare")
public class SocialShare extends Plugin {
    private static final String TAG = "SocialShare";
    private static final String INSTAGRAM_PACKAGE = "com.instagram.android";
    private static final String ACTION_ADD_TO_STORY = "com.instagram.share.ADD_TO_STORY";
    /** Instagram Stories background videos are limited to 20 seconds per Meta docs. */
    private static final double INSTAGRAM_STORIES_MAX_DURATION_SEC = 20.0;

    private String facebookAppId = "";

    @Override
    public void load() {
        facebookAppId = getConfig().getString("appId", "");
        if (facebookAppId == null) {
            facebookAppId = "";
        }
        Log.d(TAG, "SocialShare loaded with Facebook appId length=" + facebookAppId.length());
    }

    @PluginMethod
    public void share(PluginCall call) {
        String platform = call.getString("platform", "");
        switch (platform) {
            case "instagram-stories":
                shareToInstagramStories(call);
                break;
            case "instagram":
                shareToInstagram(call);
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
                shareWithSystemShare(call);
        }
    }

    private void shareToInstagram(PluginCall call) {
        Log.d(TAG, "Starting Instagram sharing");
        boolean saveToDevice = Boolean.TRUE.equals(call.getBoolean("saveToDevice", false));
        String imagePath = call.getString("imagePath");
        String imageData = call.getString("imageData");
        String videoPath = call.getString("videoPath");
        String videoData = call.getString("videoData");
        String audioPath = call.getString("audioPath");
        String audioData = call.getString("audioData");
        double startTime = call.getDouble("startTime", 0.0);
        Double duration = call.getDouble("duration");
        JSONArray textOverlays = toJsonArray(call.getArray("textOverlays"));
        JSONArray imageOverlays = toJsonArray(call.getArray("imageOverlays"));
        JSONArray timeBasedTextOverlays = toJsonArray(call.getArray("timeBasedTextOverlays"));

        File imageFile = resolveFile(imagePath, imageData, "jpg");
        File videoFile = resolveFile(videoPath, videoData, "mp4");
        File audioFile = resolveFile(audioPath, audioData, "mp3");

        Log.d(TAG, "image=" + (imageFile != null) + " video=" + (videoFile != null) + " audio=" + (audioFile != null));

        String contentURL = call.getString("contentURL", "");

        // Instagram Stories background videos max out at 20s (Meta docs).
        Double storyDuration = duration;
        if (storyDuration == null || storyDuration <= 0) {
            storyDuration = INSTAGRAM_STORIES_MAX_DURATION_SEC;
        } else {
            storyDuration = Math.min(storyDuration, INSTAGRAM_STORIES_MAX_DURATION_SEC);
        }

        // Image + audio → compose story video (primary Wave path)
        if (imageFile != null && audioFile != null) {
            ShareUtils.createVideoFromImageAndAudioAsync(
                    getContext(),
                    imageFile,
                    audioFile,
                    startTime,
                    storyDuration,
                    textOverlays,
                    imageOverlays,
                    timeBasedTextOverlays,
                    (success, outputFile, error) -> new Handler(Looper.getMainLooper()).post(() -> {
                        if (!success || outputFile == null) {
                            call.reject(error != null ? error : "Failed to create share video");
                            return;
                        }
                        presentInstagramShareOptions(outputFile, "video/mp4", saveToDevice, contentURL, call);
                    })
            );
            return;
        }

        if (videoFile != null) {
            presentInstagramShareOptions(videoFile, "video/mp4", saveToDevice, contentURL, call);
            return;
        }

        if (imageFile != null) {
            String imageMime = mimeTypeForFile(imageFile, "image/jpeg");
            presentInstagramShareOptions(imageFile, imageMime, saveToDevice, contentURL, call);
            return;
        }

        call.reject("Please provide imagePath/imageData and/or audioPath/audioData for Instagram sharing");
    }

    private void shareToInstagramStories(PluginCall call) {
        String imagePath = call.getString("imagePath");
        String videoPath = call.getString("videoPath");
        String contentURL = call.getString("contentURL", "");
        boolean saveToDevice = Boolean.TRUE.equals(call.getBoolean("saveToDevice", true));

        File videoFile = ShareUtils.resolveLocalFile(videoPath);
        if (videoFile != null) {
            // Stories platform: go straight to Instagram Stories composer.
            shareToInstagramStory(videoFile, "video/mp4", saveToDevice, contentURL, call);
            return;
        }

        File imageFile = ShareUtils.resolveLocalFile(imagePath);
        if (imageFile == null) {
            call.reject("Invalid imagePath/videoPath for Instagram Stories");
            return;
        }
        shareToInstagramStory(imageFile, "image/jpeg", saveToDevice, contentURL, call);
    }

    /**
     * Offer Instagram Story, Instagram Post, or system share sheet.
     * Story uses Meta's ADD_TO_STORY intent; Post uses ACTION_SEND to Instagram
     * (Feed / Reels / other Instagram destinations).
     */
    private void presentInstagramShareOptions(
            File mediaFile,
            String mimeType,
            boolean saveToDevice,
            String contentURL,
            PluginCall call
    ) {
        if (mediaFile == null || !mediaFile.exists()) {
            call.reject("Media file not found for sharing");
            return;
        }

        // Do not auto-save to gallery. Stories/share sheet receive a content:// Uri
        // directly (same as iOS share-sheet flow).

        Uri uri = getShareableUri(mediaFile);
        Intent storiesIntent = buildInstagramStoriesIntent(uri, mimeType, contentURL);
        Intent postIntent = buildInstagramPostIntent(uri, mimeType, contentURL);
        boolean canShareStory = storiesIntent != null
                && storiesIntent.resolveActivity(getContext().getPackageManager()) != null;
        boolean canSharePost = postIntent != null
                && postIntent.resolveActivity(getContext().getPackageManager()) != null;

        if (!canShareStory && !canSharePost) {
            Log.w(TAG, "Instagram unavailable; opening system share sheet");
            presentSystemShareSheet(uri, mimeType, contentURL, false, call);
            return;
        }

        java.util.ArrayList<String> labels = new java.util.ArrayList<>();
        java.util.ArrayList<Runnable> actions = new java.util.ArrayList<>();

        if (canShareStory) {
            labels.add("Instagram Story");
            actions.add(() -> {
                try {
                    getActivity().startActivity(storiesIntent);
                    call.resolve(new JSObject()
                            .put("status", "shared")
                            .put("method", "instagram_stories")
                            .put("note", "Instagram Stories composer opened"));
                } catch (Exception e) {
                    call.reject("Failed to open Instagram Stories: " + e.getMessage());
                }
            });
        }

        if (canSharePost) {
            labels.add("Instagram Post");
            actions.add(() -> {
                try {
                    getActivity().startActivity(postIntent);
                    call.resolve(new JSObject()
                            .put("status", "shared")
                            .put("method", "instagram_post")
                            .put("note", "Instagram post share opened"));
                } catch (Exception e) {
                    call.reject("Failed to open Instagram Post share: " + e.getMessage());
                }
            });
        }

        labels.add("More…");
        actions.add(() -> presentSystemShareSheet(uri, mimeType, contentURL, false, call));

        new android.app.AlertDialog.Builder(getActivity())
                .setTitle("Share")
                .setItems(labels.toArray(new CharSequence[0]), (dialog, which) -> {
                    if (which >= 0 && which < actions.size()) {
                        actions.get(which).run();
                    }
                })
                .setOnCancelListener(dialog -> call.resolve(new JSObject()
                        .put("status", "cancelled")
                        .put("method", "instagram_share_options")))
                .show();
    }

    private Intent buildInstagramPostIntent(Uri mediaUri, String mimeType, String contentURL) {
        if (mediaUri == null) {
            return null;
        }
        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType(mimeType);
        intent.putExtra(Intent.EXTRA_STREAM, mediaUri);
        intent.setClipData(ClipData.newUri(getContext().getContentResolver(), "instagram_post", mediaUri));
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.setPackage(INSTAGRAM_PACKAGE);
        if (contentURL != null && !contentURL.isEmpty()) {
            intent.putExtra(Intent.EXTRA_TEXT, contentURL);
        }
        Activity activity = getActivity();
        if (activity != null) {
            activity.grantUriPermission(
                    INSTAGRAM_PACKAGE,
                    mediaUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else {
            getContext().grantUriPermission(
                    INSTAGRAM_PACKAGE,
                    mediaUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION);
        }
        return intent;
    }

    private void shareToInstagramStory(
            File mediaFile,
            String mimeType,
            boolean saveToDevice,
            String contentURL,
            PluginCall call
    ) {
        if (mediaFile == null || !mediaFile.exists()) {
            call.reject("Media file not found for sharing");
            return;
        }
        Uri uri = getShareableUri(mediaFile);
        Intent storiesIntent = buildInstagramStoriesIntent(uri, mimeType, contentURL);
        if (storiesIntent == null
                || storiesIntent.resolveActivity(getContext().getPackageManager()) == null) {
            presentSystemShareSheet(uri, mimeType, contentURL, false, call);
            return;
        }
        try {
            getActivity().startActivity(storiesIntent);
            call.resolve(new JSObject()
                    .put("status", "shared")
                    .put("method", "instagram_stories")
                    .put("note", "Instagram Stories composer opened"));
        } catch (Exception e) {
            call.reject("Failed to open Instagram Stories: " + e.getMessage());
        }
    }

    private void maybeSaveToGallery(File mediaFile, String mimeType, boolean saveToDevice) {
        // Intentionally unused for Instagram Stories/share-sheet flow.
        // Kept for potential future explicit "Save to device" actions.
        if (!saveToDevice) {
            return;
        }
        new Thread(() -> {
            try {
                if (mimeType.startsWith("video")) {
                    saveVideoToGallery(mediaFile);
                } else {
                    saveImageToGallery(mediaFile);
                }
            } catch (Exception e) {
                Log.w(TAG, "Background gallery save failed: " + e.getMessage());
            }
        }, "social-share-gallery").start();
    }

    private void presentSystemShareSheet(
            Uri uri,
            String mimeType,
            String contentURL,
            boolean includeInstagramStories,
            PluginCall call
    ) {
        Intent sendIntent = new Intent(Intent.ACTION_SEND);
        sendIntent.setType(mimeType);
        sendIntent.putExtra(Intent.EXTRA_STREAM, uri);
        sendIntent.setClipData(ClipData.newUri(getContext().getContentResolver(), "shared_media", uri));
        sendIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        if (contentURL != null && !contentURL.isEmpty()) {
            sendIntent.putExtra(Intent.EXTRA_TEXT, contentURL);
        }

        Intent chooser = Intent.createChooser(sendIntent, "Share");
        if (includeInstagramStories) {
            Intent storiesIntent = buildInstagramStoriesIntent(uri, mimeType, contentURL);
            if (storiesIntent != null
                    && storiesIntent.resolveActivity(getContext().getPackageManager()) != null) {
                chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Intent[] { storiesIntent });
            }
        }

        try {
            getActivity().startActivity(chooser);
            call.resolve(new JSObject()
                    .put("status", "shared")
                    .put("method", "system_share_sheet")
                    .put("note", "System share sheet opened"));
        } catch (Exception e) {
            call.reject("Failed to open share sheet: " + e.getMessage());
        }
    }

    /**
     * Build Instagram Stories intent per Meta docs:
     * https://developers.facebook.com/documentation/instagram-platform/sharing-to-stories
     *
     * Requires: ADD_TO_STORY action, Facebook App ID (source_application),
     * and a content:// Uri to a local background image/video.
     */
    private Intent buildInstagramStoriesIntent(Uri mediaUri, String mimeType, String contentURL) {
        if (mediaUri == null) {
            return null;
        }
        // Meta requires a content Uri (FileProvider), not file://
        if (!"content".equalsIgnoreCase(mediaUri.getScheme())) {
            Log.e(TAG, "Instagram Stories requires a content:// Uri, got: " + mediaUri);
            return null;
        }

        String appId = resolveFacebookAppId();
        if (appId.isEmpty()) {
            Log.e(TAG, "Instagram Stories requires Facebook App ID (source_application)");
            return null;
        }

        Intent intent = new Intent(ACTION_ADD_TO_STORY);
        intent.setDataAndType(mediaUri, mimeType);
        intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.putExtra("source_application", appId);
        intent.setPackage(INSTAGRAM_PACKAGE);

        if (contentURL != null && !contentURL.isEmpty()) {
            intent.putExtra("content_url", contentURL);
        }

        Activity activity = getActivity();
        if (activity != null) {
            activity.grantUriPermission(
                    INSTAGRAM_PACKAGE,
                    mediaUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else {
            getContext().grantUriPermission(
                    INSTAGRAM_PACKAGE,
                    mediaUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION);
        }
        return intent;
    }

    private String resolveFacebookAppId() {
        if (facebookAppId != null && !facebookAppId.isEmpty()) {
            return facebookAppId;
        }
        try {
            int resId = getContext().getResources().getIdentifier(
                    "facebook_app_id", "string", getContext().getPackageName());
            if (resId != 0) {
                String fromResources = getContext().getString(resId);
                if (fromResources != null) {
                    return fromResources;
                }
            }
        } catch (Exception ignored) {
            // fall through
        }
        return "";
    }

    private static String mimeTypeForFile(File file, String fallback) {
        String name = file.getName().toLowerCase();
        if (name.endsWith(".png")) {
            return "image/png";
        }
        if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
            return "image/jpeg";
        }
        if (name.endsWith(".mp4") || name.endsWith(".mov")) {
            return "video/mp4";
        }
        if (name.endsWith(".webm")) {
            return "video/webm";
        }
        return fallback;
    }

    private void saveImageToGallery(File imageFile) throws IOException {
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, imageFile.getName());
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES);
        }
        Uri uri = getContext().getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) {
            throw new IOException("Failed to create gallery image URI");
        }
        copyFileToUri(imageFile, uri);
    }

    private void saveVideoToGallery(File videoFile) throws IOException {
        ContentValues values = new ContentValues();
        values.put(MediaStore.Video.Media.DISPLAY_NAME, videoFile.getName());
        values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES);
        }
        Uri uri = getContext().getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) {
            throw new IOException("Failed to create gallery video URI");
        }
        copyFileToUri(videoFile, uri);
    }

    private void shareToFacebook(PluginCall call) {
        shareTextOrMedia(call, "com.facebook.katana", "text/plain");
    }

    private void shareToTwitter(PluginCall call) {
        shareTextOrMedia(call, "com.twitter.android", "text/plain");
    }

    private void shareToTikTok(PluginCall call) {
        File video = resolveFile(call.getString("videoPath"), call.getString("videoData"), "mp4");
        File image = resolveFile(call.getString("imagePath"), call.getString("imageData"), "jpg");
        File media = video != null ? video : image;
        if (media == null) {
            call.reject("TikTok sharing requires videoPath or imagePath");
            return;
        }
        Uri uri = getShareableUri(media);
        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType(video != null ? "video/*" : "image/*");
        intent.putExtra(Intent.EXTRA_STREAM, uri);
        intent.setPackage("com.zhiliaoapp.musically");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        if (intent.resolveActivity(getContext().getPackageManager()) != null) {
            getActivity().startActivity(intent);
            call.resolve();
        } else {
            shareWithSystemShare(call);
        }
    }

    private void shareToWhatsApp(PluginCall call) {
        shareTextOrMedia(call, "com.whatsapp", "text/plain");
    }

    private void shareToLinkedIn(PluginCall call) {
        shareTextOrMedia(call, "com.linkedin.android", "text/plain");
    }

    private void shareToSnapchat(PluginCall call) {
        shareTextOrMedia(call, "com.snapchat.android", "image/*");
    }

    private void shareToTelegram(PluginCall call) {
        shareTextOrMedia(call, "org.telegram.messenger", "text/plain");
    }

    private void shareToReddit(PluginCall call) {
        shareTextOrMedia(call, "com.reddit.frontpage", "text/plain");
    }

    private void shareTextOrMedia(PluginCall call, String packageName, String defaultType) {
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String shareText = text;
        if (url != null && !url.isEmpty()) {
            shareText = shareText.isEmpty() ? url : shareText + " " + url;
        }
        File image = resolveFile(call.getString("imagePath"), call.getString("imageData"), "jpg");
        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setPackage(packageName);
        if (image != null) {
            Uri uri = getShareableUri(image);
            intent.setType("image/*");
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            getContext().grantUriPermission(packageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else {
            intent.setType(defaultType);
        }
        if (!shareText.isEmpty()) {
            intent.putExtra(Intent.EXTRA_TEXT, shareText);
        }
        if (intent.resolveActivity(getContext().getPackageManager()) != null) {
            getActivity().startActivity(intent);
            call.resolve();
        } else {
            shareWithSystemShare(call);
        }
    }

    private void shareWithSystemShare(PluginCall call) {
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String shareText = text;
        if (url != null && !url.isEmpty()) {
            shareText = shareText.isEmpty() ? url : shareText + " " + url;
        }
        File image = resolveFile(call.getString("imagePath"), call.getString("imageData"), "jpg");
        File video = resolveFile(call.getString("videoPath"), call.getString("videoData"), "mp4");
        Intent intent = new Intent(Intent.ACTION_SEND);
        if (video != null) {
            Uri uri = getShareableUri(video);
            intent.setType("video/*");
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else if (image != null) {
            Uri uri = getShareableUri(image);
            intent.setType("image/*");
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else {
            intent.setType("text/plain");
        }
        if (!shareText.isEmpty()) {
            intent.putExtra(Intent.EXTRA_TEXT, shareText);
        }
        getActivity().startActivity(Intent.createChooser(intent, "Share"));
        call.resolve();
    }

    private Uri getShareableUri(File file) {
        String authority = getContext().getPackageName() + ".fileprovider";
        return FileProvider.getUriForFile(getContext(), authority, file);
    }

    private void copyFileToUri(File file, Uri uri) throws IOException {
        try (OutputStream out = getContext().getContentResolver().openOutputStream(uri);
             FileInputStream in = new FileInputStream(file)) {
            if (out == null) {
                throw new IOException("Unable to open output stream");
            }
            byte[] buffer = new byte[8192];
            int length;
            while ((length = in.read(buffer)) > 0) {
                out.write(buffer, 0, length);
            }
        }
    }

    private File resolveFile(String path, String data, String extension) {
        if (data != null && !data.isEmpty()) {
            return saveBase64ToTempFile(data, extension);
        }
        return ShareUtils.resolveLocalFile(path);
    }

    private File saveBase64ToTempFile(String base64Data, String extension) {
        try {
            String clean = base64Data.contains(",") ? base64Data.substring(base64Data.indexOf(',') + 1) : base64Data;
            byte[] decoded = Base64.decode(clean, Base64.DEFAULT);
            File tempDir = new File(getContext().getCacheDir(), "temp_files");
            if (!tempDir.exists() && !tempDir.mkdirs()) {
                return null;
            }
            File tempFile = new File(tempDir, "temp_" + System.currentTimeMillis() + "." + extension);
            try (FileOutputStream fos = new FileOutputStream(tempFile)) {
                fos.write(decoded);
            }
            return tempFile;
        } catch (Exception e) {
            Log.e(TAG, "Failed to save base64 temp file", e);
            return null;
        }
    }

    private JSONArray toJsonArray(JSArray array) {
        if (array == null) {
            return null;
        }
        try {
            return new JSONArray(array.toString());
        } catch (Exception e) {
            return null;
        }
    }
}
