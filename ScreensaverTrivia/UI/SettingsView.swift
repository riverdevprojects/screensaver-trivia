import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Your explorer") {
                    TextField("Name", text: $store.settings.name)
                        .textContentType(.nickname).autocorrectionDisabled()
                        .onChange(of: store.settings.name) { _, value in
                            if value.count > 16 { store.settings.name = String(value.prefix(16)) }
                        }.accessibilityIdentifier("playerName")
                    HStack(spacing: 12) {
                        ForEach(0..<PartyTheme.avatars.count, id: \.self) { avatar in
                            Button { store.settings.avatar = avatar } label: {
                                AvatarView(avatar: avatar, size: 40)
                                    .overlay(alignment: .bottomTrailing) {
                                        if store.settings.avatar == avatar {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(PartyTheme.ink, PartyTheme.mint)
                                        }
                                    }
                            }.buttonStyle(.plain).accessibilityLabel("Explorer avatar \(avatar + 1)")
                                .accessibilityAddTraits(store.settings.avatar == avatar ? .isSelected : [])
                        }
                    }.padding(.vertical, 4)
                }
                Section {
                    Picker("Collection", selection: $store.settings.collection) {
                        ForEach(Collection.allCases) { collection in
                            Text("\(collection.title) (\(store.catalog.count(in: collection)))").tag(collection)
                        }
                    }
                    Picker("Rounds", selection: $store.settings.roundCount) {
                        Text("5").tag(5)
                        Text("8").tag(8)
                    }.pickerStyle(.segmented)
                    Picker("Seconds per location", selection: $store.settings.duration) {
                        Text("10 seconds").tag(10.0)
                        Text("15 seconds").tag(15.0)
                        Text("20 seconds").tag(20.0)
                    }
                } header: { Text("Your next adventure") }
                footer: { Text("\(store.availableRounds) unique locations per game. Collections never repeat a place within a game. Party hosts choose these settings for everyone.") }
                Section {
                    Toggle("Haptic feedback", isOn: $store.settings.haptics)
                    NavigationLink("How to play") { InstructionsContent() }
                    NavigationLink("Footage & credits") { CreditsView() }
                }
                Section("On this iPhone") {
                    LabeledContent("Tours completed", value: "\(store.stats.gamesPlayed)")
                    LabeledContent("Places spotted", value: "\(store.stats.locationsGuessed)")
                    LabeledContent("Best score", value: store.stats.bestScore.formatted())
                    Text("Your name, settings and scores stay on this device. Nearby parties share your chosen name, avatar and game answers directly with the other players. No accounts, analytics or servers.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ready for takeoff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { store.saveSettings(); dismiss() }.accessibilityIdentifier("saveSettings")
            } }
        }.onDisappear { store.saveSettings() }
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            InstructionsContent().toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Let’s go") { dismiss() } }
            }
        }
    }
}

struct InstructionsContent: View {
    var body: some View {
        List {
            Section {
                instruction("1", "Watch the world", "A real location plays on screen. Take in the skyline, landscape and little clues.")
                instruction("2", "Pick a place", "Tap one of four options before time runs out. Your first answer is final.")
                instruction("3", "Beat the clock", "Correct answers earn up to 1,000 points. The score falls toward 100 as time passes. Wrong and late answers earn zero.")
                instruction("4", "Take the podium", "After everyone answers, see the place and the points. The most points at the end wins. Ties break by correct answers, then total correct-answer time.")
            }
            Section("Bring your travel buddies") {
                Text("On one iPhone, choose Party → Host a party. On the others, choose Party → Join a nearby party, then tap the host’s name. Up to 8 people can play, each on their own iPhone.")
                Text("Keep all devices on the same Wi-Fi network with Wi-Fi and Bluetooth enabled. Allow Local Network access, and keep the app open. There’s no internet or account requirement. The host starts and advances each round.")
                Text("During a party, all answers stay hidden until everyone locks in or the timer ends. The host measures response times when answers arrive, so a small amount of local network latency is included.")
            }
            Section("Solo layovers") {
                Text("Pause a solo round whenever you need to. Leaving the app also pauses solo play. Leaving an active party disconnects that device; if the host leaves, the party ends.")
            }
        }
        .font(.system(.body, design: .rounded)).navigationTitle("How to play").navigationBarTitleDisplayMode(.inline)
    }

    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.party(18)).foregroundStyle(PartyTheme.ink)
                .frame(width: 34, height: 34).background(PartyTheme.mint, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.party(18))
                Text(detail).font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
        }
    }
}

private struct CreditsView: View {
    @EnvironmentObject private var store: GameStore
    var body: some View {
        List {
            Section {
                Text("Real places, generously shared. Each clip is a 15-second, silent H.264 adaptation: scaled, cropped and sometimes looped. The clips and posters retain their source licenses. No Apple TV screensaver footage is used.")
                    .font(.footnote)
            }
            ForEach(store.catalog.locations) { location in
                Section(location.name) {
                    Text(location.sourceTitle).font(.system(.subheadline, design: .rounded)).fontWeight(.semibold)
                    Text(location.author).font(.caption).foregroundStyle(.secondary)
                    if let source = URL(string: location.sourceURL) { Link("Original source", destination: source) }
                    if let license = URL(string: location.licenseURL) { Link(location.license, destination: license) }
                }
            }
        }.navigationTitle("Footage & credits").navigationBarTitleDisplayMode(.inline)
    }
}
