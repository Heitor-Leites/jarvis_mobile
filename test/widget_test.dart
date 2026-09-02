import 'package:flutter_test/flutter_test.dart';

import 'package:jarvis_mobile/main.dart';

void main() {
  testWidgets('JARVIS inicia corretamente', (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());

    expect(find.text('JARVIS'), findsOneWidget);
    expect(find.text('SISTEMA ONLINE'), findsOneWidget);
    expect(find.text('ATIVAR JARVIS'), findsOneWidget);
  });
}