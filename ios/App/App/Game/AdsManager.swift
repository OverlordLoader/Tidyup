import Foundation
import Combine
import UIKit
import GoogleMobileAds

/// Owns all ad behavior: rewarded ads (free boosters) and interstitials.
/// Every ad path checks `StoreManager.shared.removeAds` first — buying
/// "Remove Ads" disables ALL ads immediately. Ads fail gracefully offline:
/// nothing blocks gameplay, and loads retry in the background.
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    #if DEBUG
    // Google's official sample IDs — show test ads in debug builds.
    static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    // TODO(Henry): replace with real AdMob IDs from apps.admob.com before release.
    // Create one "Rewarded" and one "Interstitial" ad unit for the Tidy Up! app.
    static let rewardedAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/RRRRRRRRRR"
    static let interstitialAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII"
    #endif

    @Published private(set) var rewardedReady = false
    @Published private(set) var interstitialReady = false

    private var rewardedAd: GADRewardedAd?
    private var interstitialAd: GADInterstitialAd?
    private var pendingRewardCompletion: ((Bool) -> Void)?
    private var pendingInterstitialCompletion: (() -> Void)?
    private var rewardEarned = false

    private enum Keys {
        static let totalWins = "tidyup.ads.totalWins"
        static let winsSinceAd = "tidyup.ads.winsSinceAd"
    }

    private override init() { super.init() }

    /// Call once at app launch.
    func configure() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        loadRewarded()
        loadInterstitial()
    }

    // MARK: - Rewarded

    private func loadRewarded() {
        guard !StoreManager.shared.removeAds else { return }
        GADRewardedAd.load(withAdUnitID: Self.rewardedAdUnitID, request: GADRequest()) { [weak self] ad, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if let ad {
                    ad.fullScreenContentDelegate = self
                    self.rewardedAd = ad
                    self.rewardedReady = true
                } else {
                    self.rewardedReady = false
                    // Retry in the background; gameplay never waits on ads.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                        self?.loadRewarded()
                    }
                }
            }
        }
    }

    /// Shows a rewarded ad. `completion(true)` only if the user watched
    /// long enough to earn the reward. `completion(false)` on any failure
    /// (offline, no fill, dismissed early) — the caller just skips the reward.
    func showRewarded(completion: @escaping (Bool) -> Void) {
        guard !StoreManager.shared.removeAds,
              let ad = rewardedAd,
              let vc = topViewController() else {
            completion(false)
            loadRewarded()
            return
        }
        rewardEarned = false
        pendingRewardCompletion = completion
        rewardedReady = false
        ad.present(from: vc) { [weak self] in
            self?.rewardEarned = true
        }
    }

    // MARK: - Interstitial

    private func loadInterstitial() {
        guard !StoreManager.shared.removeAds else { return }
        GADInterstitialAd.load(withAdUnitID: Self.interstitialAdUnitID, request: GADRequest()) { [weak self] ad, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if let ad {
                    ad.fullScreenContentDelegate = self
                    self.interstitialAd = ad
                    self.interstitialReady = true
                } else {
                    self.interstitialReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                        self?.loadInterstitial()
                    }
                }
            }
        }
    }

    /// Call on every level win. The ad itself only shows when due:
    /// never for Remove-Ads owners, never during a new player's first
    /// 3 wins, and at most once every 3 wins after that.
    func recordLevelCompleted() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: Keys.totalWins) + 1, forKey: Keys.totalWins)
        d.set(d.integer(forKey: Keys.winsSinceAd) + 1, forKey: Keys.winsSinceAd)
    }

    /// Presents an interstitial if one is due, then always calls completion
    /// (immediately when no ad shows). Present it at a transition point
    /// (e.g. tapping Next/Levels on the win overlay), never mid-level.
    func showInterstitialIfDue(completion: @escaping () -> Void) {
        let d = UserDefaults.standard
        let total = d.integer(forKey: Keys.totalWins)
        let since = d.integer(forKey: Keys.winsSinceAd)
        guard !StoreManager.shared.removeAds,
              total >= 3, since >= 3,
              let ad = interstitialAd,
              let vc = topViewController() else {
            completion()
            return
        }
        d.set(0, forKey: Keys.winsSinceAd)
        pendingInterstitialCompletion = completion
        interstitialReady = false
        ad.present(from: vc)
    }

    // MARK: - Helpers

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let root = scene.keyWindow?.rootViewController {
                var top = root
                while let presented = top.presentedViewController { top = presented }
                return top
            }
        }
        return nil
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdsManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad as? GADRewardedAd != nil {
            rewardedAd = nil
            let completion = pendingRewardCompletion
            pendingRewardCompletion = nil
            let earned = rewardEarned
            rewardEarned = false
            completion?(earned)
            loadRewarded()
        } else if ad as? GADInterstitialAd != nil {
            interstitialAd = nil
            let completion = pendingInterstitialCompletion
            pendingInterstitialCompletion = nil
            completion?()
            loadInterstitial()
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad as? GADRewardedAd != nil {
            rewardedAd = nil
            pendingRewardCompletion?(false)
            pendingRewardCompletion = nil
            rewardEarned = false
            loadRewarded()
        } else if ad as? GADInterstitialAd != nil {
            interstitialAd = nil
            pendingInterstitialCompletion?()
            pendingInterstitialCompletion = nil
            loadInterstitial()
        }
    }
}
