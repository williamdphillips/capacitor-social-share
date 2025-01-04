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

func createVideoFromImageAndAudio(audioURL: URL, outputURL: URL, startTime: Double, backgroundColor: String?, backgroundImage: UIImage?, completion: @escaping (Bool, URL?) -> Void) {
    let size = CGSize(width: 1080, height: 1920)
    let maxDuration = CMTime(seconds: 15, preferredTimescale: 600)

    print("Starting video creation process with provided background...")

    let background: UIImage?
    if let bgImage = backgroundImage {
        print("Using provided background image.")
        background = bgImage
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
            createVideoFromImageAndAudio(audioURL: convertedAudioURL, outputURL: outputURL, startTime: startTime, backgroundColor: backgroundColor, backgroundImage: backgroundImage, completion: completion)
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
    guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        print("Error: Unable to add audio track to composition.")
        completion(false, nil)
        return
    }

    let audioStartTime = CMTime(seconds: startTime, preferredTimescale: 600)
    let audioDuration = min(CMTime(seconds: 15, preferredTimescale: 600), audioAsset.duration - audioStartTime)

    do {
        try audioTrack.insertTimeRange(CMTimeRange(start: audioStartTime, duration: audioDuration), of: audioTrackSource, at: .zero)
        print("Audio track inserted successfully with duration: \(audioDuration.seconds) seconds")
    } catch {
        print("Error inserting audio track: \(error.localizedDescription)")
        completion(false, nil)
        return
    }

    // Generate a video from the background image
    let videoURL = outputURL.deletingLastPathComponent().appendingPathComponent("temp_video_\(Date().timeIntervalSince1970).mp4")
    generateVideoFromImage(image: finalBackground, duration: audioDuration, outputURL: videoURL) { success, videoPath in
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

        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Error: Unable to add video track to composition.")
            completion(false, nil)
            return
        }

        do {
            try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration), of: videoTrackSource, at: .zero)
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

        // Prepare export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error: Unable to create export session.")
            completion(false, nil)
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

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

func generateVideoFromImage(image: UIImage, duration: CMTime, outputURL: URL, completion: @escaping (Bool, URL?) -> Void) {
    let size = CGSize(width: 1080, height: 1920)

    guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
        print("Error: Unable to create AVAssetWriter.")
        completion(false, nil)
        return
    }

    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height
    ]
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: writerInput,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
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

    let buffer = pixelBufferFromImage(image: image, size: size)
    adaptor.append(buffer, withPresentationTime: .zero)

    writerInput.markAsFinished()
    writer.finishWriting {
        print("Video generation completed.")
        completion(true, outputURL)
    }
}

func pixelBufferFromImage(image: UIImage, size: CGSize) -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        kCVPixelBufferWidthKey as String: size.width,
        kCVPixelBufferHeightKey as String: size.height
    ]
    CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixelBuffer)

    let context = CIContext()
    context.render(CIImage(image: image)!, to: pixelBuffer!)

    return pixelBuffer!
}

func convertAudioToM4A(audioURL: URL, completion: @escaping (URL?) -> Void) {
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("converted-audio.m4a")

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
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
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
