//
//  Views/Components/ColorVariantBadge.swift
//  MediaCloset
//
import SwiftUI

/// A pill-shaped badge that shows a visual color swatch alongside the variant
/// name. Supports single-color and dual-color (e.g. "Black with Red Splatter")
/// descriptions.
struct ColorVariantBadge: View {
    let variant: String

    /// Controls badge sizing.
    enum Size { case small, regular }
    var size: Size = .regular

    private var swatchDiameter: CGFloat {
        size == .small ? 10 : 14
    }

    private var fontSize: Font {
        size == .small ? .caption2 : .caption
    }

    private var hPadding: CGFloat {
        size == .small ? 6 : 10
    }

    private var vPadding: CGFloat {
        size == .small ? 3 : 5
    }

    var body: some View {
        HStack(spacing: size == .small ? 4 : 6) {
            ColorSwatch(variant: variant, diameter: swatchDiameter)
            Text(variant)
                .font(fontSize)
                .lineLimit(1)
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

/// A small circular swatch that renders one or two extracted colors.
struct ColorSwatch: View {
    let variant: String
    var diameter: CGFloat = 14

    var body: some View {
        let colors = VinylColor.extractColors(from: variant)

        ZStack {
            if colors.count >= 2 {
                // Split circle showing both colors
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if let primary = colors.first {
                Circle().fill(primary)
            } else {
                // Fallback: generic vinyl icon
                Image(systemName: "opticaldisc.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }

            // Subtle inner highlight for depth
            Circle()
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        }
        .frame(width: diameter, height: diameter)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ColorVariantBadge(variant: "Black")
        ColorVariantBadge(variant: "Red")
        ColorVariantBadge(variant: "Black with Red Splatter")
        ColorVariantBadge(variant: "Clear with Blue Marble")
        ColorVariantBadge(variant: "Gold")
        ColorVariantBadge(variant: "Custom Pressing", size: .small)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
