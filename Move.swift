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
