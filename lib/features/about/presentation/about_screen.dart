import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kozuchi/features/about/domain/about_info.dart';
import 'package:kozuchi/features/about/presentation/about_app_keys.dart';

/// 「アプリについて」画面。
///
/// アプリ名・バージョン、OSSライセンス、プライバシーポリシー、
/// 問い合わせ（メール）への導線を提供する。
/// 外部依存（package_info_plus / url_launcher）は用いない。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.info = kAboutInfo});

  final AboutInfo info;

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
                  onTap: () => _showUrlDialog(
                    context,
                    'プライバシーポリシー',
                    info.privacyPolicyUrl,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: AboutAppKeys.contactTile,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('問い合わせ'),
                  subtitle: Text(info.contactEmail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showUrlDialog(
                    context,
                    '問い合わせ',
                    info.contactEmail,
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
