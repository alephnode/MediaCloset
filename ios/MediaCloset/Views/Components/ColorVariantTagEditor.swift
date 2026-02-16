//
//  Views/Components/ColorVariantTagEditor.swift
//  MediaCloset
//
import SwiftUI

/// A tag-based editor for color variants. Each variant is rendered as a
/// removable chip with a color swatch. New variants are added via a text field.
struct ColorVariantTagEditor: View {
    @Binding var variants: [String]

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Existing tags in a wrapping flow layout
            if !variants.isEmpty {
                WrappingHStack(alignment: .leading, spacing: 8) {
                    ForEach(variants, id: \.self) { variant in
                        tagChip(variant)
                    }
                }
            }

            // Input row
            HStack(spacing: 8) {
                TextField("Add variant (e.g. Black, Clear w/ Red)", text: $draft)
                    .textInputAutocapitalization(.words)
                    .focused($fieldFocused)
                    .onSubmit { commitDraft() }

                if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        commitDraft()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func tagChip(_ variant: String) -> some View {
        HStack(spacing: 4) {
            ColorSwatch(variant: variant, diameter: 12)
            Text(variant)
                .font(.callout)
                .lineLimit(1)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    variants.removeAll { $0 == variant }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Helpers

    private func commitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Support pasting comma-separated values
        let newVariants = trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !variants.contains($0) }

        withAnimation(.easeInOut(duration: 0.2)) {
            variants.append(contentsOf: newVariants)
        }
        draft = ""
    }
}

// MARK: - Wrapping HStack (Flow Layout)

/// A simple flow-layout container that wraps children to the next line when
/// they exceed the available width.
struct WrappingHStack: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            if i > 0 { y += spacing }
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

#Preview {
    struct Preview: View {
        @State var variants = ["Black", "Red with Gold Splatter"]
        var body: some View {
            Form {
                Section("Color Variants") {
                    ColorVariantTagEditor(variants: $variants)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    return Preview()
}
