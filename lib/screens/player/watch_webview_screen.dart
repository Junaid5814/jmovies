import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

/// Fullscreen in-app WebView player.
///
/// Points at a hosted player PAGE (see [WebviewPlayerUrls] in
/// api_constants.dart) served by YOUR OWN backend — not a third-party
/// embed/aggregator site. The backend page is expected to resolve the
/// title server-side (using [tmdbId], and [seasonNumber]/[episodeNumber]
/// for TV) and render its own <video>/player UI; this screen just hosts
/// that page fullscreen with landscape lock, a loading spinner, and
/// popup/ad-window blocking.
///
/// The player base URL is read from WEBVIEW_PLAYER_BASE_URL in .env —
/// point it at your backend's player route. See WebviewPlayerUrls for the
/// exact path shape built for movies vs. TV episodes.
class WatchWebviewScreen extends StatefulWidget {
  final int tmdbId;
  final String title;
  final bool isTv;
  final int? seasonNumber;
  final int? episodeNumber;

  const WatchWebviewScreen({
    super.key,
    required this.tmdbId,
    required this.title,
    required this.isTv,
    this.seasonNumber,
    this.episodeNumber,
  }) : assert(
          !isTv || (seasonNumber != null && episodeNumber != null),
          'seasonNumber and episodeNumber are required when isTv is true',
        );

  /// Resolves the player URL for this screen's content, given the
  /// configured backend base URL (from .env).
  String _resolveStreamUrl() {
    final envBaseUrl = dotenv.env['WEBVIEW_PLAYER_BASE_URL'];
    if (isTv) {
      return WebviewPlayerUrls.forEpisode(
        envBaseUrl,
        tmdbId,
        seasonNumber!,
        episodeNumber!,
      );
    }
    return WebviewPlayerUrls.forMovie(envBaseUrl, tmdbId);
  }

  @override
  State<WatchWebviewScreen> createState() => _WatchWebviewScreenState();
}

class _WatchWebviewScreenState extends State<WatchWebviewScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;
  late final String _streamUrl = widget._resolveStreamUrl();

  /// Host of the URL we were asked to load. Only navigations staying on
  /// this host are allowed inline; everything else (ad redirects, popup
  /// tabs, third-party windows) is blocked rather than opened.
  late final String? _allowedHost = Uri.tryParse(_streamUrl)?.host;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_controller != null && await _controller!.canGoBack()) {
      _controller!.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop()) {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              if (_errorMessage != null)
                _ErrorView(
                  message: _errorMessage!,
                  onRetry: () {
                    setState(() {
                      _errorMessage = null;
                      _isLoading = true;
                    });
                    _controller?.reload();
                  },
                )
              else
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_streamUrl)),
                  initialSettings: InAppWebViewSettings(
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    javaScriptEnabled: true,
                    // Block the WebView from ever opening a second window —
                    // this is what stops most ad/popup redirect chains.
                    javaScriptCanOpenWindowsAutomatically: false,
                    supportMultipleWindows: false,
                    useOnDownloadStart: true,
                    transparentBackground: true,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() => _progress = progress / 100);
                  },
                  onLoadStop: (controller, url) {
                    setState(() => _isLoading = false);
                  },
                  onReceivedError: (controller, request, error) {
                    // Only treat it as fatal if it's the main page failing,
                    // not a blocked ad/sub-resource.
                    if (request.isForMainFrame ?? false) {
                      setState(() {
                        _isLoading = false;
                        _errorMessage = 'Could not load the player.\n${error.description}';
                      });
                    }
                  },
                  // Blocks popup/ad windows: returning false here refuses
                  // to create the new window the page tried to open.
                  onCreateWindow: (controller, createWindowAction) async {
                    return false;
                  },
                  // Gatekeeps every navigation (including redirects) that
                  // happens inside the WebView itself.
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri == null) return NavigationActionPolicy.CANCEL;

                    // Always allow the very first load of our own player URL.
                    if (uri.toString() == _streamUrl) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    // Allow same-host navigation (the player page's own
                    // internal routes/asset requests/quality switches).
                    if (_allowedHost != null && uri.host == _allowedHost) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    // Anything else — ad redirects, affiliate links,
                    // "open in new tab" popups posing as navigation —
                    // gets silently blocked instead of hijacking the screen.
                    return NavigationActionPolicy.CANCEL;
                  },
                ),
              if (_isLoading && _errorMessage == null)
                Container(
                  color: AppColors.pureBlack,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          color: AppColors.crimson,
                          value: _progress > 0 && _progress < 1 ? _progress : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text('Loading stream…',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () async {
                      if (await _onWillPop()) {
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pureBlack,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.crimson, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
