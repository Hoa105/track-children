import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_models.dart';
import 'package:track_children/features/growth/growth_weight_stature_chart.dart';
import 'package:track_children/features/growth/weight_chart_view.dart';

void main() {
  test('stature range respects WHO domain', () {
    expect(growthStatureDisplayRange(80,5,45,110), (min:75.0,max:85.0));
    expect(growthStatureDisplayRange(46,5,45,110), (min:45.0,max:51.0));
  });
  testWidgets('same-day pairs use normalized stature and day-731 boundary', (tester) async {
    final birth=DateTime(2024,1,1);
    Future<WeightChartView> show(int days,bool length,GrowthMeasurementMethod method) async {
      final date=birth.add(Duration(days:days));
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:GrowthWeightStatureChart(
        dateOfBirth:birth,useLength:length,statureLabel:length?'chiều dài':'chiều cao',
        weights:[GrowthMeasurementDraft(value:10,measuredAt:date)],
        statures:[GrowthMeasurementDraft(value:80,measuredAt:date,method:method)],
      )))));
      return tester.widget<WeightChartView>(find.byType(WeightChartView));
    }
    var chart=await show(730,true,GrowthMeasurementMethod.standing);
    expect(chart.points.single.x,80.7);
    chart=await show(731,false,GrowthMeasurementMethod.recumbent);
    expect(chart.points.single.x,79.3);
    expect(chart.age,isFalse);
    chart=await show(100,true,GrowthMeasurementMethod.standing);
    expect(chart.points,isEmpty);
    expect(tester.takeException(),isNull);
  });
}
