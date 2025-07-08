// Game.swift
import Foundation

struct Game {
    var board: Board
    var activeColor: PieceColor // Whose turn it is to move
    // For a complete game, you would also need:
    // var castlingRights: CastlingRights // Needs a new struct/enum
    // var enPassantTarget: Square?
    // var halfmoveClock: Int
    // var fullmoveNumber: Int
    
    init(board: Board, activeColor: PieceColor = .white) {
        self.board = board
        self.activeColor = activeColor
    }
    
    // Initializes a new game with a standard starting board and white to move
    init() {
        self.board = .startingBoard()
        self.activeColor = .white
    }
    
    // This is the function that applies a parsed move to the game state.
    // It will be expanded significantly.
    // For now, it just calls the board's applyMove and flips the active color.
    mutating func makeMove(_ move: Move) {
        self.board.applyMove(move)
        // Flip the active color after the move
        self.activeColor = self.activeColor.opposite
        // TODO: Update castling rights, en passant target, clocks, etc.
    }
}
