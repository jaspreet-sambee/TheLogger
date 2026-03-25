//
//  WorkoutCardRenderer.swift
//  TheLogger
//
//  Generates a 9:16 shareable workout card from a peak-contraction camera frame.
//  Output: filtered photo with a Strava-style frosted stats card overlay.
//

import UIKit
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Card Theme

enum CardTheme: String, CaseIterable {
    case cinematic, portra, bleach, chrome, moody, goldenHour, grit, velvia

    var displayName: String {
        switch self {
        case .cinematic:  return "CINEMATIC"
        case .portra:     return "PORTRA"
        case .bleach:     return "BLEACH"
        case .chrome:     return "CHROME"
        case .moody:      return "MOODY"
        case .goldenHour: return "GOLDEN HOUR"
        case .grit:       return "GRIT"
        case .velvia:     return "VELVIA"
        }
    }

    var accentUI: UIColor {
        switch self {
        case .cinematic:  return UIColor(red: 0.92, green: 0.62, blue: 0.20, alpha: 1) // warm orange
        case .portra:     return UIColor(red: 1.00, green: 0.85, blue: 0.60, alpha: 1) // creamy gold
        case .bleach:     return UIColor(white: 0.92, alpha: 1)                         // silver
        case .chrome:     return UIColor(red: 0.65, green: 0.78, blue: 0.85, alpha: 1) // muted cyan-blue
        case .moody:      return UIColor(red: 0.95, green: 0.78, blue: 0.40, alpha: 1) // amber
        case .goldenHour: return UIColor(red: 1.00, green: 0.80, blue: 0.30, alpha: 1) // golden yellow
        case .grit:       return UIColor(white: 0.90, alpha: 1)                         // off-white
        case .velvia:     return UIColor(red: 0.30, green: 0.80, blue: 1.00, alpha: 1) // electric cyan
        }
    }

    var accentSwiftUI: Color { Color(accentUI) }

    /// Approximate tint for the live SwiftUI preview (colorMultiply layer).
    var previewTint: Color {
        switch self {
        case .cinematic:  return Color(red: 0.80, green: 0.85, blue: 0.88) // cool teal
        case .portra:     return Color(red: 1.00, green: 0.93, blue: 0.82) // warm creamy
        case .bleach:     return Color(white: 0.88)                         // silver-gray
        case .chrome:     return Color(red: 0.86, green: 0.88, blue: 0.90) // cool muted
        case .moody:      return Color(red: 0.75, green: 0.78, blue: 0.88) // dark blue-gray
        case .goldenHour: return Color(red: 1.00, green: 0.92, blue: 0.72) // golden warm
        case .grit:       return Color(white: 0.82)                         // B&W gray
        case .velvia:     return Color(red: 0.85, green: 0.95, blue: 1.00) // cyan-bright
        }
    }

    /// Per-theme saturation for the live SwiftUI preview — matches the Core Image filter's saturation level.
    var previewSaturation: Double {
        switch self {
        case .cinematic:  return 0.85
        case .portra:     return 1.10
        case .bleach:     return 0.20
        case .chrome:     return 0.60
        case .moody:      return 0.70
        case .goldenHour: return 1.22
        case .grit:       return 0.0   // fully B&W
        case .velvia:     return 1.80  // hypersaturated
        }
    }

    /// Radial glow colour for the workout summary card background.
    var glowUI: UIColor { accentUI.withAlphaComponent(0.25) }
}

// MARK: - Card Background

enum CardBackground: String, CaseIterable {
    case dark, light, blur, gradient

    var displayName: String {
        switch self {
        case .dark:     return "Dark"
        case .light:    return "Light"
        case .blur:     return "Blur"
        case .gradient: return "Glow"
        }
    }
}

// MARK: - Share Card Config

struct ShareCardConfig {
    var photo: UIImage
    var exerciseName: String
    var reps: Int
    var weight: Double        // display units (lbs or kg)
    var weightUnit: String    // "lbs" or "kg"
    var estimated1RM: Double  // display units, computed via Epley: weight*(1+reps/30)
    var isPR: Bool

    // Stat toggles
    var showExerciseName: Bool = true
    var showWeightReps: Bool = true
    var show1RM: Bool = false
    var showDate: Bool = false

    // Photo framing (1.0 = full photo visible / aspect-fit; >1 zooms in)
    var photoScale: CGFloat = 1.0
    var photoOffset: CGPoint = .zero  // in 1080×1920 canvas pixels
    var isPhotoFlipped: Bool = false  // flip horizontally (front camera frames are mirrored)

    // Stats card 2D position offset from default (in 1080×1920 canvas pixels)
    var statsOffset: CGPoint = .zero

    // Stats card uniform scale (1.0 = default size; text + box scale together)
    var statsScale: CGFloat = 1.0

    // Color theme
    var theme: CardTheme = .cinematic

    // Background style
    var background: CardBackground = .dark

    var hasAnyStats: Bool {
        showExerciseName || showWeightReps || show1RM || showDate || isPR
    }
}

// MARK: - Renderer

enum WorkoutCardRenderer {

    nonisolated(unsafe) private static let ciContext = CIContext()

    /// Renders a 1080×1920 share card.
    static func render(config: ShareCardConfig) -> UIImage? {
        let cardSize = CGSize(width: 1080, height: 1920)

        let sourcePhoto = config.isPhotoFlipped ? config.photo.flippedHorizontally() : config.photo
        guard let filtered = applyPhotoFilter(to: sourcePhoto, theme: config.theme) else { return nil }

        return UIGraphicsImageRenderer(size: cardSize).image { ctx in
            let cgCtx = ctx.cgContext

            // --- 1. Background ---
            drawBackground(config: config, filtered: filtered, cgCtx: cgCtx, canvasSize: cardSize)

            // --- 2. Photo: aspect-fit baseline + user scale/offset ---
            let baseRect = aspectFitRect(imageSize: filtered.size, canvasSize: cardSize)
            let s = config.photoScale
            let scaledW = baseRect.width * s
            let scaledH = baseRect.height * s
            let photoRect = CGRect(
                x: cardSize.width  / 2 - scaledW / 2 + config.photoOffset.x,
                y: cardSize.height / 2 - scaledH / 2 + config.photoOffset.y,
                width: scaledW,
                height: scaledH
            )
            // Clip photo to rounded corners (≈ 16pt × display scale in a 1080px canvas)
            cgCtx.saveGState()
            let photoCornerR: CGFloat = 60
            cgCtx.addPath(UIBezierPath(roundedRect: photoRect, cornerRadius: photoCornerR).cgPath)
            cgCtx.clip()
            filtered.draw(in: photoRect)
            cgCtx.restoreGState()

            // --- 3. Vignette ---
            let vigCenter = CGPoint(x: cardSize.width / 2, y: cardSize.height / 2)
            let vigRadius = max(cardSize.width, cardSize.height) * 0.75
            let vigColors = [
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0.35).cgColor
            ]
            if let vigGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: vigColors as CFArray,
                locations: [0, 1]
            ) {
                cgCtx.drawRadialGradient(
                    vigGradient,
                    startCenter: vigCenter, startRadius: 0,
                    endCenter: vigCenter, endRadius: vigRadius,
                    options: [.drawsAfterEndLocation]
                )
            }

            // --- 4 & 5. Frosted stats card + text ---
            if config.hasAnyStats {
                let ss = config.statsScale
                let cardWidth = (cardSize.width - 180) * ss
                let cardPadding: CGFloat = 48 * ss
                let innerWidth = cardWidth - cardPadding * 2

                let accent = config.theme.accentUI
                let boldFont68     = UIFont.systemFont(ofSize: 68 * ss, weight: .bold)
                let semiboldFont52 = UIFont.systemFont(ofSize: 52 * ss, weight: .semibold)
                let mediumFont38   = UIFont.systemFont(ofSize: 38 * ss, weight: .medium)
                let boldFont28     = UIFont.systemFont(ofSize: 28 * ss, weight: .bold)
                let regularFont30  = UIFont.systemFont(ofSize: 30 * ss, weight: .regular)

                let pillPadH: CGFloat = 24 * ss
                let pillPadV: CGFloat = 10 * ss

                var contentHeight: CGFloat = 0
                if config.showExerciseName { contentHeight += measureTextHeight(config.exerciseName.uppercased(), font: boldFont68, width: innerWidth) + 16 * ss }
                if config.showWeightReps   { contentHeight += measureTextHeight(weightRepsString(config), font: semiboldFont52, width: innerWidth) + 12 * ss }
                if config.show1RM          { contentHeight += measureTextHeight(est1RMString(config), font: mediumFont38, width: innerWidth) + 10 * ss }
                if config.isPR             { contentHeight += 28 * ss + 20 * ss + 20 * ss }
                if config.showDate         { contentHeight += measureTextHeight(dateString(), font: regularFont30, width: innerWidth) + 8 * ss }
                if contentHeight > 0 { contentHeight -= 8 * ss }

                let cardHeight = contentHeight + cardPadding * 2

                let cardCenterX = cardSize.width / 2 + config.statsOffset.x
                let cardCenterY = cardSize.height * 0.58 + config.statsOffset.y
                let cardRect = CGRect(
                    x: cardCenterX - cardWidth / 2,
                    y: cardCenterY - cardHeight / 2,
                    width: cardWidth,
                    height: cardHeight
                )

                cgCtx.saveGState()
                cgCtx.setShadow(
                    offset: CGSize(width: 0, height: 8),
                    blur: 30,
                    color: UIColor.black.withAlphaComponent(0.4).cgColor
                )
                let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 40 * ss)
                UIColor(red: 0.10, green: 0.09, blue: 0.09, alpha: 0.82).setFill()
                cardPath.fill()
                cgCtx.restoreGState()

                UIColor(white: 1.0, alpha: 0.18).setStroke()
                cardPath.lineWidth = 1
                cardPath.stroke()

                var textY = cardRect.minY + cardPadding
                let textX = cardRect.minX + cardPadding

                if config.showExerciseName {
                    let attrs: [NSAttributedString.Key: Any] = [.font: boldFont68, .foregroundColor: UIColor.white]
                    let str = config.exerciseName.uppercased() as NSString
                    let h = measureTextHeight(config.exerciseName.uppercased(), font: boldFont68, width: innerWidth)
                    str.draw(in: CGRect(x: textX, y: textY, width: innerWidth, height: h), withAttributes: attrs)
                    textY += h + 16 * ss
                }
                if config.showWeightReps {
                    let attrs: [NSAttributedString.Key: Any] = [.font: semiboldFont52, .foregroundColor: accent]
                    let str = weightRepsString(config) as NSString
                    let h = measureTextHeight(weightRepsString(config), font: semiboldFont52, width: innerWidth)
                    str.draw(in: CGRect(x: textX, y: textY, width: innerWidth, height: h), withAttributes: attrs)
                    textY += h + 12 * ss
                }
                if config.show1RM {
                    let attrs: [NSAttributedString.Key: Any] = [.font: mediumFont38, .foregroundColor: UIColor.white.withAlphaComponent(0.70)]
                    let str = est1RMString(config) as NSString
                    let h = measureTextHeight(est1RMString(config), font: mediumFont38, width: innerWidth)
                    str.draw(in: CGRect(x: textX, y: textY, width: innerWidth, height: h), withAttributes: attrs)
                    textY += h + 10 * ss
                }
                if config.isPR {
                    textY += 20 * ss
                    let pillText = "🏆  NEW PR" as NSString
                    let pillAttrs: [NSAttributedString.Key: Any] = [
                        .font: boldFont28,
                        .foregroundColor: UIColor(red: 0.10, green: 0.09, blue: 0.09, alpha: 1)
                    ]
                    let pillTextSize = pillText.size(withAttributes: pillAttrs)
                    let pillW = pillTextSize.width + pillPadH * 2
                    let pillH = pillTextSize.height + pillPadV * 2
                    let pillRect = CGRect(x: textX, y: textY, width: pillW, height: pillH)
                    let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: 14 * ss)
                    accent.setFill()
                    pillPath.fill()
                    pillText.draw(
                        in: CGRect(x: textX + pillPadH, y: textY + pillPadV, width: pillTextSize.width, height: pillTextSize.height),
                        withAttributes: pillAttrs
                    )
                    textY += pillH + 20 * ss
                }
                if config.showDate {
                    let attrs: [NSAttributedString.Key: Any] = [.font: regularFont30, .foregroundColor: UIColor.white.withAlphaComponent(0.50)]
                    let str = dateString() as NSString
                    let h = measureTextHeight(dateString(), font: regularFont30, width: innerWidth)
                    str.draw(in: CGRect(x: textX, y: textY, width: innerWidth, height: h), withAttributes: attrs)
                }
            }

            // --- 6. Branding ---
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55)
            ]
            let brandStr = "TheLogger" as NSString
            let brandSize = brandStr.size(withAttributes: brandAttrs)
            brandStr.draw(
                in: CGRect(
                    x: cardSize.width - brandSize.width - 60,
                    y: cardSize.height - brandSize.height - 50,
                    width: brandSize.width,
                    height: brandSize.height
                ),
                withAttributes: brandAttrs
            )
        }
    }

    // MARK: - Photo Filter Pipeline

    /// Public entry point: apply the theme's filter chain to a full-resolution photo.
    nonisolated static func applyPhotoFilter(to image: UIImage, theme: CardTheme) -> UIImage? {
        guard let ci = CIImage(image: image) else { return nil }
        let output: CIImage?
        switch theme {
        case .cinematic:  output = cinematicFilter(ci)
        case .portra:     output = portraFilter(ci)
        case .bleach:     output = bleachFilter(ci)
        case .chrome:     output = chromeFilter(ci)
        case .moody:      output = moodyFilter(ci)
        case .goldenHour: output = goldenHourFilter(ci)
        case .grit:       output = gritFilter(ci)
        case .velvia:     output = velviaFilter(ci)
        }
        guard let out = output,
              let cg = ciContext.createCGImage(out, from: out.extent) else { return nil }
        let result = UIImage(cgImage: cg)
        // Add film grain for GRIT and BLEACH
        switch theme {
        case .grit:   return result.addingGrain(intensity: 0.045)
        case .bleach: return result.addingGrain(intensity: 0.022)
        default:      return result
        }
    }

    /// Generates a small thumbnail (108×192 @2× for a 54×96pt slot) for the filter strip UI.
    nonisolated static func thumbnailImage(photo: UIImage, theme: CardTheme) -> UIImage? {
        let thumbSize = CGSize(width: 108, height: 192)
        let renderer = UIGraphicsImageRenderer(size: thumbSize)
        let small = renderer.image { ctx in
            // Aspect-fill crop into thumbnail
            let imgSize = photo.size
            let scale = max(thumbSize.width / imgSize.width, thumbSize.height / imgSize.height)
            let scaledW = imgSize.width * scale
            let scaledH = imgSize.height * scale
            photo.draw(in: CGRect(
                x: (thumbSize.width - scaledW) / 2,
                y: (thumbSize.height - scaledH) / 2,
                width: scaledW, height: scaledH
            ))
        }
        return applyPhotoFilter(to: small, theme: theme)
    }

    // MARK: - Filter Helpers

    /// CINEMATIC — teal shadows + warm orange highlights (Hollywood blockbuster split-tone)
    private nonisolated static func cinematicFilter(_ ci: CIImage) -> CIImage? {
        let cc = CIFilter.colorControls()
        cc.inputImage = ci; cc.contrast = 1.15; cc.saturation = 0.85
        guard let c = cc.outputImage else { return nil }
        // Push shadows cool (teal) and highlights warm (orange) via color matrix
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = c
        // Red: boost highlights (orange), slightly reduce shadows
        matrix.rVector = CIVector(x: 0.95, y: 0.0, z: 0.0, w: 0)
        // Green: neutral with slight boost
        matrix.gVector = CIVector(x: 0.0, y: 1.0, z: 0.0, w: 0)
        // Blue: boost in shadows (teal), pull back in highlights
        matrix.bVector = CIVector(x: 0.0, y: 0.0, z: 0.90, w: 0)
        // Bias: cool shadow push (teal = more green+blue in darks), warm highlight push
        matrix.biasVector = CIVector(x: 0.04, y: 0.03, z: 0.06, w: 0)
        guard let m = matrix.outputImage else { return c }
        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = m; hs.shadowAmount = -0.15; hs.highlightAmount = 0.08
        return hs.outputImage ?? m
    }

    /// PORTRA — Kodak Portra 400 warm film stock simulation
    private nonisolated static func portraFilter(_ ci: CIImage) -> CIImage? {
        let temp = CIFilter.temperatureAndTint()
        temp.inputImage = ci
        temp.neutral = CIVector(x: 6500, y: 0)
        temp.targetNeutral = CIVector(x: 4200, y: 0)
        guard let t = temp.outputImage else { return nil }
        let cc = CIFilter.colorControls()
        cc.inputImage = t; cc.contrast = 1.05; cc.saturation = 1.10; cc.brightness = 0.015
        guard let c = cc.outputImage else { return nil }
        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = c; hs.shadowAmount = 0.18; hs.highlightAmount = -0.05
        return hs.outputImage ?? c
    }

    /// BLEACH — Bleach bypass: partial desaturation, crushed contrast, silver overlay feel
    private nonisolated static func bleachFilter(_ ci: CIImage) -> CIImage? {
        let cc = CIFilter.colorControls()
        cc.inputImage = ci; cc.saturation = 0.20; cc.contrast = 1.40
        guard let c = cc.outputImage else { return nil }
        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = c; hs.shadowAmount = -0.25; hs.highlightAmount = 0.12
        guard let h = hs.outputImage else { return c }
        // Slight cool cast (chemical silver feel)
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = h
        matrix.rVector = CIVector(x: 0.97, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: 0.98, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: 1.04, w: 0)
        matrix.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        return matrix.outputImage ?? h
    }

    /// CHROME — Fuji Classic Chrome: muted, faded, slightly cool documentary feel
    private nonisolated static func chromeFilter(_ ci: CIImage) -> CIImage? {
        let cc = CIFilter.colorControls()
        cc.inputImage = ci; cc.saturation = 0.60; cc.contrast = 0.90; cc.brightness = 0.025
        guard let c = cc.outputImage else { return nil }
        let temp = CIFilter.temperatureAndTint()
        temp.inputImage = c
        temp.neutral = CIVector(x: 6500, y: 0)
        temp.targetNeutral = CIVector(x: 7500, y: 10)
        guard let t = temp.outputImage else { return c }
        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = t; hs.shadowAmount = 0.15; hs.highlightAmount = -0.05
        return hs.outputImage ?? t
    }

    /// MOODY — Deep blue-black shadows + amber glow in highlights
    private nonisolated static func moodyFilter(_ ci: CIImage) -> CIImage? {
        let cc = CIFilter.colorControls()
        cc.inputImage = ci; cc.saturation = 0.70; cc.contrast = 1.25
        guard let c = cc.outputImage else { return nil }
        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = c; hs.shadowAmount = -0.30; hs.highlightAmount = 0.06
        guard let h = hs.outputImage else { return c }
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = h
        // Boost blue channel (cool shadows), add warm bias (amber highlights)
        matrix.rVector = CIVector(x: 1.0, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: 1.0, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: 1.20, w: 0)
        matrix.biasVector = CIVector(x: 0.06, y: 0.04, z: 0.0, w: 0)
        return matrix.outputImage ?? h
    }

    /// GOLDEN HOUR — Warm colour grade, saturated, sun-drenched
    private nonisolated static func goldenHourFilter(_ ci: CIImage) -> CIImage? {
        let temp = CIFilter.temperatureAndTint()
        temp.inputImage = ci
        temp.neutral = CIVector(x: 6500, y: 0)
        temp.targetNeutral = CIVector(x: 3600, y: 0)
        guard let t = temp.outputImage else { return nil }
        let cc = CIFilter.colorControls()
        cc.inputImage = t; cc.saturation = 1.22; cc.contrast = 1.06; cc.brightness = 0.02
        guard let c = cc.outputImage else { return nil }
        let vig = CIFilter.vignette()
        vig.inputImage = c; vig.intensity = 0.45; vig.radius = 1.6
        return vig.outputImage ?? c
    }

    /// GRIT — B&W with crushed blacks and heavy grain (grain added in UIKit layer)
    private nonisolated static func gritFilter(_ ci: CIImage) -> CIImage? {
        let mono = CIFilter.colorMonochrome()
        mono.inputImage = ci; mono.color = CIColor(red: 0.5, green: 0.5, blue: 0.5); mono.intensity = 1.0
        guard let m = mono.outputImage else { return nil }
        let cc = CIFilter.colorControls()
        cc.inputImage = m; cc.contrast = 1.50; cc.brightness = -0.04
        guard let c = cc.outputImage else { return nil }
        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = c; hs.shadowAmount = -0.35; hs.highlightAmount = 0.10
        return hs.outputImage ?? c
    }

    /// VELVIA — Fuji Velvia: hyper-saturated, punchy, electric gym energy
    private nonisolated static func velviaFilter(_ ci: CIImage) -> CIImage? {
        let cc = CIFilter.colorControls()
        cc.inputImage = ci; cc.saturation = 1.80; cc.contrast = 1.28
        guard let c = cc.outputImage else { return nil }
        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = c; hs.shadowAmount = -0.18; hs.highlightAmount = 0.06
        return hs.outputImage ?? c
    }

    // MARK: - Background Rendering

    private static func drawBackground(
        config: ShareCardConfig,
        filtered: UIImage,
        cgCtx: CGContext,
        canvasSize: CGSize
    ) {
        let fullRect = CGRect(origin: .zero, size: canvasSize)
        switch config.background {
        case .dark:
            UIColor.black.setFill()
            UIBezierPath(rect: fullRect).fill()

        case .light:
            UIColor(red: 0.94, green: 0.93, blue: 0.92, alpha: 1).setFill()
            UIBezierPath(rect: fullRect).fill()

        case .blur:
            UIColor.black.setFill()
            UIBezierPath(rect: fullRect).fill()
            if let blurred = blurredBackground(image: filtered, canvasSize: canvasSize) {
                blurred.draw(in: fullRect)
                UIColor.black.withAlphaComponent(0.38).setFill()
                UIBezierPath(rect: fullRect).fill()
            }

        case .gradient:
            UIColor.black.setFill()
            UIBezierPath(rect: fullRect).fill()
            let glowCenter = CGPoint(x: canvasSize.width / 2, y: 0)
            let glowColors = [
                config.theme.glowUI.withAlphaComponent(0.55).cgColor,
                UIColor.clear.cgColor
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: glowColors as CFArray,
                locations: [0, 1]
            ) {
                cgCtx.drawRadialGradient(
                    gradient,
                    startCenter: glowCenter, startRadius: 0,
                    endCenter: glowCenter, endRadius: 1100,
                    options: [.drawsAfterEndLocation]
                )
            }
        }
    }

    /// Aspect-fills and Gaussian-blurs an image to fill the canvas — used for the blur background.
    private nonisolated static func blurredBackground(image: UIImage, canvasSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let filled = renderer.image { _ in
            let fillRect = aspectFillRect(imageSize: image.size, canvasSize: canvasSize)
            image.draw(in: fillRect)
        }
        guard let ci = CIImage(image: filled) else { return nil }
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ci
        blur.radius = 28
        guard let out = blur.outputImage,
              let cg = ciContext.createCGImage(out, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Generates a 108×192pt swatch preview image for the background picker (rendered at 2× for crispness).
    nonisolated static func backgroundSwatch(photo: UIImage, background: CardBackground, theme: CardTheme) -> UIImage? {
        let size = CGSize(width: 108, height: 192)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cgCtx = ctx.cgContext
            let fullRect = CGRect(origin: .zero, size: size)
            switch background {
            case .dark:
                UIColor.black.setFill()
                UIBezierPath(rect: fullRect).fill()
            case .light:
                UIColor(red: 0.94, green: 0.93, blue: 0.92, alpha: 1).setFill()
                UIBezierPath(rect: fullRect).fill()
            case .blur:
                UIColor.black.setFill()
                UIBezierPath(rect: fullRect).fill()
                if let blurred = blurredBackground(image: photo, canvasSize: size) {
                    blurred.draw(in: fullRect)
                    UIColor.black.withAlphaComponent(0.38).setFill()
                    UIBezierPath(rect: fullRect).fill()
                }
            case .gradient:
                UIColor.black.setFill()
                UIBezierPath(rect: fullRect).fill()
                let glowCenter = CGPoint(x: size.width / 2, y: 0)
                let glowColors = [theme.glowUI.withAlphaComponent(0.65).cgColor, UIColor.clear.cgColor]
                if let grad = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: glowColors as CFArray,
                    locations: [0, 1]
                ) {
                    cgCtx.drawRadialGradient(
                        grad,
                        startCenter: glowCenter, startRadius: 0,
                        endCenter: glowCenter, endRadius: size.height * 0.85,
                        options: [.drawsAfterEndLocation]
                    )
                }
            }
        }
    }

    // MARK: - Text Helpers

    private static func weightRepsString(_ config: ShareCardConfig) -> String {
        "\(Int(config.weight)) \(config.weightUnit) × \(config.reps)"
    }

    private static func est1RMString(_ config: ShareCardConfig) -> String {
        "est. 1RM  \(Int(config.estimated1RM)) \(config.weightUnit)"
    }

    private static func dateString() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: Date())
    }

    private static func measureTextHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        return ceil(boundingRect.height)
    }

    private static func aspectFitRect(imageSize: CGSize, canvasSize: CGSize) -> CGRect {
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: (canvasSize.width - w) / 2,
            y: (canvasSize.height - h) / 2,
            width: w,
            height: h
        )
    }

    private nonisolated static func aspectFillRect(imageSize: CGSize, canvasSize: CGSize) -> CGRect {
        let scale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: (canvasSize.width - w) / 2,
            y: (canvasSize.height - h) / 2,
            width: w,
            height: h
        )
    }
}

// MARK: - UIImage helpers

extension UIImage {
    /// Returns a copy scaled so the longest edge ≤ maxDimension. Returns self if already small enough.
    nonisolated func scaledDown(toMaxDimension maxDim: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDim else { return self }
        let scale = maxDim / longest
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Adds a subtle film grain overlay using random pixel dots.
    nonisolated func addingGrain(intensity: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(at: .zero)
            let dotCount = Int(size.width * size.height * 0.003)
            for _ in 0..<dotCount {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let r = CGFloat.random(in: 1.0...2.2)
                let alpha = CGFloat.random(in: 0...intensity)
                UIColor(white: CGFloat.random(in: 0.3...0.7), alpha: alpha).setFill()
                UIBezierPath(ovalIn: CGRect(x: x, y: y, width: r, height: r)).fill()
            }
        }
    }
}
