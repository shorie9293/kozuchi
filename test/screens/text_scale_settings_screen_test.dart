import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/theme/text_scale_repository.dart';
import 'package:kozuchi/screens/text_scale_settings_screen.dart';

Widget _wrap(double scale, ValueChanged<double> onChanged) {
  return MaterialApp(home: TextScaleSettingsScreen(currentScale: scale, onScaleChanged: onChanged));
}

void main() {
  group('TextScaleSettingsScreen', () {
    testWidgets('3段階の選択肢が表示される', (tester) async {
      await tester.pumpWidget(_wrap(1.0, (_) {}));
      expect(find.byType(RadioListTile<double>), findsNWidgets(3));
      expect(find.text('小'), findsOneWidget);
      expect(find.text('通常'), findsOneWidget);
      expect(find.text('大'), findsOneWidget);
    });

    testWidgets('現在の選択がgroupValueに反映される（通常1.0）', (tester) async {
      await tester.pumpWidget(_wrap(1.0, (_) {}));
      final radio = tester.widget<RadioListTile<double>>(
        find.byKey(const Key('text_scale_1.0')),
      );
      expect(radio.groupValue, 1.0);
    });

    testWidgets('大（1.25）を選択するとonScaleChangedに1.25が渡る', (tester) async {
      double? changed;
      await tester.pumpWidget(_wrap(1.0, (v) => changed = v));
      await tester.tap(find.byKey(const Key('text_scale_1.25')));
      await tester.pump();
      expect(changed, TextScaleSetting.largeScale);
    });

    testWidgets('小（0.9）を選択するとonScaleChangedに0.9が渡る', (tester) async {
      double? changed;
      await tester.pumpWidget(_wrap(1.25, (v) => changed = v));
      await tester.tap(find.byKey(const Key('text_scale_0.9')));
      await tester.pump();
      expect(changed, TextScaleSetting.smallScale);
    });

    testWidgets('選択後は選択肢のgroupValueが更新される', (tester) async {
      double scale = 1.0;
      late StateSetter setter;
      await tester.pumpWidget(
        StatefulBuilder(builder: (context, setState) {
          setter = setState;
          return _wrap(scale, (v) => setter(() => scale = v));
        }),
      );
      await tester.tap(find.byKey(const Key('text_scale_1.25')));
      await tester.pump();
      expect(scale, 1.25);
      final radio = tester.widget<RadioListTile<double>>(
        find.byKey(const Key('text_scale_1.25')),
      );
      expect(radio.groupValue, 1.25);
    });
  });
}