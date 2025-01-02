package com.soundsstudios.socialshare;

import android.content.Intent;
import android.net.Uri;

import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.Plugin;

import java.io.File;

@CapacitorPlugin(name = "SocialShare")
public class SocialShare extends Plugin {
    @PluginMethod
    public void share(PluginCall call) {
        String platform = call.getString("platform");
        String title = call.getString("title", "");
        String text = call.getString("text", "");
        String url = call.getString("url", "");
        String imagePath = call.getString("imagePath", "");

        switch (platform) {
            case "instagram-stories":
                shareToInstagramStories(call, imagePath, url);
                break;
            case "instagram-post":
                shareToInstagramPost(call, imagePath);
                break;
            default:
                shareToDefaultPlatform(call, title, text, url, imagePath, platform);
        }
    }

    private void shareToInstagramStories(PluginCall call, String imagePath, String contentURL) {
        if (imagePath == null || imagePath.isEmpty()) {
            call.reject("Invalid imagePath for Instagram Stories");
            return;
        }

        File imageFile = new File(imagePath);
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
            Intent.FLAG_GRANT_READ_URI_PERMISSION
        );

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(shareIntent);
            call.resolve();
        } else {
            call.reject("Instagram Stories is not installed.");
        }
    }

    private void shareToInstagramPost(PluginCall call, String imagePath) {
        if (imagePath == null || imagePath.isEmpty()) {
            call.reject("Invalid imagePath for Instagram Post");
            return;
        }

        File imageFile = new File(imagePath);
        Uri imageUri = Uri.fromFile(imageFile);

        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.setType("image/*");
        shareIntent.putExtra(Intent.EXTRA_STREAM, imageUri);

        grantUriPermission(
            "com.instagram.android", 
            imageUri, 
            Intent.FLAG_GRANT_READ_URI_PERMISSION
        );

        shareIntent.setPackage("com.instagram.android");

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(shareIntent);
            call.resolve();
        } else {
            call.reject("Instagram is not installed.");
        }
    }

    private void shareToDefaultPlatform(PluginCall call, String title, String text, String url, String imagePath, String packageName) {
        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.putExtra(Intent.EXTRA_TEXT, text + " " + url);

        if (imagePath != null && !imagePath.isEmpty()) {
            File imageFile = new File(imagePath);
            Uri imageUri = Uri.fromFile(imageFile);
            shareIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
            shareIntent.setType("image/*");
            grantUriPermission(
                packageName != null ? packageName : "com.example.socialshare",
                imageUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            );
        } else {
            shareIntent.setType("text/plain");
        }

        if (packageName != null) {
            shareIntent.setPackage(packageName);
        }

        if (shareIntent.resolveActivity(getContext().getPackageManager()) != null) {
            getContext().startActivity(Intent.createChooser(shareIntent, title));
            call.resolve();
        } else {
            call.reject("No app available to handle sharing.");
        }
    }
}