// ContentView.swift
import SwiftUI

// --- GameViewModel is unchanged ---
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

// MARK: - SwiftUI View (UPDATED FOR RESIZING)

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    
    // --- START of RESIZING CODE ---
    @State private var boardSize: CGFloat = 350
    @State private var lastDragValue: DragGesture.Value?
    // --- END of RESIZING CODE ---
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
    
    var body: some View {
        VStack {
            // ... (Header Text is the same) ...
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

                Spacer() // Pushes the board to the center

                // --- START of RESIZING WRAPPER ---
                ZStack(alignment: .bottomTrailing) {
                    // Board
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
                    .frame(width: boardSize, height: boardSize, alignment: .center) // Frame controls the size
                    
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
                                    boardSize += dragAmount / 2 // Divide by 2 to reduce sensitivity
                                    
                                    // Clamp the size to a reasonable min/max
                                    if boardSize < 150 { boardSize = 150 }
                                    if boardSize > 500 { boardSize = 500 }
                                    
                                    lastDragValue = value
                                }
                                .onEnded { _ in
                                    lastDragValue = nil
                                }
                        )
                }
                // --- END of RESIZING WRAPPER ---

                Spacer() // Pushes the controls to the bottom
                
                // ... (Buttons and other info are the same) ...
                HStack {
                    Button("Previous Position") {
                        viewModel.previousPosition()
                    }
                    .disabled(viewModel.currentMoveIndex == 0)
                    
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
                Text("No PGN game loaded.")
            }
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
