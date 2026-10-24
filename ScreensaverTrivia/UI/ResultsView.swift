import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var store: GameStore
    var body: some View {
        GeometryReader { geo in
            ZStack {
                PartyBackground(gold: true)
                if let match = store.match {
                    let ranked = GameRules.ranking(match.players)
                    ScrollView(.vertical) {
                        VStack(spacing: 10) {
                            HStack {
                                CircleButton(symbol: "house.fill", label: "Back to home") { store.leave() }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(store.isParty ? "A world-class finish!" : "What a trip!")
                                        .font(.party(25, weight: .black))
                                    Text("\(match.collection.title) · \(match.roundCount) destinations explored")
                                        .font(.party(11, weight: .semibold)).opacity(0.75)
                                }
                                Spacer()
                                Image(systemName: "trophy.fill").font(.system(size: 30)).foregroundStyle(.white)
                            }
                            .foregroundStyle(PartyTheme.ink)
                            HStack(alignment: .bottom, spacing: 12) {
                                if ranked.count >= 2 { podium(ranked[1], place: 2, height: geo.size.height * 0.19) }
                                if let winner = ranked.first { podium(winner, place: 1, height: geo.size.height * 0.27) }
                                if ranked.count >= 3 { podium(ranked[2], place: 3, height: geo.size.height * 0.14) }
                            }.frame(maxWidth: .infinity, alignment: .bottom)
                            if ranked.count > 3 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(ranked.dropFirst(3).enumerated()), id: \.element.id) { index, player in
                                            HStack(spacing: 7) {
                                                Text("#\(index + 4)")
                                                AvatarView(avatar: player.avatar, size: 24)
                                                Text(player.name)
                                                Text(player.score.formatted()).fontWeight(.black)
                                            }.font(.party(11)).foregroundStyle(PartyTheme.ink)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(.white.opacity(0.3), in: Capsule())
                                        }
                                    }
                                }.frame(height: 40)
                            }
                            HStack(spacing: 12) {
                                resultStat(symbol: "checkmark.seal.fill", value: "\(store.localPlayer?.correctAnswers ?? 0)/\(match.roundCount)", label: "SPOTTED")
                                resultStat(symbol: "star.fill", value: (store.localPlayer?.score ?? 0).formatted(), label: "YOUR POINTS")
                                resultStat(symbol: "trophy.fill", value: store.stats.bestScore.formatted(), label: "PERSONAL BEST")
                                if store.isHost {
                                    Button { store.playAgain() } label: { Label("Play again", systemImage: "arrow.clockwise") }
                                        .buttonStyle(PartyButtonStyle(color: PartyTheme.ink, foreground: .white))
                                        .frame(maxWidth: 210).accessibilityIdentifier("playAgain")
                                } else {
                                    Text("Waiting for the host\nto play again…").font(.party(12))
                                        .foregroundStyle(PartyTheme.ink).multilineTextAlignment(.center)
                                }
                            }
                        }.padding(.horizontal, 24).padding(.vertical, 12)
                            .frame(minHeight: geo.size.height)
                    }
                }
            }
        }
    }

    private func podium(_ player: Player, place: Int, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            if place == 1 {
                Image(systemName: "crown.fill").font(.system(size: 23)).foregroundStyle(PartyTheme.ink)
            }
            AvatarView(avatar: player.avatar, size: place == 1 ? 65 : 48)
            Text(player.name).font(.party(14)).lineLimit(1).foregroundStyle(PartyTheme.ink)
            VStack(spacing: 2) {
                Text(["", "1st", "2nd", "3rd"][place]).font(.party(13, weight: .black))
                    .padding(.horizontal, 15).padding(.vertical, 4)
                    .background(PartyTheme.ink.opacity(0.12), in: Capsule())
                Text(player.score.formatted()).font(.party(place == 1 ? 28 : 23, weight: .black)).monospacedDigit()
                Text("POINTS").font(.party(8, weight: .black)).tracking(1.7)
            }.foregroundStyle(PartyTheme.ink)
                .frame(maxWidth: .infinity).frame(height: height, alignment: .top).padding(.top, 10)
                .background(.white.opacity(place == 1 ? 0.48 : 0.25), in: UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
        }.frame(maxWidth: 195)
    }

    private func resultStat(symbol: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(PartyTheme.ink.opacity(0.65))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.party(19, weight: .black)).monospacedDigit()
                Text(label).font(.party(7, weight: .black)).tracking(1)
            }
        }.foregroundStyle(PartyTheme.ink).padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity).background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }
}
