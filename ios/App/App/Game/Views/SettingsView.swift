import SwiftUI

/// Store screen: Remove Ads, Magic Pour booster pack, Restore Purchases.
/// Every row does something real — no dead UI (Apple review rule).
struct SettingsView: View {
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x17102E).ignoresSafeArea()
                List {
                    Section {
                        removeAdsRow
                        boosterRow
                    } header: {
                        Text("Tidy Up! Plus").foregroundColor(.white.opacity(0.6))
                    }
                    Section {
                        restoreRow
                    }
                }
                .scrollContentBackground(.hidden)
                if store.purchaseInProgress {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        SoundManager.shared.play(.click)
                        dismiss()
                    }
                    .foregroundColor(Color(hex: 0xFFD60A))
                }
            }
            .task { await store.requestProducts() }
            .alert("Store", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.lastError ?? "")
            }
        }
        .tint(Color(hex: 0xFFD60A))
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )
    }

    // MARK: - Rows

    private var removeAdsRow: some View {
        Button {
            guard !store.removeAds,
                  let product = store.removeAdsProduct else { return }
            SoundManager.shared.play(.click)
            Haptics.tap()
            Task { await store.purchase(product) }
        } label: {
            HStack {
                Image(systemName: "nosign")
                    .font(.title2)
                    .foregroundColor(Color(hex: 0xFFD60A))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove Ads").font(.headline)
                    Text("No more ads, ever. One-time purchase.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if store.removeAds {
                    Text("Owned")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                } else if let product = store.removeAdsProduct {
                    Text(product.displayPrice)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: 0xFF8A00))
                } else {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(store.removeAds)
    }

    private var boosterRow: some View {
        Button {
            guard let product = store.magicPourPackProduct else { return }
            SoundManager.shared.play(.click)
            Haptics.tap()
            Task { await store.purchase(product) }
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(Color(hex: 0x7DD3FC))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Magic Pour Pack").font(.headline)
                    Text("5 boosters — auto-completes a tube. You own \(store.magicPourCount).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let product = store.magicPourPackProduct {
                    Text(product.displayPrice)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: 0xFF8A00))
                } else {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var restoreRow: some View {
        Button {
            SoundManager.shared.play(.click)
            Haptics.tap()
            Task { await store.restorePurchases() }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore Purchases").font(.headline)
                    Text("Already bought Remove Ads? Tap to restore it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
