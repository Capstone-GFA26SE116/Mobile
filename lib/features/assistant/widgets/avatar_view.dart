import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/constants/app_colors.dart';

enum AvatarEmotion { neutral, happy, thinking, sad }

/// Sends commands to the avatar page. Calls before the page reports `ready`
/// are dropped, so the screen never drives a half-loaded model.
class AvatarController {
  InAppWebViewController? _webView;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> setSpeaking(bool speaking) =>
      _run('avatar.setSpeaking($speaking)');

  Future<void> setEmotion(AvatarEmotion emotion) =>
      _run('avatar.setEmotion(${jsonEncode(emotion.name)})');

  Future<void> _run(String source) async {
    final webView = _webView;
    if (!_ready || webView == null) return;
    await webView.evaluateJavascript(source: source);
  }
}

/// VRM avatar rendered by three.js in a WebView. Serves assets/avatar/ over
/// http://localhost (InAppLocalhostServer) and listens on the `AvatarBridge` JS handler.
class AvatarView extends StatefulWidget {
  final AvatarController controller;
  final VoidCallback? onReady;

  /// Local asset server port. Two avatars on screen at once need two ports.
  final int port;

  static const int defaultPort = 8080;

  const AvatarView({
    super.key,
    required this.controller,
    this.onReady,
    this.port = defaultPort,
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  late final InAppLocalhostServer _server = InAppLocalhostServer(
    port: widget.port,
    documentRoot: 'assets/avatar',
  );

  bool _serverReady = false;
  bool _avatarReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      await _server.start();
      if (mounted) setState(() => _serverReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to start local asset server: $e');
    }
  }

  @override
  void dispose() {
    widget.controller
      .._ready = false
      .._webView = null;
    _server.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (!_serverReady) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri('http://localhost:${widget.port}/index.html'),
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            disableContextMenu: true,
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
            widget.controller._webView = controller;
            controller.addJavaScriptHandler(
              handlerName: 'AvatarBridge',
              callback: _onBridgeMessage,
            );
          },
          onConsoleMessage: (controller, message) {
            debugPrint('[avatar] ${message.messageLevel}: ${message.message}');
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame ?? true) {
              setState(() => _error = 'Could not load 3D character: ${error.description}');
            }
          },
        ),
        if (!_avatarReady)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
      ],
    );
  }

  void _onBridgeMessage(List<dynamic> args) {
    final payload = args.isNotEmpty && args.first is Map ? args.first as Map : const {};
    if (!mounted) return;
    switch (payload['type']) {
      case 'ready':
        widget.controller._ready = true;
        setState(() => _avatarReady = true);
        widget.onReady?.call();
      case 'error':
        setState(() => _error = payload['message']?.toString() ?? 'Unknown avatar error');
    }
  }
}
