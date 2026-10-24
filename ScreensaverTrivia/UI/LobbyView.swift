import SwiftUI

struct LobbyView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showSettings = false
    var body: some View {
        ZStack {
            PartyBackground()
            VStack(spacing: 12) {
                HStack {
                    CircleButton(symbol: "arrow.left", label: "Leave party") { store.leave() }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.isHost ? "Your party. Your planet." : "Find your people.")
                            .font(.party(24, weight: .black))
                        Text(store.isHost ? "Friends can join from their iPhones." : "Join a host nearby. No account needed.")
                            .font(.party(12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    StatPill(symbol: "antenna.radiowaves.left.and.right", text: "NEARBY PARTY")
                    if store.isHost {
                        CircleButton(symbol: "slider.horizontal.3", label: "Party settings") { showSettings = true }
                    }
                }
                if let match = store.match {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: match.collection.symbol)
                                .font(.system(size: 42, weight: .bold)).foregroundStyle(PartyTheme.mint)
                            Text(match.collection.title).font(.party(28, weight: .black))
                            Text("\(match.roundCount) rounds · 4 choices")
                                .font(.party(13)).foregroundStyle(.white.opacity(0.8))
                            Text("Fast guesses. Big points.")
                                .font(.party(12, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(20).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("THE EXPLORERS").font(.party(12, weight: .black)).tracking(1)
                                Spacer()
                                Text("\(match.players.count)/8").font(.party(13))
                            }.foregroundStyle(.white.opacity(0.75))
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                                ForEach(match.players) { player in
                                    HStack(spacing: 8) {
                                        AvatarView(avatar: player.avatar, size: 34)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(player.name).font(.party(13)).lineLimit(1)
                                            Text(player.id == match.hostID ? "HOST" : "READY")
                                                .font(.party(9, weight: .black)).foregroundStyle(PartyTheme.mint)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(PartyTheme.mint)
                                            .font(.system(size: 14))
                                    }.padding(9).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            if match.players.count < 2 {
                                Label("Waiting for your first travel buddy…", systemImage: "person.badge.plus")
                                    .font(.party(12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                                    .padding(.top, 4)
                            }
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    HStack(spacing: 18) {
                        Label("Same Wi-Fi · Wi-Fi & Bluetooth on", systemImage: "wifi")
                            .font(.party(11, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        if store.isHost {
                            Button { store.startMatch() } label: {
                                Label("Start the adventure", systemImage: "play.fill")
                            }.buttonStyle(PartyButtonStyle(color: PartyTheme.mint))
                                .frame(maxWidth: 290)
                                .opacity(match.players.count >= 2 ? 1 : 0.5)
                                .disabled(match.players.count < 2)
                                .accessibilityIdentifier("startParty")
                        } else {
                            Label("Waiting for the host to start", systemImage: "hourglass")
                                .font(.party(14)).padding(14).background(.white.opacity(0.14), in: Capsule())
                        }
                    }
                } else {
                    NearbyPartyBrowser(session: store.nearby, isJoining: store.isJoining) { store.join($0) }
                }
            }.padding(.horizontal, 22).padding(.vertical, 12).foregroundStyle(.white)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

private struct NearbyPartyBrowser: View {
    @ObservedObject var session: NearbySession
    let isJoining: Bool
    var onJoin: (NearbyRoom) -> Void
    var body: some View {
        HStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 52)).foregroundStyle(PartyTheme.mint)
                Text("Better together.").font(.party(25, weight: .black))
                Text("Ask a friend to tap Party → Host a party.\nKeep both iPhones on the same Wi-Fi\nwith Wi-Fi and Bluetooth switched on.")
                    .font(.party(13, weight: .medium)).multilineTextAlignment(.center).lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.8))
                Button("Open app settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.font(.party(12)).foregroundStyle(PartyTheme.mint)
            }.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                Text("NEARBY PARTIES").font(.party(12, weight: .black)).tracking(1)
                if session.rooms.isEmpty {
                    VStack(spacing: 14) {
                        ProgressView().tint(.white)
                        Text(session.status).font(.party(14))
                        Text("Allow Local Network access when asked.")
                            .font(.party(11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(session.rooms) { room in
                                Button { onJoin(room) } label: {
                                    HStack {
                                        Image(systemName: "party.popper.fill").foregroundStyle(PartyTheme.pink)
                                        Text("\(room.name)’s party").font(.party(16))
                                        Spacer()
                                        if isJoining { ProgressView().tint(PartyTheme.ink) }
                                        else { Image(systemName: "arrow.right.circle.fill") }
                                    }
                                }.buttonStyle(PartyButtonStyle()).disabled(isJoining)
                            }
                        }.padding(.bottom, 6)
                    }
                }
            }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
        }.frame(maxHeight: .infinity)
    }
}
