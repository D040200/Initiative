// LocalDatabaseView.swift
import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct LocalDatabaseView: View {
    @StateObject private var dataManager = ChessLocalDataManager.shared
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
        
        // Apply search filter
        if !searchText.isEmpty {
            games = dataManager.searchGames(query: searchText)
        }
        
        // Apply result filter
        if let predicate = selectedFilter.predicate {
            games = games.filter { game in
                predicate.evaluate(with: game)
            }
        }
        
        return games
    }
    
    var body: some View {
        VStack {
            // Header with stats
            gameStatsHeader
            
            // Search and filters
            searchAndFilters
            
            // Games list
            gamesList
            
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
        .alert("Error", isPresented: .constant(dataManager.errorMessage != nil)) {
            Button("OK") {
                dataManager.errorMessage = nil
            }
        } message: {
            if let errorMessage = dataManager.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var gameStatsHeader: some View {
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
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var searchAndFilters: some View {
        VStack {
            // Search bar
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
            
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(GameFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
    
    private var gamesList: some View {
        List {
            ForEach(filteredGames, id: \.id) { game in
                GameRowView(game: game)
                    .onTapGesture {
                        showingGameDetail = game
                    }
                    .contextMenu {
                        Button {
                            showingGameDetail = game
                        } label: {
                            Label("View Details", systemImage: "eye")
                        }
                        
                        Button {
                            // TODO: Load game in analysis view
                        } label: {
                            Label("Analyze", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Button {
                            if let pgnString = dataManager.exportGame(game) {
                                copyToClipboard(pgnString)
                            }
                        } label: {
                            Label("Copy PGN", systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive) {
                            dataManager.deleteGame(game)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete(perform: deleteGames)
        }
        .refreshable {
            dataManager.fetchGames()
        }
    }
    
    private func deleteGames(offsets: IndexSet) {
        for index in offsets {
            let game = filteredGames[index]
            dataManager.deleteGame(game)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Game Row View
struct GameRowView: View {
    let game: ChessGameEntity
    
    var body: some View {
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
    }
}

// MARK: - Import PGN View
struct ImportPGNView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var pgnText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import PGN Games")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Import from File", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Text("or")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading) {
                        Text("Paste PGN Text:")
                            .font(.headline)
                        
                        TextEditor(text: $pgnText)
                            .frame(minHeight: 200)
                            .padding(8)
                            .cornerRadius(8)
                    }
                    
                    Button("Import Games") {
                        importPGNText()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pgnText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import PGN")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    ChessLocalDataManager.shared.importPGNFile(from: url)
                    dismiss()
                }
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }
    
    private func importPGNText() {
        do {
            let pgn = try PGNParser.parse(pgnString: pgnText)
            ChessLocalDataManager.shared.saveGame(from: pgn)
            dismiss()
        } catch {
            print("PGN parsing error: \(error)")
        }
    }
}

// MARK: - Export Database View
struct ExportDatabaseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var exportedContent = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Database")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    Button {
                        exportedContent = ChessLocalDataManager.shared.exportAllGames()
                        showingShareSheet = true
                    } label: {
                        Label("Export All Games", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text("Export all games as PGN file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportedContent])
        }
        #endif
    }
}

// MARK: - Share Sheet (iOS Only)
#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Game Detail View
struct GameDetailView: View {
    let game: ChessGameEntity
    @Environment(\.dismiss) private var dismiss
    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Game header
                    gameHeader
                    
                    // Game details
                    gameDetails
                    
                    // Notes section
                    notesSection
                    
                    // PGN section
                    pgnSection
                }
                .padding()
            }
            .navigationTitle("Game Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            ChessLocalDataManager.shared.updateGame(game, title: editedTitle, notes: editedNotes)
                        } else {
                            editedTitle = game.title ?? ""
                            editedNotes = game.notes ?? ""
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .onAppear {
            editedTitle = game.title ?? ""
            editedNotes = game.notes ?? ""
        }
    }
    
    private var gameHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                TextField("Game Title", text: $editedTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title2)
            } else {
                Text(game.displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            HStack {
                Image(systemName: game.resultIcon)
                    .foregroundColor(game.resultColor)
                Text(game.result ?? "*")
                    .fontWeight(.semibold)
            }
        }
    }
    
    private var gameDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Information")
                .font(.headline)
            
            DetailRow(label: "White", value: game.whitePlayer ?? "Unknown")
            DetailRow(label: "Black", value: game.blackPlayer ?? "Unknown")
            DetailRow(label: "Event", value: game.event ?? "Unknown")
            DetailRow(label: "Site", value: game.site ?? "Unknown")
            DetailRow(label: "Date", value: game.date ?? "Unknown")
            
            if let round = game.round {
                DetailRow(label: "Round", value: round)
            }
            
            if let eco = game.eco {
                DetailRow(label: "ECO", value: eco)
            }
            
            DetailRow(label: "Created", value: game.formattedDate)
        }
        .padding()
        .cornerRadius(10)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            
            if isEditing {
                TextEditor(text: $editedNotes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .cornerRadius(8)
            } else {
                Text(game.notes?.isEmpty == false ? game.notes! : "No notes added")
                    .foregroundColor(game.notes?.isEmpty != false ? .secondary : .primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cornerRadius(8)
            }
        }
    }
    
    private var pgnSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PGN")
                .font(.headline)
            
            if let pgnString = game.pgnString {
                ScrollView {
                    Text(pgnString)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Helper Views
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Add Game View
struct AddGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var whitePlayer = ""
    @State private var blackPlayer = ""
    @State private var event = ""
    @State private var site = ""
    @State private var result = "*"
    
    let results = ["*", "1-0", "0-1", "1/2-1/2"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Game Details") {
                    TextField("Title", text: $title)
                    TextField("White Player", text: $whitePlayer)
                    TextField("Black Player", text: $blackPlayer)
                    TextField("Event", text: $event)
                    TextField("Site", text: $site)
                    
                    Picker("Result", selection: $result) {
                        ForEach(results, id: \.self) { result in
                            Text(result).tag(result)
                        }
                    }
                }
            }
            .navigationTitle("New Game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGame()
                    }
                    .disabled(whitePlayer.isEmpty || blackPlayer.isEmpty)
                }
            }
        }
    }
    
    private func saveGame() {
        var tags: [String: String] = [:]
        tags["White"] = whitePlayer
        tags["Black"] = blackPlayer
        tags["Result"] = result
        
        if !event.isEmpty { tags["Event"] = event }
        if !site.isEmpty { tags["Site"] = site }
        
        let pgn = PGN(tags: tags, initialFen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", moves: [], result: result)
        
        ChessLocalDataManager.shared.saveGame(from: pgn, title: title.isEmpty ? nil : title)
        dismiss()
    }
}
