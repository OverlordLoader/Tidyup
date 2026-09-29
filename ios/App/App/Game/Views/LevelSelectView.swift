import SwiftUI

struct LevelSelectView: View {
    @ObservedObject private var progress = ProgressStore.shared
    @State private var showSettings = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2B1B4D), Color(hex: 0x17102E)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundColor(.yellow)
                        Text("\(progress.totalStars) / \(LevelGenerator.totalLevels * 3)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<LevelGenerator.totalLevels, id: \.self) { i in
                            levelCell(i)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Levels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    SoundManager.shared.play(.click)
                    Haptics.tap()
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .tint(Color(hex: 0xFFD60A))
    }

    @ViewBuilder
    private func levelCell(_ i: Int) -> some View {
        if i < progress.unlocked {
            NavigationLink(value: Route.game(i)) {
                VStack(spacing: 5) {
                    Text("\(i + 1)")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { s in
                            Image(systemName: s < progress.stars(for: i) ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.14)))
            }
        } else {
            Image(systemName: "lock.fill")
                .foregroundColor(.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
        }
    }
}
