import Foundation
import SwiftData
import SwiftUI

@Model
final class AvatarProfile {
    var id: UUID

    // Avatar images
    var originalPhotoData: Data?        // Original uploaded photo
    var processedPhotoData: Data?       // Processed/cropped photo
    var stylizedPhotoData: Data?        // AI-stylized version

    // Style settings
    var style: AvatarStyle
    var backgroundColor: String?        // Hex color for background
    var frameStyle: AvatarFrameStyle

    // Generation status
    var stylizationStatus: AvatarStylizationStatus
    var stylizationProvider: String?
    var lastStylizedAt: Date?

    // Display preferences
    var useStylizedVersion: Bool        // Use stylized or original
    var showInChat: Bool                // Show avatar in AI chat
    var showInProfile: Bool             // Show in Soul Profile

    var createdAt: Date
    var updatedAt: Date

    init() {
        self.id = UUID()
        self.originalPhotoData = nil
        self.processedPhotoData = nil
        self.stylizedPhotoData = nil
        self.style = .realistic
        self.backgroundColor = nil
        self.frameStyle = .circle
        self.stylizationStatus = .none
        self.stylizationProvider = nil
        self.lastStylizedAt = nil
        self.useStylizedVersion = false
        self.showInChat = true
        self.showInProfile = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    var hasPhoto: Bool {
        originalPhotoData != nil || processedPhotoData != nil
    }

    var hasStylizedVersion: Bool {
        stylizedPhotoData != nil && stylizationStatus == .ready
    }

    var displayPhoto: Data? {
        if useStylizedVersion && hasStylizedVersion {
            return stylizedPhotoData
        }
        return processedPhotoData ?? originalPhotoData
    }

    var displayImage: Image? {
        guard let data = displayPhoto,
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    var originalImage: UIImage? {
        guard let data = originalPhotoData else { return nil }
        return UIImage(data: data)
    }

    var processedImage: UIImage? {
        guard let data = processedPhotoData else { return nil }
        return UIImage(data: data)
    }

    var stylizedImage: UIImage? {
        guard let data = stylizedPhotoData else { return nil }
        return UIImage(data: data)
    }

    var backgroundColorValue: Color {
        guard let hex = backgroundColor else {
            return style.defaultBackgroundColor
        }
        return Color(hex: hex) ?? style.defaultBackgroundColor
    }

    var statusDescription: String {
        switch stylizationStatus {
        case .none:
            return String(localized: "avatar.status.none")
        case .processing:
            return String(localized: "avatar.status.processing")
        case .ready:
            return String(localized: "avatar.status.ready")
        case .failed:
            return String(localized: "avatar.status.failed")
        }
    }

    // MARK: - Methods

    func setOriginalPhoto(_ image: UIImage) {
        // Resize if too large (max 1024px)
        let maxSize: CGFloat = 1024
        let resized = image.resizedToFit(maxSize: maxSize)
        originalPhotoData = resized.jpegData(compressionQuality: 0.85)

        // Auto-crop to square for processed version
        let cropped = resized.croppedToSquare()
        processedPhotoData = cropped.jpegData(compressionQuality: 0.85)

        updatedAt = Date()
    }

    func setProcessedPhoto(_ image: UIImage) {
        let maxSize: CGFloat = 512
        let resized = image.resizedToFit(maxSize: maxSize)
        processedPhotoData = resized.jpegData(compressionQuality: 0.85)
        updatedAt = Date()
    }

    func setStylizedPhoto(_ image: UIImage) {
        let maxSize: CGFloat = 512
        let resized = image.resizedToFit(maxSize: maxSize)
        stylizedPhotoData = resized.jpegData(compressionQuality: 0.85)
        stylizationStatus = .ready
        lastStylizedAt = Date()
        updatedAt = Date()
    }

    func startStylization(provider: String) {
        stylizationStatus = .processing
        stylizationProvider = provider
        updatedAt = Date()
    }

    func failStylization() {
        stylizationStatus = .failed
        updatedAt = Date()
    }

    func clearStylizedPhoto() {
        stylizedPhotoData = nil
        stylizationStatus = .none
        stylizationProvider = nil
        lastStylizedAt = nil
        useStylizedVersion = false
        updatedAt = Date()
    }

    func reset() {
        originalPhotoData = nil
        processedPhotoData = nil
        stylizedPhotoData = nil
        style = .realistic
        backgroundColor = nil
        frameStyle = .circle
        stylizationStatus = .none
        stylizationProvider = nil
        lastStylizedAt = nil
        useStylizedVersion = false
        updatedAt = Date()
    }
}

// MARK: - Avatar Style

enum AvatarStyle: String, Codable, CaseIterable {
    case realistic = "realistic"
    case cartoon = "cartoon"
    case anime = "anime"
    case sketch = "sketch"
    case watercolor = "watercolor"
    case minimal = "minimal"

    var label: String {
        switch self {
        case .realistic: return String(localized: "avatar.style.realistic")
        case .cartoon: return String(localized: "avatar.style.cartoon")
        case .anime: return String(localized: "avatar.style.anime")
        case .sketch: return String(localized: "avatar.style.sketch")
        case .watercolor: return String(localized: "avatar.style.watercolor")
        case .minimal: return String(localized: "avatar.style.minimal")
        }
    }

    var description: String {
        switch self {
        case .realistic: return String(localized: "avatar.style.realistic.desc")
        case .cartoon: return String(localized: "avatar.style.cartoon.desc")
        case .anime: return String(localized: "avatar.style.anime.desc")
        case .sketch: return String(localized: "avatar.style.sketch.desc")
        case .watercolor: return String(localized: "avatar.style.watercolor.desc")
        case .minimal: return String(localized: "avatar.style.minimal.desc")
        }
    }

    var icon: String {
        switch self {
        case .realistic: return "person.fill"
        case .cartoon: return "face.smiling"
        case .anime: return "sparkles"
        case .sketch: return "pencil.tip"
        case .watercolor: return "paintbrush"
        case .minimal: return "circle.fill"
        }
    }

    var defaultBackgroundColor: Color {
        switch self {
        case .realistic: return .gray.opacity(0.2)
        case .cartoon: return .blue.opacity(0.2)
        case .anime: return .pink.opacity(0.2)
        case .sketch: return .white
        case .watercolor: return .cyan.opacity(0.1)
        case .minimal: return .purple.opacity(0.15)
        }
    }

    var promptModifier: String {
        switch self {
        case .realistic: return "photorealistic portrait"
        case .cartoon: return "cartoon style, colorful, friendly"
        case .anime: return "anime style, vibrant colors, expressive"
        case .sketch: return "pencil sketch, hand-drawn, artistic"
        case .watercolor: return "watercolor painting, soft colors, artistic"
        case .minimal: return "minimalist, simple shapes, flat design"
        }
    }
}

// MARK: - Avatar Frame Style

enum AvatarFrameStyle: String, Codable, CaseIterable {
    case circle = "circle"
    case roundedSquare = "rounded_square"
    case square = "square"
    case hexagon = "hexagon"

    var label: String {
        switch self {
        case .circle: return String(localized: "avatar.frame.circle")
        case .roundedSquare: return String(localized: "avatar.frame.rounded_square")
        case .square: return String(localized: "avatar.frame.square")
        case .hexagon: return String(localized: "avatar.frame.hexagon")
        }
    }

    var icon: String {
        switch self {
        case .circle: return "circle"
        case .roundedSquare: return "app"
        case .square: return "square"
        case .hexagon: return "hexagon"
        }
    }
}

// MARK: - Avatar Stylization Status

enum AvatarStylizationStatus: String, Codable {
    case none = "none"
    case processing = "processing"
    case ready = "ready"
    case failed = "failed"
}

// MARK: - UIImage Extensions

extension UIImage {
    func resizedToFit(maxSize: CGFloat) -> UIImage {
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1 { return self }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func croppedToSquare() -> UIImage {
        let minDimension = min(size.width, size.height)
        let x = (size.width - minDimension) / 2
        let y = (size.height - minDimension) / 2
        let cropRect = CGRect(x: x, y: y, width: minDimension, height: minDimension)

        guard let cgImage = cgImage?.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
