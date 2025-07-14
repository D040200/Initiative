// ContentView.swift - Enhanced with move highlighting and interaction
import SwiftUI

// MARK: - Game Tab Data
struct GameTab: Identifiable {
    let id = UUID()
    let game: ChessGameEntity
    let viewModel: GameViewModel
    
    init(game: ChessGameEntity) {
        self.game = game
        self.viewModel = GameViewModel()
        self.viewModel.loadGame(from: game)
    }
}

// MARK: - Open Games Manager
class OpenGamesManager: ObservableObject {
    @Published var openTabs: [GameTab] = []
    @Published var activeTabId: UUID? = nil
    @Published var globalBoardSize: CGFloat = 350
    
    static let shared = OpenGamesManager()
    
    private init() {}
    
    func openGame(_ game: ChessGameEntity) {
        // Don't add if already open
        if !openTabs.contains(where: { $0.game.id == game.id }) {
            let newTab = GameTab(game: game)
            openTabs.append(newTab)
            activeTabId = newTab.id
        } else {
            // If already open, just activate it
            if let existingTab = openTabs.first(where: { $0.game.id == game.id }) {
                activeTabId = existingTab.id
            }
        }
    }
    
    func closeTab(_ tab: GameTab) {
        openTabs.removeAll { $0.id == tab.id }
        
        // If we closed the active tab, select another one or set to nil
        if activeTabId == tab.id {
            activeTabId = openTabs.first?.id
        }
    }
    
    func setActiveTab(_ tab: GameTab) {
        activeTabId = tab.id
    }
    
    var activeTab: GameTab? {
        return openTabs.first { $0.id == activeTabId }
    }
    
    func closeAllTabs() {
        openTabs.removeAll()
        activeTabId = nil
    }
}

// MARK: - Enhanced Game View Model with Move Interaction
class GameViewModel: ObservableObject {
    @Published var game: Game = Game()
    @Published var currentMoveIndex: Int = 0
    @Published var pgnGame: PGN? = nil
    @Published var errorMessage: String? = nil
    @Published var gameTitle: String = "No Game"
    @Published var highlightManager = MoveHighlightManager()
    
    // NEW: Move interaction properties
    @Published var selectedSquare: Square? = nil
    @Published var validMoves: [Move] = []
    @Published var currentVariation: GameVariation? = nil
    @Published var isInVariationMode = false
    
    var boardHistory: [Board] = []
    private var moveHistory: [Move] = [] // Track the actual moves made
    
    init() {
        // Don't load default game anymore - let tabs manage their own content
    }
    
    func loadGame(from entity: ChessGameEntity) {
        guard let pgnString = entity.pgnString else { return }
        loadGame(pgnString: pgnString, title: entity.displayTitle)
    }
    
    func loadGame(pgnString: String, title: String) {
        do {
            let parsedPgn = try PGNParser.parse(pgnString: pgnString)
            self.pgnGame = parsedPgn
            self.gameTitle = title
            
            if let initialBoardFromFEN = Board(fen: parsedPgn.initialFen) {
                self.game = Game(board: initialBoardFromFEN, activeColor: .white)
            } else {
                self.game = Game()
            }
            
            self.boardHistory = [self.game.board]
            self.moveHistory = [] // Reset move history
            
            var tempGame = self.game
            for sanMoveString in parsedPgn.moves {
                do {
                    let move = try MoveParser.parse(san: sanMoveString, currentBoard: tempGame.board, activeColor: tempGame.activeColor)
                    self.moveHistory.append(move) // Store the actual move
                    tempGame.makeMove(move)
                    self.boardHistory.append(tempGame.board)
                } catch {
                    self.errorMessage = "Error parsing or applying move '\(sanMoveString)': \(error.localizedDescription)"
                    break
                }
            }
            
            self.currentMoveIndex = 0
            if let firstBoard = boardHistory.first {
                self.game.board = firstBoard
            }
            
            // Clear highlights when loading new game
            highlightManager.clearHighlights()
            
        } catch {
            self.errorMessage = "Error parsing PGN: \(error.localizedDescription)"
        }
    }
    
    var totalPositions: Int {
        return boardHistory.count
    }
    
    func nextPosition() {
        if currentMoveIndex < boardHistory.count - 1 {
            currentMoveIndex += 1
            game.board = boardHistory[currentMoveIndex]
            updateHighlighting()
            
            // Notify arrow manager of move change
            NotificationCenter.default.post(
                name: NSNotification.Name("MoveIndexChanged"),
                object: currentMoveIndex
            )
        }
    }

    func previousPosition() {
        if currentMoveIndex > 0 {
            currentMoveIndex -= 1
            game.board = boardHistory[currentMoveIndex]
            updateHighlighting()
            
            // Notify arrow manager of move change
            NotificationCenter.default.post(
                name: NSNotification.Name("MoveIndexChanged"),
                object: currentMoveIndex
            )
        }
    }

    func navigateToMove(_ moveIndex: Int) {
        guard moveIndex >= 0 && moveIndex < boardHistory.count else { return }
        currentMoveIndex = moveIndex
        game.board = boardHistory[moveIndex]
        updateHighlighting()
        
        // Notify arrow manager of move change
        NotificationCenter.default.post(
            name: NSNotification.Name("MoveIndexChanged"),
            object: currentMoveIndex
        )
    }
    
    private func updateHighlighting() {
        // Clear highlights if we're at the starting position
        guard currentMoveIndex > 0 else {
            highlightManager.clearHighlights()
            return
        }
        
        // Get the move that led to the current position
        let moveHistoryIndex = currentMoveIndex - 1
        guard moveHistoryIndex < moveHistory.count else {
            highlightManager.clearHighlights()
            return
        }
        
        let lastMove = moveHistory[moveHistoryIndex]
        highlightManager.highlightMove(lastMove)
    }
    
    // MARK: - NEW: Move Interaction Methods
    
    func selectSquare(_ square: Square) {
        print("🔍 GameViewModel.selectSquare called with: \(square)")
        
        // Clear previous selection
        validMoves.removeAll()
        
        // If clicking on the same square, deselect
        if selectedSquare == square {
            selectedSquare = nil
            print("🔍 Deselected square \(square)")
            return
        }
        
        // If there's a piece on this square, select it (ignore color for now)
        if let piece = game.board.piece(at: square) {
            print("🔍 Found piece: \(piece.type) at \(square)")
            selectedSquare = square
            // Generate valid moves for this piece
            validMoves = generateValidMovesForPiece(at: square)
            print("🔍 Selected \(piece.type) at \(square), found \(validMoves.count) valid moves")
            for move in validMoves.prefix(3) {
                print("🔍   Valid move: \(move.to)")
            }
        } else {
            print("🔍 No piece found at \(square)")
        }
    }
    func attemptMove(from: Square, to: Square) {
        print("🚀 GameViewModel.attemptMove called: \(from) -> \(to)")
        
        guard let piece = game.board.piece(at: from) else {
            print("🚀 No piece at source square \(from)")
            return
        }
        
        print("🚀 Found piece: \(piece.type)")
        
        // CRITICAL FIX: If we don't have valid moves for this piece, generate them now
        if selectedSquare != from || validMoves.isEmpty {
            print("🚀 No valid moves cached, generating for drag move...")
            selectSquare(from)
        }
        
        print("🚀 Now have \(validMoves.count) valid moves to check against")
        
        // Check if this is a valid move
        let move = Move(from: from, to: to, piece: piece, capturedPiece: game.board.piece(at: to))
        
        if isValidMove(move) {
            print("🚀 Move is valid, executing...")
            executeMove(move)
        } else {
            print("🚀 Invalid move attempted: \(piece.type) from \(from) to \(to)")
            print("🚀 Valid moves are:")
            for validMove in validMoves {
                print("🚀   \(validMove.from) -> \(validMove.to)")
            }
        }
        
        // Clear selection after move attempt
        selectedSquare = nil
        validMoves.removeAll()
    }
    private func generateValidMovesForPiece(at square: Square) -> [Move] {
        guard let piece = game.board.piece(at: square) else {
            print("🔍 No piece found at \(square)")
            return []
        }
        
        print("🔍 Trying BOARD system for \(piece.type) at \(square)")
        
        // First try the proper board move generation
        let boardMoves = game.board.generateLegalMoves(for: piece.color)
            .filter { $0.from == square }
        
        print("🔍 BOARD system generated \(boardMoves.count) moves")
        
        if !boardMoves.isEmpty {
            // Board system works - use it!
            print("🔍 Using BOARD system moves:")
            for move in boardMoves.prefix(5) {
                print("🔍   \(move.from) -> \(move.to)")
            }
            return boardMoves
        }
        
        // Manual system with special moves
        print("🔍 BOARD system failed, using enhanced manual system")
        
        // Proper turn calculation
        let currentPlayer: PieceColor
        if isInVariationMode && currentVariation != nil {
            let baseMove = currentVariation!.startingMoveIndex
            let variationMoves = currentVariation!.moves.count
            let totalMoves = baseMove + variationMoves
            currentPlayer = totalMoves % 2 == 0 ? .white : .black
        } else {
            currentPlayer = currentMoveIndex % 2 == 0 ? .white : .black
        }
        
        guard piece.color == currentPlayer else {
            print("🔍 Wrong color - piece is \(piece.color), current player is \(currentPlayer)")
            return []
        }
        
        var moves: [Move] = []
        
        switch piece.type {
        case .pawn:
            moves.append(contentsOf: generatePawnMovesWithSpecial(piece: piece, at: square))
            
        case .king:
            moves.append(contentsOf: generateKingMovesWithCastling(piece: piece, at: square))
            
        case .knight:
            moves.append(contentsOf: generateKnightMoves(piece: piece, at: square))
            
        case .bishop:
            moves.append(contentsOf: generateBishopMoves(piece: piece, at: square))
            
        case .rook:
            moves.append(contentsOf: generateRookMoves(piece: piece, at: square))
            
        case .queen:
            moves.append(contentsOf: generateQueenMoves(piece: piece, at: square))
        }
        
        print("🔍 Enhanced manual system generated \(moves.count) moves")
        return moves
    }

    // MARK: - Enhanced Move Generation with Special Moves

    private func generatePawnMovesWithSpecial(piece: Piece, at square: Square) -> [Move] {
        var moves: [Move] = []
        let direction = piece.color == .white ? 1 : -1
        let startingRank = piece.color == .white ? Rank.two : Rank.seven
        let promotionRank = piece.color == .white ? Rank.eight : Rank.one
        
        // Forward moves
        if let oneSquareUp = Rank(rawValue: square.rank.rawValue + direction) {
            let targetSquare = Square(file: square.file, rank: oneSquareUp)
            if game.board.piece(at: targetSquare) == nil {
                // Check for promotion
                if oneSquareUp == promotionRank {
                    moves.append(Move(from: square, to: targetSquare, piece: piece, flag: .promotion(.queen)))
                    print("🔍 Added pawn promotion move \(square) -> \(targetSquare)")
                } else {
                    moves.append(Move(from: square, to: targetSquare, piece: piece))
                }
                
                // Double move from starting position
                if square.rank == startingRank,
                   let twoSquaresUp = Rank(rawValue: square.rank.rawValue + 2 * direction) {
                    let doubleTargetSquare = Square(file: square.file, rank: twoSquaresUp)
                    if game.board.piece(at: doubleTargetSquare) == nil {
                        moves.append(Move(from: square, to: doubleTargetSquare, piece: piece, flag: .doublePawnPush))
                    }
                }
            }
        }
        
        // Pawn captures (including en passant)
        for fileOffset in [-1, 1] {
            if let newFile = File(rawValue: square.file.rawValue + fileOffset),
               let newRank = Rank(rawValue: square.rank.rawValue + direction) {
                let targetSquare = Square(file: newFile, rank: newRank)
                
                if let targetPiece = game.board.piece(at: targetSquare), targetPiece.color != piece.color {
                    // Regular capture
                    if newRank == promotionRank {
                        moves.append(Move(from: square, to: targetSquare, piece: piece, capturedPiece: targetPiece, flag: .promotion(.queen)))
                    } else {
                        moves.append(Move(from: square, to: targetSquare, piece: piece, capturedPiece: targetPiece, flag: .capture))
                    }
                } else if game.board.piece(at: targetSquare) == nil {
                    // Check for en passant
                    if (piece.color == .white && square.rank == .five) || (piece.color == .black && square.rank == .four) {
                        let capturedPawnSquare = Square(file: newFile, rank: square.rank)
                        if let capturedPawn = game.board.piece(at: capturedPawnSquare),
                           capturedPawn.type == .pawn && capturedPawn.color != piece.color {
                            // Simple en passant check: if there's an enemy pawn next to us, allow en passant
                            // (In a full implementation, we'd check if it just moved 2 squares)
                            moves.append(Move(from: square, to: targetSquare, piece: piece, capturedPiece: capturedPawn, flag: .enPassantCapture))
                            print("🔍 Added en passant move \(square) -> \(targetSquare)")
                        }
                    }
                }
            }
        }
        
        return moves
    }

    private func generateKingMovesWithCastling(piece: Piece, at square: Square) -> [Move] {
        var moves: [Move] = []
        
        // Regular king moves
        let kingMoves = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        for (fileOffset, rankOffset) in kingMoves {
            if let newFile = File(rawValue: square.file.rawValue + fileOffset),
               let newRank = Rank(rawValue: square.rank.rawValue + rankOffset) {
                let targetSquare = Square(file: newFile, rank: newRank)
                let targetPiece = game.board.piece(at: targetSquare)
                
                if targetPiece == nil || targetPiece!.color != piece.color {
                    moves.append(Move(from: square, to: targetSquare, piece: piece, capturedPiece: targetPiece))
                }
            }
        }
        
        // Castling (simplified - assumes king and rooks haven't moved)
        let homeRank = piece.color == .white ? Rank.one : Rank.eight
        if square.file == .E && square.rank == homeRank {
            // King-side castling
            let kingsideRookSquare = Square(file: .H, rank: homeRank)
            let f1 = Square(file: .F, rank: homeRank)
            let g1 = Square(file: .G, rank: homeRank)
            
            if let rook = game.board.piece(at: kingsideRookSquare),
               rook.type == .rook && rook.color == piece.color,
               game.board.piece(at: f1) == nil,
               game.board.piece(at: g1) == nil {
                moves.append(Move(from: square, to: g1, piece: piece, flag: .kingSideCastling))
                print("🔍 Added king-side castling")
            }
            
            // Queen-side castling
            let queensideRookSquare = Square(file: .A, rank: homeRank)
            let d1 = Square(file: .D, rank: homeRank)
            let c1 = Square(file: .C, rank: homeRank)
            let b1 = Square(file: .B, rank: homeRank)
            
            if let rook = game.board.piece(at: queensideRookSquare),
               rook.type == .rook && rook.color == piece.color,
               game.board.piece(at: d1) == nil,
               game.board.piece(at: c1) == nil,
               game.board.piece(at: b1) == nil {
                moves.append(Move(from: square, to: c1, piece: piece, flag: .queenSideCastling))
                print("🔍 Added queen-side castling")
            }
        }
        
        return moves
    }

    // Basic sliding piece moves
    private func generateBishopMoves(piece: Piece, at square: Square) -> [Move] {
        return generateSlidingMoves(piece: piece, at: square, directions: [(-1, -1), (-1, 1), (1, -1), (1, 1)])
    }

    private func generateRookMoves(piece: Piece, at square: Square) -> [Move] {
        return generateSlidingMoves(piece: piece, at: square, directions: [(-1, 0), (1, 0), (0, -1), (0, 1)])
    }

    private func generateQueenMoves(piece: Piece, at square: Square) -> [Move] {
        return generateSlidingMoves(piece: piece, at: square, directions: [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)])
    }

    private func generateKnightMoves(piece: Piece, at square: Square) -> [Move] {
        var moves: [Move] = []
        let knightOffsets = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
        
        for (fileOffset, rankOffset) in knightOffsets {
            if let newFile = File(rawValue: square.file.rawValue + fileOffset),
               let newRank = Rank(rawValue: square.rank.rawValue + rankOffset) {
                let targetSquare = Square(file: newFile, rank: newRank)
                let targetPiece = game.board.piece(at: targetSquare)
                
                if targetPiece == nil || targetPiece!.color != piece.color {
                    moves.append(Move(from: square, to: targetSquare, piece: piece, capturedPiece: targetPiece))
                }
            }
        }
        return moves
    }

    private func generateSlidingMoves(piece: Piece, at square: Square, directions: [(Int, Int)]) -> [Move] {
        var moves: [Move] = []
        
        for (fileDirection, rankDirection) in directions {
            var currentFile = square.file.rawValue + fileDirection
            var currentRank = square.rank.rawValue + rankDirection
            
            while let file = File(rawValue: currentFile), let rank = Rank(rawValue: currentRank) {
                let targetSquare = Square(file: file, rank: rank)
                
                if let targetPiece = game.board.piece(at: targetSquare) {
                    if targetPiece.color != piece.color {
                        moves.append(Move(from: square, to: targetSquare, piece: piece, capturedPiece: targetPiece, flag: .capture))
                    }
                    break // Can't continue past any piece
                } else {
                    moves.append(Move(from: square, to: targetSquare, piece: piece))
                }
                
                currentFile += fileDirection
                currentRank += rankDirection
            }
        }
        
        return moves
    }

    private var totalMovesPlayed: Int {
        return (pgnGame?.moves.count ?? 0) + (currentVariation?.moves.count ?? 0)
    }
    
    private func isValidMove(_ move: Move) -> Bool {
        return validMoves.contains { $0.from == move.from && $0.to == move.to }
    }
    
    private func executeMove(_ move: Move) {
        // Convert move to SAN notation
        do {
            let sanMove = try convertMoveToSAN(move)
            
            if isInVariationMode || currentVariation != nil {
                // Add to current variation
                if currentVariation == nil {
                    currentVariation = GameVariation(
                        moves: [sanMove],
                        startingMoveIndex: currentMoveIndex
                    )
                } else {
                    currentVariation!.moves.append(sanMove)
                }
                isInVariationMode = true
            } else {
                // Start a new variation if we're not at the end of the main line
                if currentMoveIndex < (pgnGame?.moves.count ?? 0) {
                    currentVariation = GameVariation(
                        moves: [sanMove],
                        startingMoveIndex: currentMoveIndex
                    )
                    isInVariationMode = true
                } else {
                    // Add to main line if we're at the end
                    pgnGame?.moves.append(sanMove)
                }
            }
            
            // Apply the move to the board
            game.makeMove(move)
            boardHistory.append(game.board)
            currentMoveIndex = boardHistory.count - 1
            
            // Save the updated game to database
            saveGameToDatabase()
            
            print("Move executed: \(sanMove)")
            
        } catch {
            print("Error converting move to SAN: \(error)")
        }
    }
    
    private func convertMoveToSAN(_ move: Move) throws -> String {
        // This is a simplified SAN conversion - you might want to use a more robust implementation
        var san = ""
        
        // Piece prefix (except for pawns)
        if move.piece.type != .pawn {
            san += String(move.piece.type.character).uppercased()
        }
        
        // Source file for pawn captures
        if move.piece.type == .pawn && move.capturedPiece != nil {
            san += move.from.file.description
        }
        
        // Capture indicator
        if move.capturedPiece != nil {
            san += "x"
        }
        
        // Destination square
        san += move.to.description
        
        // Promotion
        if case .promotion(let pieceType) = move.flag {
            san += "=" + String(pieceType.character).uppercased()
        }
        
        return san
    }
    
    private func saveGameToDatabase() {
        guard var pgn = pgnGame else { return }
        
        // Add current variation to PGN if it exists
        if let variation = currentVariation {
            if !pgn.variations.contains(where: { $0.id == variation.id }) {
                pgn.variations.append(variation)
            }
        }
        
        // Update the game in the database
        ChessLocalDataManager.shared.saveGame(from: pgn, title: gameTitle)
        print("Game automatically saved to database")
    }
    
    func exitVariationMode() {
        isInVariationMode = false
        currentVariation = nil
        // Return to main line at the variation start point
        if let variation = currentVariation {
            navigateToMove(variation.startingMoveIndex)
        }
    }
    
    func loadVariation(_ variation: GameVariation) {
        currentVariation = variation
        isInVariationMode = true
        navigateToMove(variation.startingMoveIndex)
    }
}

// MARK: - Sidebar Pages Enum
enum SidebarPage: String, CaseIterable {
    case gameAnalysis = "Game Analysis"
    case search = "Search"
    case openingRepertoire = "Opening Repertoire"
    case endgames = "Endgames"
    case puzzles = "Tactics Puzzles"
    case database = "Game Database"
    case engine = "Engine Analysis"
    case settings = "Settings"
    
    var iconName: String {
        switch self {
        case .gameAnalysis: return "chart.line.uptrend.xyaxis"
        case .search: return "magnifyingglass"
        case .openingRepertoire: return "book.fill"
        case .endgames: return "crown.fill"
        case .puzzles: return "puzzlepiece.fill"
        case .database: return "folder.fill"
        case .engine: return "cpu"
        case .settings: return "gear"
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedPage: SidebarPage = .gameAnalysis
    @StateObject private var openGamesManager = OpenGamesManager.shared
    @StateObject private var dataManager = ChessLocalDataManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar - Full Height
            VStack(spacing: 0) {
                // Sidebar Header
                Text("Chess App")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                
                // Navigation List
                List(selection: $selectedPage) {
                    Section("Main") {
                        ForEach(SidebarPage.allCases, id: \.self) { page in
                            Label(page.rawValue, systemImage: page.iconName)
                                .tag(page)
                        }
                    }
                }
                .listStyle(SidebarListStyle())
            }
            .frame(width: 250)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right Content Area
            VStack(spacing: 0) {
                // Safari-style Tab Bar
                if !openGamesManager.openTabs.isEmpty {
                    SafariTabBar(
                        openTabs: openGamesManager.openTabs,
                        activeTabId: openGamesManager.activeTabId,
                        onSelectTab: { tab in
                            openGamesManager.setActiveTab(tab)
                        },
                        onCloseTab: { tab in
                            openGamesManager.closeTab(tab)
                        }
                    )
                }
                
                // Main Content
                Group {
                    switch selectedPage {
                    case .gameAnalysis:
                        if let activeTab = openGamesManager.activeTab {
                            GameAnalysisView()
                                .environmentObject(activeTab.viewModel)
                                .environmentObject(openGamesManager)
                        } else {
                            EmptyGameAnalysisView()
                        }
                    case .search:
                        SearchView()
                    case .openingRepertoire:
                        OpeningRepertoireView()
                    case .endgames:
                        EndgamesView()
                    case .puzzles:
                        PuzzlesView()
                    case .database:
                        EnhancedLocalDatabaseView()
                    case .engine:
                        EngineAnalysisView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoadGameInAnalysis"))) { notification in
            if let game = notification.object as? ChessGameEntity {
                openGamesManager.openGame(game)
                selectedPage = .gameAnalysis
            }
        }
    }
}

// MARK: - Safari-style Tab Bar
struct SafariTabBar: View {
    let openTabs: [GameTab]
    let activeTabId: UUID?
    let onSelectTab: (GameTab) -> Void
    let onCloseTab: (GameTab) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(openTabs, id: \.id) { tab in
                SafariTabView(
                    tab: tab,
                    isActive: activeTabId == tab.id,
                    onSelect: { onSelectTab(tab) },
                    onClose: { onCloseTab(tab) }
                )
            }
            
            // Fill remaining space with background
            Spacer()
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(height: 36)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Safari-style Individual Tab
struct SafariTabView: View {
    let tab: GameTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Tab content
            HStack(spacing: 6) {
                // Favicon-style icon
                Image(systemName: tab.game.resultIcon)
                    .foregroundColor(tab.game.resultColor)
                    .font(.system(size: 10))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(tab.game.displayTitle)
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("\(tab.game.whitePlayer ?? "?") vs \(tab.game.blackPlayer ?? "?")")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 200)
            .contentShape(Rectangle())
            .onTapGesture {
                print("Safari tab clicked: \(tab.game.displayTitle)")
                onSelect()
            }
            
            // Close button
            Button(action: {
                print("Safari tab close: \(tab.game.displayTitle)")
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color.clear))
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isActive ? 1.0 : 0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 180, maxWidth: 220)
        .background(
            SafariTabShape(isActive: isActive)
                .fill(isActive ? Color(NSColor.controlBackgroundColor) : Color.clear)
        )
        .overlay(
            SafariTabShape(isActive: isActive)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .zIndex(isActive ? 1 : 0)
    }
}

// MARK: - Safari Tab Shape
struct SafariTabShape: Shape {
    let isActive: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if isActive {
            // Active tab - rounded top corners
            path.move(to: CGPoint(x: 0, y: rect.maxY))
            path.addLine(to: CGPoint(x: 8, y: rect.minY + 8))
            path.addQuadCurve(
                to: CGPoint(x: 16, y: rect.minY),
                control: CGPoint(x: 8, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - 16, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 8, y: rect.minY + 8),
                control: CGPoint(x: rect.maxX - 8, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            // Inactive tab - simple rectangle
            path.addRect(rect)
        }
        
        return path
    }
}

// MARK: - Empty Game Analysis View
struct EmptyGameAnalysisView: View {
    @StateObject private var dataManager = ChessLocalDataManager.shared
    @StateObject private var openGamesManager = OpenGamesManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "chessboard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Game Open")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a game from the database to start analysis")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !dataManager.savedGames.isEmpty {
                VStack(spacing: 12) {
                    Text("Recent Games:")
                        .font(.headline)
                        .padding(.top)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(dataManager.savedGames.prefix(5), id: \.id) { game in
                            Button {
                                openGamesManager.openGame(game)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(game.displayTitle)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("\(game.whitePlayer ?? "Unknown") vs \(game.blackPlayer ?? "Unknown")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: game.resultIcon)
                                        .foregroundColor(game.resultColor)
                                }
                                .padding()
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 400)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Game Analysis View with Move Interaction
struct GameAnalysisView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @EnvironmentObject var openGamesManager: OpenGamesManager
    @State private var lastDragValue: DragGesture.Value?
    @FocusState private var isFocused: Bool
    
    
    // Check if this view's tab is the active one
    private var isActiveTab: Bool {
        if let activeTab = openGamesManager.activeTab {
            return activeTab.viewModel === viewModel
        }
        return false
    }
    
    // Computed property for move list font size based on board size
    private var moveListFontSize: CGFloat {
        return max(10, openGamesManager.globalBoardSize / 35) // Scale font with board, minimum 10pt
    }
    
    // Computed property for move list width based on board size
    private var moveListWidth: CGFloat {
        return max(200, openGamesManager.globalBoardSize * 0.6) // Scale width with board, minimum 200pt
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Game title and info
            VStack {
                Text(viewModel.gameTitle)
                    .font(.largeTitle)
                    .padding(.bottom, 5)
                
                if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                if let pgn = viewModel.pgnGame {
                    VStack {
                        Text("Event: \(pgn.tags["Event"] ?? "N/A")")
                        Text("\(pgn.tags["White"] ?? "N/A") vs \(pgn.tags["Black"] ?? "N/A")")
                    }
                    .font(.subheadline)
                    .padding(.bottom)
                }
            }
            .padding(.horizontal)
            
            // Main content area with board and moves
            if let pgn = viewModel.pgnGame {
                HStack(spacing: 20) {
                    // Chess board with interaction
                    ZStack(alignment: .bottomTrailing) {
                        InteractiveChessBoard(
                            board: viewModel.game.board,
                            highlightManager: viewModel.highlightManager,
                            boardSize: $openGamesManager.globalBoardSize,
                            gameViewModel: viewModel
                        )
                        
                        // Resize handle
                        Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.8))
                            .background(Color.white.clipShape(Circle()))
                            .padding(3)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let dragAmount = (value.translation.width - (lastDragValue?.translation.width ?? 0)) + (value.translation.height - (lastDragValue?.translation.height ?? 0))
                                        openGamesManager.globalBoardSize += dragAmount / 2
                                        
                                        if openGamesManager.globalBoardSize < 200 { openGamesManager.globalBoardSize = 200 }
                                        if openGamesManager.globalBoardSize > 600 { openGamesManager.globalBoardSize = 600 }
                                        
                                        lastDragValue = value
                                    }
                                    .onEnded { _ in
                                        lastDragValue = nil
                                    }
                            )
                    }
                    
                    // Enhanced moves list panel with variation support
                    VStack(alignment: .leading, spacing: 8) {
                        // Header with mode indicator
                        HStack {
                            Text("Moves")
                                .font(.headline)
                            
                            if viewModel.isInVariationMode {
                                Spacer()
                                Text("VARIATION")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Button("Exit Variation") {
                                    viewModel.exitVariationMode()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    // Display main line moves
                                    ForEach(0..<((pgn.moves.count + 1) / 2), id: \.self) { pairIndex in
                                        HStack(spacing: 8) {
                                            // Move number
                                            Text("\(pairIndex + 1).")
                                                .font(.system(size: moveListFontSize, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .frame(width: 30, alignment: .trailing)
                                            
                                            // White move
                                            if pairIndex * 2 < pgn.moves.count {
                                                let whiteMove = pgn.moves[pairIndex * 2]
                                                let whiteMoveIndex = pairIndex * 2 + 1
                                                
                                                Button(whiteMove) {
                                                    viewModel.navigateToMove(whiteMoveIndex)
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(viewModel.currentMoveIndex == whiteMoveIndex ? Color.blue.opacity(0.3) : Color.clear)
                                                .cornerRadius(4)
                                                .font(.system(size: moveListFontSize, design: .monospaced))
                                                .id("move-\(whiteMoveIndex)")
                                            }
                                            
                                            // Black move
                                            if pairIndex * 2 + 1 < pgn.moves.count {
                                                let blackMove = pgn.moves[pairIndex * 2 + 1]
                                                let blackMoveIndex = pairIndex * 2 + 2
                                                
                                                Button(blackMove) {
                                                    viewModel.navigateToMove(blackMoveIndex)
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(viewModel.currentMoveIndex == blackMoveIndex ? Color.blue.opacity(0.3) : Color.clear)
                                                .cornerRadius(4)
                                                .font(.system(size: moveListFontSize, design: .monospaced))
                                                .id("move-\(blackMoveIndex)")
                                            }
                                            
                                            Spacer()
                                        }
                                        
                                        // Show variations after this move
                                        let variationsHere = pgn.variations.filter { $0.startingMoveIndex == pairIndex * 2 + 2 }
                                        ForEach(variationsHere, id: \.id) { variation in
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack {
                                                    Text("Variation:")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                    
                                                    Button("Load") {
                                                        viewModel.loadVariation(variation)
                                                    }
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                                }
                                                
                                                Text(variation.moves.joined(separator: " "))
                                                    .font(.system(size: moveListFontSize - 1, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                    .padding(.leading, 16)
                                                    .background(Color.orange.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                            .padding(.leading, 40)
                                        }
                                    }
                                    
                                    // Show current variation if in variation mode
                                    if let currentVar = viewModel.currentVariation {
                                        Divider()
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Current Variation:")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            
                                            ForEach(0..<currentVar.moves.count, id: \.self) { index in
                                                let move = currentVar.moves[index]
                                                let moveIndex = currentVar.startingMoveIndex + index + 1
                                                
                                                Button(move) {
                                                    viewModel.navigateToMove(moveIndex)
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(viewModel.currentMoveIndex == moveIndex ? Color.orange.opacity(0.3) : Color.orange.opacity(0.1))
                                                .cornerRadius(4)
                                                .font(.system(size: moveListFontSize, design: .monospaced))
                                            }
                                        }
                                        .padding(.leading, 16)
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            .onChange(of: viewModel.currentMoveIndex) { oldValue, newValue in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("move-\(newValue)", anchor: .center)
                                }
                            }
                        }
                        .frame(maxHeight: openGamesManager.globalBoardSize)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .frame(width: moveListWidth)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Control buttons
                HStack {
                    Button("◀◀") {
                        viewModel.navigateToMove(0)
                    }
                    .disabled(viewModel.currentMoveIndex == 0)
                    
                    Button("◀ Previous") {
                        viewModel.previousPosition()
                    }
                    .disabled(viewModel.currentMoveIndex == 0)
                    
                    Button("Save Game") {
                        if let pgn = viewModel.pgnGame {
                            ChessLocalDataManager.shared.saveGame(from: pgn)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Next ▶") {
                        viewModel.nextPosition()
                    }
                    .disabled(viewModel.currentMoveIndex == viewModel.totalPositions - 1)
                    
                    Button("▶▶") {
                        viewModel.navigateToMove(viewModel.totalPositions - 1)
                    }
                    .disabled(viewModel.currentMoveIndex == viewModel.totalPositions - 1)
                }
                .padding()
                
            } else {
                Text("No game loaded.")
                    .padding()
                Spacer()
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress { keyPress in
            // Only handle key presses if this is the active tab
            guard isActiveTab else { return .ignored }
            
            print("Key pressed in tab: \(viewModel.gameTitle), key: \(keyPress.key)")
            switch keyPress.key {
            case .leftArrow:
                if viewModel.currentMoveIndex > 0 {
                    viewModel.previousPosition()
                    return .handled
                }
            case .rightArrow:
                if viewModel.currentMoveIndex < viewModel.totalPositions - 1 {
                    viewModel.nextPosition()
                    return .handled
                }
            case .upArrow:
                // Go to beginning of game
                viewModel.navigateToMove(0)
                return .handled
            case .downArrow:
                // Go to end of game
                viewModel.navigateToMove(viewModel.totalPositions - 1)
                return .handled
            default:
                break
            }
            return .ignored
        }
        .onAppear {
            // Only auto-focus if this is the active tab
            if isActiveTab {
                isFocused = true
            }
        }
        .onTapGesture {
            // Only re-focus if this is the active tab
            if isActiveTab {
                isFocused = true
            }
        }
        .onChange(of: openGamesManager.activeTabId) { oldValue, newValue in
            // Update focus when active tab changes
            isFocused = isActiveTab
        }
    }
}

// MARK: - Enhanced Database View
struct EnhancedLocalDatabaseView: View {
    @StateObject private var dataManager = ChessLocalDataManager.shared
    @StateObject private var openGamesManager = OpenGamesManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: GameFilter = .all
    @State private var showingImportSheet = false
    @State private var showingGameDetail: ChessGameEntity?
    @State private var showingAddGameSheet = false
    @State private var showingExportSheet = false
    
    enum GameFilter: String, CaseIterable {
        case all = "All Games"
        case wins = "Wins (1-0)"
        case losses = "Losses (0-1)"
        case draws = "Draws (1/2-1/2)"
        case ongoing = "Ongoing (*)"
        
        var predicate: NSPredicate? {
            switch self {
            case .all: return nil
            case .wins: return NSPredicate(format: "result == %@", "1-0")
            case .losses: return NSPredicate(format: "result == %@", "0-1")
            case .draws: return NSPredicate(format: "result == %@", "1/2-1/2")
            case .ongoing: return NSPredicate(format: "result == %@", "*")
            }
        }
    }
    
    var filteredGames: [ChessGameEntity] {
        var games = dataManager.savedGames
        
        if !searchText.isEmpty {
            games = dataManager.searchGames(query: searchText)
        }
        
        if let predicate = selectedFilter.predicate {
            games = games.filter { game in
                predicate.evaluate(with: game)
            }
        }
        
        return games
    }
    
    var body: some View {
        VStack {
            // Stats header
            HStack(spacing: 20) {
                VStack {
                    Text("\(dataManager.savedGames.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total Games")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(dataManager.gamesByResult("1-0").count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Wins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(dataManager.gamesByResult("0-1").count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Losses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(dataManager.gamesByResult("1/2-1/2").count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Draws")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Search and filters
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search games, players, events...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
                
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(GameFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            
            // Games list
            List {
                ForEach(filteredGames, id: \.id) { game in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.displayTitle)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text("\(game.whitePlayer ?? "Unknown") vs \(game.blackPlayer ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                if let event = game.event {
                                    Text(event)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                Text(game.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack {
                            Image(systemName: game.resultIcon)
                                .foregroundColor(game.resultColor)
                                .font(.title2)
                            
                            Text(game.result ?? "*")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        openGamesManager.openGame(game)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("LoadGameInAnalysis"),
                            object: game
                        )
                    }
                }
            }
            
            Spacer()
        }
        .navigationTitle("Game Database")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                
                Button {
                    showingImportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                
                Button {
                    showingAddGameSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportPGNView()
        }
        .sheet(isPresented: $showingAddGameSheet) {
            AddGameView()
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDatabaseView()
        }
        .sheet(item: $showingGameDetail) { game in
            GameDetailView(game: game)
        }
    }
}

// MARK: - Placeholder Views
struct SearchView: View {
    var body: some View {
        VStack {
            Text("Search")
                .font(.largeTitle)
                .padding()
            Text("Search through your chess games and positions")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct OpeningRepertoireView: View {
    var body: some View {
        VStack {
            Text("Opening Repertoire")
                .font(.largeTitle)
                .padding()
            Text("Build and study your opening repertoire")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct EndgamesView: View {
    var body: some View {
        VStack {
            Text("Endgames")
                .font(.largeTitle)
                .padding()
            Text("Master essential endgame patterns")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct PuzzlesView: View {
    var body: some View {
        VStack {
            Text("Tactics Puzzles")
                .font(.largeTitle)
                .padding()
            Text("Sharpen your tactical vision")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct EngineAnalysisView: View {
    var body: some View {
        VStack {
            Text("Engine Analysis")
                .font(.largeTitle)
                .padding()
            Text("Computer analysis of positions")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            Text("Customize your chess app")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
