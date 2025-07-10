// ContentView.swift - Enhanced with per-tab state management
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

// MARK: - Enhanced Game View Model
class GameViewModel: ObservableObject {
    @Published var game: Game = Game()
    @Published var currentMoveIndex: Int = 0
    @Published var pgnGame: PGN? = nil
    @Published var errorMessage: String? = nil
    @Published var gameTitle: String = "No Game"
    
    var boardHistory: [Board] = []
    
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
            
            var tempGame = self.game
            for sanMoveString in parsedPgn.moves {
                do {
                    let move = try MoveParser.parse(san: sanMoveString, currentBoard: tempGame.board, activeColor: tempGame.activeColor)
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
        }
    }
    
    func previousPosition() {
        if currentMoveIndex > 0 {
            currentMoveIndex -= 1
            game.board = boardHistory[currentMoveIndex]
        }
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

// MARK: - Game Analysis View
struct GameAnalysisView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @EnvironmentObject var openGamesManager: OpenGamesManager
    @State private var lastDragValue: DragGesture.Value?
    @FocusState private var isFocused: Bool
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
    
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
                    // Chess board
                    ZStack(alignment: .bottomTrailing) {
                        LazyVGrid(columns: columns, spacing: 0) {
                            ForEach((0..<8).reversed(), id: \.self) { rankIndex in
                                ForEach(0..<8, id: \.self) { fileIndex in
                                    let square = Square(file: File(rawValue: fileIndex)!, rank: Rank(rawValue: rankIndex)!)
                                    let piece = viewModel.game.board.piece(at: square)
                                    
                                    SquareView(square: square, piece: piece)
                                }
                            }
                        }
                        .border(Color.black, width: 1)
                        .frame(width: openGamesManager.globalBoardSize, height: openGamesManager.globalBoardSize, alignment: .center)
                        
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
                    
                    // Moves list panel
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    // Move pairs (removed "Start" button)
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
                                                    viewModel.currentMoveIndex = whiteMoveIndex
                                                    if whiteMoveIndex < viewModel.boardHistory.count {
                                                        viewModel.game.board = viewModel.boardHistory[whiteMoveIndex]
                                                    }
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
                                                    viewModel.currentMoveIndex = blackMoveIndex
                                                    if blackMoveIndex < viewModel.boardHistory.count {
                                                        viewModel.game.board = viewModel.boardHistory[blackMoveIndex]
                                                    }
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
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            .onChange(of: viewModel.currentMoveIndex) { oldValue, newValue in
                                // Auto-scroll to current move
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
                        viewModel.currentMoveIndex = 0
                        if let firstBoard = viewModel.boardHistory.first {
                            viewModel.game.board = firstBoard
                        }
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
                        viewModel.currentMoveIndex = viewModel.totalPositions - 1
                        if let lastBoard = viewModel.boardHistory.last {
                            viewModel.game.board = lastBoard
                        }
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
        .focusEffectDisabled() // This removes the focus border/ring
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
                viewModel.currentMoveIndex = 0
                if let firstBoard = viewModel.boardHistory.first {
                    viewModel.game.board = firstBoard
                }
                return .handled
            case .downArrow:
                // Go to end of game
                viewModel.currentMoveIndex = viewModel.totalPositions - 1
                if let lastBoard = viewModel.boardHistory.last {
                    viewModel.game.board = lastBoard
                }
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
