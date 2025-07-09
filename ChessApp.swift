import SwiftUI

@main
struct ChessApp: App {
    let persistentContainer = ChessLocalDataManager.shared.persistentContainer
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
    }
}
