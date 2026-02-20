//
//  Views/Components/SkeletonRow.swift
//  MediaCloset
//
//  Created by Stephen Ward on 2/15/26.
//
import SwiftUI

// MARK: - Skeleton Record Row

/// Ghost row that mirrors the shape of a real RecordListView row.
/// Accepts an `index` so adjacent rows have slightly varied text widths.
struct SkeletonRecordRow: View {
    let index: Int

    private var artistWidth: CGFloat {
        [120, 100, 140, 110, 130, 95, 150, 108][index % 8]
    }
    private var albumWidth: CGFloat {
        [170, 150, 190, 160, 145, 180, 155, 175][index % 8]
    }
    private var detailWidth: CGFloat {
        [60, 80, 50, 70, 55, 90, 65, 75][index % 8]
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: artistWidth, height: 15)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: albumWidth, height: 13)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: detailWidth, height: 11)
            }

            Spacer()
        }
        .modifier(SkeletonPulse())
    }
}

// MARK: - Skeleton VHS Row

/// Ghost row that mirrors the shape of a real VHSListView row.
struct SkeletonVHSRow: View {
    let index: Int

    private var titleWidth: CGFloat {
        [140, 115, 155, 125, 145, 105, 160, 130][index % 8]
    }
    private var detailWidth: CGFloat {
        [180, 160, 200, 170, 150, 190, 165, 185][index % 8]
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: titleWidth, height: 15)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: detailWidth, height: 13)
            }

            Spacer()
        }
        .modifier(SkeletonPulse())
    }
}

// MARK: - Skeleton Cassette Row

/// Ghost row that mirrors the shape of a real CassetteListView row.
struct SkeletonCassetteRow: View {
    let index: Int

    private var artistWidth: CGFloat {
        [120, 100, 140, 110, 130, 95, 150, 108][index % 8]
    }
    private var albumWidth: CGFloat {
        [170, 150, 190, 160, 145, 180, 155, 175][index % 8]
    }
    private var detailWidth: CGFloat {
        [60, 80, 50, 70, 55, 90, 65, 75][index % 8]
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: artistWidth, height: 15)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: albumWidth, height: 13)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: detailWidth, height: 11)
            }

            Spacer()
        }
        .modifier(SkeletonPulse())
    }
}

// MARK: - Pulse Animation

/// Subtle opacity pulse that fades skeleton rows between full and half opacity.
private struct SkeletonPulse: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}
