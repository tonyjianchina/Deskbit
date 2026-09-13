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
        let cellHeight = max(1, (availableHeight - gap * CGFloat(rows - 1)) / CGFloat(rows))

        let columnWidths = (0..<columns).map { column in
            let start = column * rows
            let end = min(start + rows, count)
            return min(
                maximumColumnWidth,
                sizes[start..<end].map(\.width).max() ?? maximumColumnWidth
            )
        }
        var columnOrigins: [CGFloat] = []
        var nextX = visibleFrame.minX + margin
        for width in columnWidths {
            columnOrigins.append(nextX)
            nextX += width + gap
        }

        return sizes.enumerated().map { index, requestedSize in
            let column = index / rows
            let row = index % rows
            let size = NSSize(
                width: min(requestedSize.width, columnWidths[column]),
                height: min(requestedSize.height, cellHeight)
            )
            let x = columnOrigins[column]
            let cellTop = visibleFrame.maxY - margin - CGFloat(row) * (cellHeight + gap)
            return NSRect(x: x, y: cellTop - size.height, width: size.width, height: size.height)
        }
    }
}
