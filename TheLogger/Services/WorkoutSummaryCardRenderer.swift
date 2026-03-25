//
//  WorkoutSummaryCardRenderer.swift
//  TheLogger
//
//  Renders a 1080×1080 end-of-workout summary share card.
//  Two layouts: stats at top (dark header + photo below) or stats at bottom (photo above + dark footer).
//  Optional photo with pinch-to-zoom/pan support. Transparent rounded corners in shared image.
//

import UIKit
import CoreGraphics

// MARK: - Stats Position

enum StatsPosition { case top, bottom }

// MARK: - Config

struct WorkoutSummaryConfig {
    var workoutName: String
    var date: Date
    var duration: TimeInterval?       // seconds
    var totalExercises: Int
    var totalSets: Int
    var totalVolume: Double           // display units (lbs or kg)
    var weightUnit: String
    var prCount: Int
    var prExercises: [String]         // up to 3
    var theme: CardTheme = .cinematic
    var photo: UIImage? = nil
    var isPhotoFlipped: Bool = false
    var photoScale: CGFloat = 1.0
    var photoOffset: CGPoint = .zero
    var statsPosition: StatsPosition = .top
}

// MARK: - Renderer

enum WorkoutSummaryCardRenderer {

    static func render(config: WorkoutSummaryConfig) -> UIImage? {
        let canvas = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true

        return UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            let cg = ctx.cgContext

            // --- 1. Background ---
            if let photo = config.photo {
                drawPhoto(
                    photo, isFlipped: config.isPhotoFlipped,
                    scale: config.photoScale, offset: config.photoOffset,
                    cg: cg, canvas: canvas
                )
            } else {
                drawDarkBackground(config: config, cg: cg, canvas: canvas)
            }

            // --- 2. Gradient + stats (position-dependent) ---
            let nameY: CGFloat
            switch config.statsPosition {
            case .top:
                drawTopGradient(cg: cg, canvas: canvas)
                nameY = 50
            case .bottom:
                drawBottomGradient(cg: cg, canvas: canvas)
                nameY = 660
            }
            drawStats(config: config, cg: cg, canvas: canvas, nameY: nameY)

            // --- 3. Branding ---
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.40)
            ]
            let brandStr = "TheLogger" as NSString
            let brandSize = brandStr.size(withAttributes: brandAttrs)
            brandStr.draw(
                in: CGRect(
                    x: canvas.width - brandSize.width - 60,
                    y: canvas.height - brandSize.height - 42,
                    width: brandSize.width,
                    height: brandSize.height
                ),
                withAttributes: brandAttrs
            )
        }
    }

    // MARK: - Background

    private static func drawPhoto(
        _ photo: UIImage, isFlipped: Bool,
        scale: CGFloat, offset: CGPoint,
        cg: CGContext, canvas: CGSize
    ) {
        let src = isFlipped ? photo.flippedHorizontally() : photo
        let baseS = max(canvas.width / src.size.width, canvas.height / src.size.height)
        let s = baseS * scale
        let sw = src.size.width * s
        let sh = src.size.height * s
        src.draw(in: CGRect(
            x: (canvas.width  - sw) / 2 + offset.x,
            y: (canvas.height - sh) / 2 + offset.y,
            width: sw, height: sh
        ))
    }

    private static func drawDarkBackground(
        config: WorkoutSummaryConfig, cg: CGContext, canvas: CGSize
    ) {
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: canvas)).fill()
        let glowColors = [
            config.theme.glowUI.withAlphaComponent(0.50).cgColor,
            UIColor.clear.cgColor
        ]
        if let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: glowColors as CFArray,
            locations: [0, 1]
        ) {
            cg.drawRadialGradient(
                grad,
                startCenter: CGPoint(x: canvas.width / 2, y: 0), startRadius: 0,
                endCenter:   CGPoint(x: canvas.width / 2, y: 0), endRadius: 800,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    // MARK: - Gradients

    /// Dark solid zone at top + gradient fade downward into the photo.
    private static func drawTopGradient(cg: CGContext, canvas: CGSize) {
        let solidEnd: CGFloat  = canvas.height * 0.288   // ~311px — solid dark header
        let fadeEnd:  CGFloat  = canvas.height * 0.407   // ~440px — gradient fully clear

        // Solid dark header
        UIColor.black.withAlphaComponent(0.65).setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: canvas.width, height: solidEnd)).fill()

        // Gradient: dark → clear
        let fadeColors = [
            UIColor.black.withAlphaComponent(0.65).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor
        ]
        if let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: fadeColors as CFArray,
            locations: [0, 1]
        ) {
            cg.drawLinearGradient(
                grad,
                start: CGPoint(x: 0, y: solidEnd),
                end:   CGPoint(x: 0, y: fadeEnd),
                options: []
            )
        }
    }

    /// Gradient fade from photo into solid dark zone at bottom.
    private static func drawBottomGradient(cg: CGContext, canvas: CGSize) {
        let fadeStart: CGFloat = canvas.height * 0.546   // ~590px — gradient begins
        let solidStart: CGFloat = canvas.height * 0.602  // ~650px — solid dark footer

        // Gradient: clear → dark
        let fadeColors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.65).cgColor
        ]
        if let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: fadeColors as CFArray,
            locations: [0, 1]
        ) {
            cg.drawLinearGradient(
                grad,
                start: CGPoint(x: 0, y: fadeStart),
                end:   CGPoint(x: 0, y: solidStart),
                options: []
            )
        }

        // Solid dark footer
        UIColor.black.withAlphaComponent(0.65).setFill()
        UIBezierPath(rect: CGRect(
            x: 0, y: solidStart,
            width: canvas.width,
            height: canvas.height - solidStart
        )).fill()
    }

    // MARK: - Stats

    /// Draws name, date, separator, and stats row starting at nameY.
    private static func drawStats(
        config: WorkoutSummaryConfig, cg: CGContext,
        canvas: CGSize, nameY: CGFloat
    ) {
        drawWorkoutName(config: config, cg: cg, nameY: nameY, canvasWidth: canvas.width)

        // Date
        let dateFont = UIFont.systemFont(ofSize: 30, weight: .regular)
        let fmt = DateFormatter(); fmt.dateStyle = .long
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.55)
        ]
        let dateY = nameY + 88
        (fmt.string(from: config.date) as NSString).draw(
            in: CGRect(x: 60, y: dateY, width: canvas.width - 120, height: 44),
            withAttributes: dateAttrs
        )

        // Thin accent separator
        let sepY = dateY + 52
        config.theme.accentUI.withAlphaComponent(0.55).setFill()
        UIBezierPath(roundedRect: CGRect(x: 60, y: sepY, width: 160, height: 3), cornerRadius: 1.5).fill()

        // Stats row
        drawStatsRow(config: config, cg: cg, canvas: canvas, topY: sepY + 28)
    }

    private static func drawWorkoutName(
        config: WorkoutSummaryConfig, cg: CGContext,
        nameY: CGFloat, canvasWidth: CGFloat
    ) {
        let nameFont = UIFont.systemFont(ofSize: 64, weight: .bold)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: UIColor.white
        ]
        let badgeReserve: CGFloat = config.prCount > 0 ? 190 : 0
        let nameMaxW = canvasWidth - 120 - badgeReserve
        let nameStr = config.workoutName as NSString
        let nameH = ceil(nameStr.boundingRect(
            with: CGSize(width: nameMaxW, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: nameAttrs,
            context: nil
        ).height)
        nameStr.draw(
            in: CGRect(x: 60, y: nameY, width: nameMaxW, height: nameH),
            withAttributes: nameAttrs
        )

        guard config.prCount > 0 else { return }
        let badgeFont = UIFont.systemFont(ofSize: 26, weight: .bold)
        let badgeText = "🏆  \(config.prCount) PR\(config.prCount == 1 ? "" : "s")" as NSString
        let badgeTextAttrs: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: UIColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1)
        ]
        let ts = badgeText.size(withAttributes: badgeTextAttrs)
        let pH: CGFloat = 16, pV: CGFloat = 8
        let bW = ts.width + pH * 2, bH = ts.height + pV * 2
        let bX = canvasWidth - 60 - bW
        let bY = nameY + (nameFont.lineHeight - bH) / 2 + 4
        config.theme.accentUI.setFill()
        UIBezierPath(roundedRect: CGRect(x: bX, y: bY, width: bW, height: bH), cornerRadius: 14).fill()
        badgeText.draw(
            in: CGRect(x: bX + pH, y: bY + pV, width: ts.width, height: ts.height),
            withAttributes: badgeTextAttrs
        )
    }

    private static func drawStatsRow(
        config: WorkoutSummaryConfig, cg: CGContext,
        canvas: CGSize, topY: CGFloat
    ) {
        let stats = buildStats(config: config)
        guard !stats.isEmpty else { return }
        let totalW: CGFloat = canvas.width - 120
        let gap: CGFloat = 12
        let cellW = (totalW - gap * CGFloat(stats.count - 1)) / CGFloat(stats.count)

        let valFont = UIFont.systemFont(ofSize: 48, weight: .bold)
        let lblFont = UIFont.systemFont(ofSize: 22, weight: .regular)
        let valAttrs: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: config.theme.accentUI]
        let lblAttrs: [NSAttributedString.Key: Any] = [.font: lblFont, .foregroundColor: UIColor.white.withAlphaComponent(0.50)]

        for (i, stat) in stats.enumerated() {
            let x = 60 + CGFloat(i) * (cellW + gap)
            let valStr = stat.value as NSString
            let valH = ceil(valStr.boundingRect(
                with: CGSize(width: cellW, height: 80),
                options: .usesLineFragmentOrigin,
                attributes: valAttrs,
                context: nil
            ).height)
            valStr.draw(in: CGRect(x: x, y: topY, width: cellW, height: valH), withAttributes: valAttrs)

            let lblStr = stat.label as NSString
            let lblH = ceil(lblStr.size(withAttributes: lblAttrs).height)
            lblStr.draw(in: CGRect(x: x, y: topY + valH + 6, width: cellW, height: lblH), withAttributes: lblAttrs)
        }
    }

    private static func buildStats(config: WorkoutSummaryConfig) -> [(value: String, label: String)] {
        var s: [(value: String, label: String)] = []
        if let dur = config.duration {
            let m = Int(dur) / 60, sec = Int(dur) % 60
            s.append((m > 0 ? "\(m)m \(sec)s" : "\(sec)s", "time"))
        }
        s.append(("\(config.totalExercises)", "exercises"))
        s.append(("\(config.totalSets)", "sets"))
        if config.totalVolume > 0 {
            let vol = config.totalVolume >= 1000
                ? String(format: "%.1fk", config.totalVolume / 1000) + " \(config.weightUnit)"
                : "\(Int(config.totalVolume)) \(config.weightUnit)"
            s.append((vol, "volume"))
        }
        return s
    }
}
