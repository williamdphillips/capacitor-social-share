import Capacitor
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
        case "instagram-stories":
            shareToInstagramStories(call: call)
        case "instagram-post":
            shareToInstagramPost(call: call)
        default:
            call.reject("Unsupported platform: \(platform)")
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

        var backgroundImage: UIImage? = nil
        if let imagePath = imagePath,
        let imageURL = URL(string: imagePath),
        FileManager.default.fileExists(atPath: imageURL.path) {
            backgroundImage = UIImage(contentsOfFile: imageURL.path)
        }

        var stickerImage: UIImage? = nil
        if let stickerImagePath = stickerImagePath,
        let stickerURL = URL(string: stickerImagePath),
        FileManager.default.fileExists(atPath: stickerURL.path) {
            stickerImage = UIImage(contentsOfFile: stickerURL.path)
        }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("instagram_story-\(Date().timeIntervalSince1970).mp4")

        if let audioPath = audioPath,
        let audioURL = URL(string: audioPath),
        FileManager.default.fileExists(atPath: audioURL.path) {
            // If audio is provided, create a video with the provided audio and background
            createVideoFromImageAndAudio(
                audioURL: audioURL,
                outputURL: outputURL,
                startTime: startTime,
                backgroundColor: backgroundImage == nil ? backgroundColor : nil, // Use backgroundColor only if backgroundImage is nil
                backgroundImage: backgroundImage // Use the full-screen image if provided
            ) { success, videoURL in
                if success, let videoURL = videoURL {
                    self.shareToInstagramWithVideo(
                        videoURL: videoURL,
                        stickerImage: stickerImage,
                        contentURL: contentURL,
                        linkURL: linkURL,
                        call: call
                    )
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

    private func createPlaceholderImage(colorHex: String) -> UIImage {
        guard let color = UIColor(hex: colorHex) else {
            print("Error: Invalid hex string for color.")
            return UIImage()
        }

        let size = CGSize(width: 1080, height: 1920) // Default Instagram Story size
        UIGraphicsBeginImageContext(size)
        guard let context = UIGraphicsGetCurrentContext() else {
            print("Error: Unable to get graphics context.")
            return UIImage()
        }

        context.setFillColor(color.cgColor) // Use unwrapped `UIColor`
        context.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }

    private func shareToInstagramWithVideo(videoURL: URL, stickerImage: UIImage?, contentURL: String?, linkURL: String?, call: CAPPluginCall) {
        guard let urlScheme = URL(string: "instagram-stories://share?source_application=\(self.appId ?? "")") else {
            call.reject("Invalid URL scheme")
            return
        }

        UIPasteboard.general.items = [] // Clears the current pasteboard content

        var pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundVideo": try! Data(contentsOf: videoURL)
        ]

        if let stickerImage = stickerImage {
            pasteboardItems["com.instagram.sharedSticker.stickerImage"] = stickerImage.pngData()
        }

        if let contentURL = contentURL {
            pasteboardItems["com.instagram.sharedSticker.contentURL"] = "\(contentURL)?timestamp=\(Date().timeIntervalSince1970)"
        }

        if let linkURL = linkURL {
            pasteboardItems["com.instagram.sharedSticker.link"] = linkURL
        }

        if let attributionURL = contentURL { // Attribution URL is typically the same as your content URL
            pasteboardItems["com.instagram.sharedSticker.attributionURL"] = attributionURL
        }

        UIPasteboard.general.setItems([pasteboardItems], options: [.expirationDate: Date().addingTimeInterval(5)])

        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                call.resolve(["status": "shared"])
            } else {
                call.reject("Failed to open Instagram Stories.")
            }
        }
    }

    private func shareToInstagramWithImage(backgroundImage: UIImage, stickerImage: UIImage?, contentURL: String?, call: CAPPluginCall) {
        guard let urlScheme = URL(string: "instagram-stories://share?source_application=\(self.appId ?? "")") else {
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

        UIPasteboard.general.setItems([pasteboardItems], options: [.expirationDate: Date().addingTimeInterval(60 * 5)])

        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                call.resolve(["status": "shared"])
            } else {
                call.reject("Failed to open Instagram Stories.")
            }
        }
    }

    private func shareToInstagramPost(call: CAPPluginCall) {
        guard let imagePath = call.getString("imagePath"),
            let imageURL = URL(string: imagePath),
            FileManager.default.fileExists(atPath: imageURL.path),
            let image = UIImage(contentsOfFile: imageURL.path) else {
            call.reject("Invalid or inaccessible imagePath")
            return
        }

        // Save image to temporary directory
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("instagram_post_image.jpg")
        do {
            try image.jpegData(compressionQuality: 0.9)?.write(to: outputPath)
        } catch {
            call.reject("Failed to save image for Instagram post: \(error.localizedDescription)")
            return
        }

        // Instagram URL scheme for posts
        guard let urlScheme = URL(string: "instagram://library?AssetPath=\(outputPath.path)") else {
            call.reject("Invalid URL scheme for Instagram Post.")
            return
        }

        // Open Instagram with the saved image
        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                call.resolve(["status": "shared"])
            } else {
                call.reject("Failed to open Instagram for sharing a post.")
            }
        }
    }
}