import Capacitor
import UIKit

@objc(SocialShare)
public class SocialShare: CAPPlugin {
    @objc func share(_ call: CAPPluginCall) {
        let platform = call.getString("platform") ?? ""
        
        switch platform {
        case "instagram-stories":
            shareToInstagramStories(call: call)
        case "instagram-post":
            shareToInstagramPost(call: call)
        case "facebook", "twitter", "whatsapp":
            shareToDefaultPlatform(call: call)
        default:
            call.reject("Unsupported platform: \(platform)")
        }
    }

    private func shareToInstagramStories(call: CAPPluginCall) {
        let imagePath = call.getString("imagePath")
        let contentURL = call.getString("contentURL")
        let stickerImage = call.getString("stickerImage")
        let backgroundColorTop = call.getString("backgroundColorTop")
        let backgroundColorBottom = call.getString("backgroundColorBottom")

        guard let imagePath = imagePath, let imageURL = URL(string: imagePath) else {
            call.reject("Invalid imagePath")
            return
        }

        guard let urlScheme = URL(string: "instagram-stories://share") else {
            call.reject("Instagram Stories URL scheme is not available.")
            return
        }

        if UIApplication.shared.canOpenURL(urlScheme) {
            var pasteboardItems: [String: Any] = [
                "com.instagram.sharedSticker.backgroundImage": imageURL,
            ]
            
            if let contentURL = contentURL {
                pasteboardItems["com.instagram.sharedSticker.contentURL"] = contentURL
            }
            if let stickerImage = stickerImage, let stickerURL = URL(string: stickerImage) {
                pasteboardItems["com.instagram.sharedSticker.stickerImage"] = stickerURL
            }
            if let backgroundColorTop = backgroundColorTop {
                pasteboardItems["com.instagram.sharedSticker.backgroundTopColor"] = backgroundColorTop
            }
            if let backgroundColorBottom = backgroundColorBottom {
                pasteboardItems["com.instagram.sharedSticker.backgroundBottomColor"] = backgroundColorBottom
            }

            UIPasteboard.general.setItems([pasteboardItems], options: [.expirationDate: Date().addingTimeInterval(60 * 5)])
            UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
            call.resolve()
        } else {
            call.reject("Instagram Stories is not installed.")
        }
    }

    private func shareToInstagramPost(call: CAPPluginCall) {
        let imagePath = call.getString("imagePath")

        guard let imagePath = imagePath, let _ = URL(string: imagePath) else {
            call.reject("Invalid imagePath")
            return
        }

        guard let urlScheme = URL(string: "instagram://library?AssetPath=\(imagePath)") else {
            call.reject("Instagram URL scheme is not available.")
            return
        }

        if UIApplication.shared.canOpenURL(urlScheme) {
            UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
            call.resolve()
        } else {
            call.reject("Instagram is not installed.")
        }
    }

    private func shareToDefaultPlatform(call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let text = call.getString("text") ?? ""
        let url = call.getString("url")
        let imagePath = call.getString("imagePath")

        var items: [Any] = []
        if !text.isEmpty {
            items.append(text)
        }
        if let url = url, let shareURL = URL(string: url) {
            items.append(shareURL)
        }
        if let imagePath = imagePath, let imageURL = URL(string: imagePath), let imageData = try? Data(contentsOf: imageURL), let image = UIImage(data: imageData) {
            items.append(image)
        }

        if items.isEmpty {
            call.reject("No valid shareable items provided.")
            return
        }

        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)

        DispatchQueue.main.async {
            self.bridge?.viewController?.present(activityViewController, animated: true, completion: {
                call.resolve()
            })
        }
    }
}