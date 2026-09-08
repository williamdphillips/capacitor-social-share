package com.soundsstudios.socialshare;

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

        // Image + audio → compose story video (primary Wave path)
        if (imageFile != null && audioFile != null) {
            ShareUtils.createVideoFromImageAndAudioAsync(
                    getContext(),
                    imageFile,
                    audioFile,
                    startTime,
                    duration,
                    textOverlays,
                    imageOverlays,
                    timeBasedTextOverlays,
                    (success, outputFile, error) -> new Handler(Looper.getMainLooper()).post(() -> {
                        if (!success || outputFile == null) {
                            call.reject(error != null ? error : "Failed to create share video");
                            return;
                        }
                        // Match iOS: present system share sheet (user picks Instagram or any app).
                        presentShareSheetWithVideo(outputFile, saveToDevice, call);
                    })
            );
            return;
        }

        if (videoFile != null) {
            presentShareSheetWithVideo(videoFile, saveToDevice, call);
            return;
        }

        if (imageFile != null) {
            presentShareSheetWithMedia(imageFile, "image/*", saveToDevice, call);
            return;
        }

        call.reject("Please provide imagePath/imageData and/or audioPath/audioData for Instagram sharing");
    }

    private void shareToInstagramStories(PluginCall call) {
        String imagePath = call.getString("imagePath");
        String videoPath = call.getString("videoPath");
        boolean saveToDevice = Boolean.TRUE.equals(call.getBoolean("saveToDevice", true));

        File videoFile = ShareUtils.resolveLocalFile(videoPath);
        if (videoFile != null) {
            presentShareSheetWithVideo(videoFile, saveToDevice, call);
            return;
        }

        File imageFile = ShareUtils.resolveLocalFile(imagePath);
        if (imageFile == null) {
            call.reject("Invalid imagePath/videoPath for Instagram Stories");
            return;
        }
        presentShareSheetWithMedia(imageFile, "image/*", saveToDevice, call);
    }

    /**
     * Present the system share sheet with a video (same UX as iOS UIActivityViewController).
     * Optionally saves a copy to the gallery in the background when saveToDevice is true.
     */
    private void presentShareSheetWithVideo(File videoFile, boolean saveToDevice, PluginCall call) {
        presentShareSheetWithMedia(videoFile, "video/*", saveToDevice, call);
    }

    private void presentShareSheetWithMedia(File mediaFile, String mimeType, boolean saveToDevice, PluginCall call) {
        if (mediaFile == null || !mediaFile.exists()) {
            call.reject("Media file not found for sharing");
            return;
        }

        if (saveToDevice) {
            // Non-blocking gallery save (mirrors iOS Photos background save).
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

        Uri uri = getShareableUri(mediaFile);
        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType(mimeType);
        intent.putExtra(Intent.EXTRA_STREAM, uri);
        intent.setClipData(ClipData.newUri(getContext().getContentResolver(), "shared_media", uri));
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

        Intent chooser = Intent.createChooser(intent, "Share");
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
