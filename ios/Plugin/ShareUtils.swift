import AVFoundation
import UIKit

extension UIColor {
    func image(size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            self.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor ?? fontDescriptor, size: pointSize)
    }
}

func createVideoFromImageAndAudio(
    audioURL: URL, outputURL: URL, startTime: Double, duration: Double?, backgroundColor: String?,
    backgroundImage: UIImage?, textOverlays: [[String: Any]]? = nil, imageOverlays: [[String: Any]]? = nil, timeBasedTextOverlays: [[String: Any]]? = nil, completion: @escaping (Bool, URL?) -> Void
) {
    let size = CGSize(width: 1080, height: 1920)

    print("Starting video creation process with provided background...")

    let background: UIImage?
    if let bgImage = backgroundImage {
        print("Using provided background image.")
        // Ensure image is rendered at full quality without compression
        // Redraw to avoid any potential color space or compression issues
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        bgImage.draw(in: CGRect(origin: .zero, size: size))
        background = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    } else if let bgColor = backgroundColor, let uiBackgroundColor = UIColor(hex: bgColor) {
        print("Using provided background color \(bgColor)")
        background = uiBackgroundColor.image(size: size)
    } else {
        print("Error: Invalid background configuration (no image or color).")
        completion(false, nil)
        return
    }

    guard let finalBackground = background else {
        print("Error: Failed to generate final background image.")
        completion(false, nil)
        return
    }

    // Convert audio to .m4a if not already
    if audioURL.pathExtension != "m4a" {
        convertAudioToM4A(audioURL: audioURL) { convertedAudioURL in
            guard let convertedAudioURL = convertedAudioURL else {
                print("Error converting audio to .m4a")
                completion(false, nil)
                return
            }
            print("Audio converted successfully. Proceeding with video creation.")
            createVideoFromImageAndAudio(
                audioURL: convertedAudioURL, outputURL: outputURL, startTime: startTime,
                duration: duration, backgroundColor: backgroundColor,
                backgroundImage: backgroundImage,
                textOverlays: textOverlays,
                imageOverlays: imageOverlays,
                timeBasedTextOverlays: timeBasedTextOverlays,
                completion: completion)
        }
        return
    }

    let audioAsset = AVURLAsset(url: audioURL)
    guard let audioTrackSource = audioAsset.tracks(withMediaType: .audio).first else {
        print("Error: No audio tracks found in the file.")
        completion(false, nil)
        return
    }
    print("Audio asset loaded with duration: \(audioAsset.duration.seconds) seconds")

    let composition = AVMutableComposition()

    // Add the audio track
    guard
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    else {
        print("Error: Unable to add audio track to composition.")
        completion(false, nil)
        return
    }

    let audioStartTime = CMTime(seconds: startTime, preferredTimescale: 600)

    // Calculate duration: use provided duration, or remaining audio duration, or default to full audio
    let requestedDuration: CMTime
    if let customDuration = duration, customDuration > 0 {
        requestedDuration = CMTime(seconds: customDuration, preferredTimescale: 600)
        print("Using custom duration: \(customDuration) seconds")
    } else {
        requestedDuration = audioAsset.duration - audioStartTime
        print(
            "Using remaining audio duration: \((audioAsset.duration - audioStartTime).seconds) seconds"
        )
    }

    // Ensure we don't exceed available audio
    let availableAudioDuration = audioAsset.duration - audioStartTime
    let audioDuration = min(requestedDuration, availableAudioDuration)

    print("Final video duration: \(audioDuration.seconds) seconds")

    do {
        try audioTrack.insertTimeRange(
            CMTimeRange(start: audioStartTime, duration: audioDuration), of: audioTrackSource,
            at: .zero)
        print("Audio track inserted successfully with duration: \(audioDuration.seconds) seconds")
    } catch {
        print("Error inserting audio track: \(error.localizedDescription)")
        completion(false, nil)
        return
    }

    // Generate a video from the background image
    let videoURL = outputURL.deletingLastPathComponent().appendingPathComponent(
        "temp_video_\(Date().timeIntervalSince1970).mp4")
    generateVideoFromImage(image: finalBackground, duration: audioDuration, outputURL: videoURL) {
        success, videoPath in
        guard success, let videoPath = videoPath else {
            print("Error generating video from background.")
            completion(false, nil)
            return
        }

        let videoAsset = AVURLAsset(url: videoPath)
        guard let videoTrackSource = videoAsset.tracks(withMediaType: .video).first else {
            print("Error: No video tracks found in generated video.")
            completion(false, nil)
            return
        }

        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            print("Error: Unable to add video track to composition.")
            completion(false, nil)
            return
        }

        do {
            try videoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: audioDuration), of: videoTrackSource, at: .zero)
            print("Video track inserted successfully.")
        } catch {
            print("Error inserting video track: \(error.localizedDescription)")
            completion(false, nil)
            return
        }

        // Configure video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: audioDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Add overlays if provided
        if (textOverlays != nil && !textOverlays!.isEmpty) || (imageOverlays != nil && !imageOverlays!.isEmpty) || (timeBasedTextOverlays != nil && !timeBasedTextOverlays!.isEmpty) {
            print("📱 [Overlays] Adding \(textOverlays?.count ?? 0) text overlays, \(imageOverlays?.count ?? 0) image overlays, and \(timeBasedTextOverlays?.count ?? 0) time-based text overlays")
            if let timeBased = timeBasedTextOverlays {
                print("📱 [Overlays] ✅ timeBasedTextOverlays is NOT nil, count: \(timeBased.count)")
            } else {
                print("📱 [Overlays] ❌ timeBasedTextOverlays is nil")
            }
            
            // Create parent layer for the video
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: size)
            
            // Create video layer
            let videoLayer = CALayer()
            videoLayer.frame = CGRect(origin: .zero, size: size)
            parentLayer.addSublayer(videoLayer)
            
            // Add image overlays (can be time-based)
            if let imageOverlays = imageOverlays {
                for (index, overlay) in imageOverlays.enumerated() {
                    if let imageLayer = createImageOverlayLayer(overlay: overlay, videoSize: size, videoDuration: audioDuration) {
                        parentLayer.addSublayer(imageLayer)
                        print("📱 [Overlays] Added image overlay \(index + 1)")
                    }
                }
            }
            
            // Add text overlays (can be time-based)
            if let textOverlays = textOverlays {
                for (index, overlay) in textOverlays.enumerated() {
                    if let textLayer = createTextOverlayLayer(overlay: overlay, videoSize: size, videoDuration: audioDuration) {
                        parentLayer.addSublayer(textLayer)
                        print("📱 [Overlays] Added text overlay \(index + 1)")
                    }
                }
            }
            
            // Add time-based text overlays (with animations)
            if let timeBasedTextOverlays = timeBasedTextOverlays {
                print("📱 [Overlays] Processing \(timeBasedTextOverlays.count) time-based text overlays")
                for (index, overlay) in timeBasedTextOverlays.enumerated() {
                    if let textLayer = createTimeBasedTextOverlayLayer(overlay: overlay, videoSize: size, videoDuration: audioDuration) {
                        // Ensure the layer is properly configured for video composition
                        textLayer.speed = 1.0
                        textLayer.timeOffset = 0.0
                        parentLayer.addSublayer(textLayer)
                        print("📱 [Overlays] ✅ Added time-based text overlay \(index + 1) - text: \"\(overlay["text"] as? String ?? "unknown")\"")
                    } else {
                        print("❌ [Overlays] Failed to create time-based text overlay \(index + 1)")
                    }
                }
            }
            
            // Configure parent layer for video composition
            parentLayer.speed = 1.0
            parentLayer.timeOffset = 0.0
            
            // Apply animation tool
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                postProcessingAsVideoLayer: videoLayer,
                in: parentLayer
            )
        }

        // Remove existing file if necessary
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: outputURL.path)
                print("Existing file at \(outputURL.path) removed.")
            } catch {
                print("Error removing existing file: \(error.localizedDescription)")
                completion(false, nil)
                return
            }
        }

        // Prepare high-quality export session
        guard
            let exportSession = AVAssetExportSession(
                asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else {
            print("Error: Unable to create export session.")
            completion(false, nil)
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        // Additional quality settings for export
        exportSession.shouldOptimizeForNetworkUse = false  // Prioritize quality over file size
        if #available(iOS 11.0, *) {
            exportSession.canPerformMultiplePassesOverSourceMediaData = true  // Enable multi-pass encoding for better quality
        }

        print("Export session configured. Output URL: \(outputURL)")

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                print("Export completed successfully. File saved at \(outputURL.path)")
                completion(true, outputURL)
            case .failed:
                if let error = exportSession.error {
                    print("Export failed: \(error.localizedDescription)")
                }
                completion(false, nil)
            case .cancelled:
                print("Export cancelled.")
                completion(false, nil)
            default:
                print("Export status: \(exportSession.status.rawValue)")
                completion(false, nil)
            }
        }
    }
}

func generateVideoFromImage(
    image: UIImage, duration: CMTime, outputURL: URL, completion: @escaping (Bool, URL?) -> Void
) {
    let size = CGSize(width: 1080, height: 1920)
    let frameRate: Int32 = 30
    let frameDuration = CMTime(value: 1, timescale: frameRate)

    // Remove existing file if it exists
    if FileManager.default.fileExists(atPath: outputURL.path) {
        do {
            try FileManager.default.removeItem(atPath: outputURL.path)
        } catch {
            print("Error removing existing file: \(error.localizedDescription)")
        }
    }

    guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
        print("Error: Unable to create AVAssetWriter.")
        completion(false, nil)
        return
    }

    // High-quality Instagram-optimized video settings
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 8_000_000,  // 8 Mbps for high quality (Instagram supports up to 10 Mbps)
            AVVideoMaxKeyFrameIntervalKey: 30,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
            AVVideoQualityKey: 0.9,  // High quality setting (0.0 to 1.0)
            AVVideoExpectedSourceFrameRateKey: 30,
            AVVideoAverageNonDroppableFrameRateKey: 30,
        ],
    ]

    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    writerInput.expectsMediaDataInRealTime = false

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: writerInput,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,  // Better compatibility
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
    )

    guard writer.canAdd(writerInput) else {
        print("Cannot add video writer input.")
        completion(false, nil)
        return
    }
    writer.add(writerInput)

    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    // Create multiple frames for the duration to make a proper video
    let totalFrames = Int(duration.seconds * Double(frameRate))
    print("Creating video with \(totalFrames) frames for \(duration.seconds) seconds")

    let queue = DispatchQueue(label: "videoWriterQueue")
    queue.async {
        var frameCount = 0

        while frameCount < totalFrames {
            let presentationTime = CMTime(value: Int64(frameCount), timescale: frameRate)

            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }

            guard let buffer = pixelBufferFromImage(image: image, size: size) else {
                print("Error creating pixel buffer for frame \(frameCount)")
                break
            }

            if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                print("Error appending pixel buffer for frame \(frameCount)")
                break
            }

            frameCount += 1
        }

        writerInput.markAsFinished()
        writer.finishWriting {
            DispatchQueue.main.async {
                if writer.status == .completed {
                    print("Video generation completed successfully with \(frameCount) frames.")
                    completion(true, outputURL)
                } else {
                    print("Video generation failed with status: \(writer.status.rawValue)")
                    if let error = writer.error {
                        print("Writer error: \(error.localizedDescription)")
                    }
                    completion(false, nil)
                }
            }
        }
    }
}

func pixelBufferFromImage(image: UIImage, size: CGSize) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        kCVPixelBufferWidthKey as String: size.width,
        kCVPixelBufferHeightKey as String: size.height,
    ]

    let result = CVPixelBufferCreate(
        kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA,
        attributes as CFDictionary, &pixelBuffer)

    guard result == kCVReturnSuccess, let buffer = pixelBuffer else {
        print("Error creating pixel buffer")
        return nil
    }

    CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

    // Use sRGB color space for better color accuracy
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        print("Error creating sRGB color space")
        return nil
    }

    let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
    )

    guard let cgContext = context else {
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        print("Error creating CG context")
        return nil
    }

    // Set high quality rendering
    cgContext.setAllowsAntialiasing(true)
    cgContext.setShouldAntialias(true)
    cgContext.interpolationQuality = .high

    // Scale and draw the image to fit the video size
    let imageRect = CGRect(origin: .zero, size: size)
    cgContext.clear(imageRect)

    if let cgImage = image.cgImage {
        // Ensure proper aspect ratio scaling
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let aspectFitRect = AVMakeRect(aspectRatio: imageSize, insideRect: imageRect)
        cgContext.draw(cgImage, in: aspectFitRect)
    }

    CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

    return buffer
}

func convertAudioToM4A(audioURL: URL, completion: @escaping (URL?) -> Void) {
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "converted-audio.m4a")

    // Remove existing file if necessary
    if FileManager.default.fileExists(atPath: outputURL.path) {
        do {
            try FileManager.default.removeItem(atPath: outputURL.path)
            print("Existing file at \(outputURL.path) removed.")
        } catch {
            print("Error removing existing file: \(error.localizedDescription)")
            completion(nil)
            return
        }
    }

    let asset = AVAsset(url: audioURL)
    guard
        let exportSession = AVAssetExportSession(
            asset: asset, presetName: AVAssetExportPresetAppleM4A)
    else {
        print("Error creating export session for audio conversion.")
        completion(nil)
        return
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
            print("Audio successfully converted to .m4a at \(outputURL.path)")
            completion(outputURL)
        case .failed:
            if let error = exportSession.error {
                print("Audio conversion failed: \(error.localizedDescription)")
            }
            completion(nil)
        case .cancelled:
            print("Audio conversion cancelled.")
            completion(nil)
        default:
            break
        }
    }
}

func isBase64Encoded(_ string: String) -> Bool {
    let base64Regex = "^([A-Za-z0-9+/=]{4})*([A-Za-z0-9+/=]{2}==|[A-Za-z0-9+/=]{3}=)?$"
    let base64Predicate = NSPredicate(format: "SELF MATCHES %@", base64Regex)
    return base64Predicate.evaluate(with: string)
}

// Helper function to create text overlay layer
func createTextOverlayLayer(overlay: [String: Any], videoSize: CGSize, videoDuration: CMTime? = nil) -> CATextLayer? {
    guard let text = overlay["text"] as? String,
          let xPercent = overlay["x"] as? Double,
          let yPercent = overlay["y"] as? Double,
          let fontSize = overlay["fontSize"] as? Double else {
        print("❌ [Overlays] Invalid text overlay data")
        return nil
    }
    
    let textLayer = CATextLayer()
    // Don't set string, fontSize, or foregroundColor here - will be set via attributed string below
    
    // Calculate position (percentages to pixels)
    // xPercent and yPercent are CENTER coordinates (from CSS transform: translate(-50%, -50%))
    // IMPORTANT: CALayer uses bottom-left origin (Y=0 at bottom, Y increases upward)
    // JavaScript sends coordinates with top-left origin (Y=0 at top, Y increases downward)
    // We need to convert from top-based to bottom-based coordinates
    let centerX = (xPercent / 100.0) * Double(videoSize.width)
    let centerYFromTop = (yPercent / 100.0) * Double(videoSize.height)
    let centerYFromBottom = Double(videoSize.height) - centerYFromTop
    
    // Calculate text size - use attributed string for accurate measurement
    // Use the actual font that will be rendered
    let fontFamily = overlay["fontFamily"] as? String
    let font: UIFont
    
    // Parse fontWeight and fontStyle
    let fontWeightString = overlay["fontWeight"] as? String ?? "normal"
    let fontStyleString = overlay["fontStyle"] as? String ?? "normal"
    let isBold = fontWeightString == "bold"
    let isItalic = fontStyleString == "italic"
    
    // Handle CSS font stacks and system fonts
    if let fontFamilyName = fontFamily, fontFamilyName != "System" {
        // Check for CSS font stacks (e.g., "system-ui, -apple-system, ...")
        let fontName = fontFamilyName.split(separator: ",").first?.trimmingCharacters(in: .whitespaces) ?? fontFamilyName
        
        // Map common CSS font names to iOS equivalents
        if fontName.lowercased().contains("system-ui") || fontName.lowercased().contains("apple-system") {
            if isBold && isItalic {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold).withTraits(.traitItalic)
            } else if isBold {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold)
            } else if isItalic {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize)).withTraits(.traitItalic)
            } else {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize))
            }
        } else if fontName.lowercased().contains("segoe") {
            // Fallback to system font
            if isBold && isItalic {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold).withTraits(.traitItalic)
            } else if isBold {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold)
            } else if isItalic {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize)).withTraits(.traitItalic)
            } else {
                font = UIFont.systemFont(ofSize: CGFloat(fontSize))
            }
        } else if fontName.lowercased().contains("roboto") {
            // Try to use Roboto if available, otherwise fallback
            let ctFont = CTFontCreateWithName("Roboto" as CFString, CGFloat(fontSize), nil)
            let baseFont = UIFont(descriptor: CTFontCopyFontDescriptor(ctFont), size: CGFloat(fontSize))
            var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
            if isBold { symbolicTraits.insert(.traitBold) }
            if isItalic { symbolicTraits.insert(.traitItalic) }
            if !symbolicTraits.isEmpty {
                font = baseFont.withTraits(symbolicTraits)
            } else {
                font = baseFont
            }
        } else {
            // Try to use the font name directly
            let ctFont = CTFontCreateWithName(fontName as CFString, CGFloat(fontSize), nil)
            let baseFont = UIFont(descriptor: CTFontCopyFontDescriptor(ctFont), size: CGFloat(fontSize))
            var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
            if isBold { symbolicTraits.insert(.traitBold) }
            if isItalic { symbolicTraits.insert(.traitItalic) }
            if !symbolicTraits.isEmpty {
                font = baseFont.withTraits(symbolicTraits)
            } else {
                font = baseFont
            }
        }
    } else {
        // System font
        if isBold && isItalic {
            font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold).withTraits(.traitItalic)
        } else if isBold {
            font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold)
        } else if isItalic {
            font = UIFont.systemFont(ofSize: CGFloat(fontSize)).withTraits(.traitItalic)
        } else {
            font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
    }
    
    // Parse shadow properties (defaults match preview: 2px 2px 4px rgba(0,0,0,0.8))
    let shadowColorString = overlay["shadowColor"] as? String ?? "rgba(0,0,0,0.8)"
    let shadowOffsetX = overlay["shadowOffsetX"] as? Double ?? 2.0
    let shadowOffsetY = overlay["shadowOffsetY"] as? Double ?? 2.0
    let shadowBlur = overlay["shadowBlur"] as? Double ?? 4.0
    
    let shadowColor = parseColor(shadowColorString) ?? UIColor.black.withAlphaComponent(0.8)
    
    // Create shadow attribute
    let shadow = NSShadow()
    shadow.shadowColor = shadowColor
    shadow.shadowOffset = CGSize(width: shadowOffsetX, height: shadowOffsetY)
    shadow.shadowBlurRadius = CGFloat(shadowBlur)
    
    // Create attributed string with font and shadow
    let attributedText = NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: parseColor(overlay["color"] as? String ?? "#FFFFFF") ?? UIColor.white,
            .shadow: shadow
        ]
    )
    // Calculate text size with proper width constraint for wrapping
    // Use video width minus padding to allow text to wrap naturally
    let maxTextWidth = videoSize.width - 200 // Leave padding on sides
    let textSize = attributedText.boundingRect(
        with: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        context: nil
    ).size
    
    // Calculate frame width - use actual text width plus padding
    let padding: CGFloat = 100 // More generous padding to prevent cutoff
    var frameWidth = min(textSize.width + padding, videoSize.width) // Don't exceed video width
    frameWidth = max(frameWidth, 200) // Minimum 200px width
    
    // Calculate frame height with padding for multi-line text
    let frameHeight = max(textSize.height + 40, 40)
    
    // Convert center coordinates to bottom-left corner for CALayer frame
    // CALayer frame.origin is the bottom-left corner
    let frameX = centerX - (frameWidth / 2.0)
    let frameY = centerYFromBottom - (frameHeight / 2.0)
    
    // Clamp to video bounds
    let adjustedFrameX = max(0, min(frameX, videoSize.width - frameWidth))
    let adjustedFrameY = max(0, min(frameY, videoSize.height - frameHeight))
    
    textLayer.frame = CGRect(
        x: adjustedFrameX,
        y: adjustedFrameY,
        width: frameWidth,
        height: frameHeight
    )
    textLayer.string = attributedText // Use attributed string with shadow
    textLayer.alignmentMode = .center // Center align to match UI (x/y are center positions)
    textLayer.isWrapped = true // Enable text wrapping if needed
    textLayer.contentsScale = UIScreen.main.scale
    
    print("📱 [Overlays] Text frame (BOTTOM-LEFT ORIGIN): centerX=\(centerX), centerY_from_top=\(centerYFromTop)px, centerY_from_bottom=\(centerYFromBottom)px, frameWidth=\(frameWidth), frameHeight=\(frameHeight), frame.origin.x=\(adjustedFrameX), frame.origin.y=\(adjustedFrameY)")
    
    // Check if this is a time-based overlay
    if let startTime = overlay["startTime"] as? Double,
       let endTime = overlay["endTime"] as? Double,
       let duration = videoDuration {
        // Set initial opacity to 0 (hidden)
        textLayer.opacity = 0.0
        
        // Create fade-in animation
        let fadeInDuration = min(0.3, (endTime - startTime) / 2.0)
        
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        fadeIn.duration = fadeInDuration
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false
        
        // Create fade-out animation
        let fadeOutStart = endTime - fadeInDuration
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + fadeOutStart
        fadeOut.duration = fadeInDuration
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        
        // Add animations to layer
        textLayer.add(fadeIn, forKey: "fadeIn")
        textLayer.add(fadeOut, forKey: "fadeOut")
        
        print("📱 [Overlays] Time-based text layer created: \"\(text)\" at (\(startTime)s - \(endTime)s)")
    } else {
        print("📱 [Overlays] Text layer created: \"\(text)\" at (\(adjustedFrameX), \(adjustedFrameY))")
    }
    
    return textLayer
}

// Helper function to create time-based text overlay layer with animations
func createTimeBasedTextOverlayLayer(overlay: [String: Any], videoSize: CGSize, videoDuration: CMTime) -> CATextLayer? {
    guard let text = overlay["text"] as? String,
          let xPercent = overlay["x"] as? Double,
          let yPercent = overlay["y"] as? Double,
          let fontSize = overlay["fontSize"] as? Double,
          let startTime = overlay["startTime"] as? Double,
          let endTime = overlay["endTime"] as? Double else {
        print("❌ [Overlays] Invalid time-based text overlay data")
        return nil
    }
    
    // Create the text layer (pass nil for videoDuration to skip the time-based check in createTextOverlayLayer)
    // We'll handle animations ourselves here
    var overlayWithoutTime = overlay
    overlayWithoutTime.removeValue(forKey: "startTime")
    overlayWithoutTime.removeValue(forKey: "endTime")
    guard let textLayer = createTextOverlayLayer(overlay: overlayWithoutTime, videoSize: videoSize, videoDuration: nil) else {
        return nil
    }
    
    // Use CAKeyframeAnimation for more reliable video composition timing
    // This explicitly defines opacity at key times throughout the video
    let totalDuration = videoDuration.seconds
    let fadeDuration = min(0.2, max(0.05, (endTime - startTime) / 4.0))
    
    // Create keyframe animation that defines opacity at each key time
    let keyframeAnimation = CAKeyframeAnimation(keyPath: "opacity")
    
    // Calculate key times (normalized 0.0 to 1.0)
    var keyTimes: [NSNumber] = []
    var values: [Any] = []
    
    // Before start: opacity 0
    if startTime > 0 {
        keyTimes.append(0.0)
        values.append(0.0)
    }
    
    // Fade in start
    let fadeInStart = max(0.0, startTime - fadeDuration)
    if fadeInStart > 0 && fadeInStart < totalDuration {
        keyTimes.append(NSNumber(value: fadeInStart / totalDuration))
        values.append(0.0)
    }
    
    // Fully visible
    let visibleStart = startTime
    let visibleEnd = endTime
    if visibleStart < totalDuration {
        keyTimes.append(NSNumber(value: visibleStart / totalDuration))
        values.append(1.0)
    }
    
    // Fade out
    let fadeOutStart = min(totalDuration, endTime)
    if fadeOutStart < totalDuration {
        keyTimes.append(NSNumber(value: fadeOutStart / totalDuration))
        values.append(1.0)
    }
    
    // After end: opacity 0
    let fadeOutEnd = min(totalDuration, endTime + fadeDuration)
    if fadeOutEnd < totalDuration {
        keyTimes.append(NSNumber(value: fadeOutEnd / totalDuration))
        values.append(0.0)
    }
    
    // End of video: opacity 0
    if fadeOutEnd < totalDuration {
        keyTimes.append(1.0)
        values.append(0.0)
    }
    
    keyframeAnimation.keyTimes = keyTimes
    keyframeAnimation.values = values
    keyframeAnimation.duration = totalDuration
    keyframeAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
    keyframeAnimation.fillMode = .forwards
    keyframeAnimation.isRemovedOnCompletion = false
    
    // Set initial opacity
    textLayer.opacity = (startTime <= 0.1) ? 1.0 : 0.0
    
    // Add animation
    textLayer.add(keyframeAnimation, forKey: "opacityAnimation")
    
    print("📱 [Overlays] Time-based text layer created: \"\(text)\" at (\(startTime)s - \(endTime)s) with \(keyTimes.count) keyframes")
    print("📱 [Overlays]   Key times: \(keyTimes.map { String(format: "%.2f", $0.doubleValue) }.joined(separator: ", "))")
    print("📱 [Overlays]   Values: \(values.map { String(format: "%.1f", ($0 as? Double ?? 0.0)) }.joined(separator: ", "))")
    return textLayer
}

// Helper function to create image overlay layer
func createImageOverlayLayer(overlay: [String: Any], videoSize: CGSize, videoDuration: CMTime? = nil) -> CALayer? {
    guard let xPercent = overlay["x"] as? Double,
          let yPercent = overlay["y"] as? Double,
          let widthPercent = overlay["width"] as? Double,
          let heightPercent = overlay["height"] as? Double else {
        print("❌ [Overlays] Invalid image overlay data")
        return nil
    }
    
    var image: UIImage?
    
    // Try to load image from path or base64
    if let imagePath = overlay["imagePath"] as? String {
        let url = URL(fileURLWithPath: imagePath)
        image = UIImage(contentsOfFile: url.path)
    } else if let imageData = overlay["imageData"] as? String {
        if let data = Data(base64Encoded: imageData) {
            // Decompress image data to reduce memory spikes during rendering
            if let decodedImage = UIImage(data: data) {
                // Force decode the image to avoid decompression during rendering
                UIGraphicsBeginImageContextWithOptions(decodedImage.size, false, 1.0)
                decodedImage.draw(at: .zero)
                image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
        }
    }
    
    guard let finalImage = image else {
        print("❌ [Overlays] Failed to load image")
        return nil
    }
    
    print("📱 [Overlays] Image loaded: \(finalImage.size.width)x\(finalImage.size.height)")
    
    // Calculate position and size (percentages to pixels)
    // xPercent and yPercent are CENTER coordinates (from CSS transform: translate(-50%, -50%))
    // IMPORTANT: CALayer uses bottom-left origin (Y=0 at bottom, Y increases upward)
    // JavaScript sends coordinates with top-left origin (Y=0 at top, Y increases downward)
    // We need to convert from top-based to bottom-based coordinates
    let centerX = (xPercent / 100.0) * Double(videoSize.width)
    let noInvertY = overlay["noInvertY"] as? Bool ?? false
    print("📱 [Overlays] 🔍 WATERMARK DEBUG: noInvertY flag = \(noInvertY), yPercent received = \(yPercent)")
    
    let width = (widthPercent / 100.0) * Double(videoSize.width)
    let height = (heightPercent / 100.0) * Double(videoSize.height)
    
    // Convert center coordinates to bottom-left origin for CALayer
    // CALayer frame.origin is the bottom-left corner
    let x = centerX - (width / 2.0)
    let y: Double
    
    if noInvertY {
        // Watermark sends BOTTOM position (large Y value like 96% from top)
        // Convert from top-based to bottom-based: centerY_from_bottom = videoHeight - centerY_from_top
        // Then calculate bottom-left corner: y = centerY_from_bottom - (height/2)
        let centerYFromTop = (yPercent / 100.0) * Double(videoSize.height)
        let centerYFromBottom = Double(videoSize.height) - centerYFromTop
        y = centerYFromBottom - (height / 2.0)
        print("📱 [Overlays] 🔍 WATERMARK (BOTTOM-LEFT ORIGIN): yPercent=\(yPercent)% from top, centerY_from_top=\(centerYFromTop)px, centerY_from_bottom=\(centerYFromBottom)px, frame.origin.y=\(y)px")
    } else {
        // Other images: convert from top-based to bottom-based coordinates
        let centerYFromTop = (yPercent / 100.0) * Double(videoSize.height)
        let centerYFromBottom = Double(videoSize.height) - centerYFromTop
        y = centerYFromBottom - (height / 2.0)
        print("📱 [Overlays] Image Y calculation (BOTTOM-LEFT ORIGIN): yPercent=\(yPercent)% from top, centerY_from_top=\(centerYFromTop)px, centerY_from_bottom=\(centerYFromBottom)px, frame.origin.y=\(y)px")
    }
    
    print("📱 [Overlays] Image frame calc: centerX=\(centerX), width=\(width), height=\(height), frame.origin.x=\(x), frame.origin.y=\(y)")
    
    let imageLayer = CALayer()
    imageLayer.frame = CGRect(x: x, y: y, width: width, height: height)
    imageLayer.contents = finalImage.cgImage
    // Use .resize for full-screen overlays (100% width/height) to stretch exactly
    // Use .resizeAspect for partial overlays to maintain aspect ratio
    imageLayer.contentsGravity = (widthPercent >= 99 && heightPercent >= 99) ? .resize : .resizeAspect
    
    // Apply corner radius if specified (for cover art rounded corners)
    if let cornerRadius = overlay["cornerRadius"] as? Double, cornerRadius > 0 {
        imageLayer.cornerRadius = CGFloat(cornerRadius)
        imageLayer.masksToBounds = true
        print("📱 [Overlays] Applied corner radius: \(cornerRadius)px")
    }
    
    // Check if this is a time-based overlay
    if let startTime = overlay["startTime"] as? Double,
       let endTime = overlay["endTime"] as? Double,
       let duration = videoDuration {
        // Set initial opacity to 0 (hidden)
        imageLayer.opacity = 0.0
        
        // Create fade-in animation
        let fadeInDuration = CMTime(seconds: min(0.3, (endTime - startTime) / 2.0), preferredTimescale: 600)
        
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        fadeIn.duration = fadeInDuration.seconds
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false
        
        // Create fade-out animation
        let fadeOutStart = endTime - fadeInDuration.seconds
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + fadeOutStart
        fadeOut.duration = fadeInDuration.seconds
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        
        // Add animations to layer
        imageLayer.add(fadeIn, forKey: "fadeIn")
        imageLayer.add(fadeOut, forKey: "fadeOut")
        
        print("📱 [Overlays] Time-based image layer created at (\(startTime)s - \(endTime)s)")
    } else {
    print("📱 [Overlays] Image layer created at (\(x), \(y)) with size (\(width)x\(height)) - gravity: \(imageLayer.contentsGravity)")
    }
    
    return imageLayer
}

// Helper function to parse color string (hex or rgba)
func parseColor(_ colorString: String) -> UIColor? {
    // Try hex format first
    if colorString.hasPrefix("#") {
        return UIColor(hex: colorString)
    }
    
    // Try rgba format
    if colorString.hasPrefix("rgba") {
        let components = colorString
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        
        if components.count == 4 {
            return UIColor(
                red: CGFloat(components[0]) / 255.0,
                green: CGFloat(components[1]) / 255.0,
                blue: CGFloat(components[2]) / 255.0,
                alpha: CGFloat(components[3])
            )
        }
    }
    
    // Try rgb format
    if colorString.hasPrefix("rgb") {
        let components = colorString
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        
        if components.count == 3 {
            return UIColor(
                red: CGFloat(components[0]) / 255.0,
                green: CGFloat(components[1]) / 255.0,
                blue: CGFloat(components[2]) / 255.0,
                alpha: 1.0
            )
        }
    }
    
    return nil
}

// Apply overlays to an existing video
func applyOverlaysToVideo(
    videoURL: URL,
    outputURL: URL,
    textOverlays: [[String: Any]]?,
    imageOverlays: [[String: Any]]?,
    timeBasedTextOverlays: [[String: Any]]? = nil,
    completion: @escaping (Bool, URL?) -> Void
) {
    print("📱 [Overlays] Starting overlay application to video")
    
    let videoAsset = AVURLAsset(url: videoURL)
    guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
        print("❌ [Overlays] No video track found")
        completion(false, nil)
        return
    }
    
    let composition = AVMutableComposition()
    let videoDuration = videoAsset.duration
    
    // Add video track
    guard let compositionVideoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
        print("❌ [Overlays] Failed to add video track to composition")
        completion(false, nil)
        return
    }
    
    do {
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )
        compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
    } catch {
        print("❌ [Overlays] Failed to insert video track: \(error)")
        completion(false, nil)
        return
    }
    
    // DO NOT add audio track from original video - we want video only
    // (This function is for overlays only, audio replacement is handled elsewhere)
    print("📱 [Overlays] Video track added, NO audio track (video will be silent or use external audio)")
    
    // Create video composition with overlays
    // ALWAYS use 1080x1920 for render size and overlay calculations (Instagram story format)
    // The video will be scaled to fit within this size
    let targetSize = CGSize(width: 1080, height: 1920)
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = targetSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: videoDuration)
    
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
    
    // Scale video to fit within 1080x1920 while maintaining aspect ratio
    let naturalSize = videoTrack.naturalSize
    let scaleX = targetSize.width / naturalSize.width
    let scaleY = targetSize.height / naturalSize.height
    let scale = min(scaleX, scaleY) // Use the smaller scale to ensure video fits
    
    // Calculate centered position
    let scaledWidth = naturalSize.width * scale
    let scaledHeight = naturalSize.height * scale
    let xOffset = (targetSize.width - scaledWidth) / 2.0
    let yOffset = (targetSize.height - scaledHeight) / 2.0
    
    // Apply transform to scale and center the video
    layerInstruction.setTransform(
        CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: xOffset, y: yOffset)),
        at: .zero
    )
    
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]
    
    // Add overlays if provided
    if (textOverlays != nil && !textOverlays!.isEmpty) || (imageOverlays != nil && !imageOverlays!.isEmpty) || (timeBasedTextOverlays != nil && !timeBasedTextOverlays!.isEmpty) {
        print("📱 [Overlays] Creating overlay layers")
        print("📱 [Overlays] Video natural size: \(naturalSize.width)x\(naturalSize.height)")
        print("📱 [Overlays] Target render size: \(targetSize.width)x\(targetSize.height)")
        print("📱 [Overlays] Video scale: \(scale), offset: (\(xOffset), \(yOffset))")
        
        // Create parent layer for the video - use target size (1080x1920)
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: targetSize)
        
        // Create video layer - will be scaled and positioned by layerInstruction transform
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: targetSize)
        parentLayer.addSublayer(videoLayer)
        
        // Add image overlays (can be time-based) - use target size for calculations
        if let imageOverlays = imageOverlays {
            for (index, overlay) in imageOverlays.enumerated() {
                if let imageLayer = createImageOverlayLayer(overlay: overlay, videoSize: targetSize, videoDuration: videoDuration) {
                    parentLayer.addSublayer(imageLayer)
                    print("📱 [Overlays] Added image overlay \(index + 1)")
                }
            }
        }
        
        // Add text overlays (can be time-based) - use target size for calculations
        if let textOverlays = textOverlays {
            for (index, overlay) in textOverlays.enumerated() {
                if let textLayer = createTextOverlayLayer(overlay: overlay, videoSize: targetSize, videoDuration: videoDuration) {
                    parentLayer.addSublayer(textLayer)
                    print("📱 [Overlays] Added text overlay \(index + 1)")
                }
            }
        }
        
        // Add time-based text overlays (with animations) - use target size for calculations
        if let timeBasedTextOverlays = timeBasedTextOverlays {
            for (index, overlay) in timeBasedTextOverlays.enumerated() {
                if let textLayer = createTimeBasedTextOverlayLayer(overlay: overlay, videoSize: targetSize, videoDuration: videoDuration) {
                    parentLayer.addSublayer(textLayer)
                    print("📱 [Overlays] Added time-based text overlay \(index + 1)")
                }
            }
        }
        
        // Apply animation tool
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }
    
    // Remove existing file if necessary
    if FileManager.default.fileExists(atPath: outputURL.path) {
        do {
            try FileManager.default.removeItem(atPath: outputURL.path)
            print("📱 [Overlays] Removed existing file at output path")
        } catch {
            print("❌ [Overlays] Failed to remove existing file: \(error)")
            completion(false, nil)
            return
        }
    }
    
    // Export video with overlays
    guard let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetHighestQuality
    ) else {
        print("❌ [Overlays] Failed to create export session")
        completion(false, nil)
        return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.videoComposition = videoComposition
    exportSession.shouldOptimizeForNetworkUse = false
    
    if #available(iOS 11.0, *) {
        exportSession.canPerformMultiplePassesOverSourceMediaData = true
    }
    
    print("📱 [Overlays] Starting export...")
    exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
            print("✅ [Overlays] Export completed successfully")
            completion(true, outputURL)
        case .failed:
            if let error = exportSession.error {
                print("❌ [Overlays] Export failed: \(error.localizedDescription)")
            }
            completion(false, nil)
        case .cancelled:
            print("⚠️ [Overlays] Export cancelled")
            completion(false, nil)
        default:
            print("❌ [Overlays] Export status: \(exportSession.status.rawValue)")
            completion(false, nil)
        }
    }
}

// Replace video's audio track with new audio and apply overlays
func replaceVideoAudioAndApplyOverlays(
    videoURL: URL,
    audioURL: URL,
    outputURL: URL,
    startTime: Double,
    duration: Double?,
    videoStartTime: Double? = nil,
    textOverlays: [[String: Any]]?,
    imageOverlays: [[String: Any]]?,
    timeBasedTextOverlays: [[String: Any]]? = nil,
    completion: @escaping (Bool, URL?) -> Void
) {
    print("📱 [Audio+Overlays] Starting video audio replacement and overlay application")
    print("📱 [Audio+Overlays] Video: \(videoURL.path)")
    print("📱 [Audio+Overlays] Audio: \(audioURL.path)")
    print("📱 [Audio+Overlays] Audio start time: \(startTime)s, Duration: \(duration?.description ?? "auto")")
    print("📱 [Audio+Overlays] Video start time: \(videoStartTime ?? 0)s")
    
    let videoAsset = AVURLAsset(url: videoURL)
    let audioAsset = AVURLAsset(url: audioURL)
    
    guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
        print("❌ [Audio+Overlays] No video track found")
        completion(false, nil)
        return
    }
    
    let composition = AVMutableComposition()
    
    // Calculate duration
    let audioStartTime = CMTime(seconds: startTime, preferredTimescale: 600)
    let videoDuration = videoAsset.duration
    let audioDuration = audioAsset.duration
    let audioRemainingDuration = CMTimeSubtract(audioDuration, audioStartTime)
    
    // Calculate video start time within the video file
    let videoStartTimeCM = CMTime(seconds: videoStartTime ?? 0, preferredTimescale: 600)
    let videoAvailableDuration = CMTimeSubtract(videoDuration, videoStartTimeCM)
    
    print("🎵 [Audio+Overlays] Audio clip parameters:")
    print("   - Start time: \(startTime)s")
    print("   - Requested duration: \(duration ?? 0)s")
    print("   - Audio start time (CMTime): \(CMTimeGetSeconds(audioStartTime))s")
    print("🎥 [Audio+Overlays] Video clip parameters:")
    print("   - Video start time: \(videoStartTime ?? 0)s")
    print("   - Video start time (CMTime): \(CMTimeGetSeconds(videoStartTimeCM))s")
    print("   - Video available duration from start: \(CMTimeGetSeconds(videoAvailableDuration))s")
    
    // Use the shorter of: available video duration, specified duration, or remaining audio duration
    var finalDuration = videoAvailableDuration
    if let specifiedDuration = duration {
        let specifiedCMTime = CMTime(seconds: specifiedDuration, preferredTimescale: 600)
        finalDuration = CMTimeMinimum(finalDuration, specifiedCMTime)
        print("   - Using specified duration: \(specifiedDuration)s")
    }
    finalDuration = CMTimeMinimum(finalDuration, audioRemainingDuration)
    
    print("📱 [Audio+Overlays] Video duration: \(CMTimeGetSeconds(videoDuration))s")
    print("📱 [Audio+Overlays] Audio duration: \(CMTimeGetSeconds(audioDuration))s")
    print("📱 [Audio+Overlays] Audio remaining from start: \(CMTimeGetSeconds(audioRemainingDuration))s")
    print("📱 [Audio+Overlays] Final duration: \(CMTimeGetSeconds(finalDuration))s")
    
    // Verify original video has audio tracks (for logging)
    let originalAudioTracks = videoAsset.tracks(withMediaType: .audio)
    print("📱 [Audio+Overlays] Original video has \(originalAudioTracks.count) audio track(s)")
    if originalAudioTracks.count > 0 {
        print("📱 [Audio+Overlays] ⚠️ STRIPPING original video audio - will NOT be included in output")
        for (index, audioTrack) in originalAudioTracks.enumerated() {
            print("📱 [Audio+Overlays]   - Audio track \(index): ID=\(audioTrack.trackID), duration=\(CMTimeGetSeconds(audioTrack.timeRange.duration))s")
        }
    }
    
    // CRITICAL: Verify we're NOT accidentally adding audio tracks from the video
    print("📱 [Audio+Overlays] Video track to be added: ID=\(videoTrack.trackID), mediaType=\(videoTrack.mediaType)")
    
    // Add ONLY the video track (EXPLICITLY excluding all audio from original video)
    guard let compositionVideoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
        print("❌ [Audio+Overlays] Failed to add video track to composition")
        completion(false, nil)
        return
    }
    
    do {
        // Extract video from the specified start time within the video file
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: videoStartTimeCM, duration: finalDuration),
            of: videoTrack,
            at: .zero
        )
        // CRITICAL: Set preferred transform to maintain video orientation
        compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
        
        print("✅ [Audio+Overlays] Video track added successfully (original audio EXCLUDED)")
        print("📱 [Audio+Overlays] Composition now has \(composition.tracks(withMediaType: .audio).count) audio track(s) - should be 0 before adding new audio")
        
        // VERIFY: Ensure NO audio tracks exist in composition yet
        let audioTracksCount = composition.tracks(withMediaType: .audio).count
        if audioTracksCount > 0 {
            print("❌ [Audio+Overlays] ERROR: Composition has \(audioTracksCount) audio track(s) when it should have 0!")
            print("❌ [Audio+Overlays] This means original video audio is leaking through!")
        }
    } catch {
        print("❌ [Audio+Overlays] Failed to insert video track: \(error)")
        completion(false, nil)
        return
    }
    
    // Add new audio track (replacing the original)
    guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
        print("❌ [Audio+Overlays] No audio track found in audio file")
        completion(false, nil)
        return
    }
    
    guard let compositionAudioTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
        print("❌ [Audio+Overlays] Failed to create audio track in composition")
        completion(false, nil)
        return
    }
    
    do {
        try compositionAudioTrack.insertTimeRange(
            CMTimeRange(start: audioStartTime, duration: finalDuration),
            of: audioTrack,
            at: .zero
        )
        print("✅ [Audio+Overlays] NEW audio track added successfully")
        print("📱 [Audio+Overlays] Composition now has \(composition.tracks(withMediaType: .audio).count) audio track(s) - should be 1 (new audio only)")
        print("📱 [Audio+Overlays] ✅ VERIFIED: Original video audio stripped, new song audio added")
    } catch {
        print("❌ [Audio+Overlays] Failed to insert audio track: \(error)")
        completion(false, nil)
        return
    }
    
    // Create video composition with overlays
    // ALWAYS use 1080x1920 for render size and overlay calculations (Instagram story format)
    // The video will be scaled to fit within this size
    let targetSize = CGSize(width: 1080, height: 1920)
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = targetSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: finalDuration)
    
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
    
    // Scale video to fit within 1080x1920 while maintaining aspect ratio
    let naturalSize = videoTrack.naturalSize
    let scaleX = targetSize.width / naturalSize.width
    let scaleY = targetSize.height / naturalSize.height
    let scale = min(scaleX, scaleY) // Use the smaller scale to ensure video fits
    
    // Calculate centered position
    let scaledWidth = naturalSize.width * scale
    let scaledHeight = naturalSize.height * scale
    let xOffset = (targetSize.width - scaledWidth) / 2.0
    let yOffset = (targetSize.height - scaledHeight) / 2.0
    
    // Apply transform to scale and center the video
    layerInstruction.setTransform(
        CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: xOffset, y: yOffset)),
        at: .zero
    )
    
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]
    
    // Add overlays if provided
    if (textOverlays != nil && !textOverlays!.isEmpty) || (imageOverlays != nil && !imageOverlays!.isEmpty) || (timeBasedTextOverlays != nil && !timeBasedTextOverlays!.isEmpty) {
        print("📱 [Audio+Overlays] Creating overlay layers")
        print("📱 [Audio+Overlays] Video natural size: \(naturalSize.width)x\(naturalSize.height)")
        print("📱 [Audio+Overlays] Target render size: \(targetSize.width)x\(targetSize.height)")
        print("📱 [Audio+Overlays] Video scale: \(scale), offset: (\(xOffset), \(yOffset))")
        
        // Create parent layer for the video - use target size (1080x1920)
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: targetSize)
        
        // Create video layer - will be scaled and positioned by layerInstruction transform
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: targetSize)
        parentLayer.addSublayer(videoLayer)
        
        // Add image overlays (can be time-based) - use target size for calculations
        if let imageOverlays = imageOverlays {
            for (index, overlay) in imageOverlays.enumerated() {
                if let imageLayer = createImageOverlayLayer(overlay: overlay, videoSize: targetSize, videoDuration: finalDuration) {
                    parentLayer.addSublayer(imageLayer)
                    print("📱 [Audio+Overlays] Added image overlay \(index + 1)")
                }
            }
        }
        
        // Add text overlays (can be time-based) - use target size for calculations
        if let textOverlays = textOverlays {
            for (index, overlay) in textOverlays.enumerated() {
                if let textLayer = createTextOverlayLayer(overlay: overlay, videoSize: targetSize, videoDuration: finalDuration) {
                    parentLayer.addSublayer(textLayer)
                    print("📱 [Audio+Overlays] Added text overlay \(index + 1)")
                }
            }
        }
        
        // Add time-based text overlays (with animations) - use target size for calculations
        if let timeBasedTextOverlays = timeBasedTextOverlays {
            for (index, overlay) in timeBasedTextOverlays.enumerated() {
                if let textLayer = createTimeBasedTextOverlayLayer(overlay: overlay, videoSize: targetSize, videoDuration: finalDuration) {
                    parentLayer.addSublayer(textLayer)
                    print("📱 [Audio+Overlays] Added time-based text overlay \(index + 1)")
                }
            }
        }
        
        // Apply animation tool
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }
    
    // Remove existing file if necessary
    if FileManager.default.fileExists(atPath: outputURL.path) {
        do {
            try FileManager.default.removeItem(atPath: outputURL.path)
            print("📱 [Audio+Overlays] Removed existing file at output path")
        } catch {
            print("❌ [Audio+Overlays] Failed to remove existing file: \(error)")
            completion(false, nil)
            return
        }
    }
    
    // Export video with new audio and overlays
    // Use Medium quality preset to reduce memory usage (Instagram will compress anyway)
    guard let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPreset1920x1080
    ) else {
        print("❌ [Audio+Overlays] Failed to create export session")
        completion(false, nil)
        return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.videoComposition = videoComposition
    exportSession.shouldOptimizeForNetworkUse = true // Optimize for sharing
    
    // Create audio mix for the new audio track
    let audioMix = AVMutableAudioMix()
    let audioMixInputParameters = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
    audioMixInputParameters.setVolume(1.0, at: .zero) // Full volume for new audio
    audioMix.inputParameters = [audioMixInputParameters]
    exportSession.audioMix = audioMix
    
    print("📱 [Audio+Overlays] Audio mix configured - new audio at 100% volume")
    
    // Disable multiple passes to reduce memory usage
    if #available(iOS 11.0, *) {
        exportSession.canPerformMultiplePassesOverSourceMediaData = false
    }
    
    print("📱 [Audio+Overlays] Starting export...")
    print("📱 [Audio+Overlays] Final composition tracks: \(composition.tracks.count) total, \(composition.tracks(withMediaType: .video).count) video, \(composition.tracks(withMediaType: .audio).count) audio")
    exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
            print("✅ [Audio+Overlays] Export completed successfully")
            
            // VERIFY: Check what tracks are in the exported file
            let exportedAsset = AVURLAsset(url: outputURL)
            let exportedVideoTracks = exportedAsset.tracks(withMediaType: .video)
            let exportedAudioTracks = exportedAsset.tracks(withMediaType: .audio)
            print("📱 [Audio+Overlays] EXPORTED FILE VERIFICATION:")
            print("📱 [Audio+Overlays]   - Video tracks: \(exportedVideoTracks.count)")
            print("📱 [Audio+Overlays]   - Audio tracks: \(exportedAudioTracks.count)")
            for (index, audioTrack) in exportedAudioTracks.enumerated() {
                print("📱 [Audio+Overlays]   - Audio track \(index): ID=\(audioTrack.trackID), duration=\(CMTimeGetSeconds(audioTrack.timeRange.duration))s")
            }
            if exportedAudioTracks.count != 1 {
                print("❌ [Audio+Overlays] ERROR: Expected 1 audio track (new song), found \(exportedAudioTracks.count)!")
            }
            
            completion(true, outputURL)
        case .failed:
            if let error = exportSession.error {
                print("❌ [Audio+Overlays] Export failed: \(error.localizedDescription)")
            }
            completion(false, nil)
        case .cancelled:
            print("⚠️ [Audio+Overlays] Export cancelled")
            completion(false, nil)
        default:
            print("❌ [Audio+Overlays] Export status: \(exportSession.status.rawValue)")
            completion(false, nil)
        }
    }
}
