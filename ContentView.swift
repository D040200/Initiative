// ContentView.swift
import SwiftUI

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

// MARK: - GameViewModel (unchanged)
class GameViewModel: ObservableObject {
    @Published var game: Game = Game()
    @Published var currentMoveIndex: Int = 0
    @Published var pgnGame: PGN? = nil
    @Published var errorMessage: String? = nil
    
    private var boardHistory: [Board] = []
    
    init() {
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
        
        do {
            let parsedPgn = try PGNParser.parse(pgnString: samplePGNString)
            self.pgnGame = parsedPgn
            
            if let initialBoardFromFEN = Board(fen: parsedPgn.initialFen) {
                self.game = Game(board: initialBoardFromFEN, activeColor: .white)
            } else {
                self.game = Game()
            }
            
            self.boardHistory.append(self.game.board)
            
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
            self.game = Game()
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

// MARK: - Main Content View
struct GameAnalysisView: View {
    @StateObject private var viewModel = GameViewModel()
    @State private var boardSize: CGFloat = 350
    @State private var lastDragValue: DragGesture.Value?
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
    
    var body: some View {
        VStack {
            Text("Chess Game from PGN")
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

                // Board with resizing handle
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
                    
                    // Resizing Handle
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
                
                // Navigation controls
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
                
            } else {
                Text("No PGN game loaded.")
            }
        }
        .padding()
    }
}

// MARK: - Placeholder Views for Sidebar Pages
struct SearchView: View {
    var body: some View {
        VStack {
            Text("Search")
                .font(.largeTitle)
                .padding()
            
            Text("Search through your chess games and positions")
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(spacing: 20) {
                TextField("Search games...", text: .constant(""))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button("By Player") { }
                    Button("By Opening") { }
                    Button("By Position") { }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
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
            
            VStack(spacing: 15) {
                Text("Popular Openings:")
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                    ForEach(["Sicilian Defense", "French Defense", "Caro-Kann", "Queen's Gambit", "Ruy Lopez", "English Opening"], id: \.self) { opening in
                        Button(opening) { }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            
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
            
            VStack(spacing: 15) {
                Text("Endgame Categories:")
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                    ForEach(["King & Pawn", "Rook Endgames", "Queen Endgames", "Bishop Endgames", "Knight Endgames", "Opposite Bishops"], id: \.self) { category in
                        Button(category) { }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            
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
            
            VStack(spacing: 20) {
                Text("Daily Puzzle")
                    .font(.title2)
                
                // Placeholder for puzzle board
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .overlay(Text("Puzzle Board"))
                
                HStack {
                    Button("Show Solution") { }
                    Button("Next Puzzle") { }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

struct DatabaseView: View {
    var body: some View {
        VStack {
            Text("Game Database")
                .font(.largeTitle)
                .padding()
            
            Text("Browse and analyze master games")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Database features coming soon...")
                .foregroundColor(.secondary)
                .italic()
            
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
            
            Text("Engine integration coming soon...")
                .foregroundColor(.secondary)
                .italic()
            
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
            
            Form {
                Section("Board") {
                    Toggle("Show coordinates", isOn: .constant(true))
                    Toggle("Highlight last move", isOn: .constant(true))
                }
                
                Section("Engine") {
                    Stepper("Analysis depth: 15", value: .constant(15), in: 1...30)
                    Toggle("Auto-analysis", isOn: .constant(false))
                }
            }
            .frame(maxHeight: 300)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Main ContentView with Sidebar
struct ContentView: View {
    @State private var selectedPage: SidebarPage = .gameAnalysis
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarPage.allCases, id: \.self, selection: $selectedPage) { page in
                Label(page.rawValue, systemImage: page.iconName)
                    .tag(page)
            }
            .navigationTitle("Chess App")
        } detail: {
            // Main content area
            Group {
                switch selectedPage {
                case .gameAnalysis:
                    GameAnalysisView()
                case .search:
                    SearchView()
                case .openingRepertoire:
                    OpeningRepertoireView()
                case .endgames:
                    EndgamesView()
                case .puzzles:
                    PuzzlesView()
                case .database:
                    LocalDatabaseView()
                case .engine:
                    EngineAnalysisView()
                case .settings:
                    SettingsView()
                }
            }
            .navigationTitle(selectedPage.rawValue)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
