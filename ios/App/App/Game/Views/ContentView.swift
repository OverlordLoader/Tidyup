import SwiftUI

enum Route: Hashable {
    case levels
    case game(Int)
}

struct ContentView: View {
    @State private var path: [Route] = []
    @ObservedObject private var progress = ProgressStore.shared
    @State private var showHowTo = false
    @State private var soundOn = ProgressStore.shared.soundEnabled

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x2B1B4D), Color(hex: 0x17102E)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    TitleTubesView()
                    Text("Tidy Up!")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Sort the rainbow. Clear your mind.")
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    Button {
                        SoundManager.shared.play(.click)
                        Haptics.tap()
                        path.append(.levels)
                    } label: {
                        Text("Play")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: 0x2B1B4D))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: 0xFFD60A))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal, 40)
                    HStack(spacing: 28) {
                        Button("How to play") {
                            SoundManager.shared.play(.click)
                            showHowTo = true
                        }
                        .foregroundColor(.white.opacity(0.85))
                        Button {
                            toggleSound()
                        } label: {
                            Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("\(progress.totalStars) stars collected")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .levels:
                    LevelSelectView()
                case .game(let i):
                    GameView(levelIndex: i,
                             onNext: i + 1 < LevelGenerator.totalLevels
                                ? { path.append(.game(i + 1)) } : nil)
                }
            }
            .sheet(isPresented: $showHowTo) { howToSheet }
        }
        .tint(Color(hex: 0xFFD60A))
        .onAppear {
            soundOn = ProgressStore.shared.soundEnabled
            SoundManager.shared.enabled = soundOn
        }
    }

    private func toggleSound() {
        soundOn.toggle()
        ProgressStore.shared.soundEnabled = soundOn
        SoundManager.shared.enabled = soundOn
        if soundOn { SoundManager.shared.play(.click) }
        Haptics.tap()
    }

    private var howToSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                howToRow(number: "1",
                         title: "Tap a tube, then tap another to pour",
                         detail: "The top color flows out in a stream. Watch it land!")
                howToRow(number: "2",
                         title: "Match colors or use an empty tube",
                         detail: "Liquid only pours onto the same color — or into an empty tube.")
                howToRow(number: "3",
                         title: "One color per tube wins",
                         detail: "Fill every tube with a single color to tidy the level. No timers, no failing — undo anytime.")
                Spacer()
            }
            .padding()
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showHowTo = false }
                }
            }
        }
    }

    private func howToRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.title2.bold())
                .foregroundColor(Color(hex: 0x2B1B4D))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xFFD60A))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

/// Decorative mini tubes for the title screen.
struct TitleTubesView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            miniTube(colors: [0, 1, 2, 3])
            miniTube(colors: [4, 5, 6, 7]).offset(y: -12)
            miniTube(colors: [8, 9, 0, 1])
        }
    }

    private func miniTube(colors: [Int]) -> some View {
        VStack(spacing: 3) {
            ForEach(colors.reversed(), id: \.self) { c in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Palette.color(id: c).swiftUIColor)
                    .frame(width: 44, height: 22)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.5), lineWidth: 4)
        )
    }
}
