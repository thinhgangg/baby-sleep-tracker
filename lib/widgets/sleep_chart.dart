import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/data_service.dart';

class SleepLineChart extends StatelessWidget {
  final List<SleepEntry> data;
  final String label;
  final double Function(SleepEntry) valueGetter;
  final Color lineColor;

  final double? safeMin;
  final double? safeMax;

  const SleepLineChart({
    super.key,
    required this.data,
    required this.label,
    required this.valueGetter,
    required this.lineColor,
    this.safeMin,
    this.safeMax,
  });

  ({double min, double max}) _getDefaultYAxisRange() {
    if (label.contains("Baby Temp")) {
      return (min: 35.0, max: 39.0);
    } else if (label.contains("Room Temp")) {
      return (min: 18.0, max: 34.0);
    } else if (label.contains("Humidity")) {
      return (min: 30.0, max: 80.0);
    }
    return (min: 0.0, max: 100.0);
  }

  ({double min, double max, bool hasOutlier}) _calculateSmartYAxisRange() {
    final values = data.map(valueGetter).where((v) => v > 0).toList();
    if (values.isEmpty) {
      final defaultRange = _getDefaultYAxisRange();
      return (min: defaultRange.min, max: defaultRange.max, hasOutlier: false);
    }

    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final defaultRange = _getDefaultYAxisRange();

    final hasOutlier =
        minVal < defaultRange.min - 5 || maxVal > defaultRange.max + 5;

    if (!hasOutlier) {
      return (min: defaultRange.min, max: defaultRange.max, hasOutlier: false);
    }

    final padding = (maxVal - minVal) * 0.15;
    return (
      min: (minVal - padding).clamp(0, double.infinity),
      max: maxVal + padding,
      hasOutlier: true,
    );
  }

  bool _isOutlier(double value) {
    final defaultRange = _getDefaultYAxisRange();
    return value < defaultRange.min - 2 || value > defaultRange.max + 2;
  }

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) {
      final index = e.key.toDouble();
      final value = valueGetter(e.value);
      return FlSpot(index, value);
    }).toList();

    if (spots.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              "Chưa có dữ liệu",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    final yRange = _calculateSmartYAxisRange();

    return Column(
      children: [
        if (yRange.hasOutlier)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Phát hiện giá trị bất thường! Có thể cảm biến đang lỗi.",
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: yRange.min,
              maxY: yRange.max,

              titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: _calculateInterval(yRange.min, yRange.max),
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: data.length > 10
                        ? (data.length / 5).ceilToDouble()
                        : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox();
                      }

                      if (data.length > 10 && index % (data.length ~/ 5) != 0) {
                        return const SizedBox();
                      }

                      final timestamp = data[index].timestamp;
                      final time = DateTime.parse(timestamp);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.grey[300]!, width: 1),
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                  right: BorderSide.none,
                  top: BorderSide.none,
                ),
              ),

              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateInterval(yRange.min, yRange.max),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),

              extraLinesData: yRange.hasOutlier
                  ? null
                  : ExtraLinesData(horizontalLines: _buildSafetyLines()),

              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  barWidth: 3,
                  color: lineColor,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) {
                      if (_isOutlier(spot.y)) return true;
                      return data.length <= 20;
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      final isOutlierPoint = _isOutlier(spot.y);
                      return FlDotCirclePainter(
                        radius: isOutlierPoint ? 6 : 4,
                        color: isOutlierPoint ? Colors.orange : lineColor,
                        strokeWidth: isOutlierPoint ? 3 : 2,
                        strokeColor: isOutlierPoint
                            ? Colors.white
                            : Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lineColor.withValues(alpha: 0.3),
                        lineColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ],

              // TOOLTIP
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tooltipMargin: 8,
                  getTooltipColor: (spot) => Colors.black87,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      if (index < 0 || index >= data.length) return null;

                      final entry = data[index];
                      final time = DateTime.parse(entry.timestamp);
                      final value = spot.y;

                      String unit = '';
                      if (label.contains("Temp")) unit = '°C';
                      if (label.contains("Humidity")) unit = '%';

                      final isOutlierPoint = _isOutlier(value);
                      final warning = isOutlierPoint
                          ? '\n⚠️ Giá trị bất thường'
                          : '';

                      return LineTooltipItem(
                        '${value.toStringAsFixed(1)}$unit\n${time.hour}:${time.minute.toString().padLeft(2, '0')}$warning',
                        TextStyle(
                          color: isOutlierPoint ? Colors.orange : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    final spot = barData.spots[index];
                    final isOutlierPoint = _isOutlier(spot.y);

                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: (isOutlierPoint ? Colors.orange : lineColor)
                            .withValues(alpha: 0.5),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: isOutlierPoint
                                ? Colors.orange
                                : lineColor,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // tính toán khoảng cách giữa các vạch trên trục Y
  double _calculateInterval(double min, double max) {
    final range = max - min;
    if (range <= 5) return 1;
    if (range <= 20) return 2;
    if (range <= 50) return 10;
    return 20;
  }

  // các đường ngang biểu thị vùng an toàn
  List<HorizontalLine> _buildSafetyLines() {
    final lines = <HorizontalLine>[];
    if (safeMin != null) {
      lines.add(
        HorizontalLine(
          y: safeMin!,
          color: Colors.green.withValues(alpha: 0.4),
          strokeWidth: 1.5,
          dashArray: [8, 4],
        ),
      );
    }
    if (safeMax != null) {
      lines.add(
        HorizontalLine(
          y: safeMax!,
          color: Colors.green.withValues(alpha: 0.4),
          strokeWidth: 1.5,
          dashArray: [8, 4],
        ),
      );
    }
    return lines;
  }
}
