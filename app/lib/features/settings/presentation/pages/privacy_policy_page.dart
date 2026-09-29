import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/web_view_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _url = 'https://4ktrendbackgrounds.com/page/privacy-policy';

  @override
  Widget build(BuildContext context) {
    return WebViewPage(title: context.l10n.privacyPolicy, url: _url);
  }
}
