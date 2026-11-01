import 'package:flutter_test/flutter_test.dart';
import 'package:aniscroll/app.dart';

void main() {
  testWidgets('AniScroll opens with its main navigation', (tester) async {
    await tester.pumpWidget(const AniScrollApp());

    // The branded splash screen transitions to the main shell after 1.5s.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
