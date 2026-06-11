import 'package:desktop_webview_window/desktop_webview_window.dart';

/// Runs the title-bar widget of a `desktop_webview_window` auth window.
///
/// `flutter_web_auth_2` opens its embedded OAuth webview on Linux/Windows
/// by re-launching this executable with `web_view_title_bar <id>` args and
/// embedding that engine as the window's title bar. Without this hook the
/// secondary engine boots the full admin console instead, and the auth
/// window never appears.
bool runDesktopWebViewTitleBar(List<String> args) =>
    runWebViewTitleBarWidget(args);
