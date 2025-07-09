// ContentView.swift - Enhanced with sidebar game information
import SwiftUI

// MARK: - Open Games Manager
class OpenGamesManager: ObservableObject {
    @Published var openGames: [ChessGameEntity] = []
    @Published var activeGameId: UUID? = nil
    
    static let shared = OpenGamesManager()
    
    private init() {}
    
    func openGame(_ game: ChessGameEntity) {
        // Don't add if already open
        if !openGames.contains(where: { $0.id == game.id }) {
            openGames.append(game)
        }
        activeGameId = game.id
    }
    
    func closeGame(_ game: ChessGameEntity) {
        openGames.removeAll { $0.id == game.id }
        
        // If we closed the active game, select another one or set to nil
        if activeGameId == game.id {
            activeGameId = openGames.first?.id
        }
    }
    
    func setActiveGame(_ game: ChessGameEntity) {
        activeGameId = game.id
    }
    
    var activeGame: ChessGameEntity? {
        return openGames.first { $0.id == activeGameId }
    }
    
    func closeAllGames() {
        openGames.removeAll()
        activeGameId = nil
    }
}

// MARK: - Enhanced Game View Model
class GameViewModel: ObservableObject {
    @Published var game: Game = Game()
    @Published var currentMoveIndex: Int = 0
    @Published var pgnGame: PGN? = nil
    @Published var errorMessage: String? = nil
    @Published var gameTitle: String = "Opera Game"
    
    private var boardHistory: [Board] = []
    
    init() {
        loadDefaultGame()
    }
    
    private func loadDefaultGame() {
        let samplePGNString = """
        [Event "Opera Game"]
        [Site "Paris"]
        [Date "1858.00.00"]
        [Round "?"]
        [White "Paul Morphy"]
        [Black "Duke Karl of Brunswick and Count Isouard"]
        [Result "1-0"]
        
        1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7
        8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7
        14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8# 1-0
        """
        
        loadGame(pgnString: samplePGNString, title: "Opera Game")
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
    @StateObject private var gameViewModel = GameViewModel()
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
                if !openGamesManager.openGames.isEmpty {
                    SafariTabBar(
                        openGames: openGamesManager.openGames,
                        activeGameId: openGamesManager.activeGameId,
                        onSelectGame: { game in
                            openGamesManager.setActiveGame(game)
                            gameViewModel.loadGame(from: game)
                        },
                        onCloseGame: { game in
                            openGamesManager.closeGame(game)
                            if let newActiveGame = openGamesManager.activeGame {
                                gameViewModel.loadGame(from: newActiveGame)
                            }
                        }
                    )
                }
                
                // Main Content
                Group {
                    switch selectedPage {
                    case .gameAnalysis:
                        if openGamesManager.activeGame != nil {
                            GameAnalysisView()
                                .environmentObject(gameViewModel)
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
                gameViewModel.loadGame(from: game)
                selectedPage = .gameAnalysis
            }
        }
        .onChange(of: openGamesManager.activeGameId) { oldValue, newValue in
            if let activeGame = openGamesManager.activeGame {
                gameViewModel.loadGame(from: activeGame)
            }
        }
    }
}

// MARK: - Safari-style Tab Bar
struct SafariTabBar: View {
    let openGames: [ChessGameEntity]
    let activeGameId: UUID?
    let onSelectGame: (ChessGameEntity) -> Void
    let onCloseGame: (ChessGameEntity) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(openGames, id: \.id) { game in
                SafariTabView(
                    game: game,
                    isActive: activeGameId == game.id,
                    onSelect: { onSelectGame(game) },
                    onClose: { onCloseGame(game) }
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
    let game: ChessGameEntity
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Tab content
            HStack(spacing: 6) {
                // Favicon-style icon
                Image(systemName: game.resultIcon)
                    .foregroundColor(game.resultColor)
                    .font(.system(size: 10))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(game.displayTitle)
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("\(game.whitePlayer ?? "?") vs \(game.blackPlayer ?? "?")")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 200)
            .contentShape(Rectangle())
            .onTapGesture {
                print("Safari tab clicked: \(game.displayTitle)")
                onSelect()
            }
            
            // Close button
            Button(action: {
                print("Safari tab close: \(game.displayTitle)")
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
    @State private var boardSize: CGFloat = 350
    @State private var lastDragValue: DragGesture.Value?
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
    
    var body: some View {
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
                    Text("Moves: \(pgn.moves.joined(separator: " "))")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: false)
                }
                .font(.subheadline)
                .padding(.bottom)

                Spacer()

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
                    .frame(width: boardSize, height: boardSize, alignment: .center)
                    
                    Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray.opacity(0.8))
                        .background(Color.white.clipShape(Circle()))
                        .padding(3)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let dragAmount = (value.translation.width - (lastDragValue?.translation.width ?? 0)) + (value.translation.height - (lastDragValue?.translation.height ?? 0))
                                    boardSize += dragAmount / 2
                                    
                                    if boardSize < 150 { boardSize = 150 }
                                    if boardSize > 500 { boardSize = 500 }
                                    
                                    lastDragValue = value
                                }
                                .onEnded { _ in
                                    lastDragValue = nil
                                }
                        )
                }

                Spacer()
                
                HStack {
                    Button("Previous Position") {
                        viewModel.previousPosition()
                    }
                    .disabled(viewModel.currentMoveIndex == 0)
                    
                    Button("Save Game") {
                        if let pgn = viewModel.pgnGame {
                            ChessLocalDataManager.shared.saveGame(from: pgn)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Move \(viewModel.currentMoveIndex) of \(viewModel.totalPositions - 1)")
                        .font(.headline)
                    
                    Button("Next Position") {
                        viewModel.nextPosition()
                    }
                    .disabled(viewModel.currentMoveIndex == viewModel.totalPositions - 1)
                }
                .padding()
                
                Text("Result: \(pgn.result ?? "N/A")")
                    .font(.headline)
                    .padding(.bottom)
                
            } else {
                Text("No game loaded.")
            }
        }
        .padding()
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
