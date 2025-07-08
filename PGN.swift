// PGN.swift
import Foundation

// MARK: - PGN Struct
struct PGN {
    var tags: [String: String]
    var initialFen: String
    var moves: [String]
    var result: String?
    
    init(tags: [String: String], initialFen: String, moves: [String], result: String?) {
        self.tags = tags
        self.initialFen = initialFen
        self.moves = moves
        self.result = result
    }
}

// MARK: - PGNParser
enum PGNParserError: Error, LocalizedError {
    case invalidFormat
    case missingFENTag
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "The PGN string has an invalid format."
        case .missingFENTag: return "FEN tag is missing in the PGN header, cannot determine initial position."
        }
    }
}

class PGNParser {
    static func parse(pgnString: String) throws -> PGN {
        var tags: [String: String] = [:]
        var initialFen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        var moves: [String] = []
        var result: String?
        
        let lines = pgnString.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        
        var parsingTags = true
        var movesString = ""
        
        for line in lines {
            if parsingTags {
                if line.hasPrefix("[") && line.hasSuffix("]") {
                    let content = line.dropFirst().dropLast()
                    let parts = content.split(separator: " \"", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        let key = parts[0]
                        let value = String(parts[1].dropLast())
                        tags[key] = value
                    }
                } else if !line.isEmpty {
                    parsingTags = false
                    movesString += line + " "
                }
            } else {
                movesString += line + " "
            }
        }
        
        if let fenTag = tags["FEN"] {
            initialFen = fenTag
        }
        
        let cleanedMovesString = movesString
            .replacingOccurrences(of: "\\{[^\\}]*\\}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\([^\\)]*\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "[0-9]+\\.", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\+", with: "", options: .regularExpression) // Remove check '+'
            .replacingOccurrences(of: "#", with: "", options: .regularExpression) // Remove checkmate '#'
        // We need to keep promotion type for MoveParser, but remove the '='
            .replacingOccurrences(of: "=", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let components = cleanedMovesString.split(separator: " ").map(String.init)
        
        if let lastComponent = components.last,
           ["1-0", "0-1", "1/2-1/2", "*"].contains(lastComponent) {
            result = lastComponent
            moves = components.dropLast()
        } else {
            moves = components
        }
        
        return PGN(tags: tags, initialFen: initialFen, moves: moves, result: result)
    }
}

enum MoveParsingError: Error, LocalizedError {
    case invalidMoveFormat(String)
    case pieceNotFound(String, Square)
    case invalidDestination(String, String)
    case ambiguousMove(String)
    case generalError(String)
    case noPieceFoundAtFromSquare(Square, PieceType, PieceColor)
    
    var errorDescription: String? {
        switch self {
        case .invalidMoveFormat(let move): return "Invalid move format: \(move)"
        case .pieceNotFound(let pieceChar, let square): return "Piece '\(pieceChar)' not found for move to \(square)."
        case .invalidDestination(let move, let toSquareStr): return "Invalid destination '\(toSquareStr)' for move '\(move)'."
        case .ambiguousMove(let move): return "Ambiguous move: \(move). Requires disambiguation."
        case .generalError(let message): return "Move parsing error: \(message)"
        case .noPieceFoundAtFromSquare(let square, let type, let color): return "No \(color) \(type) found at inferred starting square \(square)."
        }
    }
}

class MoveParser {
    
    // This helper function seems unused in parse() currently, keeping for completeness if needed later
    private static func getSquares(for pieceType: PieceType, color: PieceColor, in board: Board) -> [Square] {
        var squares: [Square] = []
        let bitboard: Bitboard
        switch (pieceType, color) {
        case (.pawn, .white): bitboard = board.whitePawns
        case (.knight, .white): bitboard = board.whiteKnights
        case (.bishop, .white): bitboard = board.whiteBishops
        case (.rook, .white): bitboard = board.whiteRooks
        case (.queen, .white): bitboard = board.whiteQueens
        case (.king, .white): bitboard = board.whiteKing
        case (.pawn, .black): bitboard = board.blackPawns
        case (.knight, .black): bitboard = board.blackKnights
        case (.bishop, .black): bitboard = board.blackBishops
        case (.rook, .black): bitboard = board.blackRooks
        case (.queen, .black): bitboard = board.blackQueens
        case (.king, .black): bitboard = board.blackKing
        }
        
        for square in Square.all {
            if bitboard.contains(square) {
                squares.append(square)
            }
        }
        return squares
    }
    
    static func parse(san: String, currentBoard: Board, activeColor: PieceColor) throws -> Move {
        let originalSan = san
        var cleanSan = san
            .replacingOccurrences(of: "x", with: "") // Remove capture indicator for parsing square
            .replacingOccurrences(of: "+", with: "") // Remove check indicator
            .replacingOccurrences(of: "#", with: "") // Remove checkmate indicator
        
        var promotionType: PieceType? = nil
        // Handle promotion (e.g., "e8=Q")
        if let promotionChar = cleanSan.last, let promotedPiece = Piece(fenCharacter: promotionChar), promotedPiece.type != .pawn {
            promotionType = promotedPiece.type
            cleanSan.removeLast() // Remove 'Q'
            if cleanSan.last == "=" { // Remove '=' if present
                cleanSan.removeLast()
            }
        }
        
        // --- Castling ---
        if cleanSan == "O-O" || cleanSan == "0-0" {
            let kingRank = activeColor == .white ? Rank.one : Rank.eight
            let kingSquare = Square(file: .E, rank: kingRank)
            let targetSquare = Square(file: .G, rank: kingRank)
            return Move(from: kingSquare, to: targetSquare, piece: Piece(type: .king, color: activeColor), flag: .kingSideCastling)
        }
        if cleanSan == "O-O-O" || cleanSan == "0-0-0" {
            let kingRank = activeColor == .white ? Rank.one : Rank.eight
            let kingSquare = Square(file: .E, rank: kingRank)
            let targetSquare = Square(file: .C, rank: kingRank)
            return Move(from: kingSquare, to: targetSquare, piece: Piece(type: .king, color: activeColor), flag: .queenSideCastling)
        }
        
        // --- Determine Piece Type and Target Square ---
        var pieceType: PieceType?
        var toSquareString: String
        var fromFileDisambiguation: File? = nil
        var fromRankDisambiguation: Rank? = nil
        
        let firstChar = cleanSan.first
        let isCaptureSan = originalSan.contains("x") // Use original SAN to check for capture indicator
        
        if firstChar?.isUppercase == true {
            // Non-pawn piece moves (N, B, R, Q, K)
            switch firstChar {
            case "N": pieceType = .knight
            case "B": pieceType = .bishop
            case "R": pieceType = .rook
            case "Q": pieceType = .queen
            case "K": pieceType = .king
            default: pieceType = nil // Should not happen if SAN is valid
            }
            toSquareString = String(cleanSan.dropFirst()) // e.g., for "Nf3", toSquareString is "f3"
            
            // Handle disambiguation for non-pawn pieces (e.g., "Nbd2", "R1e2")
            if toSquareString.count == 3 {
                let disambiguationChar = toSquareString.first!
                if let file = File.allCases.first(where: { $0.description.lowercased().first == Character(disambiguationChar.lowercased()) }) {
                    fromFileDisambiguation = file
                } else if let rankInt = Int(String(disambiguationChar)), let rank = Rank(rawValue: rankInt - 1) {
                    fromRankDisambiguation = rank
                }
                toSquareString = String(toSquareString.dropFirst()) // Remove disambiguation char
            }
            
        } else {
            // Pawn moves (e.g., "e4", "exd5")
            pieceType = .pawn
            toSquareString = cleanSan // For "e4", toSquareString is "e4"; for "exd5", it's "xd5" (already cleaned 'x')
            
            // Handle pawn capture disambiguation (e.g., "cxd5")
            if cleanSan.count == 3 { // This means it was "cxd5" originally, now "cd5" (or "c5" for non-capture ambiguity)
                let disambiguationChar = cleanSan.first!
                if let file = File.allCases.first(where: { $0.description.lowercased().first == Character(disambiguationChar.lowercased()) }) {
                    fromFileDisambiguation = file // This is the file from which the pawn moved
                    toSquareString = String(cleanSan.dropFirst()) // The remaining part is the target square
                }
            }
        }
        
        guard let finalPieceType = pieceType else { throw MoveParsingError.invalidMoveFormat(originalSan) }
        guard let toSquare = Square(algebraic: toSquareString) else { throw MoveParsingError.invalidDestination(originalSan, toSquareString) }
        
        // --- Find the 'from' Square by validating moves ---
        var candidateFromSquares: [Square] = []
        for currentSquare in Square.all {
            if let pieceOnSquare = currentBoard.piece(at: currentSquare),
               pieceOnSquare.type == finalPieceType && pieceOnSquare.color == activeColor {
                
                // Apply file/rank disambiguation early if provided
                if let fileDis = fromFileDisambiguation, fileDis != currentSquare.file {
                    continue
                }
                if let rankDis = fromRankDisambiguation, rankDis != currentSquare.rank {
                    continue
                }
                
                candidateFromSquares.append(currentSquare)
            }
        }
        
        var validFromSquares: [Square] = []
        let targetOccupiedPiece = currentBoard.piece(at: toSquare)
        
        for fromSquare in candidateFromSquares {
            var isLegalMove = false
            
            if finalPieceType == .pawn {
                let fileDiff = abs(fromSquare.file.rawValue - toSquare.file.rawValue)
                let rankDiff = toSquare.rank.rawValue - fromSquare.rank.rawValue
                let forwardDirection = activeColor == .white ? 1 : -1
                
                if !isCaptureSan { // Pawn non-capture move (e.g., "e4")
                    if fileDiff == 0 { // Same file
                        if rankDiff == forwardDirection && targetOccupiedPiece == nil {
                            // Single square pawn push (e.g., e2->e3)
                            isLegalMove = true
                        } else if rankDiff == 2 * forwardDirection && (fromSquare.rank == (activeColor == .white ? .two : .seven)) && targetOccupiedPiece == nil {
                            // Double square pawn push from starting rank (e.g., e2->e4)
                            // Must check if intermediate square is empty
                            let intermediateRank = Rank(rawValue: fromSquare.rank.rawValue + forwardDirection)!
                            let intermediateSquare = Square(file: fromSquare.file, rank: intermediateRank)
                            if currentBoard.piece(at: intermediateSquare) == nil {
                                isLegalMove = true
                            }
                        }
                    }
                } else { // Pawn capture move (e.g., "exd5")
                    if fileDiff == 1 && rankDiff == forwardDirection { // Diagonal move
                        // Normal capture: target must be occupied by opponent
                        if let captured = targetOccupiedPiece, captured.color == activeColor.opposite {
                            isLegalMove = true
                        }
                        // En Passant capture: target square is empty, but pawn was on specific rank
                        // This assumes `currentBoard` is the state *before* the move, so we check for the pawn to be captured
                        else if targetOccupiedPiece == nil { // Target is empty, could be en passant
                            let capturedPawnSquare: Square
                            if activeColor == .white {
                                // White capturing en passant on rank 6 (black pawn on rank 5)
                                if toSquare.rank == .six && fromSquare.rank == .five {
                                    capturedPawnSquare = Square(file: toSquare.file, rank: .five)
                                    if let capturedPawn = currentBoard.piece(at: capturedPawnSquare),
                                       capturedPawn.type == .pawn, capturedPawn.color == .black {
                                        isLegalMove = true
                                    }
                                }
                            } else {
                                // Black capturing en passant on rank 3 (white pawn on rank 4)
                                if toSquare.rank == .three && fromSquare.rank == .four {
                                    capturedPawnSquare = Square(file: toSquare.file, rank: .four)
                                    if let capturedPawn = currentBoard.piece(at: capturedPawnSquare),
                                       capturedPawn.type == .pawn, capturedPawn.color == .white {
                                        isLegalMove = true
                                    }
                                }
                            }
                        }
                    }
                }
            } else if finalPieceType == .knight {
                let fileDiff = abs(fromSquare.file.rawValue - toSquare.file.rawValue)
                let rankDiff = abs(fromSquare.rank.rawValue - toSquare.rank.rawValue)
                
                // Knight moves are L-shaped: (1,2) or (2,1) difference in file/rank
                let isKnightMoveShape = (fileDiff == 1 && rankDiff == 2) || (fileDiff == 2 && rankDiff == 1)
                
                if isKnightMoveShape {
                    if isCaptureSan {
                        // Knight capture: target must be occupied by opponent
                        if let captured = targetOccupiedPiece, captured.color == activeColor.opposite {
                            isLegalMove = true
                        }
                    } else {
                        // Knight non-capture: target must be empty
                        if targetOccupiedPiece == nil {
                            isLegalMove = true
                        }
                    }
                }
            } else if finalPieceType == .bishop {
                let fileDiff = abs(fromSquare.file.rawValue - toSquare.file.rawValue)
                let rankDiff = abs(fromSquare.rank.rawValue - toSquare.rank.rawValue)
                
                // Bishop moves are strictly diagonal (file difference must equal rank difference)
                let isDiagonalMove = fileDiff > 0 && fileDiff == rankDiff
                
                if isDiagonalMove {
                    // Check if path is clear
                    if currentBoard.isPathClear(from: fromSquare, to: toSquare) {
                        if isCaptureSan {
                            if let captured = targetOccupiedPiece, captured.color == activeColor.opposite {
                                isLegalMove = true
                            }
                        } else {
                            if targetOccupiedPiece == nil {
                                isLegalMove = true
                            }
                        }
                    }
                }
            } else if finalPieceType == .rook { // ADDED THIS BLOCK
                let fileDiff = abs(fromSquare.file.rawValue - toSquare.file.rawValue)
                let rankDiff = abs(fromSquare.rank.rawValue - toSquare.rank.rawValue)
                
                // Rook moves are strictly horizontal or vertical
                let isStraightMove = (fileDiff == 0 && rankDiff > 0) || (rankDiff == 0 && fileDiff > 0)
                
                if isStraightMove {
                    // Check if path is clear
                    if currentBoard.isPathClear(from: fromSquare, to: toSquare) {
                        if isCaptureSan {
                            if let captured = targetOccupiedPiece, captured.color == activeColor.opposite {
                                isLegalMove = true
                            }
                        } else {
                            if targetOccupiedPiece == nil {
                                isLegalMove = true
                            }
                        }
                    }
                }
            }
            // Add more `else if` blocks for other piece types (Queen, King) here
            // For now, if no specific logic, revert to basic check (though this will still cause ambiguity for Q, K if multiple pieces can move to target)
            else {
                let targetOccupiedByOpponent = (targetOccupiedPiece != nil && targetOccupiedPiece?.color == activeColor.opposite)
                let targetIsEmpty = (targetOccupiedPiece == nil)
                
                if isCaptureSan {
                    if targetOccupiedByOpponent {
                        isLegalMove = true
                    }
                } else {
                    if targetIsEmpty {
                        isLegalMove = true
                    }
                }
            }
            
            
            if isLegalMove {
                validFromSquares.append(fromSquare)
            }
        }
        
        // --- Final fromSquare determination ---
        var finalFromSquare: Square?
        if validFromSquares.count == 1 {
            finalFromSquare = validFromSquares.first
        } else if validFromSquares.count > 1 {
            // If we still have multiple valid sources, and no disambiguation was fully effective, it's ambiguous
            throw MoveParsingError.ambiguousMove(originalSan)
        } else {
            throw MoveParsingError.generalError("No valid starting square found for '\(originalSan)' for \(activeColor) \(finalPieceType)")
        }
        
        guard let unwrappedFromSquare = finalFromSquare else { throw MoveParsingError.generalError("Could not determine unique starting square for '\(originalSan)'") }
        
        // --- Determine MoveFlag and Captured Piece ---
        var flag: MoveFlag = .normal
        var actualCapturedPiece: Piece? = targetOccupiedPiece // Default captured piece
        
        // Re-evaluate captured piece for en passant, as targetOccupiedPiece will be nil
        if finalPieceType == .pawn && unwrappedFromSquare.file != toSquare.file && targetOccupiedPiece == nil {
            // This is a diagonal pawn move to an empty square, must be en passant
            let capturedPawnSquare: Square
            if activeColor == .white {
                capturedPawnSquare = Square(file: toSquare.file, rank: .five) // Black pawn on rank 5
            } else {
                capturedPawnSquare = Square(file: toSquare.file, rank: .four) // White pawn on rank 4
            }
            
            if let captured = currentBoard.piece(at: capturedPawnSquare),
               captured.type == .pawn, captured.color == activeColor.opposite {
                actualCapturedPiece = captured
                flag = .enPassantCapture
            }
        } else if let promType = promotionType {
            flag = .promotion(promType)
        } else if flag == .normal && actualCapturedPiece != nil { // if not already a special flag like en passant or promotion
            flag = .capture
        }
        
        // Final check for actual piece on fromSquare
        guard let pieceOnFromSquare = currentBoard.piece(at: unwrappedFromSquare),
              pieceOnFromSquare.type == finalPieceType,
              pieceOnFromSquare.color == activeColor else {
            throw MoveParsingError.noPieceFoundAtFromSquare(unwrappedFromSquare, finalPieceType, activeColor)
        }
        
        return Move(from: unwrappedFromSquare, to: toSquare, piece: pieceOnFromSquare, capturedPiece: actualCapturedPiece, flag: flag)
    }
}
