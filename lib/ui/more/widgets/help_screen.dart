import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/widgets/common.dart';

// shortcut: placeholder until the real help page exists; replace the URL then.
final _helpUrl = Uri.parse('https://example.com');

/// The help page inside the app, under an AppBar titled Help.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _State();
}

class _State extends State<HelpScreen> {
  int _progress = 0;

  /// The native view paints blank while it starts and the route animates in.
  bool _shown = false;

  late final _controller = WebViewController()
    // No white flash in dark mode before the page paints: the screen shows.
    ..setBackgroundColor(Colors.transparent)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) => _update(() => _progress = progress),
        onPageFinished: (_) => _update(() {
          _progress = 100;
          _shown = true;
        }),
        // An error page is still a page: stop covering it.
        onWebResourceError: (_) => _update(() => _shown = true),
        onNavigationRequest: _guard,
      ),
    )
    ..loadRequest(_helpUrl);

  /// The page can call back after this screen closes.
  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  /// Only https pages on the help host open here. There is no address bar, so
  /// another site, plain http, mailto: or tel: stays closed, with a notice.
  // shortcut: a redirect to another host (e.g. www.) is blocked too; allow
  // that host here when the real help URL needs it.
  NavigationDecision _guard(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri != null && uri.scheme == 'https' && uri.host == _helpUrl.host) {
      return NavigationDecision.navigate;
    }
    // An embedded frame is not a link the user tapped: no notice for it.
    if (request.isMainFrame && mounted) {
      toast(context, 'This link cannot open in Help.');
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: Column(
        children: [
          // Fixed height, so the page does not jump when the bar goes away.
          SizedBox(
            height: 3,
            child: _progress < 100
                ? LinearProgressIndicator(value: _progress / 100)
                : null,
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _shown,
                    child: AnimatedOpacity(
                      opacity: _shown ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
