// ChessLocalDataManager.swift
import Foundation
import CoreData
import SwiftUI

// MARK: - Local Core Data Stack (No CloudKit)
class ChessLocalDataManager: ObservableObject {
    static let shared = ChessLocalDataManager()
    
    @Published var savedGames: [ChessGameEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ChessDataModel")
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {
        fetchGames()
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
                fetchGames()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchGames() {
        isLoading = true
        let request: NSFetchRequest<ChessGameEntity> = ChessGameEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChessGameEntity.dateCreated, ascending: false)]
        
        do {
            savedGames = try context.fetch(request)
        } catch {
            errorMessage = "Failed to fetch games: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func saveGame(from pgn: PGN, title: String? = nil) {
        let gameEntity = ChessGameEntity(context: context)
        gameEntity.id = UUID()
        gameEntity.title = title ?? pgn.tags["Event"] ?? "Untitled Game"
        gameEntity.whitePlayer = pgn.tags["White"] ?? "Unknown"
        gameEntity.blackPlayer = pgn.tags["Black"] ?? "Unknown"
        gameEntity.result = pgn.result ?? "*"
        gameEntity.event = pgn.tags["Event"]
        gameEntity.site = pgn.tags["Site"]
        gameEntity.date = pgn.tags["Date"]
        gameEntity.round = pgn.tags["Round"]
        gameEntity.eco = pgn.tags["ECO"]
        gameEntity.pgnString = generatePGNString(from: pgn)
        gameEntity.dateCreated = Date()
        gameEntity.lastModified = Date()
        
        save()
    }
    
    func deleteGame(_ game: ChessGameEntity) {
        context.delete(game)
        save()
    }
    
    func updateGame(_ game: ChessGameEntity, title: String? = nil, notes: String? = nil) {
        if let title = title {
            game.title = title
        }
        if let notes = notes {
            game.notes = notes
        }
        game.lastModified = Date()
        save()
    }
    
    // Convert PGN back to string format
    private func generatePGNString(from pgn: PGN) -> String {
        var pgnString = ""
        
        // Add tags
        for (key, value) in pgn.tags.sorted(by: { $0.key < $1.key }) {
            pgnString += "[\(key) \"\(value)\"]\n"
        }
        
        pgnString += "\n"
        
        // Add moves
        pgnString += pgn.moves.joined(separator: " ")
        
        if let result = pgn.result {
            pgnString += " \(result)"
        }
        
        return pgnString
    }
    
    // Search functionality
    func searchGames(query: String) -> [ChessGameEntity] {
        let request: NSFetchRequest<ChessGameEntity> = ChessGameEntity.fetchRequest()
        
        if !query.isEmpty {
            let predicates = [
                NSPredicate(format: "title CONTAINS[cd] %@", query),
                NSPredicate(format: "whitePlayer CONTAINS[cd] %@", query),
                NSPredicate(format: "blackPlayer CONTAINS[cd] %@", query),
                NSPredicate(format: "event CONTAINS[cd] %@", query),
                NSPredicate(format: "notes CONTAINS[cd] %@", query)
            ]
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChessGameEntity.dateCreated, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            return []
        }
    }
    
    // Filter by player
    func gamesByPlayer(_ playerName: String) -> [ChessGameEntity] {
        let request: NSFetchRequest<ChessGameEntity> = ChessGameEntity.fetchRequest()
        let predicate = NSPredicate(format: "whitePlayer CONTAINS[cd] %@ OR blackPlayer CONTAINS[cd] %@", playerName, playerName)
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChessGameEntity.dateCreated, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    // Filter by result
    func gamesByResult(_ result: String) -> [ChessGameEntity] {
        let request: NSFetchRequest<ChessGameEntity> = ChessGameEntity.fetchRequest()
        request.predicate = NSPredicate(format: "result == %@", result)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChessGameEntity.dateCreated, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    // Import/Export functionality
    func importPGNFile(from url: URL) {
        do {
            let content = try String(contentsOf: url)
            let games = parsePGNFile(content)
            
            for pgnGame in games {
                saveGame(from: pgnGame)
            }
            
        } catch {
            errorMessage = "Failed to import PGN file: \(error.localizedDescription)"
        }
    }
    
    func exportGame(_ game: ChessGameEntity) -> String? {
        return game.pgnString
    }
    
    func exportAllGames() -> String {
        var allGames = ""
        for game in savedGames {
            if let pgnString = game.pgnString {
                allGames += pgnString + "\n\n"
            }
        }
        return allGames
    }
    
    // Parse multiple games from a PGN file
    private func parsePGNFile(_ content: String) -> [PGN] {
        let gameStrings = content.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var games: [PGN] = []
        
        for gameString in gameStrings {
            do {
                let pgn = try PGNParser.parse(pgnString: gameString)
                games.append(pgn)
            } catch {
                print("Failed to parse game: \(error)")
            }
        }
        
        return games
    }
}

// MARK: - Core Data Model Extensions
extension ChessGameEntity {
    var pgnObject: PGN? {
        guard let pgnString = pgnString else { return nil }
        return try? PGNParser.parse(pgnString: pgnString)
    }
    
    
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return "\(whitePlayer ?? "Unknown") vs \(blackPlayer ?? "Unknown")"
    }
    
    var formattedDate: String {
        guard let date = dateCreated else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var resultIcon: String {
        switch result {
        case "1-0": return "w.circle.fill"
        case "0-1": return "b.circle.fill"
        case "1/2-1/2": return "equal.circle.fill"
        default: return "asterisk.circle"
        }
    }
    
    var resultColor: Color {
        switch result {
        case "1-0": return .blue
        case "0-1": return .red
        case "1/2-1/2": return .orange
        default: return .gray
        }
    }
}
