import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// =======================
/// MODEL
/// =======================
class WeatherData {
  final DateTime timeStamp;
  final double atmPressure;
  final double currentTemperature;
  final double currentHumidity;
  final double windSpeed;
  final double rainfallHourly;

  WeatherData({
    required this.timeStamp,
    required this.atmPressure,
    required this.currentTemperature,
    required this.currentHumidity,
    required this.windSpeed,
    required this.rainfallHourly,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      timeStamp: DateTime.parse(json['TimeStamp']),
      atmPressure: (json['AtmPressure'] ?? 0).toDouble(),
      currentTemperature: (json['CurrentTemperature'] ?? 0).toDouble(),
      currentHumidity: (json['CurrentHumidity'] ?? 0).toDouble(),
      windSpeed: (json['WindSpeed'] ?? 0).toDouble(),
      rainfallHourly: (json['RainfallHourly'] ?? 0).toDouble(),
    );
  }
}

/// =======================
/// PARAMETERS
/// =======================
enum WeatherParameter {
  temperature,
  humidity,
  pressure,
  windSpeed,
  rainfall,
}

String parameterLabel(WeatherParameter p) {
  switch (p) {
    case WeatherParameter.temperature:
      return 'Temperature (°C)';
    case WeatherParameter.humidity:
      return 'Humidity (%)';
    case WeatherParameter.pressure:
      return 'Pressure (hPa)';
    case WeatherParameter.windSpeed:
      return 'Wind Speed (m/s)';
    case WeatherParameter.rainfall:
      return 'Rainfall (mm)';
  }
}

double getParameterValue(WeatherData d, WeatherParameter p) {
  switch (p) {
    case WeatherParameter.temperature:
      return d.currentTemperature;
    case WeatherParameter.humidity:
      return d.currentHumidity;
    case WeatherParameter.pressure:
      return d.atmPressure;
    case WeatherParameter.windSpeed:
      return d.windSpeed;
    case WeatherParameter.rainfall:
      return d.rainfallHourly;
  }
}

/// =======================
/// API BUILDER
/// =======================
String buildApiUrl({
  required int deviceId,
  required String startDate,
  required String endDate,
}) {
  if (deviceId == 1) {
    return 'https://d3g5fo66jwc4iw.cloudfront.net/campusdata'
        '?deviceid=1&startdate=$startDate&enddate=$endDate';
  } else {
    return 'https://d3dj66m23j48gu.cloudfront.net/campusdata'
        '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
  }
}

/// =======================
/// PAGE
/// =======================
class SensorComparisonPage extends StatefulWidget {
  const SensorComparisonPage({Key? key}) : super(key: key);

  @override
  State<SensorComparisonPage> createState() => _SensorComparisonPageState();
}

class _SensorComparisonPageState extends State<SensorComparisonPage> {
  final TextEditingController deviceAController =
      TextEditingController(text: '1');
  final TextEditingController deviceBController =
      TextEditingController(text: '2');

  DateTime startDate = DateTime(2026, 1, 29);
  DateTime endDate = DateTime(2026, 1, 29);

  WeatherParameter selectedParameter = WeatherParameter.temperature;

  List<WeatherData> dataA = [];
  List<WeatherData> dataB = [];

  bool loading = false;
  String? error;

  Future<void> pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> fetchComparisonData() async {
    final int? deviceA = int.tryParse(deviceAController.text);
    final int? deviceB = int.tryParse(deviceBController.text);

    if (deviceA == null || deviceB == null) {
      setState(() => error = 'Please enter valid device IDs');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final start = DateFormat('dd-MM-yyyy').format(startDate);
      final end = DateFormat('dd-MM-yyyy').format(endDate);

      final urlA = buildApiUrl(
        deviceId: deviceA,
        startDate: start,
        endDate: end,
      );

      final urlB = buildApiUrl(
        deviceId: deviceB,
        startDate: start,
        endDate: end,
      );

      final resA = await http.get(Uri.parse(urlA));
      final resB = await http.get(Uri.parse(urlB));

      if (resA.statusCode != 200 || resB.statusCode != 200) {
        throw Exception('Failed to load sensor data');
      }

      final itemsA = json.decode(resA.body)['items'] as List;
      final itemsB = json.decode(resB.body)['items'] as List;

      setState(() {
        dataA = itemsA.map((e) => WeatherData.fromJson(e)).toList();
        dataB = itemsB.map((e) => WeatherData.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Sensor Comparison'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputs(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.compare),
              label: const Text('Compare'),
              onPressed: loading ? null : fetchComparisonData,
            ),
            const SizedBox(height: 24),
            if (loading) const CircularProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (!loading && dataA.isNotEmpty && dataB.isNotEmpty)
              SizedBox(height: 350, child: _buildChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildInputs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: deviceAController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Device ID A',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: deviceBController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Device ID B',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WeatherParameter>(
              value: selectedParameter,
              items: WeatherParameter.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(parameterLabel(p)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selectedParameter = v!),
              decoration: const InputDecoration(
                labelText: 'Parameter',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateButton('Start Date', startDate, true)),
                const SizedBox(width: 16),
                Expanded(child: _dateButton('End Date', endDate, false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(String label, DateTime date, bool isStart) {
    return OutlinedButton(
      onPressed: () => pickDate(isStart),
      child: Column(
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd-MM-yyyy').format(date),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spotsA = <FlSpot>[];
    final spotsB = <FlSpot>[];

    final length = min(dataA.length, dataB.length);

    for (int i = 0; i < length; i++) {
      spotsA.add(
        FlSpot(i.toDouble(), getParameterValue(dataA[i], selectedParameter)),
      );
      spotsB.add(
        FlSpot(i.toDouble(), getParameterValue(dataB[i], selectedParameter)),
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                parameterLabel(selectedParameter),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: length > 20 ? (length / 10).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < dataA.length) {
                  final time =
                      DateFormat('HH:mm').format(dataA[index].timeStamp);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      time,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spotsA,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: spotsB,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= dataA.length) return null;

                final timestamp = DateFormat('dd-MM-yyyy HH:mm')
                    .format(dataA[index].timeStamp);

                final valueA =
                    getParameterValue(dataA[index], selectedParameter);
                final valueB =
                    getParameterValue(dataB[index], selectedParameter);

                if (spot.barIndex == 0) {
                  return LineTooltipItem(
                    '$timestamp\nSensor A: ${valueA.toStringAsFixed(1)}',
                    const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                } else {
                  return LineTooltipItem(
                    '$timestamp\nSensor B: ${valueB.toStringAsFixed(1)}',
                    const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    deviceAController.dispose();
    deviceBController.dispose();
    super.dispose();
  }
}
