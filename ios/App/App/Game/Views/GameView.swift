import SwiftUI
import SpriteKit

struct GameView: View {
    let levelIndex: Int
    let onNext: (() -> Void)?

    @StateObject private var engine: GameEngine
    @State private var scene: BoardScene?
    @State private var soundOn: Bool
    @State private var showSettings = false
    @State private var showMagicAdOffer = false
    @State private var showRewindAdOffer = false
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    init(levelIndex: Int, onNext: (() -> Void)? = nil) {
        self.levelIndex = levelIndex
        self.onNext = onNext
        _engine = StateObject(wrappedValue: GameEngine(levelIndex: levelIndex))
        _soundOn = State(initialValue: ProgressStore.shared.soundEnabled)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: 0x17102E).ignoresSafeArea()
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }
                VStack(spacing: 0) {
                    hud
                    Spacer(minLength: 0)
                    bottomBar
                }
                if engine.showWinOverlay {
                    winOverlay
                }
            }
            .onAppear {
                SoundManager.shared.enabled = soundOn
                if scene == nil {
                    let s = BoardScene(size: geo.size, engine: engine)
                    s.scaleMode = .resizeFill
                    engine.onEvent = { [weak s] event in s?.handle(event) }
                    scene = s
                }
            }
            .onChange(of: engine.won) { _, won in
                if won { AdsManager.shared.recordLevelCompleted() }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("Out of Magic Pours", isPresented: $showMagicAdOffer) {
                Button("Watch Ad for Free") {
                    AdsManager.shared.showRewarded { earned in
                        if earned { engine.magicPour() }
                    }
                }
                Button("Get More") { showSettings = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Watch a short ad for a free Magic Pour, or grab a 5-pack in Settings.")
            }
            .alert("Second Chance", isPresented: $showRewindAdOffer) {
                Button("Watch Ad") {
                    AdsManager.shared.showRewarded { earned in
                        if earned { engine.undo(count: 3) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Watch a short ad to undo your last 3 moves at once.")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - HUD

    private var hud: some View {
        HStack {
            Button {
                SoundManager.shared.play(.click)
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Level \(engine.levelNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Moves \(engine.moves) · Par \(engine.par)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button {
                soundOn.toggle()
                ProgressStore.shared.soundEnabled = soundOn
                SoundManager.shared.enabled = soundOn
                if soundOn { SoundManager.shared.play(.click) }
                Haptics.tap()
            } label: {
                Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Bottom controls

    private var bottomBar: some View {
        HStack(spacing: 12) {
            controlButton(icon: "arrow.uturn.backward", label: "Undo",
                          disabled: !engine.canUndo) { engine.undo() }
            magicButton
            controlButton(icon: "arrow.counterclockwise.circle", label: "Rewind",
                          disabled: engine.busy || engine.won) { showRewindAdOffer = true }
            controlButton(icon: "arrow.counterclockwise", label: "Restart",
                          disabled: engine.busy || engine.won) { engine.restart() }
        }
        .padding(.bottom, 30)
    }

    /// Magic Pour booster: uses an owned booster, or offers a rewarded ad.
    private var magicButton: some View {
        let disabled = engine.busy || engine.won
        return Button {
            SoundManager.shared.play(.click)
            Haptics.tap()
            if store.consumeBooster() {
                engine.magicPour()
            } else {
                showMagicAdOffer = true
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: "wand.and.stars").font(.title2.bold())
                    Text("Magic").font(.caption.bold())
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 64)
                .background(Color.white.opacity(disabled ? 0.06 : 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .opacity(disabled ? 0.45 : 1)
                if store.magicPourCount > 0 {
                    Text("\(store.magicPourCount)")
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: 0x2B1B4D))
                        .padding(6)
                        .background(Color(hex: 0xFFD60A))
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .disabled(disabled)
    }

    private func controlButton(icon: String, label: String, disabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title2.bold())
                Text(label).font(.caption.bold())
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 64)
            .background(Color.white.opacity(disabled ? 0.06 : 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .opacity(disabled ? 0.45 : 1)
        }
        .disabled(disabled)
    }

    // MARK: - Win overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Level Complete!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < engine.lastStars ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                    }
                }
                Text("Moves: \(engine.moves) · Par: \(engine.par)")
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 12) {
                    Button("Replay") { engine.restart() }
                        .buttonStyle(WinButtonStyle())
                    if onNext != nil {
                        Button("Next") {
                            SoundManager.shared.play(.click)
                            AdsManager.shared.showInterstitialIfDue { onNext?() }
                        }
                        .buttonStyle(WinButtonStyle(primary: true))
                    }
                    Button("Levels") {
                        SoundManager.shared.play(.click)
                        AdsManager.shared.showInterstitialIfDue { dismiss() }
                    }
                    .buttonStyle(WinButtonStyle())
                }
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x2B1B4D)))
            .padding(.horizontal, 40)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

struct WinButtonStyle: ButtonStyle {
    var primary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(primary ? Color(hex: 0xFF8A00) : Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
