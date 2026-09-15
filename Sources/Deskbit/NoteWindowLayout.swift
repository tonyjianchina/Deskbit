import AppKit

enum NoteWindowLayout {
    static func alignedFrames(
        sizes: [NSSize],
        in visibleFrame: NSRect,
        margin: CGFloat = 16,
        gap: CGFloat = 12,
        maximumRows: Int = 4
    ) -> [NSRect] {
        guard !sizes.isEmpty else { return [] }

        let count = sizes.count
        let availableWidth = max(1, visibleFrame.width - margin * 2)
        let availableHeight = max(1, visibleFrame.height - margin * 2)
        let rows = min(count, max(1, maximumRows))
        let columns = Int(ceil(Double(count) / Double(rows)))
        let maximumColumnWidth = max(
            1,
            (availableWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
        )
        let columnRanges = (0..<columns).map { column in
            let start = column * rows
            let end = min(start + rows, count)
            return start..<end
        }
        let columnWidths = columnRanges.map { range in
            return min(
                maximumColumnWidth,
                sizes[range].map(\.width).max() ?? maximumColumnWidth
            )
        }
        let columnHeightScales = columnRanges.map { range in
            let requestedHeight = sizes[range].reduce(CGFloat.zero) { total, size in
                total + max(1, size.height)
            }
            let availableNoteHeight = max(1, availableHeight - gap * CGFloat(range.count - 1))
            return min(1, availableNoteHeight / requestedHeight)
        }
        var columnOrigins: [CGFloat] = []
        var nextX = visibleFrame.minX + margin
        for width in columnWidths {
            columnOrigins.append(nextX)
            nextX += width + gap
        }

        var columnTops = Array(repeating: visibleFrame.maxY - margin, count: columns)
        return sizes.enumerated().map { index, requestedSize in
            let column = index / rows
            let size = NSSize(
                width: min(requestedSize.width, columnWidths[column]),
                height: max(1, requestedSize.height) * columnHeightScales[column]
            )
            let x = columnOrigins[column]
            let y = columnTops[column] - size.height
            columnTops[column] = y - gap
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }
    }
}
