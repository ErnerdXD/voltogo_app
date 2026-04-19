import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/charging_session_model.dart';

class EnergyChart extends StatelessWidget {
  final List<ChargingSessionModel> sessions;
  final bool showCO2;
  const EnergyChart({super.key, required this.sessions, this.showCO2 = false});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    // Sort sessions by date
    final sorted = [...sessions]..sort((a, b) => (a.checkedInAt ?? DateTime(0)).compareTo(b.checkedInAt ?? DateTime(0)));
    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      final value = showCO2 ? (sorted[i].co2SavedKg ?? 0) : (sorted[i].energyConsumedKwh ?? 0);
      spots.add(FlSpot(i.toDouble(), value));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 260,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    interval: 5,
                    getTitlesWidget: (value, meta) {
                      // Only show integer multiples of 5
                      if (value % 5 != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= sorted.length) return const SizedBox.shrink();
                    final date = sorted[idx].checkedInAt;
                    return Text(date != null ? '${date.month}/${date.day}' : '', style: const TextStyle(fontSize: 10));
                  }),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: 0,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: showCO2 ? Colors.green : Colors.blue,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
