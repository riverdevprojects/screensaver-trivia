import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showSettings = false
    @State private var showHowTo = false
    @State private var showPartyOptions = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 450
            let tiny = geo.size.height < 340
            ZStack {
                PartyBackground()
                VStack(spacing: compact ? 10 : 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe.americas.fill").font(.system(size: 30))
                            .foregroundStyle(PartyTheme.mint)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("SCREENSAVER").font(.party(12, weight: .black)).tracking(2)
                            Text("TRIVIA").font(.party(25, weight: .black)).tracking(1.5)
                        }.foregroundStyle(.white)
                        Spacer()
                        StatPill(symbol: "wifi.slash", text: "OFFLINE READY")
                        StatPill(symbol: "trophy.fill", text: "\(store.stats.bestScore.formatted()) BEST")
                        CircleButton(symbol: "gearshape.fill", label: "Settings") { showSettings = true }
                            .accessibilityIdentifier("settings")
                    }
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: tiny ? 8 : compact ? 10 : 16) {
                            Text("Know the place?\nWin the race.")
                                .font(.party(tiny ? 26 : compact ? 30 : 39, weight: .black))
                                .foregroundStyle(.white).lineSpacing(-2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Watch the world. Make your guess.")
                                .font(.party(13, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                            menuButton(title: "SOLO", subtitle: "Your own little world tour", symbol: "bolt.fill", color: .orange, compact: tiny) {
                                store.startSolo()
                            }.accessibilityIdentifier("playSolo")
                            menuButton(title: "PARTY", subtitle: "2–8 friends · nearby iPhones", symbol: "party.popper.fill", color: PartyTheme.pink, compact: tiny) {
                                showPartyOptions = true
                            }.accessibilityIdentifier("playParty")
                        }
                        .frame(maxWidth: geo.size.width * 0.48)
                        VStack(spacing: 4) {
                            TravelGlobe().frame(maxHeight: .infinity)
                            HStack(spacing: 8) {
                                AvatarView(avatar: store.settings.avatar, size: 28)
                                Text("Ready, \(store.settings.name)?").font(.party(14)).foregroundStyle(.white)
                            }
                        }.frame(maxWidth: .infinity)
                    }
                    HStack(spacing: 8) {
                        Label("\(store.catalog.locations.count) destinations", systemImage: "mappin.and.ellipse")
                        Text("·")
                        Text("4 choices. Every second counts.")
                        Spacer()
                        Button { showHowTo = true } label: { Label("How to play", systemImage: "questionmark.circle.fill") }
                            .accessibilityIdentifier("howToPlay")
                    }.font(.party(12)).foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 24).padding(.vertical, compact ? 12 : 20)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showHowTo) { HowToPlayView() }
        .confirmationDialog("Let’s get the party started", isPresented: $showPartyOptions, titleVisibility: .visible) {
            Button("Host a party") { store.hostParty() }
            Button("Join a nearby party") { store.findParty() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func menuButton(title: String, subtitle: String, symbol: String, color: Color, compact: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 27, weight: .bold))
                    .foregroundStyle(color).frame(width: 35)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.party(compact ? 18 : 20, weight: .black))
                    Text(subtitle).font(.party(11, weight: .semibold)).opacity(0.65)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .black)).opacity(0.35)
            }
        }.buttonStyle(PartyButtonStyle(verticalPadding: compact ? 8 : 13))
    }
}
