import SwiftUI

struct GridCanvasView: View {
    let vm: EditorViewModel

    @State private var gestureActive = false
    @State private var lastCell: GridCell? = nil

    private let gridColor   = Color(hex: "#d8dee5")
    private let inProgFill  = Color(hex: "#ffd166")
    private let inProgLine  = Color(hex: "#e0a420")
    private let selLine     = Color(hex: "#ff3b30")

    var body: some View {
        let cs = vm.cellSize
        Canvas { ctx, _ in
            drawBackground(&ctx, cs: cs)
            drawGrid(&ctx, cs: cs)
            for ob in vm.obstacles          { drawObstacle(ob, ctx: &ctx, cs: cs) }
            for (i, p) in vm.pieces.enumerated() {
                let sel = vm.selectedKind == .piece && vm.selectedId == p.id
                drawPiece(p, index: i, ctx: &ctx, cs: cs, selected: sel, inProgress: false)
            }
            if let cp = vm.currentPiece    { drawPiece(cp, index: -1, ctx: &ctx, cs: cs, selected: false, inProgress: true) }
        }
        .frame(width: CGFloat(vm.width) * cs, height: CGFloat(vm.height) * cs)
        .contentShape(.rect)
        .gesture(drawGesture)
    }

    // MARK: - Gesture

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                let cell = clampedCell(v.location)
                if !gestureActive {
                    gestureActive = true
                    lastCell = cell
                    vm.onDragStarted(at: cell)
                } else if cell != lastCell {
                    lastCell = cell
                    vm.onDragMoved(to: cell)
                }
            }
            .onEnded { _ in
                gestureActive = false
                lastCell = nil
                vm.onDragEnded()
            }
    }

    private func clampedCell(_ p: CGPoint) -> GridCell {
        GridCell(
            x: max(0, min(vm.width  - 1, Int(p.x / vm.cellSize))),
            y: max(0, min(vm.height - 1, Int(p.y / vm.cellSize)))
        )
    }

    private func cellRect(_ cell: GridCell, cs: CGFloat) -> CGRect {
        CGRect(x: CGFloat(cell.x) * cs + 1, y: CGFloat(cell.y) * cs + 1,
               width: cs - 2, height: cs - 2)
    }

    // MARK: - Drawing

    private func drawBackground(_ ctx: inout GraphicsContext, cs: CGFloat) {
        ctx.fill(Path(CGRect(x: 0, y: 0,
                             width: CGFloat(vm.width) * cs,
                             height: CGFloat(vm.height) * cs)),
                 with: .color(.white))
    }

    private func drawGrid(_ ctx: inout GraphicsContext, cs: CGFloat) {
        var path = Path()
        for x in 0...vm.width {
            let px = CGFloat(x) * cs
            path.move(to: CGPoint(x: px, y: 0))
            path.addLine(to: CGPoint(x: px, y: CGFloat(vm.height) * cs))
        }
        for y in 0...vm.height {
            let py = CGFloat(y) * cs
            path.move(to: CGPoint(x: 0, y: py))
            path.addLine(to: CGPoint(x: CGFloat(vm.width) * cs, y: py))
        }
        ctx.stroke(path, with: .color(gridColor), lineWidth: 0.5)
    }

    private func drawObstacle(_ ob: Obstacle, ctx: inout GraphicsContext, cs: CGFloat) {
        let rect = cellRect(ob.cell, cs: cs)
        let path = Path(roundedRect: rect, cornerRadius: 3)
        ctx.fill(path, with: .color(ob.kind.uiColor))
        let sel = vm.selectedKind == .obstacle && vm.selectedId == ob.id
        ctx.stroke(path, with: .color(sel ? selLine : Color(hex: "#555555")), lineWidth: sel ? 2.5 : 1)
        ctx.draw(
            Text(ob.kind.glyph).font(.system(size: cs * 0.45, weight: .bold)).foregroundStyle(.white),
            at: CGPoint(x: rect.midX, y: rect.midY)
        )
    }

    private func drawPiece(
        _ p: Piece, index: Int,
        ctx: inout GraphicsContext, cs: CGFloat,
        selected: Bool, inProgress: Bool
    ) {
        guard !p.cells.isEmpty else { return }
        let fill    = inProgress ? inProgFill : pieceColor(at: index)
        let outline = selected ? selLine : (inProgress ? inProgLine : Color(hex: "#333333"))
        let lw: CGFloat = selected ? 2.5 : 1.5

        // Body cells
        for cell in p.cells {
            let rect = cellRect(cell, cs: cs)
            let path = Path(roundedRect: rect, cornerRadius: 4)
            ctx.fill(path, with: .color(fill))
            ctx.stroke(path, with: .color(outline), lineWidth: lw)
        }

        // Connectors between adjacent cells
        for i in 1..<p.cells.count {
            let a = p.cells[i - 1], b = p.cells[i]
            let x0 = CGFloat(min(a.x, b.x)) * cs + cs / 4
            let y0 = CGFloat(min(a.y, b.y)) * cs + cs / 4
            let x1 = CGFloat(max(a.x, b.x) + 1) * cs - cs / 4
            let y1 = CGFloat(max(a.y, b.y) + 1) * cs - cs / 4
            ctx.fill(Path(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)),
                     with: .color(fill))
        }

        // Arrow on head
        if p.cells.count >= 2 && !inProgress, let head = p.cells.last {
            let r = cellRect(head, cs: cs)
            ctx.draw(
                Text(p.direction.arrow)
                    .font(.system(size: cs * 0.5, weight: .bold))
                    .foregroundStyle(.white),
                at: CGPoint(x: r.midX, y: r.midY)
            )
        }

        // Kind badge on tail
        if p.kind != .standard, let badge = p.kind.badge, let tail = p.cells.first {
            let r = cellRect(tail, cs: cs)
            ctx.draw(
                Text(badge)
                    .font(.system(size: cs * 0.3, weight: .bold))
                    .foregroundStyle(.white),
                at: CGPoint(x: r.minX + cs * 0.28, y: r.minY + cs * 0.28)
            )
        }
    }
}
