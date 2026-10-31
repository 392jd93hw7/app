import 'package:flutter_test/flutter_test.dart';
import 'package:aniscroll/app.dart';

void main() {
  testWidgets('AniScroll opens with its main navigation', (tester) async {
    await tester.pumpWidget(const AniScrollApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
