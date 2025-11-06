import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/data_service.dart';

class SleepLineChart extends StatelessWidget {
  final List<SleepEntry> data;
  final String label;
  final double Function(SleepEntry) valueGetter;
  final Color lineColor;

  const SleepLineChart({
    super.key,
    required this.data,
    required this.label,
    required this.valueGetter,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) {
      final index = e.key.toDouble();
      final value = valueGetter(e.value);
      return FlSpot(index, value);
    }).toList();

    if (spots.isEmpty) {
      return const Center(child: Text("Không có dữ liệu"));
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: true),
          gridData: const FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: lineColor,
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
