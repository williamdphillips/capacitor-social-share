import AVFoundation
import Capacitor
import Photos
import UIKit

@objc(SocialShare)
public class SocialShare: CAPPlugin {
    private var appId: String?

    public override func load() {
        if let configAppId = self.getConfig().getString("appId") {
            self.appId = configAppId
            print("Loaded appId from Capacitor config: \(self.appId ?? "none")")
        } else {
            print("No appId provided in Capacitor config.")
        }
    }

    @objc func share(_ call: CAPPluginCall) {
        let platform = call.getString("platform") ?? ""

        switch platform {
        case "native":
            shareNatively(call: call)
        case "instagram-stories":
            shareToInstagramStories(call: call)
        case "instagram":
            shareToInstagram(call: call)
        case "facebook":
            shareToFacebook(call: call)
        case "twitter":
            shareToTwitter(call: call)
        case "tiktok":
            shareToTikTok(call: call)
        case "whatsapp":
            shareToWhatsApp(call: call)
        case "linkedin":
            shareToLinkedIn(call: call)
        case "snapchat":
            shareToSnapchat(call: call)
        case "telegram":
            shareToTelegram(call: call)
        case "reddit":
            shareToReddit(call: call)
        default:
            call.reject("Unsupported platform: \(platform)")
        }
    }

    // Native system sharing using iOS share sheet
    private func shareNatively(call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let text = call.getString("text") ?? ""
        let url = call.getString("url") ?? ""
        let imagePath = call.getString("imagePath")
        let imageData = call.getString("imageData")
        let videoPath = call.getString("videoPath")
        let videoData = call.getString("videoData")
        let files = call.getArray("files") as? [String] ?? []

        var activityItems: [Any] = []

        // Add text content
        if !title.isEmpty && !text.isEmpty {
            activityItems.append("\(title)\n\n\(text)")
        } else if !title.isEmpty {
            activityItems.append(title)
        } else if !text.isEmpty {
            activityItems.append(text)
        }

        // Add URL
        if !url.isEmpty, let shareURL = URL(string: url) {
            activityItems.append(shareURL)
        }

        // Add image if provided
        if let imagePath = imagePath, !imagePath.isEmpty {
            if let imageURL = URL(string: imagePath),
                FileManager.default.fileExists(atPath: imageURL.path),
                let image = UIImage(contentsOfFile: imageURL.path)
            {
                activityItems.append(image)
            }
        } else if let imageData = imageData, !imageData.isEmpty {
            // Handle base64 image data
            let cleanBase64 = imageData.replacingOccurrences(of: "data:image/png;base64,", with: "")
                .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")

            if let data = Data(base64Encoded: cleanBase64),
                let image = UIImage(data: data)
            {
                activityItems.append(image)
            }
        }

        // Add video if provided
        if let videoPath = videoPath, !videoPath.isEmpty {
            if let videoURL = URL(string: videoPath),
                FileManager.default.fileExists(atPath: videoURL.path)
            {
                activityItems.append(videoURL)
            }
        } else if let videoData = videoData, !videoData.isEmpty {
            // Handle base64 video data by creating temporary file
            let cleanBase64 = videoData.replacingOccurrences(of: "data:video/mp4;base64,", with: "")

            if let data = Data(base64Encoded: cleanBase64) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                    "shared_video_\(Date().timeIntervalSince1970).mp4")

                do {
                    try data.write(to: tempURL)
                    activityItems.append(tempURL)
                } catch {
                    print("Failed to write video data: \(error)")
                }
            }
        }

        // Add additional files
        for filePath in files {
            if let fileURL = URL(string: filePath),
                FileManager.default.fileExists(atPath: fileURL.path)
            {
                activityItems.append(fileURL)
            }
        }

        // Check if we have any content to share
        if activityItems.isEmpty {
            call.reject("No content provided for sharing")
            return
        }

        // Present native share sheet
        DispatchQueue.main.async {
            guard let rootViewController = UIApplication.shared.windows.first?.rootViewController
            else {
                call.reject("No root view controller available")
                return
            }

            let activityViewController = UIActivityViewController(
                activityItems: activityItems, applicationActivities: nil)

            // For iPad - set popover presentation
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            // Set completion handler
            activityViewController.completionWithItemsHandler = {
                activityType, completed, returnedItems, error in
                if let error = error {
                    call.reject("Share failed: \(error.localizedDescription)")
                } else if completed {
                    call.resolve([
                        "status": "shared",
                        "method": "native_system_share",
                        "activityType": activityType?.rawValue ?? "unknown",
                    ])
                } else {
                    call.resolve([
                        "status": "cancelled",
                        "method": "native_system_share",
                    ])
                }
            }

            rootViewController.present(activityViewController, animated: true)
        }
    }

    private func shareToInstagramStories(call: CAPPluginCall) {
        let backgroundColor = call.getString("backgroundColor") ?? "#000000"
        let imagePath = call.getString("imagePath")
        let stickerImagePath = call.getString("stickerImage")
        let audioPath = call.getString("audioPath")
        let contentURL = call.getString("contentURL")
        let linkURL = call.getString("linkURL")
        let startTime = call.getDouble("startTime") ?? 0.0
        let duration = call.getDouble("duration")  // Optional duration parameter
        let saveToDevice = call.getBool("saveToDevice") ?? false
        let textOverlays = call.getArray("textOverlays", [String: Any].self)
        let imageOverlays = call.getArray("imageOverlays", [String: Any].self)

        // Videos are now created automatically from imagePath + audioPath

        var backgroundImage: UIImage? = nil
        if let imagePath = imagePath,
            let imageURL = URL(string: imagePath),
            FileManager.default.fileExists(atPath: imageURL.path)
        {
            backgroundImage = UIImage(contentsOfFile: imageURL.path)
        }

        var stickerImage: UIImage? = nil
        if let stickerImagePath = stickerImagePath,
            let stickerURL = URL(string: stickerImagePath),
            FileManager.default.fileExists(atPath: stickerURL.path)
        {
            stickerImage = UIImage(contentsOfFile: stickerURL.path)
        }

        // Create a more persistent output URL in Documents directory instead of temporary
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
            0]
        let outputURL = documentsPath.appendingPathComponent(
            "instagram_story_\(Date().timeIntervalSince1970).mp4")

        if let audioPath = audioPath,
            let audioURL = URL(string: audioPath),
            FileManager.default.fileExists(atPath: audioURL.path)
        {
            // If audio is provided, create a video with the provided audio and background
            createVideoFromImageAndAudio(
                audioURL: audioURL,
                outputURL: outputURL,
                startTime: startTime,
                duration: duration,
                backgroundColor: backgroundImage == nil ? backgroundColor : nil,  // Use backgroundColor only if backgroundImage is nil
                backgroundImage: backgroundImage,  // Use the full-screen image if provided
                textOverlays: textOverlays,
                imageOverlays: imageOverlays
            ) { success, videoURL in
                if success, let videoURL = videoURL {
                    if saveToDevice {
                        self.saveVideoAndShareToStories(
                            videoURL: videoURL, stickerImage: stickerImage, contentURL: contentURL,
                            linkURL: linkURL, call: call)
                    } else {
                        self.shareToInstagramWithVideo(
                            videoURL: videoURL,
                            stickerImage: stickerImage,
                            contentURL: contentURL,
                            linkURL: linkURL,
                            call: call
                        )
                    }
                } else {
                    call.reject("Failed to generate video.")
                }
            }
        } else {
            // If no audio is provided, share as an image
            if let backgroundImage = backgroundImage {
                // Use the full-screen image as the background
                shareToInstagramWithImage(
                    backgroundImage: backgroundImage,
                    stickerImage: stickerImage,
                    contentURL: contentURL,
                    call: call
                )
            } else {
                // Use the backgroundColor as the fallback
                let placeholderImage = createPlaceholderImage(colorHex: backgroundColor)
                shareToInstagramWithImage(
                    backgroundImage: placeholderImage,
                    stickerImage: stickerImage,
                    contentURL: contentURL,
                    call: call
                )
            }
        }
    }

    private func saveVideoAndShareToStories(
        videoURL: URL, stickerImage: UIImage?, contentURL: String?, linkURL: String?,
        call: CAPPluginCall
    ) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if #available(iOS 14, *) {
                    if status == .authorized || status == .limited {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(
                                atFileURL: videoURL)
                        }) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    print("Video saved to Photos successfully")
                                    // Now share to Instagram Stories
                                    self.shareToInstagramWithVideo(
                                        videoURL: videoURL,
                                        stickerImage: stickerImage,
                                        contentURL: contentURL,
                                        linkURL: linkURL,
                                        call: call
                                    )
                                } else {
                                    print(
                                        "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"
                                    )
                                    // Continue with sharing even if save fails
                                    self.shareToInstagramWithVideo(
                                        videoURL: videoURL,
                                        stickerImage: stickerImage,
                                        contentURL: contentURL,
                                        linkURL: linkURL,
                                        call: call
                                    )
                                }
                            }
                        }
                    } else {
                        print("Photos access denied, continuing with sharing")
                        self.shareToInstagramWithVideo(
                            videoURL: videoURL,
                            stickerImage: stickerImage,
                            contentURL: contentURL,
                            linkURL: linkURL,
                            call: call
                        )
                    }
                } else {
                    // Fallback on earlier versions
                }
            }
        }
    }

    private func getStickerImage(from stickerImagePath: String?, call: CAPPluginCall) -> UIImage? {
        guard let stickerImagePath = stickerImagePath else { return nil }

        if let stickerURL = URL(string: stickerImagePath),
            FileManager.default.fileExists(atPath: stickerURL.path)
        {
            return UIImage(contentsOfFile: stickerURL.path)
        }
        return nil
    }

    private func createPlaceholderImage(colorHex: String) -> UIImage {
        guard let color = UIColor(hex: colorHex) else {
            print("Error: Invalid hex string for color.")
            return UIImage()
        }

        let size = CGSize(width: 1080, height: 1920)  // Default Instagram Story size
        UIGraphicsBeginImageContext(size)
        guard let context = UIGraphicsGetCurrentContext() else {
            print("Error: Unable to get graphics context.")
            return UIImage()
        }

        context.setFillColor(color.cgColor)  // Use unwrapped `UIColor`
        context.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }

    private func shareToInstagramWithVideo(
        videoURL: URL, stickerImage: UIImage?, contentURL: String?, linkURL: String?,
        call: CAPPluginCall
    ) {
        guard
            let urlScheme = URL(
                string: "instagram-stories://share?source_application=\(self.appId ?? "")")
        else {
            call.reject("Invalid URL scheme")
            return
        }

        UIPasteboard.general.items = []  // Clears the current pasteboard content

        var pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundVideo": try! Data(contentsOf: videoURL)
        ]

        if let stickerImageInput = call.getString("stickerImage") {
            var stickerImage: UIImage? = nil

            // Check if the input is Base64
            if stickerImageInput.starts(with: "data:image") || isBase64Encoded(stickerImageInput) {
                // Remove Base64 prefix if it exists
                let cleanBase64String = stickerImageInput.replacingOccurrences(
                    of: "data:image/png;base64,", with: ""
                )
                .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")

                // Decode Base64 and convert to UIImage
                if let imageData = Data(base64Encoded: cleanBase64String),
                    let decodedImage = UIImage(data: imageData)
                {
                    stickerImage = decodedImage
                } else {
                    call.reject("Invalid Base64 string for sticker image")
                    return
                }
            } else {
                // Treat input as a file path
                if let imageURL = URL(string: stickerImageInput),
                    FileManager.default.fileExists(atPath: imageURL.path)
                {
                    stickerImage = UIImage(contentsOfFile: imageURL.path)
                } else {
                    call.reject("Invalid file path for sticker image")
                    return
                }
            }

            // Add stickerImage to the pasteboard
            if let image = stickerImage {
                pasteboardItems["com.instagram.sharedSticker.stickerImage"] = image.pngData()
            } else {
                call.reject("Failed to process sticker image")
            }
        } else {
            call.reject("No sticker image provided")
        }

        if let contentURL = contentURL {
            pasteboardItems["com.instagram.sharedSticker.contentURL"] =
                "\(contentURL)?timestamp=\(Date().timeIntervalSince1970)"
        }

        if let linkURL = linkURL {
            pasteboardItems["com.instagram.sharedSticker.link"] = linkURL
        }

        if let attributionURL = contentURL {  // Attribution URL is typically the same as your content URL
            pasteboardItems["com.instagram.sharedSticker.attributionURL"] = attributionURL
        }

        UIPasteboard.general.setItems(
            [pasteboardItems], options: [.expirationDate: Date().addingTimeInterval(5)])

        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                call.resolve(["status": "shared"])
            } else {
                call.reject("Failed to open Instagram Stories.")
            }
        }
    }

    private func shareToInstagramWithImage(
        backgroundImage: UIImage, stickerImage: UIImage?, contentURL: String?, call: CAPPluginCall
    ) {
        guard
            let urlScheme = URL(
                string: "instagram-stories://share?source_application=\(self.appId ?? "")")
        else {
            call.reject("Invalid URL scheme")
            return
        }

        var pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": backgroundImage.pngData()!
        ]

        if let stickerImage = stickerImage {
            pasteboardItems["com.instagram.sharedSticker.stickerImage"] = stickerImage.pngData()
        }

        if let contentURL = contentURL {
            pasteboardItems["com.instagram.sharedSticker.contentURL"] = contentURL
        }

        UIPasteboard.general.setItems(
            [pasteboardItems], options: [.expirationDate: Date().addingTimeInterval(60 * 5)])

        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                call.resolve(["status": "shared"])
            } else {
                call.reject("Failed to open Instagram Stories.")
            }
        }
    }

    // Instagram sharing with native picker (Story/Reels/Messages/Feed)
    private func shareToInstagram(call: CAPPluginCall) {
        print("📱 [SocialShare] Starting Instagram sharing process")

        let saveToDevice = call.getBool("saveToDevice") ?? false
        let imagePath = call.getString("imagePath")
        let imageData = call.getString("imageData")
        let videoPath = call.getString("videoPath")
        let videoData = call.getString("videoData")
        let audioPath = call.getString("audioPath")
        let audioData = call.getString("audioData")
        let backgroundColor = call.getString("backgroundColor") ?? "#000000"
        let startTime = call.getDouble("startTime") ?? 0.0
        let duration = call.getDouble("duration")  // Optional duration parameter
        let textOverlays = call.getArray("textOverlays", [String: Any].self)
        let imageOverlays = call.getArray("imageOverlays", [String: Any].self)

        print("📱 [SocialShare] Instagram sharing parameters:")
        print("   - saveToDevice: \(saveToDevice)")
        print("   - imagePath: \(imagePath ?? "nil")")
        print("   - imageData: \(imageData != nil ? "provided" : "nil")")
        print("   - videoPath: \(videoPath ?? "nil")")
        print("   - videoData: \(videoData != nil ? "provided" : "nil")")
        print("   - audioPath: \(audioPath ?? "nil")")
        print("   - audioData: \(audioData != nil ? "provided" : "nil")")
        print("   - backgroundColor: \(backgroundColor)")
        print("   - startTime: \(startTime)")
        print("   - duration: \(duration?.description ?? "auto")")
        print("   - textOverlays: \(textOverlays?.count ?? 0)")
        print("   - imageOverlays: \(imageOverlays?.count ?? 0)")

        // Get file URLs from paths or base64 data
        let imageURL = getFileURL(from: imagePath, orData: imageData, withExtension: "jpg")
        let videoURL = getFileURL(from: videoPath, orData: videoData, withExtension: "mp4")
        let audioURL = getFileURL(from: audioPath, orData: audioData, withExtension: "mp3")

        print("📱 [SocialShare] File URL resolution:")
        print("   - imageURL: \(imageURL?.path ?? "nil")")
        print("   - videoURL: \(videoURL?.path ?? "nil")")
        print("   - audioURL: \(audioURL?.path ?? "nil")")
        print("   - audioPath input: \(audioPath ?? "nil")")
        print("   - audioURL absoluteString: \(audioURL?.absoluteString ?? "nil")")
        
        // Check file existence
        if let videoURL = videoURL {
            let videoExists = FileManager.default.fileExists(atPath: videoURL.path)
            print("📱 [SocialShare] Video file exists: \(videoExists)")
        } else {
            print("📱 [SocialShare] Video URL is nil")
        }
        if let audioURL = audioURL {
            let audioExists = FileManager.default.fileExists(atPath: audioURL.path)
            print("📱 [SocialShare] Audio file exists: \(audioExists) at path: \(audioURL.path)")
            if !audioExists {
                print("⚠️ [SocialShare] WARNING: Audio file does NOT exist at path!")
            }
        } else {
            print("📱 [SocialShare] Audio URL is nil - no audio will be added")
        }

        // Priority 1: If video is provided with audio (with or without overlays), replace audio and optionally apply overlays
        print("🔍 [SocialShare] Checking Priority 1 conditions:")
        print("   - videoURL exists: \(videoURL != nil)")
        print("   - audioURL exists: \(audioURL != nil)")
        print("   - video file exists: \(videoURL != nil ? FileManager.default.fileExists(atPath: videoURL!.path) : false)")
        print("   - audio file exists: \(audioURL != nil ? FileManager.default.fileExists(atPath: audioURL!.path) : false)")
        
        if let videoURL = videoURL,
            let audioURL = audioURL,
            FileManager.default.fileExists(atPath: videoURL.path),
            FileManager.default.fileExists(atPath: audioURL.path)
        {
            print("🎯 [SocialShare] PRIORITY 1: Video + Audio + Overlays path selected")
            let hasOverlays = (textOverlays != nil && !textOverlays!.isEmpty) || (imageOverlays != nil && !imageOverlays!.isEmpty)
            print("📱 [SocialShare] Video + audio detected - will replace audio" + (hasOverlays ? " and apply overlays" : ""))
            
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsPath.appendingPathComponent(
                "instagram_video_audio_overlays_\(Date().timeIntervalSince1970).mp4")
            
            // First, replace the video's audio track with the provided audio
            replaceVideoAudioAndApplyOverlays(
                videoURL: videoURL,
                audioURL: audioURL,
                outputURL: outputURL,
                startTime: startTime,
                duration: duration,
                textOverlays: textOverlays,
                imageOverlays: imageOverlays
            ) { success, finalVideoURL in
                if success, let finalVideoURL = finalVideoURL {
                    print("📱 [SocialShare] Video with audio and overlays created at: \(finalVideoURL.path)")
                    if saveToDevice {
                        self.saveVideoToPhotosAndOpenInstagram(videoURL: finalVideoURL, call: call)
                    } else {
                        self.shareVideoToInstagramDirectly(videoURL: finalVideoURL, call: call)
                    }
                } else {
                    print("❌ [SocialShare] Failed to replace audio and apply overlays to video")
                    call.reject("Failed to replace audio and apply overlays to video")
                }
            }
        }
        // Priority 2: If video is provided with overlays (no audio replacement), apply overlays to video
        else if let videoURL = videoURL,
            FileManager.default.fileExists(atPath: videoURL.path),
            ((textOverlays != nil && !textOverlays!.isEmpty) || (imageOverlays != nil && !imageOverlays!.isEmpty))
        {
            print("🎯 [SocialShare] PRIORITY 2: Video + Overlays (NO audio replacement) path selected")
            print("⚠️ [SocialShare] WARNING: Original video audio will be preserved!")
            print("📱 [SocialShare] Applying overlays to video background")
            
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsPath.appendingPathComponent(
                "instagram_video_with_overlays_\(Date().timeIntervalSince1970).mp4")
            
            applyOverlaysToVideo(
                videoURL: videoURL,
                outputURL: outputURL,
                textOverlays: textOverlays,
                imageOverlays: imageOverlays
            ) { success, finalVideoURL in
                if success, let finalVideoURL = finalVideoURL {
                    print("📱 [SocialShare] Video with overlays created at: \(finalVideoURL.path)")
                    if saveToDevice {
                        self.saveVideoToPhotosAndOpenInstagram(videoURL: finalVideoURL, call: call)
                    } else {
                        self.shareVideoToInstagramDirectly(videoURL: finalVideoURL, call: call)
                    }
                } else {
                    print("❌ [SocialShare] Failed to apply overlays to video")
                    call.reject("Failed to apply overlays to video")
                }
            }
        }
        // Priority 2: If video is provided without overlays, use it directly
        else if let videoURL = videoURL,
            FileManager.default.fileExists(atPath: videoURL.path)
        {
            print("📱 [SocialShare] Using video directly (no overlays)")
            if saveToDevice {
                self.saveVideoToPhotosAndOpenInstagram(videoURL: videoURL, call: call)
            } else {
                self.shareVideoToInstagramDirectly(videoURL: videoURL, call: call)
            }
        }
        // Priority 3: If both image and audio are provided, create a video
        else if let imageURL = imageURL,
            let audioURL = audioURL,
            FileManager.default.fileExists(atPath: imageURL.path),
            FileManager.default.fileExists(atPath: audioURL.path)
        {
            print("📱 [SocialShare] Creating video from image + audio")
            print("📱 [SocialShare] Image path: \(imageURL.path)")
            print("📱 [SocialShare] Audio path: \(audioURL.path)")
            let backgroundImage = UIImage(contentsOfFile: imageURL.path)
            print("📱 [SocialShare] Background image loaded: \(backgroundImage != nil)")

            // Create video from image and audio
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsPath.appendingPathComponent(
                "instagram_video_\(Date().timeIntervalSince1970).mp4")

            print("📱 [SocialShare] Video output path: \(outputURL.path)")

            createVideoFromImageAndAudio(
                audioURL: audioURL,
                outputURL: outputURL,
                startTime: startTime,
                duration: duration,
                backgroundColor: backgroundImage == nil ? backgroundColor : nil,
                backgroundImage: backgroundImage,
                textOverlays: textOverlays,
                imageOverlays: imageOverlays
            ) { success, videoURL in
                print("📱 [SocialShare] Video creation completed - success: \(success)")
                if success, let videoURL = videoURL {
                    print("📱 [SocialShare] Video created at: \(videoURL.path)")
                    if saveToDevice {
                        print("📱 [SocialShare] Saving video to Photos and opening Instagram")
                        self.saveVideoToPhotosAndOpenInstagram(videoURL: videoURL, call: call)
                    } else {
                        print("📱 [SocialShare] Sharing video directly to Instagram")
                        self.shareVideoToInstagramDirectly(videoURL: videoURL, call: call)
                    }
                } else {
                    print("❌ [SocialShare] Failed to create video from image and audio")
                    call.reject("Failed to create video from image and audio")
                }
            }
        } else if let imageURL = imageURL,
            FileManager.default.fileExists(atPath: imageURL.path),
            let image = UIImage(contentsOfFile: imageURL.path)
        {
            print("📱 [SocialShare] Sharing image only to Instagram (NO AUDIO PROVIDED)")
            print("📱 [SocialShare] Image loaded successfully from: \(imageURL.path)")
            print("⚠️ [SocialShare] audioURL: \(audioURL?.path ?? "nil")")
            print("⚠️ [SocialShare] audioURL exists: \(audioURL != nil ? FileManager.default.fileExists(atPath: audioURL!.path) : false)")

            // Share image only
            if saveToDevice {
                print("📱 [SocialShare] Saving image to Photos and opening Instagram")
                saveImageToPhotosAndOpenInstagram(image: image, call: call)
            } else {
                print("📱 [SocialShare] Sharing image directly to Instagram")
                shareImageToInstagramDirectly(image: image, call: call)
            }
        } else {
            print("❌ [SocialShare] Invalid parameters for Instagram sharing")
            print("   - imageURL exists: \(imageURL != nil)")
            print(
                "   - imageURL file exists: \(imageURL != nil ? FileManager.default.fileExists(atPath: imageURL!.path) : false)"
            )
            call.reject(
                "Please provide either imagePath/imageData (for image sharing) or both image and audio (for video creation)"
            )
        }
    }

    // Save video to Photos and then open Instagram
    private func saveVideoToPhotosAndOpenInstagram(videoURL: URL, call: CAPPluginCall) {
        print("📱 [SocialShare] Requesting Photos authorization for video saving")

        PHPhotoLibrary.requestAuthorization { status in
            print("📱 [SocialShare] Photos authorization status: \(status.rawValue)")

            DispatchQueue.main.async {
                if #available(iOS 14, *) {
                    if status == .authorized || status == .limited {
                        print("📱 [SocialShare] Photos access granted, saving video to Photos")

                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(
                                atFileURL: videoURL)
                        }) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    print("✅ [SocialShare] Video successfully saved to Photos")
                                    print(
                                        "📱 [SocialShare] Waiting 1 second for video processing...")

                                    // Wait a moment for the video to be processed, then open Instagram with the video
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        print("📱 [SocialShare] Opening Instagram with saved video")
                                        self.openInstagramWithAsset(
                                            assetPath: videoURL.path, call: call)
                                    }
                                } else {
                                    let errorMsg = error?.localizedDescription ?? "Unknown error"
                                    print(
                                        "❌ [SocialShare] Failed to save video to Photos: \(errorMsg)"
                                    )
                                    call.reject("Failed to save video to Photos: \(errorMsg)")
                                }
                            }
                        }
                    } else {
                        print("❌ [SocialShare] Photos access denied")
                        call.reject(
                            "Photos access denied. Please enable Photos access in Settings to save content before sharing."
                        )
                    }
                } else {
                    print("❌ [SocialShare] iOS version too old for Photos saving")
                    call.reject("Saving to Photos requires iOS 14 or later")
                }
            }
        }
    }

    // Direct Instagram video sharing with temporary file (when saveToDevice is false)
    private func shareVideoToInstagramDirectly(videoURL: URL, call: CAPPluginCall) {
        print("📱 [SocialShare] Preparing direct Instagram video sharing")
        print("📱 [SocialShare] Video path: \(videoURL.path)")

        // Instagram URL scheme that opens native sharing interface
        guard let urlScheme = URL(string: "instagram://library?AssetPath=\(videoURL.path)") else {
            print("❌ [SocialShare] Invalid URL scheme for Instagram video sharing")
            call.reject("Invalid URL scheme for Instagram video sharing.")
            return
        }

        print("📱 [SocialShare] Instagram URL scheme: \(urlScheme.absoluteString)")
        print("📱 [SocialShare] Opening Instagram with video...")

        // Open Instagram with the video
        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                print("✅ [SocialShare] Instagram opened successfully with video")
                call.resolve([
                    "status": "shared",
                    "method": "instagram_deep_link",
                    "note": "Instagram opened with native sharing interface",
                ])
            } else {
                print("❌ [SocialShare] Failed to open Instagram for video sharing")
                call.reject(
                    "Failed to open Instagram for sharing. Make sure Instagram is installed.")
            }
        }
    }

    // Save image to Photos and then open Instagram app
    private func saveImageToPhotosAndOpenInstagram(image: UIImage, call: CAPPluginCall) {
        print("📱 [SocialShare] Requesting Photos authorization for image saving")

        // First save image to temporary file to get the path
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(
            "instagram_temp_\(Date().timeIntervalSince1970).jpg")

        do {
            try image.jpegData(compressionQuality: 0.9)?.write(to: tempPath)
            print("📱 [SocialShare] Image saved to temporary path: \(tempPath.path)")
        } catch {
            print(
                "❌ [SocialShare] Failed to save image to temporary path: \(error.localizedDescription)"
            )
            call.reject("Failed to save image for Instagram sharing: \(error.localizedDescription)")
            return
        }

        PHPhotoLibrary.requestAuthorization { status in
            print("📱 [SocialShare] Photos authorization status: \(status.rawValue)")

            DispatchQueue.main.async {
                var isAuthorized = false

                if #available(iOS 14, *) {
                    isAuthorized = status == .authorized || status == .limited
                } else {
                    isAuthorized = status == .authorized
                }

                if isAuthorized {
                    print("📱 [SocialShare] Photos access granted, saving image to Photos")

                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                print("✅ [SocialShare] Image successfully saved to Photos")
                                print("📱 [SocialShare] Waiting 0.5 seconds for image processing...")

                                // Wait a moment for the photo to be processed, then open Instagram with the image
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    print("📱 [SocialShare] Opening Instagram with saved image")
                                    self.openInstagramWithAsset(
                                        assetPath: tempPath.path, call: call)
                                }
                            } else {
                                let errorMsg = error?.localizedDescription ?? "Unknown error"
                                print("❌ [SocialShare] Failed to save image to Photos: \(errorMsg)")
                                call.reject("Failed to save image to Photos: \(errorMsg)")
                            }
                        }
                    }
                } else {
                    print("❌ [SocialShare] Photos access denied")
                    call.reject(
                        "Photos access denied. Please enable Photos access in Settings to save content before sharing."
                    )
                }
            }
        }
    }

    // Open Instagram app with sharing interface (when saveToDevice is true)
    private func openInstagramApp(call: CAPPluginCall) {
        print("📱 [SocialShare] Preparing to open Instagram with sharing interface")

        // Use the camera deep link to open Instagram's post creation interface
        // This opens Instagram's camera/create post screen with access to camera roll
        guard let instagramURL = URL(string: "instagram://camera") else {
            print("❌ [SocialShare] Invalid Instagram URL")
            call.reject("Invalid Instagram URL")
            return
        }

        guard UIApplication.shared.canOpenURL(instagramURL) else {
            print("❌ [SocialShare] Instagram is not installed")
            call.reject("Instagram is not installed")
            return
        }

        print("📱 [SocialShare] Opening Instagram camera/create post interface...")
        UIApplication.shared.open(instagramURL, options: [:]) { success in
            if success {
                print("✅ [SocialShare] Instagram camera/create post opened successfully")
                call.resolve([
                    "status": "shared",
                    "method": "instagram_camera_open",
                    "note":
                        "Instagram camera opened. Content saved to Photos - tap gallery icon to select and share.",
                ])
            } else {
                print("❌ [SocialShare] Failed to open Instagram camera")
                call.reject("Failed to open Instagram camera")
            }
        }
    }

    // Open Instagram with specific asset path (the original INSTAGRAM_POST behavior)
    private func openInstagramWithAsset(assetPath: String, call: CAPPluginCall) {
        print("📱 [SocialShare] Preparing to open Instagram with specific asset")
        print("📱 [SocialShare] Asset path: \(assetPath)")

        // Instagram URL scheme that opens native sharing interface with specific asset
        guard let urlScheme = URL(string: "instagram://library?AssetPath=\(assetPath)") else {
            print("❌ [SocialShare] Invalid URL scheme for Instagram asset sharing")
            call.reject("Invalid URL scheme for Instagram asset sharing.")
            return
        }

        print("📱 [SocialShare] Instagram URL scheme: \(urlScheme.absoluteString)")
        print("📱 [SocialShare] Opening Instagram with asset...")

        guard UIApplication.shared.canOpenURL(urlScheme) else {
            print("❌ [SocialShare] Instagram is not installed")
            call.reject("Instagram is not installed")
            return
        }

        // Open Instagram with the specific asset
        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                print("✅ [SocialShare] Instagram opened successfully with asset")
                call.resolve([
                    "status": "shared",
                    "method": "instagram_library_asset",
                    "note": "Instagram opened with native sharing interface showing your content",
                ])
            } else {
                print("❌ [SocialShare] Failed to open Instagram with asset")
                call.reject(
                    "Failed to open Instagram for sharing. Make sure Instagram is installed.")
            }
        }
    }

    // Direct Instagram sharing with temporary file (when saveToDevice is false)
    private func shareImageToInstagramDirectly(image: UIImage, call: CAPPluginCall) {
        print("📱 [SocialShare] Preparing direct Instagram image sharing")

        // Save image to temporary directory
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent(
            "instagram_image.jpg")

        print("📱 [SocialShare] Saving image to temporary path: \(outputPath.path)")

        do {
            try image.jpegData(compressionQuality: 0.9)?.write(to: outputPath)
            print("✅ [SocialShare] Image saved to temporary directory")
        } catch {
            print(
                "❌ [SocialShare] Failed to save image to temporary directory: \(error.localizedDescription)"
            )
            call.reject("Failed to save image for Instagram sharing: \(error.localizedDescription)")
            return
        }

        // Instagram URL scheme that opens native sharing interface
        guard let urlScheme = URL(string: "instagram://library?AssetPath=\(outputPath.path)") else {
            print("❌ [SocialShare] Invalid URL scheme for Instagram image sharing")
            call.reject("Invalid URL scheme for Instagram sharing.")
            return
        }

        print("📱 [SocialShare] Instagram URL scheme: \(urlScheme.absoluteString)")
        print("📱 [SocialShare] Opening Instagram with image...")

        // Open Instagram with the saved image
        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                print("✅ [SocialShare] Instagram opened successfully with image")
                call.resolve([
                    "status": "shared",
                    "method": "instagram_deep_link",
                    "note": "Instagram opened with native sharing interface",
                ])
            } else {
                print("❌ [SocialShare] Failed to open Instagram for image sharing")
                call.reject(
                    "Failed to open Instagram for sharing. Make sure Instagram is installed.")
            }
        }
    }

    // Facebook sharing
    private func shareToFacebook(call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let text = call.getString("text") ?? ""
        let url = call.getString("url") ?? ""
        let hashtag = call.getString("hashtag") ?? ""
        let imagePath = call.getString("imagePath")

        var shareText = text
        if !url.isEmpty {
            shareText += (shareText.isEmpty ? "" : " ") + url
        }
        if !hashtag.isEmpty {
            shareText += (shareText.isEmpty ? "" : " ") + hashtag
        }

        // Try Facebook app first
        if let facebookURL = URL(string: "fb://"),
            UIApplication.shared.canOpenURL(facebookURL)
        {

            // Facebook doesn't support direct text sharing via URL scheme anymore
            // Fall back to native share sheet
            shareWithNativeSheet(text: shareText, url: url, imagePath: imagePath, call: call)
        } else {
            shareWithNativeSheet(text: shareText, url: url, imagePath: imagePath, call: call)
        }
    }

    // Twitter/X sharing
    private func shareToTwitter(call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        let url = call.getString("url") ?? ""
        let hashtags = call.getArray("hashtags") as? [String] ?? []
        let via = call.getString("via") ?? ""
        let imagePath = call.getString("imagePath")

        var tweetText = text
        if !hashtags.isEmpty {
            tweetText +=
                (tweetText.isEmpty ? "" : " ") + hashtags.map { "#\($0)" }.joined(separator: " ")
        }
        if !via.isEmpty {
            tweetText += (tweetText.isEmpty ? "" : " ") + "via @\(via)"
        }
        if !url.isEmpty {
            tweetText += (tweetText.isEmpty ? "" : " ") + url
        }

        // Try Twitter app first
        if let twitterURL = URL(
            string:
                "twitter://post?message=\(tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        ),
            UIApplication.shared.canOpenURL(twitterURL)
        {
            UIApplication.shared.open(twitterURL, options: [:]) { success in
                if success {
                    call.resolve(["status": "shared", "app": "twitter"])
                } else {
                    self.shareWithNativeSheet(
                        text: tweetText, url: url, imagePath: imagePath, call: call)
                }
            }
        } else {
            shareWithNativeSheet(text: tweetText, url: url, imagePath: imagePath, call: call)
        }
    }

    // TikTok sharing - uses native share sheet since TikTok has no direct sharing API
    private func shareToTikTok(call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        let hashtags = call.getArray("hashtags") as? [String] ?? []
        let videoPath = call.getString("videoPath")
        let imagePath = call.getString("imagePath")
        let audioPath = call.getString("audioPath")
        let contentURL = call.getString("contentURL")

        var caption = text
        if !hashtags.isEmpty {
            caption +=
                (caption.isEmpty ? "" : " ") + hashtags.map { "#\($0)" }.joined(separator: " ")
        }

        print("📱 TIKTOK: Sharing with native share sheet")
        print("📱 TIKTOK: Video path: \(videoPath ?? "none")")
        print("📱 TIKTOK: Image path: \(imagePath ?? "none")")
        print("📱 TIKTOK: Caption: \(caption)")

        // TikTok doesn't have a direct sharing API like Instagram
        // Best approach is to use the native share sheet with the video/image
        // This allows users to save to Files, share to TikTok (if available), or other apps
        
        // Use the native share sheet with video or image
        shareWithNativeSheet(
            text: caption,
            url: contentURL,
            videoPath: videoPath,
            imagePath: imagePath,
            call: call
        )
    }

    // WhatsApp sharing
    private func shareToWhatsApp(call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        let url = call.getString("url") ?? ""
        let phoneNumber = call.getString("phoneNumber") ?? ""
        let imagePath = call.getString("imagePath")

        var message = text
        if !url.isEmpty {
            message += (message.isEmpty ? "" : " ") + url
        }

        let encodedMessage =
            message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        var whatsappURL: URL?
        if !phoneNumber.isEmpty {
            whatsappURL = URL(string: "https://wa.me/\(phoneNumber)?text=\(encodedMessage)")
        } else {
            whatsappURL = URL(string: "whatsapp://send?text=\(encodedMessage)")
        }

        if let url = whatsappURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    call.resolve(["status": "shared", "app": "whatsapp"])
                } else {
                    self.shareWithNativeSheet(
                        text: message, url: url.absoluteString, imagePath: imagePath, call: call)
                }
            }
        } else {
            shareWithNativeSheet(text: message, url: url, imagePath: imagePath, call: call)
        }
    }

    // LinkedIn sharing
    private func shareToLinkedIn(call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let text = call.getString("text") ?? ""
        let url = call.getString("url") ?? ""
        let imagePath = call.getString("imagePath")

        var shareText = title
        if !text.isEmpty {
            shareText += (shareText.isEmpty ? "" : "\n") + text
        }
        if !url.isEmpty {
            shareText += (shareText.isEmpty ? "" : "\n") + url
        }

        // Try LinkedIn app
        if let linkedinURL = URL(string: "linkedin://"),
            UIApplication.shared.canOpenURL(linkedinURL)
        {
            UIApplication.shared.open(linkedinURL, options: [:]) { success in
                if success {
                    call.resolve([
                        "status": "shared", "app": "linkedin",
                        "note": "Please create your post manually in LinkedIn",
                    ])
                } else {
                    self.shareWithNativeSheet(
                        text: shareText, url: url, imagePath: imagePath, call: call)
                }
            }
        } else {
            shareWithNativeSheet(text: shareText, url: url, imagePath: imagePath, call: call)
        }
    }

    // Snapchat sharing
    private func shareToSnapchat(call: CAPPluginCall) {
        let imagePath = call.getString("imagePath")
        let videoPath = call.getString("videoPath")
        let stickerImage = call.getString("stickerImage")
        let attachmentUrl = call.getString("attachmentUrl")

        // Try Snapchat app
        if let snapchatURL = URL(string: "snapchat://"),
            UIApplication.shared.canOpenURL(snapchatURL)
        {

            // If we have an image or video, use native sharing
            if imagePath != nil || videoPath != nil {
                let mediaPath = videoPath ?? imagePath
                shareWithNativeSheet(
                    text: "", url: attachmentUrl ?? "", imagePath: mediaPath, call: call)
            } else {
                UIApplication.shared.open(snapchatURL, options: [:]) { success in
                    if success {
                        call.resolve(["status": "shared", "app": "snapchat"])
                    } else {
                        call.reject("Failed to open Snapchat app")
                    }
                }
            }
        } else {
            call.reject("Snapchat app is not installed")
        }
    }

    // Telegram sharing
    private func shareToTelegram(call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        let url = call.getString("url") ?? ""
        let imagePath = call.getString("imagePath")

        var message = text
        if !url.isEmpty {
            message += (message.isEmpty ? "" : "\n") + url
        }

        let encodedMessage =
            message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try Telegram app
        if let telegramURL = URL(string: "tg://msg?text=\(encodedMessage)"),
            UIApplication.shared.canOpenURL(telegramURL)
        {
            UIApplication.shared.open(telegramURL, options: [:]) { success in
                if success {
                    call.resolve(["status": "shared", "app": "telegram"])
                } else {
                    self.shareWithNativeSheet(
                        text: message, url: url, imagePath: imagePath, call: call)
                }
            }
        } else {
            shareWithNativeSheet(text: message, url: url, imagePath: imagePath, call: call)
        }
    }

    // Reddit sharing
    private func shareToReddit(call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let text = call.getString("text") ?? ""
        let url = call.getString("url") ?? ""
        let subreddit = call.getString("subreddit") ?? ""

        var shareText = title
        if !text.isEmpty {
            shareText += (shareText.isEmpty ? "" : "\n") + text
        }
        if !url.isEmpty {
            shareText += (shareText.isEmpty ? "" : "\n") + url
        }
        if !subreddit.isEmpty {
            shareText += (shareText.isEmpty ? "" : "\n") + "r/\(subreddit)"
        }

        // Try Reddit app
        if let redditURL = URL(string: "reddit://"),
            UIApplication.shared.canOpenURL(redditURL)
        {
            UIApplication.shared.open(redditURL, options: [:]) { success in
                if success {
                    call.resolve([
                        "status": "shared", "app": "reddit",
                        "note": "Please create your post manually in Reddit",
                    ])
                } else {
                    self.shareWithNativeSheet(text: shareText, url: url, imagePath: nil, call: call)
                }
            }
        } else {
            shareWithNativeSheet(text: shareText, url: url, imagePath: nil, call: call)
        }
    }

    // Helper function for native iOS share sheet
    private func shareWithNativeSheet(
        text: String, url: String, imagePath: String?, call: CAPPluginCall
    ) {
        var activityItems: [Any] = []

        if !text.isEmpty {
            activityItems.append(text)
        }

        if !url.isEmpty, let shareURL = URL(string: url) {
            activityItems.append(shareURL)
        }

        if let imagePath = imagePath,
            let imageURL = URL(string: imagePath),
            FileManager.default.fileExists(atPath: imageURL.path),
            let image = UIImage(contentsOfFile: imageURL.path)
        {
            activityItems.append(image)
        }

        if activityItems.isEmpty {
            call.reject("No content to share")
            return
        }

        DispatchQueue.main.async {
            let activityViewController = UIActivityViewController(
                activityItems: activityItems, applicationActivities: nil)

            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = self.bridge?.viewController?.view
                popover.sourceRect = CGRect(
                    x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0,
                    height: 0)
                popover.permittedArrowDirections = []
            }

            activityViewController.completionWithItemsHandler = { _, completed, _, error in
                if completed {
                    call.resolve(["status": "shared", "method": "native_sheet"])
                } else if let error = error {
                    call.reject("Share failed: \(error.localizedDescription)")
                } else {
                    call.reject("Share was cancelled")
                }
            }

            self.bridge?.viewController?.present(activityViewController, animated: true)
        }
    }

    // Helper function to save base64 data to temporary file
    private func saveBase64ToTempFile(_ base64Data: String, withExtension ext: String) -> URL? {
        guard let data = Data(base64Encoded: base64Data) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + "." + ext
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save base64 data to temp file: \(error)")
            return nil
        }
    }

    // Helper function to get file URL from path or base64 data
    private func getFileURL(from path: String?, orData data: String?, withExtension ext: String)
        -> URL?
    {
        if let data = data, !data.isEmpty {
            return saveBase64ToTempFile(data, withExtension: ext)
        }

        if let path = path, !path.isEmpty {
            return URL(string: path)
        }

        return nil
    }
}
