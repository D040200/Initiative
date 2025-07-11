// MoveHighlighting.swift - Add this as a new file to your project

import SwiftUI

// MARK: - Move Highlighting Manager
class MoveHighlightManager: ObservableObject {
    @Published var highlightedSquares: Set<Square> = []
    @Published var lastMoveSquares: Set<Square> = []
    
    func highlightMove(_ move: Move) {
        // Clear previous highlights
        highlightedSquares.removeAll()
        lastMoveSquares.removeAll()
        
        // Add the "to" square for primary highlighting
        highlightedSquares.insert(move.to)
        
        // Add both "from" and "to" squares for last move indication
        lastMoveSquares.insert(move.from)
        lastMoveSquares.insert(move.to)
    }
    
    func clearHighlights() {
        highlightedSquares.removeAll()
        lastMoveSquares.removeAll()
    }
    
    func isHighlighted(_ square: Square) -> Bool {
        return highlightedSquares.contains(square)
    }
    
    func isLastMoveSquare(_ square: Square) -> Bool {
        return lastMoveSquares.contains(square)
    }
}

// MARK: - Enhanced Square View with Highlighting
struct EnhancedSquareView: View {
    let square: Square
    let piece: Piece?
    let isHighlighted: Bool
    let isLastMoveSquare: Bool
    
    private var baseSquareColor: Color {
        let isLight = (square.file.rawValue + square.rank.rawValue) % 2 == 0
        return isLight ? Color(red: 0.9, green: 0.85, blue: 0.76) : Color(red: 0.7, green: 0.5, blue: 0.3)
    }
    
    private var finalSquareColor: Color {
        if isHighlighted {
            // Primary highlight for the destination square - bright yellow
            return Color.yellow.opacity(0.8)
        } else if isLastMoveSquare {
            // For last move squares, use a predefined blended color
            let isLight = (square.file.rawValue + square.rank.rawValue) % 2 == 0
            return isLight ? Color(red: 0.7, green: 0.7, blue: 0.9) : Color(red: 0.5, green: 0.4, blue: 0.6)
        } else {
            return baseSquareColor
        }
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(finalSquareColor)
            
            // Add border for highlighted squares
            if isHighlighted {
                Rectangle()
                    .stroke(Color.orange, lineWidth: 3)
            }
            
            if let piece = piece {
                Image(piece.imageName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(isHighlighted ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHighlighted)
            }
            
            // Add glow effect for highlighted square
            if isHighlighted {
                Rectangle()
                    .fill(Color.yellow.opacity(0.2))
                    .blur(radius: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .animation(.easeInOut(duration: 0.2), value: isLastMoveSquare)
    }
}

// MARK: - Updated Game View Model with Move Tracking
extension GameViewModel {
    private var currentMove: Move? {
        guard currentMoveIndex > 0,
              currentMoveIndex <= boardHistory.count,
              let pgn = pgnGame,
              currentMoveIndex - 1 < pgn.moves.count else {
            return nil
        }
        
        // Get the move that led to the current position
        let moveString = pgn.moves[currentMoveIndex - 1]
        let boardBeforeMove = currentMoveIndex > 1 ? boardHistory[currentMoveIndex - 1] : boardHistory[0]
        
        // Determine which color made this move
        let moveColor: PieceColor = (currentMoveIndex % 2 == 1) ? .white : .black
        
        do {
            return try MoveParser.parse(san: moveString, currentBoard: boardBeforeMove, activeColor: moveColor)
        } catch {
            print("Error parsing move for highlighting: \(error)")
            return nil
        }
    }
    
    func getCurrentMove() -> Move? {
        return currentMove
    }
}
