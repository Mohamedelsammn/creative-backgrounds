import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/web_view_page.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const _url = 'https://4ktrendbackgrounds.com/page/terms';

  @override
  Widget build(BuildContext context) {
    return WebViewPage(title: context.l10n.termsOfService, url: _url);
  }
}
