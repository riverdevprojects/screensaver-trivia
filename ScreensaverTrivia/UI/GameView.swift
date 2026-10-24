import SwiftUI

struct GameView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showExit = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PartyBackground()
                if let match = store.match, let round = match.round {
                    VStack(spacing: geo.size.height < 340 ? 6 : 10) {
                        header(match: match, round: round)
                        playerRibbon(match: match)
                        HStack(spacing: 16) {
                            videoPanel(match: match, round: round)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            VStack(spacing: 8) {
                                ForEach(Array(round.choiceIDs.enumerated()), id: \.element) { index, id in
                                    answerButton(id: id, index: index, match: match, round: round, compact: geo.size.height < 340)
                                }
                            }.frame(width: geo.size.width * 0.37)
                        }.frame(maxHeight: .infinity)
                        footer(match: match, round: round)
                    }.padding(.horizontal, 18).padding(.vertical, 8)
                }
                if store.soloPaused {
                    Color.black.opacity(0.65).ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image(systemName: "pause.circle.fill").font(.system(size: 50))
                        Text("A little layover.").font(.party(30, weight: .black))
                        Button("Keep exploring") { store.resumeSolo() }
                            .buttonStyle(PartyButtonStyle(color: PartyTheme.mint)).frame(width: 260)
                        Button("Back to home") { store.leave() }.font(.party(14))
                    }.foregroundStyle(.white)
                }
            }
        }
        .confirmationDialog(store.isHost && store.isParty ? "End the party for everyone?" : "Leave this game?",
                            isPresented: $showExit, titleVisibility: .visible) {
            Button("Leave game", role: .destructive) { store.leave() }
            Button("Keep playing", role: .cancel) {}
        }
    }

    private func header(match: MatchSnapshot, round: RoundPrompt) -> some View {
        HStack(spacing: 10) {
            Image(systemName: match.collection.symbol).font(.system(size: 19, weight: .bold)).foregroundStyle(PartyTheme.mint)
            VStack(alignment: .leading, spacing: 0) {
                Text(match.collection.title).font(.party(15))
                Text("WHERE IN THE WORLD?").font(.party(8, weight: .black)).tracking(1.4).opacity(0.65)
            }
            Spacer(minLength: 8)
            HStack(spacing: 7) {
                ForEach(1...match.roundCount, id: \.self) { number in
                    Circle().fill(number < round.number ? PartyTheme.mint : number == round.number ? PartyTheme.yellow : .white.opacity(0.25))
                        .frame(width: number == round.number ? 12 : 8, height: number == round.number ? 12 : 8)
                }
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel("Round \(round.number) of \(match.roundCount)")
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(store.isParty ? "Party mode" : "Solo mode").font(.party(14))
                Text("Round \(round.number)/\(match.roundCount)").font(.party(10)).opacity(0.65)
            }
            Button {
                if store.isParty || match.stage == .reveal { showExit = true } else { store.pauseSolo() }
            } label: {
                Image(systemName: store.isParty ? "xmark" : "pause.fill").font(.system(size: 13, weight: .bold))
                    .frame(width: 44, height: 36).background(.white.opacity(0.15), in: Capsule())
            }.accessibilityLabel(store.isParty ? "Leave game" : "Pause game").accessibilityIdentifier("pauseGame")
        }.foregroundStyle(.white).frame(height: 32)
    }

    private func playerRibbon(match: MatchSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(match.players) { player in
                    HStack(spacing: 7) {
                        AvatarView(avatar: player.avatar, size: 34)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(player.name + (player.id == store.localID ? " (you)" : ""))
                                .font(.party(10)).lineLimit(1)
                            Text(player.score.formatted()).font(.party(15, weight: .black)).monospacedDigit()
                        }
                        if !player.isConnected {
                            Image(systemName: "wifi.slash").foregroundStyle(.white.opacity(0.5)).font(.system(size: 12))
                        } else if match.stage == .reveal {
                            let correct = match.answers.first(where: { $0.playerID == player.id })?.choiceID == match.round?.locationID
                            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(correct ? PartyTheme.mint : PartyTheme.yellow).font(.system(size: 17))
                                .accessibilityLabel(correct ? "Correct" : "Incorrect or timed out")
                        } else if match.answeredPlayerIDs.contains(player.id) {
                            Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(PartyTheme.mint)
                                .accessibilityLabel("Answer locked")
                        }
                    }.padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(player.id == store.localID ? 0.2 : 0.09), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                if !store.isParty {
                    Label("Just you & the world", systemImage: "sparkles")
                        .font(.party(12, weight: .medium)).foregroundStyle(.white.opacity(0.7)).padding(.leading, 6)
                }
            }
        }.frame(height: 44)
    }

    private func videoPanel(match: MatchSnapshot, round: RoundPrompt) -> some View {
        ZStack(alignment: .bottomLeading) {
            LocationVideoView(locationID: round.locationID,
                playing: store.countdown == 0 && !store.soloPaused, resetKey: round.id)
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 3) {
                if match.stage == .reveal, let location = store.catalog.location(round.locationID) {
                    Text(location.name).font(.party(24, weight: .black))
                    Text(location.country).font(.party(12, weight: .semibold)).opacity(0.85)
                } else {
                    Label("A LITTLE WINDOW TO SOMEWHERE", systemImage: "location.viewfinder")
                        .font(.party(8, weight: .black)).tracking(1.3)
                }
            }.foregroundStyle(.white).padding(16)
            if store.countdown > 0 && match.stage == .round {
                Rectangle().fill(PartyTheme.ink)
                VStack(spacing: 3) {
                    Text("NEXT STOP…").font(.party(11, weight: .black)).tracking(2)
                    Text("\(store.countdown)").font(.party(62, weight: .black)).contentTransition(.numericText())
                    Text("Get ready to guess").font(.party(12))
                }.foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white.opacity(0.5), lineWidth: 2))
        .shadow(color: PartyTheme.ink.opacity(0.2), radius: 0, x: 0, y: 5)
    }

    private func answerButton(id: String, index: Int, match: MatchSnapshot, round: RoundPrompt, compact: Bool) -> some View {
        let location = store.catalog.location(id)
        let revealed = match.stage == .reveal
        let selected = store.selectedChoice == id
        let correct = revealed && id == round.locationID
        let wrong = revealed && selected && !correct
        let fill: Color = correct ? PartyTheme.mint : wrong ? Color(red: 1, green: 0.65, blue: 0.71) : selected ? PartyTheme.yellow : .white
        return Button { store.choose(id) } label: {
            HStack(spacing: 10) {
                Text(["A", "B", "C", "D"][index]).font(.party(12, weight: .black))
                    .frame(width: 27, height: 27).background(PartyTheme.ink.opacity(0.07), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(location?.name ?? "Unknown place").font(.party(compact ? 14 : 16)).lineLimit(1).minimumScaleFactor(0.7)
                    if !compact { Text(location?.country ?? "").font(.party(9, weight: .semibold)).opacity(0.55).lineLimit(1) }
                }
                Spacer(minLength: 0)
                if correct { Image(systemName: "checkmark.circle.fill").font(.system(size: 20)) }
                else if wrong { Image(systemName: "xmark.circle.fill").font(.system(size: 20)) }
                else if selected { Image(systemName: "lock.fill").font(.system(size: 15)) }
            }
            .foregroundStyle(PartyTheme.ink)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.35), lineWidth: 1))
            .compositingGroup()
            .shadow(color: PartyTheme.ink.opacity(0.22), radius: 0, x: 0, y: 3)
            .opacity(revealed && !correct && !selected ? 0.55 : 1)
        }
        .buttonStyle(AnswerButtonStyle()).disabled(!store.canAnswer)
        .accessibilityIdentifier("answer\(index)")
        .accessibilityLabel("\(["A", "B", "C", "D"][index]), \(location?.name ?? ""), \(location?.country ?? "")")
        .accessibilityValue(correct ? "Correct answer" : selected ? "Your answer" : "")
    }

    private func footer(match: MatchSnapshot, round: RoundPrompt) -> some View {
        HStack(spacing: 12) {
            if match.stage == .reveal {
                let answer = match.answers.first { $0.playerID == store.localID }
                VStack(alignment: .leading, spacing: 1) {
                    Text(answer == nil ? "Time’s up! Next stop?" : answer?.points == 0 ? "A detour! You’ll get the next one." : "+\(answer?.points ?? 0) points · Nice spotting!")
                        .font(.party(12))
                    if let answer { Text("Answered in \(answer.elapsed.formatted(.number.precision(.fractionLength(1))))s")
                        .font(.party(9, weight: .medium)).opacity(0.7) }
                }.foregroundStyle(.white).accessibilityIdentifier("roundFeedback")
                Spacer(minLength: 4)
                if store.isHost {
                    Button { store.nextRound() } label: {
                        HStack(spacing: 8) {
                            Text(round.number == match.roundCount ? "See results" : "Next destination")
                            Image(systemName: "arrow.right")
                        }.font(.party(12)).foregroundStyle(PartyTheme.ink)
                            .padding(.horizontal, 16).frame(height: 34).background(PartyTheme.mint, in: Capsule())
                    }.accessibilityIdentifier("nextRound")
                } else { Text("Waiting for the host…").font(.party(12)).foregroundStyle(.white.opacity(0.8)) }
            } else {
                Image(systemName: store.selectedChoice == nil ? "timer" : "lock.fill")
                    .foregroundStyle(PartyTheme.yellow)
                Text(store.selectedChoice == nil ? "\(Int(ceil(store.remaining)))s" : "Locked in!")
                    .font(.party(15, weight: .black)).foregroundStyle(.white).monospacedDigit().frame(minWidth: 35, alignment: .leading)
                    .accessibilityIdentifier("roundTimer")
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(store.remaining < 4 ? PartyTheme.yellow : PartyTheme.mint)
                            .frame(width: max(0, geometry.size.width * store.remaining / round.duration))
                    }
                }.frame(height: 6).accessibilityHidden(true)
                Text(store.selectedChoice == nil ? "Faster = more points" : "Waiting for the other explorers…")
                    .font(.party(10, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
        }.frame(height: 36)
    }
}
