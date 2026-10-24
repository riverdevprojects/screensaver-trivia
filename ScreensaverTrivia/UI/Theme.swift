import SwiftUI

enum PartyTheme {
    static let ink = Color(red: 0.24, green: 0.09, blue: 0.43)
    static let violet = Color(red: 0.47, green: 0.23, blue: 0.91)
    static let pink = Color(red: 0.93, green: 0.25, blue: 0.69)
    static let mint = Color(red: 0.53, green: 0.96, blue: 0.77)
    static let yellow = Color(red: 1, green: 0.85, blue: 0.28)
    static let playerColors: [Color] = [.pink, .cyan, .orange, .purple, .green, .indigo, .red, .teal]
    static let avatars = ["🧑‍🚀", "🧑‍✈️", "🧑‍🎤", "🧙", "🥷", "🧑‍🔬", "🧑‍🚒", "🤖"]
}

extension Font {
    static func party(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct PartyBackground: View {
    var gold = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: gold
                    ? [Color(red: 0.98, green: 0.65, blue: 0.16), Color(red: 1, green: 0.88, blue: 0.40)]
                    : [PartyTheme.violet, PartyTheme.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.06)).frame(width: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.87, y: geo.size.height * 0.12)
                Circle().stroke(.white.opacity(0.07), lineWidth: 45).frame(width: geo.size.width * 0.65)
                    .position(x: geo.size.width * 0.65, y: geo.size.height * 1.2)
                ForEach(0..<18, id: \.self) { index in
                    Capsule().fill(.white.opacity(index.isMultiple(of: 2) ? 0.13 : 0.07))
                        .frame(width: index.isMultiple(of: 3) ? 5 : 3, height: 12)
                        .rotationEffect(.degrees(Double(index * 37)))
                        .position(x: geo.size.width * CGFloat((index * 47 + 9) % 100) / 100,
                                  y: geo.size.height * CGFloat((index * 31 + 7) % 100) / 100)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PartyButtonStyle: ButtonStyle {
    var color: Color = .white
    var foreground: Color = PartyTheme.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.party(18))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: PartyTheme.ink.opacity(0.23), radius: 0, x: 0, y: configuration.isPressed ? 1 : 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CircleButton: View {
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white).frame(width: 44, height: 44)
                .background(.white.opacity(0.16), in: Circle())
        }
        .accessibilityLabel(label)
    }
}

struct AvatarView: View {
    let avatar: Int
    var size: CGFloat = 44
    var body: some View {
        Text(PartyTheme.avatars[safe: avatar] ?? PartyTheme.avatars[0])
            .font(.system(size: size * 0.64)).frame(width: size, height: size)
            .background(PartyTheme.playerColors[safe: avatar] ?? .purple, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .accessibilityHidden(true)
    }
}

struct StatPill: View {
    let symbol: String
    let text: String
    var body: some View {
        Label(text, systemImage: symbol).font(.party(12))
            .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white.opacity(0.14), in: Capsule())
    }
}

struct TravelGlobe: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false
    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width * 0.75, geometry.size.height * 0.94)
            ZStack {
                Ellipse().fill(PartyTheme.ink.opacity(0.18))
                    .frame(width: diameter * 0.72, height: 18).offset(y: diameter * 0.48)
                ZStack {
                    Circle().fill(LinearGradient(colors: [.cyan, Color(red: 0.12, green: 0.43, blue: 0.86)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    GlobeLand().fill(LinearGradient(colors: [PartyTheme.mint, Color(red: 0.24, green: 0.77, blue: 0.54)],
                                                    startPoint: .top, endPoint: .bottom))
                    Circle().stroke(.white.opacity(0.3), lineWidth: 2).padding(diameter * 0.08)
                    Ellipse().stroke(.white.opacity(0.18), lineWidth: 1.5).frame(width: diameter * 0.45)
                    Ellipse().stroke(.white.opacity(0.18), lineWidth: 1.5).frame(height: diameter * 0.34)
                    Circle().fill(.white.opacity(0.2)).frame(width: diameter * 0.13).offset(x: -diameter * 0.25, y: -diameter * 0.29)
                    Image(systemName: "mappin.circle.fill").symbolRenderingMode(.palette)
                        .foregroundStyle(PartyTheme.pink, .white).font(.system(size: diameter * 0.21))
                        .rotationEffect(.degrees(-12)).offset(x: diameter * 0.09, y: -diameter * 0.17)
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 4))
                .rotationEffect(.degrees(-12))
                .shadow(color: PartyTheme.ink.opacity(0.25), radius: 0, x: 7, y: 12)
                .offset(y: float && !reduceMotion ? -5 : 3)
                Image(systemName: "airplane").font(.system(size: diameter * 0.23, weight: .bold))
                    .foregroundStyle(.white).rotationEffect(.degrees(-25))
                    .shadow(color: PartyTheme.ink.opacity(0.2), radius: 0, x: 3, y: 4)
                    .offset(x: diameter * 0.44, y: -diameter * 0.25)
                Text("LET’S GET LOST").font(.party(max(10, diameter * 0.055)))
                    .foregroundStyle(PartyTheme.ink).padding(.horizontal, 15).padding(.vertical, 10)
                    .background(PartyTheme.yellow, in: RoundedRectangle(cornerRadius: 10))
                    .rotationEffect(.degrees(-8)).offset(x: -diameter * 0.25, y: diameter * 0.35)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { float = true } }
        .accessibilityHidden(true)
    }
}

private struct GlobeLand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let polygons: [[CGPoint]] = [
            [.init(x: 0.04, y: 0.22), .init(x: 0.30, y: 0.13), .init(x: 0.45, y: 0.24), .init(x: 0.36, y: 0.39), .init(x: 0.31, y: 0.56), .init(x: 0.18, y: 0.43), .init(x: 0.08, y: 0.45)],
            [.init(x: 0.34, y: 0.57), .init(x: 0.52, y: 0.61), .init(x: 0.56, y: 0.72), .init(x: 0.43, y: 0.96), .init(x: 0.35, y: 0.81)],
            [.init(x: 0.56, y: 0.20), .init(x: 0.70, y: 0.13), .init(x: 0.99, y: 0.23), .init(x: 0.88, y: 0.49), .init(x: 0.73, y: 0.44), .init(x: 0.65, y: 0.57), .init(x: 0.61, y: 0.41)],
            [.init(x: 0.67, y: 0.48), .init(x: 0.83, y: 0.54), .init(x: 0.80, y: 0.74), .init(x: 0.72, y: 0.82), .init(x: 0.60, y: 0.63)]
        ]
        for polygon in polygons {
            path.addLines(polygon.map { CGPoint(x: $0.x * rect.width, y: $0.y * rect.height) })
            path.closeSubpath()
        }
        return path
    }
}
