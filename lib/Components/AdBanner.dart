import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef OnAdFailedCallback = void Function();

class AdManager {
  // ... (existing code)

  void loadRewardedInterstitialAd({OnAdFailedCallback? onAdFailed}) {
    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdLoaded = true;
          _setRewardedInterstitialFullScreenContentCallback();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isRewardedInterstitialAdLoaded = false;
          // **NEW:** Call the failure callback if provided
          if (onAdFailed != null) {
            onAdFailed();
          }
        },
      ),
    );
  }

  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  // Your actual ad unit IDs (replace with your own)
  final String _bannerAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/6300978111';

  final String _interstitialAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/1033173712';

  final String _rewardedInterstitialAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5354046340'
      : 'ca-app-pub-3940256099942544/5354046340'; // Your rewarded interstitial ID

  InterstitialAd? _interstitialAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isInterstitialAdLoaded = false;
  bool _isRewardedInterstitialAdLoaded = false;

  /// Loads an interstitial ad.
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _setInterstitialFullScreenContentCallback();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  /// Sets the fullscreen content callback for the interstitial ad.
  void _setInterstitialFullScreenContentCallback() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialAdLoaded = false;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isInterstitialAdLoaded = false;
        loadInterstitialAd();
      },
    );
  }

  /// Shows the loaded interstitial ad.
  void showInterstitialAd() {
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      loadInterstitialAd(); // Try to load it if not ready
    }
  }

  /// Sets the fullscreen content callback for the rewarded interstitial ad.
  void _setRewardedInterstitialFullScreenContentCallback() {
    _rewardedInterstitialAd?.fullScreenContentCallback =
        FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _isRewardedInterstitialAdLoaded = false;
            loadRewardedInterstitialAd();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _isRewardedInterstitialAdLoaded = false;
          },
        );
  }

  /// Shows the loaded rewarded interstitial ad and gives a reward.
  void showRewardedInterstitialAd(OnUserEarnedRewardCallback onReward) {
    if (_isRewardedInterstitialAdLoaded && _rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.show(onUserEarnedReward: onReward);
    } else {
      loadRewardedInterstitialAd();
    }
  }

  // A helper function to create a banner ad widget for a specific page.
  Widget bannerAdWidget() {
    return _BannerAdWidget(adUnitId: _bannerAdUnitId);
  }

  /// Disposes all loaded ads to prevent memory leaks.
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedInterstitialAd?.dispose();
  }
}

// A private widget for displaying banner ads.
class _BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  const _BannerAdWidget({required this.adUnitId});

  @override
  State<_BannerAdWidget> createState() => __BannerAdWidgetState();
}

class __BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: widget.adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );
    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
