import Foundation
import UIKit
import SwiftUI

@Observable
final class AvatarService {
    static let shared = AvatarService()

    var isProcessing = false
    var isStylizing = false
    var stylizationProgress: Double = 0.0
    var lastError: String?

    private init() {}

    // MARK: - Image Processing

    /// Process and crop image for avatar use
    func processImage(_ image: UIImage, profile: AvatarProfile) {
        isProcessing = true
        defer { isProcessing = false }

        profile.setOriginalPhoto(image)
    }

    /// Crop image to specific region
    func cropImage(_ image: UIImage, to rect: CGRect, profile: AvatarProfile) {
        isProcessing = true
        defer { isProcessing = false }

        guard let cgImage = image.cgImage else { return }

        // Convert rect to image coordinates
        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )

        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return }
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: scale, orientation: image.imageOrientation)

        profile.setProcessedPhoto(croppedImage)
    }

    // MARK: - AI Stylization

    /// Generate stylized avatar using AI
    func stylizeAvatar(
        profile: AvatarProfile,
        aiService: AIService
    ) async throws {
        guard let imageData = profile.processedPhotoData ?? profile.originalPhotoData else {
            throw AvatarError.noImage
        }

        isStylizing = true
        stylizationProgress = 0.0
        lastError = nil
        profile.startStylization(provider: aiService.selectedProvider.rawValue)

        defer { isStylizing = false }

        // Note: This is a placeholder for actual AI image generation
        // In production, you would use an image generation API like:
        // - DALL-E 3 (OpenAI)
        // - Stable Diffusion
        // - Midjourney API
        // - Custom trained model

        stylizationProgress = 0.3

        // For now, we'll apply a simple filter as a demonstration
        // In a real implementation, send to AI service
        guard let originalImage = UIImage(data: imageData) else {
            profile.failStylization()
            throw AvatarError.invalidImage
        }

        stylizationProgress = 0.5

        // Apply style-based filter (placeholder)
        let stylizedImage = applyStyleFilter(to: originalImage, style: profile.style)

        stylizationProgress = 0.8

        if let stylized = stylizedImage {
            profile.setStylizedPhoto(stylized)
            stylizationProgress = 1.0
        } else {
            profile.failStylization()
            throw AvatarError.stylizationFailed
        }
    }

    /// Apply style filter (placeholder for AI stylization)
    private func applyStyleFilter(to image: UIImage, style: AvatarStyle) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let context = CIContext()
        var outputImage: CIImage = ciImage

        switch style {
        case .realistic:
            // Enhance slightly
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(1.05, forKey: kCIInputContrastKey)
                filter.setValue(1.02, forKey: kCIInputSaturationKey)
                outputImage = filter.outputImage ?? ciImage
            }

        case .cartoon:
            // Posterize + edge detection simulation
            if let posterize = CIFilter(name: "CIColorPosterize") {
                posterize.setValue(ciImage, forKey: kCIInputImageKey)
                posterize.setValue(6, forKey: "inputLevels")
                outputImage = posterize.outputImage ?? ciImage
            }

        case .anime:
            // High contrast + saturation boost
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(1.2, forKey: kCIInputContrastKey)
                filter.setValue(1.3, forKey: kCIInputSaturationKey)
                outputImage = filter.outputImage ?? ciImage
            }

        case .sketch:
            // Noir effect for sketch-like appearance
            if let filter = CIFilter(name: "CIPhotoEffectNoir") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                outputImage = filter.outputImage ?? ciImage
            }

        case .watercolor:
            // Soft blur + saturation
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(ciImage, forKey: kCIInputImageKey)
                blur.setValue(1.5, forKey: kCIInputRadiusKey)
                if let blurred = blur.outputImage,
                   let color = CIFilter(name: "CIColorControls") {
                    color.setValue(blurred, forKey: kCIInputImageKey)
                    color.setValue(0.95, forKey: kCIInputSaturationKey)
                    color.setValue(1.1, forKey: kCIInputBrightnessKey)
                    outputImage = color.outputImage ?? ciImage
                }
            }

        case .minimal:
            // High contrast black and white
            if let filter = CIFilter(name: "CIPhotoEffectMono") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                if let mono = filter.outputImage,
                   let contrast = CIFilter(name: "CIColorControls") {
                    contrast.setValue(mono, forKey: kCIInputImageKey)
                    contrast.setValue(1.5, forKey: kCIInputContrastKey)
                    outputImage = contrast.outputImage ?? ciImage
                }
            }
        }

        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Export

    /// Export avatar image
    func exportAvatar(profile: AvatarProfile, size: CGFloat = 512) -> UIImage? {
        guard let data = profile.displayPhoto,
              let image = UIImage(data: data) else {
            return nil
        }

        // Resize to requested size
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            // Draw background
            let bgColor = UIColor(profile.backgroundColorValue)
            bgColor.setFill()

            switch profile.frameStyle {
            case .circle:
                let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size))
                path.fill()
                path.addClip()

            case .roundedSquare:
                let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerRadius: size * 0.2)
                path.fill()
                path.addClip()

            case .square:
                context.cgContext.fill(CGRect(x: 0, y: 0, width: size, height: size))

            case .hexagon:
                let path = hexagonPath(size: size)
                path.fill()
                path.addClip()
            }

            // Draw image
            image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    private func hexagonPath(size: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = size / 2

        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3 - CGFloat.pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        return path
    }
}

// MARK: - Errors

enum AvatarError: LocalizedError {
    case noImage
    case invalidImage
    case stylizationFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .noImage:
            return String(localized: "avatar.error.no_image")
        case .invalidImage:
            return String(localized: "avatar.error.invalid_image")
        case .stylizationFailed:
            return String(localized: "avatar.error.stylization_failed")
        case .exportFailed:
            return String(localized: "avatar.error.export_failed")
        }
    }
}
