// ArrowDrawing.swift - Lichess-style arrow drawing with move-specific storage

import SwiftUI

// MARK: - Circle Highlight Data Structure
struct ChessCircle: Identifiable, Equatable {
    let id = UUID()
    let square: Square
    let color: Color
    
    static func == (lhs: ChessCircle, rhs: ChessCircle) -> Bool {
        return lhs.square == rhs.square
    }
}
struct ChessArrow: Identifiable, Equatable {
    let id = UUID()
    let from: Square
    let to: Square
    let color: Color
    
    static func == (lhs: ChessArrow, rhs: ChessArrow) -> Bool {
        return lhs.from == rhs.from && lhs.to == rhs.to
    }
}

// MARK: - Arrow Manager
class ArrowManager: ObservableObject {
    @Published var currentArrows: [ChessArrow] = []
    @Published var currentCircles: [ChessCircle] = []
    @Published var previewArrow: PreviewArrow? = nil
    @Published var isDrawing = false
    @Published private(set) var startSquare: Square? = nil
    
    // Store arrows and circles per move index
    private var arrowsByMoveIndex: [Int: [ChessArrow]] = [:]
    private var circlesByMoveIndex: [Int: [ChessCircle]] = [:]
    private var currentMoveIndex: Int = 0
    
    struct PreviewArrow {
        let from: Square
        let to: Square
        let color: Color
    }
    
    func setCurrentMove(_ moveIndex: Int) {
        // Save current arrows and circles to the previous move index
        if !currentArrows.isEmpty {
            arrowsByMoveIndex[currentMoveIndex] = currentArrows
        }
        if !currentCircles.isEmpty {
            circlesByMoveIndex[currentMoveIndex] = currentCircles
        }
        
        // Update to new move index
        currentMoveIndex = moveIndex
        
        // Load arrows and circles for the new move index
        currentArrows = arrowsByMoveIndex[moveIndex] ?? []
        currentCircles = circlesByMoveIndex[moveIndex] ?? []
        
        // Cancel any drawing in progress
        cancelDrawing()
        
        print("🔄 Switched to move \(moveIndex), loaded \(currentArrows.count) arrows, \(currentCircles.count) circles")
    }
    
    func startDrawing(from square: Square) {
        isDrawing = true
        startSquare = square
        previewArrow = nil
    }
    
    func updatePreview(to square: Square) {
        guard let startSquare = startSquare else { return }
        previewArrow = PreviewArrow(from: startSquare, to: square, color: .blue.opacity(0.7))
    }
    
    func finishDrawing(to square: Square) {
        guard let startSquare = startSquare else { return }
        
        if startSquare == square {
            // Same square - create/toggle circle
            if let existingIndex = currentCircles.firstIndex(where: { $0.square == square }) {
                // Remove existing circle
                currentCircles.remove(at: existingIndex)
                print("🔴 Removed circle from \(square) for move \(currentMoveIndex)")
            } else {
                // Add new circle
                let newCircle = ChessCircle(square: square, color: .red)
                currentCircles.append(newCircle)
                print("🟡 Added circle to \(square) for move \(currentMoveIndex)")
            }
            
            // Save circles to current move index
            circlesByMoveIndex[currentMoveIndex] = currentCircles
        } else {
            // Different squares - create/toggle arrow
            if let existingIndex = currentArrows.firstIndex(where: { $0.from == startSquare && $0.to == square }) {
                // Remove existing arrow
                currentArrows.remove(at: existingIndex)
                print("🗑️ Removed arrow from \(startSquare) to \(square) for move \(currentMoveIndex)")
            } else {
                // Add new arrow
                let newArrow = ChessArrow(from: startSquare, to: square, color: .blue)
                currentArrows.append(newArrow)
                print("➕ Added arrow from \(startSquare) to \(square) for move \(currentMoveIndex)")
            }
            
            // Save arrows to current move index
            arrowsByMoveIndex[currentMoveIndex] = currentArrows
        }
        
        // Reset state
        isDrawing = false
        self.startSquare = nil
        previewArrow = nil
    }
    
    func cancelDrawing() {
        isDrawing = false
        self.startSquare = nil
        previewArrow = nil
    }
    
    func clearAllArrows() {
        currentArrows.removeAll()
        currentCircles.removeAll()
        arrowsByMoveIndex[currentMoveIndex] = []
        circlesByMoveIndex[currentMoveIndex] = []
        cancelDrawing()
        print("🗑️ Cleared arrows and circles for move \(currentMoveIndex)")
    }
    
    func clearAllArrowsForAllMoves() {
        currentArrows.removeAll()
        currentCircles.removeAll()
        arrowsByMoveIndex.removeAll()
        circlesByMoveIndex.removeAll()
        cancelDrawing()
        print("🗑️ Cleared ALL arrows and circles for ALL moves")
    }
    
    // Debug function to see what's stored
    func debugArrowStorage() {
        print("📊 Arrow & Circle storage debug:")
        print("   Current move: \(currentMoveIndex)")
        print("   Current arrows: \(currentArrows.count)")
        print("   Current circles: \(currentCircles.count)")
        for (moveIndex, arrows) in arrowsByMoveIndex.sorted(by: { $0.key < $1.key }) {
            let circles = circlesByMoveIndex[moveIndex]?.count ?? 0
            print("   Move \(moveIndex): \(arrows.count) arrows, \(circles) circles")
        }
    }
}

// MARK: - Circle Shape
struct CircleShape: Shape {
    let square: Square
    let boardSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let squareSize = boardSize / 8
        
        // Calculate center point of square
        let centerPoint = CGPoint(
            x: CGFloat(square.file.rawValue) * squareSize + squareSize / 2,
            y: CGFloat(7 - square.rank.rawValue) * squareSize + squareSize / 2
        )
        
        // Circle radius (smaller than square to leave some margin)
        let radius = squareSize * 0.35
        
        var path = Path()
        path.addEllipse(in: CGRect(
            x: centerPoint.x - radius,
            y: centerPoint.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        
        return path
    }
}
struct ArrowShape: Shape {
    let from: Square
    let to: Square
    let boardSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let squareSize = boardSize / 8
        
        // Calculate center points of squares
        // SwiftUI drawing coordinates: y=0 at TOP, increasing downward
        // But we want rank 8 at top, rank 1 at bottom
        // So rank 1 (index 0) should be at bottom: y = 7 * squareSize + squareSize/2
        // rank 8 (index 7) should be at top: y = 0 * squareSize + squareSize/2
        let fromPoint = CGPoint(
            x: CGFloat(from.file.rawValue) * squareSize + squareSize / 2,
            y: CGFloat(7 - from.rank.rawValue) * squareSize + squareSize / 2
        )
        
        let toPoint = CGPoint(
            x: CGFloat(to.file.rawValue) * squareSize + squareSize / 2,
            y: CGFloat(7 - to.rank.rawValue) * squareSize + squareSize / 2
        )
        
        print("🎯 Arrow from \(from) (\(fromPoint)) to \(to) (\(toPoint))")
        
        // Calculate arrow properties
        let dx = toPoint.x - fromPoint.x
        let dy = toPoint.y - fromPoint.y
        let length = sqrt(dx * dx + dy * dy)
        
        guard length > 0 else { return Path() }
        
        // Normalize direction
        let unitX = dx / length
        let unitY = dy / length
        
        // Arrow dimensions
        let arrowHeadLength = max(12, boardSize / 30)
        let arrowHeadWidth = max(6, boardSize / 50)
        
        // Shorten arrow to avoid overlapping pieces
        let shortenBy = squareSize * 0.2
        let adjustedFromPoint = CGPoint(
            x: fromPoint.x + unitX * shortenBy,
            y: fromPoint.y + unitY * shortenBy
        )
        let adjustedToPoint = CGPoint(
            x: toPoint.x - unitX * shortenBy,
            y: toPoint.y - unitY * shortenBy
        )
        
        // Calculate arrow head
        let arrowTip = adjustedToPoint
        let arrowBase = CGPoint(
            x: arrowTip.x - unitX * arrowHeadLength,
            y: arrowTip.y - unitY * arrowHeadLength
        )
        
        // Perpendicular vector for arrow head
        let perpX = -unitY
        let perpY = unitX
        
        let arrowLeft = CGPoint(
            x: arrowBase.x + perpX * arrowHeadWidth,
            y: arrowBase.y + perpY * arrowHeadWidth
        )
        
        let arrowRight = CGPoint(
            x: arrowBase.x - perpX * arrowHeadWidth,
            y: arrowBase.y - perpY * arrowHeadWidth
        )
        
        // Create path
        var path = Path()
        
        // Arrow shaft
        path.move(to: adjustedFromPoint)
        path.addLine(to: arrowBase)
        
        // Arrow head
        path.move(to: arrowLeft)
        path.addLine(to: arrowTip)
        path.addLine(to: arrowRight)
        
        return path
    }
}

// MARK: - Arrow Drawing View
struct ArrowDrawingView: View {
    let currentArrows: [ChessArrow]
    let currentCircles: [ChessCircle]
    let previewArrow: ArrowManager.PreviewArrow?
    let boardSize: CGFloat
    
    var body: some View {
        ZStack {
            // Permanent arrows for current move
            ForEach(currentArrows) { arrow in
                ArrowShape(from: arrow.from, to: arrow.to, boardSize: boardSize)
                    .stroke(arrow.color, lineWidth: max(3, boardSize / 120))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)
            }
            
            // Circle highlights for current move
            ForEach(currentCircles) { circle in
                CircleShape(square: circle.square, boardSize: boardSize)
                    .stroke(circle.color, lineWidth: max(4, boardSize / 100))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)
            }
            
            // Preview arrow while dragging
            if let preview = previewArrow {
                ArrowShape(from: preview.from, to: preview.to, boardSize: boardSize)
                    .stroke(preview.color, lineWidth: max(3, boardSize / 120))
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 1, y: 1)
            }
        }
    }
}

// MARK: - Lichess-style Square View
struct LichessSquareView: View {
    let square: Square
    let piece: Piece?
    let isHighlighted: Bool
    let isLastMoveSquare: Bool
    let arrowManager: ArrowManager
    
    @State private var isHovered = false
    
    private var baseSquareColor: Color {
        let isLight = (square.file.rawValue + square.rank.rawValue) % 2 == 0
        return isLight ? Color(red: 0.9, green: 0.85, blue: 0.76) : Color(red: 0.7, green: 0.5, blue: 0.3)
    }
    
    private var finalSquareColor: Color {
        if isHighlighted {
            return Color.yellow.opacity(0.8)
        } else if isLastMoveSquare {
            let isLight = (square.file.rawValue + square.rank.rawValue) % 2 == 0
            return isLight ? Color(red: 0.7, green: 0.7, blue: 0.9) : Color(red: 0.5, green: 0.4, blue: 0.6)
        } else if arrowManager.startSquare == square {
            return baseSquareColor.opacity(0.7)
        } else {
            return baseSquareColor
        }
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(finalSquareColor)
            
            if isHighlighted {
                Rectangle()
                    .stroke(Color.orange, lineWidth: 3)
            }
            
            if arrowManager.startSquare == square {
                Rectangle()
                    .stroke(Color.green, lineWidth: 3)
            }
            
            if let piece = piece {
                Image(piece.imageName)
                    .resizable()
                    .scaledToFit()
            }
            
            if isHighlighted {
                Rectangle()
                    .fill(Color.yellow.opacity(0.2))
                    .blur(radius: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onHover { hovering in
            isHovered = hovering
            if hovering && arrowManager.isDrawing {
                arrowManager.updatePreview(to: square)
            }
        }
        .onTapGesture {
            // Handle regular clicks for finishing arrows
            if arrowManager.isDrawing {
                arrowManager.finishDrawing(to: square)
            }
        }
    }
}

// MARK: - Board Container with Right-Click Detection
struct LichessChessBoard: View {
    let board: Board
    let highlightManager: MoveHighlightManager
    @Binding var boardSize: CGFloat
    @StateObject private var arrowManager = ArrowManager()
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
    
    var body: some View {
        ZStack {
            // Chess squares (bottom layer)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach((0..<8).reversed(), id: \.self) { rankIndex in
                    ForEach(0..<8, id: \.self) { fileIndex in
                        let square = Square(file: File(rawValue: fileIndex)!, rank: Rank(rawValue: rankIndex)!)
                        let piece = board.piece(at: square)
                        
                        LichessSquareView(
                            square: square,
                            piece: piece,
                            isHighlighted: highlightManager.isHighlighted(square),
                            isLastMoveSquare: highlightManager.isLastMoveSquare(square),
                            arrowManager: arrowManager
                        )
                    }
                }
            }
            .frame(width: boardSize, height: boardSize)
            
            // Arrow overlay (middle layer)
            ArrowDrawingView(
                currentArrows: arrowManager.currentArrows,
                currentCircles: arrowManager.currentCircles,
                previewArrow: arrowManager.previewArrow,
                boardSize: boardSize
            )
            .frame(width: boardSize, height: boardSize)
            .allowsHitTesting(false)
            
            // Event handling overlay (top layer - captures all events)
            LichessBoardBackground(arrowManager: arrowManager, boardSize: boardSize)
                .frame(width: boardSize, height: boardSize)
                .allowsHitTesting(true) // This should capture all mouse events
        }
        .border(Color.black, width: 1)
        // Add keyboard shortcuts for clearing arrows
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearArrows"))) { _ in
            arrowManager.clearAllArrows()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearAllArrows"))) { _ in
            arrowManager.clearAllArrowsForAllMoves()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoveIndexChanged"))) { notification in
            if let moveIndex = notification.object as? Int {
                arrowManager.setCurrentMove(moveIndex)
            }
        }
    }
}

// MARK: - Board Background for Event Handling
struct LichessBoardBackground: NSViewRepresentable {
    @ObservedObject var arrowManager: ArrowManager
    let boardSize: CGFloat
    
    func makeNSView(context: Context) -> NSView {
        print("Creating LichessBoardView with size: \(boardSize)")
        let view = LichessBoardView()
        view.arrowManager = arrowManager
        view.boardSize = boardSize
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        print("Updating LichessBoardView with size: \(boardSize)")
        if let view = nsView as? LichessBoardView {
            view.arrowManager = arrowManager
            view.boardSize = boardSize
        }
    }
}

class LichessBoardView: NSView {
    var arrowManager: ArrowManager?
    var boardSize: CGFloat = 350
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Disable context menu to prevent interference
        menu = nil
        // Make sure we can receive mouse events
        wantsLayer = true
        needsDisplay = true
        // Make the view transparent so board squares show through
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview != nil {
            print("Board view added to superview, frame: \(frame)")
            // Become first responder to receive events
            window?.makeFirstResponder(self)
        }
    }
    
    // Override all mouse events and add extensive debugging
    override func mouseDown(with event: NSEvent) {
        print("🔵 Left mouse down detected, modifiers: \(event.modifierFlags)")
        
        // Check for Control+Click (alternative to right-click)
        if event.modifierFlags.contains(.control) {
            print("🟢 Control+Click detected - treating as right click")
            handleRightClick(event)
        } else {
            print("🔵 Regular left click")
            // Don't call super - we want to handle all events
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        print("🔵 Left drag detected")
        if event.modifierFlags.contains(.control) {
            print("🟢 Control+Drag detected")
            handleRightDrag(event)
        }
        // Don't call super
    }
    
    override func mouseUp(with event: NSEvent) {
        print("🔵 Left mouse up detected")
        if event.modifierFlags.contains(.control) {
            print("🟢 Control+Up detected")
            handleRightUp(event)
        }
        // Don't call super
    }
    
    override func rightMouseDown(with event: NSEvent) {
        print("🔴 Right mouse down detected at window location: \(event.locationInWindow)")
        handleRightClick(event)
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        print("🔴 Right mouse dragged")
        handleRightDrag(event)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        print("🔴 Right mouse up")
        handleRightUp(event)
    }
    
    // Add otherMouseDown to catch all other button events
    override func otherMouseDown(with event: NSEvent) {
        print("🟡 Other mouse down, button: \(event.buttonNumber), clickCount: \(event.clickCount)")
        super.otherMouseDown(with: event)
    }
    
    private func handleRightClick(_ event: NSEvent) {
        guard let arrowManager = arrowManager else {
            print("❌ No arrow manager available")
            return
        }
        
        let location = convert(event.locationInWindow, from: nil)
        print("📍 Converted location: \(location), view bounds: \(bounds)")
        
        if let square = pointToSquare(location) {
            arrowManager.startDrawing(from: square)
            print("✅ Started drawing arrow from \(square)")
        } else {
            print("❌ Location \(location) is outside board bounds")
        }
    }
    
    private func handleRightDrag(_ event: NSEvent) {
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.updatePreview(to: square)
            print("🔄 Dragging to \(square)")
        }
    }
    
    private func handleRightUp(_ event: NSEvent) {
        guard let arrowManager = arrowManager else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let square = pointToSquare(location) {
            arrowManager.finishDrawing(to: square)
            print("🏁 Finished arrow at \(square)")
        } else {
            arrowManager.cancelDrawing()
            print("🚫 Cancelled arrow drawing")
        }
    }
    
    // Add keyboard shortcuts for clearing arrows
    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        print("🎹 Key pressed: \(event.charactersIgnoringModifiers ?? "unknown"), keyCode: \(keyCode)")
        
        if keyCode == 51 { // Delete key
            arrowManager?.clearAllArrows()
            print("🗑️ Cleared arrows for current move")
        } else if keyCode == 51 && event.modifierFlags.contains(.command) { // Cmd+Delete
            arrowManager?.clearAllArrowsForAllMoves()
            print("🗑️ Cleared ALL arrows for ALL moves")
        } else if keyCode == 15 { // "r" key
            arrowManager?.clearAllArrowsForAllMoves()
            print("🔄 Reset: Cleared ALL arrows for ALL moves")
        } else {
            super.keyDown(with: event)
        }
    }
    
    private func pointToSquare(_ point: CGPoint) -> Square? {
        let squareSize = boardSize / 8
        let fileIndex = Int(point.x / squareSize)
        
        // NSView coordinate system: y=0 at bottom, y=boardSize at top
        // Our board layout: rank 1 at bottom, rank 8 at top
        // So we can use the point.y directly without flipping
        let ySquareIndex = Int(point.y / squareSize)
        
        print("📐 Raw Point \(point)")
        print("   - squareSize: \(squareSize)")
        print("   - fileIndex: \(fileIndex)")
        print("   - ySquareIndex: \(ySquareIndex)")
        
        // ySquareIndex 0 = rank 1 (bottom), ySquareIndex 7 = rank 8 (top)
        let rankIndex = ySquareIndex
        
        print("   - calculated rankIndex: \(rankIndex)")
        
        guard fileIndex >= 0, fileIndex < 8, rankIndex >= 0, rankIndex < 8,
              let file = File(rawValue: fileIndex),
              let rank = Rank(rawValue: rankIndex) else {
            print("❌ Invalid square coordinates")
            return nil
        }
        
        let square = Square(file: file, rank: rank)
        print("📍 Final square: \(square) (file=\(file.description), rank=\(rank.description))")
        return square
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        print("🎯 acceptsFirstMouse called")
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        print("🎯 acceptsFirstResponder called")
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        print("🎯 becomeFirstResponder called")
        return super.becomeFirstResponder()
    }
    
    // Make sure hit testing works and reduce spam
    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        // Only print occasionally to reduce spam
        if Int.random(in: 0...50) == 0 {
            print("🎯 Hit test sample at \(point) returned: \(String(describing: result))")
        }
        return result
    }
}
