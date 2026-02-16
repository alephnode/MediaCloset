//
//  Views/Components/ColorVariantUtils.swift
//  MediaCloset
//
import SwiftUI

/// Maps common vinyl record color keywords to SwiftUI colors.
enum VinylColor {

    /// Known color keywords ordered so more-specific names match first.
    private static let colorMap: [(keyword: String, color: Color)] = [
        // Whites / clears
        ("white",       Color(red: 0.92, green: 0.92, blue: 0.92)),
        ("clear",       Color(red: 0.82, green: 0.85, blue: 0.88)),
        ("transparent", Color(red: 0.82, green: 0.85, blue: 0.88)),
        ("coke bottle", Color(red: 0.70, green: 0.75, blue: 0.68)),
        // Blacks / grays
        ("black",       Color(red: 0.10, green: 0.10, blue: 0.10)),
        ("grey",        .gray),
        ("gray",        .gray),
        ("silver",      Color(red: 0.75, green: 0.75, blue: 0.75)),
        ("smoke",       Color(red: 0.55, green: 0.55, blue: 0.55)),
        // Reds
        ("oxblood",     Color(red: 0.30, green: 0.05, blue: 0.05)),
        ("burgundy",    Color(red: 0.50, green: 0.00, blue: 0.13)),
        ("maroon",      Color(red: 0.50, green: 0.00, blue: 0.13)),
        ("crimson",     Color(red: 0.86, green: 0.08, blue: 0.24)),
        ("red",         .red),
        ("pink",        .pink),
        ("rose",        .pink),
        // Oranges / yellows
        ("orange",      .orange),
        ("amber",       Color(red: 1.0, green: 0.75, blue: 0.0)),
        ("gold",        Color(red: 1.0, green: 0.84, blue: 0.0)),
        ("yellow",      .yellow),
        ("cream",       Color(red: 1.0, green: 0.99, blue: 0.82)),
        ("bone",        Color(red: 0.89, green: 0.85, blue: 0.79)),
        // Greens
        ("olive",       Color(red: 0.42, green: 0.56, blue: 0.14)),
        ("forest",      Color(red: 0.13, green: 0.55, blue: 0.13)),
        ("mint",        Color(red: 0.60, green: 0.95, blue: 0.74)),
        ("green",       .green),
        ("lime",        Color(red: 0.75, green: 1.0, blue: 0.0)),
        ("teal",        .teal),
        // Blues
        ("navy",        Color(red: 0.0, green: 0.0, blue: 0.50)),
        ("royal blue",  Color(red: 0.25, green: 0.41, blue: 0.88)),
        ("baby blue",   Color(red: 0.54, green: 0.81, blue: 0.94)),
        ("blue",        .blue),
        ("cyan",        .cyan),
        // Purples
        ("purple",      .purple),
        ("violet",      Color(red: 0.56, green: 0.0, blue: 1.0)),
        ("lavender",    Color(red: 0.71, green: 0.49, blue: 0.86)),
        ("magenta",     Color(red: 1.0, green: 0.0, blue: 1.0)),
        // Browns
        ("brown",       .brown),
        ("tan",         Color(red: 0.82, green: 0.71, blue: 0.55)),
        ("copper",      Color(red: 0.72, green: 0.45, blue: 0.20)),
    ]

    // MARK: - Public API

    /// Extracts up to two SwiftUI `Color`s from a freeform variant description
    /// such as "Black with Red Splatter".
    static func extractColors(from description: String) -> [Color] {
        let lower = description.lowercased()
        var found: [Color] = []
        var usedRanges: [Range<String.Index>] = []

        for (keyword, color) in colorMap {
            if let range = lower.range(of: keyword) {
                let overlaps = usedRanges.contains { $0.overlaps(range) }
                if !overlaps {
                    found.append(color)
                    usedRanges.append(range)
                    if found.count >= 2 { break }
                }
            }
        }
        return found
    }

    /// Returns a single representative color for a variant, or nil if none.
    static func primaryColor(from description: String) -> Color? {
        extractColors(from: description).first
    }
}
