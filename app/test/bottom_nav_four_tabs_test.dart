import 'package:creativebackground/core/widgets/floating_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The redesigned floating bottom nav must have exactly four destinations,
/// in this order: Explore, Categories, Favorites, Settings - matching the
/// approved UI and `AppRouter`'s four shell branches (branch index must line
/// up with this list's index for `MainShell._onTap` to route correctly).
void main() {
  testWidgets('defaultDestinations has exactly 4 entries: Explore, '
      'Categories, Favorites, Settings, in that order', (tester) async {
    expect(FloatingBottomNav.defaultDestinations, hasLength(4));
    expect(
      FloatingBottomNav.defaultDestinations.map((d) => d.label),
      ['Explore', 'Categories', 'Favorites', 'Settings'],
    );
  });

  testWidgets('renders 4 tappable icon slots', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingBottomNav(currentIndex: 0, onTap: (i) => tapped = i),
      ),
    ));
    await tester.pump();

    expect(find.byType(Icon), findsNWidgets(4));

    // Tap the last (Settings) icon directly.
    await tester.tap(find.byType(Icon).last);
    // The indicator springs to the target before committing navigation -
    // pumpAndSettle drains the whole spring animation rather than guessing
    // a fixed duration.
    await tester.pumpAndSettle();

    expect(tapped, 3);
  });
}
