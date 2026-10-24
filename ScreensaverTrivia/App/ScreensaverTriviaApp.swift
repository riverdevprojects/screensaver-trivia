import SwiftUI

@main
struct ScreensaverTriviaApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onChange(of: scenePhase) { _, phase in store.setActive(phase == .active) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    var body: some View {
        ZStack {
            switch store.screen {
            case .home: HomeView()
            case .lobby: LobbyView()
            case .game: GameView()
            case .results: ResultsView()
            }
        }
        .font(.party(16))
        .tint(PartyTheme.mint)
        .alert("A quick heads-up", isPresented: Binding(
            get: { store.alert != nil }, set: { if !$0 { store.alert = nil } })) {
                Button("Got it", role: .cancel) { store.alert = nil }
            } message: { Text(store.alert ?? "") }
    }
}
