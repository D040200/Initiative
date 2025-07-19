// Move.swift
import Foundation

// Enum to represent special move flags
enum MoveFlag: Equatable { // This was the fix for Move's Equatable conformance
    case normal
    case capture
    case doublePawnPush
    case kingSideCastling
    case queenSideCastling
    case promotion(PieceType)
    case enPassantCapture
}

struct Move: Equatable {
    let from: Square
    let to: Square
    let piece: Piece
    let capturedPiece: Piece?
    let flag: MoveFlag
    
    init(from: Square, to: Square, piece: Piece, capturedPiece: Piece? = nil, flag: MoveFlag = .normal) {
        self.from = from
        self.to = to
        self.piece = piece
        self.capturedPiece = capturedPiece
        self.flag = flag
    }
    
    var description: String {
        return "\(piece.fenCharacter) from \(from) to \(to)" +
        (capturedPiece != nil ? " (captures \(capturedPiece!.fenCharacter))" : "") +
        (flag != .normal ? " (\(String(describing: flag)))" : "")
    }
}

struct GameVariation: Codable, Identifiable {
    let id = UUID()
    var moves: [String] // SAN notation
    var startingMoveIndex: Int // Where this variation branches from
    var comment: String?
    var evaluation: Float?
    
    init(moves: [String], startingMoveIndex: Int, comment: String? = nil) {
        self.moves = moves
        self.startingMoveIndex = startingMoveIndex
        self.comment = comment
    }
}
