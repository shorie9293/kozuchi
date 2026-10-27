import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kozuchi/features/about/domain/about_info.dart';
import 'package:kozuchi/features/about/domain/external_url_opener.dart';
import 'package:kozuchi/features/about/presentation/about_app_keys.dart';
import 'package:kozuchi/features/about/presentation/external_url_launcher.dart';

/// 「アプリについて」画面。
///
/// アプリ名・バージョン、OSSライセンス、プライバシーポリシー、
/// 問い合わせ（メール）への導線を提供する。プライバシーポリシーと
/// 問い合わせはタップで外部アプリ（ブラウザ・メール）へ渡し、
/// 開けなかった場合は従来のコピー導線（URL表示＋クリップボード）へ退避する。
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    super.key,
    this.info = kAboutInfo,
    this.urlOpener = launchExternalUrl,
  });

  final AboutInfo info;

  /// 外部URLを開く口（試練ではフェイクを注入し、実網を撃たない）。
  final ExternalUrlOpener urlOpener;

  void _copyToClipboard(BuildContext context, String label, String value) {
    SnackBar snackBar;
    try {
      Clipboard.setData(ClipboardData(text: value));
      snackBar = SnackBar(content: Text('$labelをコピーしました'));
    } catch (_) {
      snackBar = const SnackBar(content: Text('コピーできませんでした'));
    }
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// 外部アプリで開く。開けなければ（false・例外・URI不正）コピー導線へ退避する。
  Future<void> _openOrCopy(
    BuildContext context, {
    required Uri? uri,
    required String title,
    required String url,
  }) async {
    var opened = false;
    if (uri != null) {
      try {
        opened = await urlOpener(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (opened || !context.mounted) return;
    _showUrlDialog(context, title, url);
  }

  void _showUrlDialog(BuildContext context, String title, String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              url,
              key: AboutAppKeys.dialogUrlText,
              style: const TextStyle(color: Colors.blue),
            ),
            const SizedBox(height: 12),
            const Text('ブラウザで上記URLを開いてご確認ください。'),
          ],
        ),
        actions: [
          TextButton(
            key: AboutAppKeys.dialogCopyButton,
            onPressed: () => _copyToClipboard(dialogContext, title, url),
            child: const Text('URLをコピー'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: AboutAppKeys.screen,
      appBar: AppBar(title: const Text('アプリについて')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            info.appName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (info.tagline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(info.tagline, style: TextStyle(color: colorScheme.outline)),
          ],
          Text(
            'v${info.version}',
            key: AboutAppKeys.versionText,
            style: TextStyle(color: colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: AboutAppKeys.licenseTile,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('OSSライセンス'),
                  subtitle: const Text('本アプリが利用するOSSの一覧'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                      context: context,
                      applicationName: info.appName,
                      applicationVersion: info.version),
                ),
                const Divider(height: 1),
                ListTile(
                  key: AboutAppKeys.privacyTile,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('プライバシーポリシー'),
                  subtitle: const Text('URLの表示とコピー'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openOrCopy(
                    context,
                    uri: externalUri(info.privacyPolicyUrl),
                    title: 'プライバシーポリシー',
                    url: info.privacyPolicyUrl,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: AboutAppKeys.contactTile,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('問い合わせ'),
                  subtitle: Text(info.contactEmail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openOrCopy(
                    context,
                    uri: mailtoUri(info.contactEmail),
                    title: '問い合わせ',
                    url: info.contactEmail,
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
