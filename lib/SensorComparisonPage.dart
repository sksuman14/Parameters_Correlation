import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  final double windDirection;

  WeatherData({
    required this.timeStamp,
    required this.atmPressure,
    required this.currentTemperature,
    required this.currentHumidity,
    required this.windSpeed,
    required this.rainfallHourly,
    required this.windDirection,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      timeStamp: DateTime.parse(json['TimeStamp']),
      atmPressure: (json['AtmPressure'] ?? 0).toDouble(),
      currentTemperature: (json['CurrentTemperature'] ?? 0).toDouble(),
      currentHumidity: (json['CurrentHumidity'] ?? 0).toDouble(),
      windSpeed: (json['WindSpeed'] ?? 0).toDouble(),
      rainfallHourly: (json['RainfallHourly'] ?? 0).toDouble(),
      windDirection: (json['WindDirection'] ?? 0).toDouble(),
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
  windDirection,
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
    case WeatherParameter.windDirection:
      return 'Wind Direction (°)';
  }
}

String parameterUnit(WeatherParameter p) {
  switch (p) {
    case WeatherParameter.temperature:
      return '°C';
    case WeatherParameter.humidity:
      return '%';
    case WeatherParameter.pressure:
      return 'hPa';
    case WeatherParameter.windSpeed:
      return 'm/s';
    case WeatherParameter.rainfall:
      return 'mm';
    case WeatherParameter.windDirection:
      return '°';
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
    case WeatherParameter.windDirection:
      return d.windDirection;
  }
}

/// Convert degrees to 16 cardinal directions
String degreesToDirection(double degrees) {
  // Normalize degrees to 0-360 range
  double normalized = degrees % 360;
  if (normalized < 0) normalized += 360;

  // 16 directions with 22.5° each
  // N: 348.75-11.25, NNE: 11.25-33.75, NE: 33.75-56.25, ENE: 56.25-78.75,
  // E: 78.75-101.25, ESE: 101.25-123.75, SE: 123.75-146.25, SSE: 146.25-168.75,
  // S: 168.75-191.25, SSW: 191.25-213.75, SW: 213.75-236.25, WSW: 236.25-258.75,
  // W: 258.75-281.25, WNW: 281.25-303.75, NW: 303.75-326.25, NNW: 326.25-348.75

  if (normalized >= 348.75 || normalized < 11.25) {
    return 'N';
  } else if (normalized >= 11.25 && normalized < 33.75) {
    return 'NNE';
  } else if (normalized >= 33.75 && normalized < 56.25) {
    return 'NE';
  } else if (normalized >= 56.25 && normalized < 78.75) {
    return 'ENE';
  } else if (normalized >= 78.75 && normalized < 101.25) {
    return 'E';
  } else if (normalized >= 101.25 && normalized < 123.75) {
    return 'ESE';
  } else if (normalized >= 123.75 && normalized < 146.25) {
    return 'SE';
  } else if (normalized >= 146.25 && normalized < 168.75) {
    return 'SSE';
  } else if (normalized >= 168.75 && normalized < 191.25) {
    return 'S';
  } else if (normalized >= 191.25 && normalized < 213.75) {
    return 'SSW';
  } else if (normalized >= 213.75 && normalized < 236.25) {
    return 'SW';
  } else if (normalized >= 236.25 && normalized < 258.75) {
    return 'WSW';
  } else if (normalized >= 258.75 && normalized < 281.25) {
    return 'W';
  } else if (normalized >= 281.25 && normalized < 303.75) {
    return 'WNW';
  } else if (normalized >= 303.75 && normalized < 326.25) {
    return 'NW';
  } else {
    return 'NNW';
  }
}

/// Get directional arrow showing where wind is coming FROM
String getWindArrow(double degrees) {
  // Normalize degrees to 0-360 range
  double normalized = degrees % 360;
  if (normalized < 0) normalized += 360;

  // 16 directions with 22.5° each
  // Arrow points to where wind is COMING FROM
  if (normalized >= 348.75 || normalized < 11.25) {
    return '↓'; // Wind from North
  } else if (normalized >= 11.25 && normalized < 33.75) {
    return '↙'; // Wind from NNE
  } else if (normalized >= 33.75 && normalized < 56.25) {
    return '↙'; // Wind from NE
  } else if (normalized >= 56.25 && normalized < 78.75) {
    return '↙'; // Wind from ENE
  } else if (normalized >= 78.75 && normalized < 101.25) {
    return '←'; // Wind from East
  } else if (normalized >= 101.25 && normalized < 123.75) {
    return '↖'; // Wind from ESE
  } else if (normalized >= 123.75 && normalized < 146.25) {
    return '↖'; // Wind from SE
  } else if (normalized >= 146.25 && normalized < 168.75) {
    return '↖'; // Wind from SSE
  } else if (normalized >= 168.75 && normalized < 191.25) {
    return '↑'; // Wind from South
  } else if (normalized >= 191.25 && normalized < 213.75) {
    return '↗'; // Wind from SSW
  } else if (normalized >= 213.75 && normalized < 236.25) {
    return '↗'; // Wind from SW
  } else if (normalized >= 236.25 && normalized < 258.75) {
    return '↗'; // Wind from WSW
  } else if (normalized >= 258.75 && normalized < 281.25) {
    return '→'; // Wind from West
  } else if (normalized >= 281.25 && normalized < 303.75) {
    return '↘'; // Wind from WNW
  } else if (normalized >= 303.75 && normalized < 326.25) {
    return '↘'; // Wind from NW
  } else {
    return '↘'; // Wind from NNW
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

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  WeatherParameter selectedParameter = WeatherParameter.temperature;

  List<WeatherData> dataA = [];
  List<WeatherData> dataB = [];
  int? deviceAId;
  int? deviceBId;

  bool loading = false;
  String? error;

  // Zoom and pan state
  double zoomLevel = 1.0;
  double panOffset = 0.0;
  double baseScale = 1.0;
  final double minZoom = 1.0;
  final double maxZoom = 10.0;

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
      deviceAId = deviceA;
      deviceBId = deviceB;
      loading = true;
      error = null;
      // Reset zoom when fetching new data
      zoomLevel = 1.0;
      panOffset = 0.0;
      baseScale = 1.0;
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

  void resetZoom() {
    setState(() {
      zoomLevel = 1.0;
      panOffset = 0.0;
      baseScale = 1.0;
    });
  }

  Map<String, double> calculateStatistics() {
    if (dataA.isEmpty || dataB.isEmpty) {
      return {
        'maxDiff': 0.0,
        'avgDiff': 0.0,
        'minDiff': 0.0,
      };
    }

    final length = min(dataA.length, dataB.length);
    double maxDiff = 0.0;
    double minDiff = double.infinity;
    double sumDiff = 0.0;

    for (int i = 0; i < length; i++) {
      final valueA = getParameterValue(dataA[i], selectedParameter);
      final valueB = getParameterValue(dataB[i], selectedParameter);
      final diff = (valueA - valueB).abs();

      if (diff > maxDiff) maxDiff = diff;
      if (diff < minDiff) minDiff = diff;
      sumDiff += diff;
    }

    return {
      'maxDiff': maxDiff,
      'avgDiff': sumDiff / length,
      'minDiff': minDiff,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Sensor Comparison'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (!loading && dataA.isNotEmpty && dataB.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
              onPressed: fetchComparisonData,
            ),
          if (!loading &&
              dataA.isNotEmpty &&
              dataB.isNotEmpty &&
              zoomLevel > 1.0)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: 'Reset Zoom',
              onPressed: resetZoom,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputs(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Compare'),
              onPressed: loading ? null : fetchComparisonData,
            ),
            const SizedBox(height: 24),
            if (loading) const CircularProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (!loading && dataA.isNotEmpty && dataB.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildChartCard(),
              const SizedBox(height: 16),
              _buildStatisticsCard(),
            ],
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

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Device ${deviceAId ?? "A"}', Colors.blue),
        const SizedBox(width: 24),
        _buildLegendItem('Device ${deviceBId ?? "B"}', Colors.orange),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    final stats = calculateStatistics();
    final unit = parameterUnit(selectedParameter);
    final isWindDirection = selectedParameter == WeatherParameter.windDirection;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparison Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (isWindDirection) ...[
              _buildWindDirectionInfo(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Max Difference',
                  stats['maxDiff']!,
                  unit,
                  Colors.red,
                  Icons.trending_up,
                ),
                _buildStatItem(
                  'Avg Difference',
                  stats['avgDiff']!,
                  unit,
                  Colors.blue,
                  Icons.show_chart,
                ),
                _buildStatItem(
                  'Min Difference',
                  stats['minDiff']!,
                  unit,
                  Colors.green,
                  Icons.trending_down,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindDirectionInfo() {
    if (dataA.isEmpty || dataB.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get most recent wind directions
    final latestA = dataA.last.windDirection;
    final latestB = dataB.last.windDirection;

    return Column(
      children: [
        const Text(
          'Current Wind Direction',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildWindDirectionItem(
              'Device ${deviceAId ?? "A"}',
              latestA,
              Colors.blue,
            ),
            _buildWindDirectionItem(
              'Device ${deviceBId ?? "B"}',
              latestB,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWindDirectionItem(String device, double degrees, Color color) {
    final direction = degreesToDirection(degrees);
    final arrow = getWindArrow(degrees);
    return Column(
      children: [
        Text(
          device,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            children: [
              Text(
                arrow,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                direction,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '${degrees.toStringAsFixed(1)}°',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label, double value, String unit, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(2)} $unit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge, // ← important
      child: Column(
        children: [
          // title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              parameterLabel(selectedParameter),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 350,
            child: ClipRect(
              // ← extra safety layer
              clipBehavior: Clip.hardEdge,
              child: _buildChart(),
            ),
          ),
          // legend
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildLegend(),
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

    // Calculate visible range based on zoom and pan
    final visibleRange = length / zoomLevel;
    final maxPanOffset = max(0.0, length - visibleRange);
    final clampedPanOffset = panOffset.clamp(0.0, maxPanOffset);

    final minX = clampedPanOffset;
    final maxX = min(clampedPanOffset + visibleRange, length.toDouble());

    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: RawGestureDetector(
        gestures: {
          _PanZoomGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_PanZoomGestureRecognizer>(
            () => _PanZoomGestureRecognizer(),
            (_PanZoomGestureRecognizer instance) {
              instance
                ..onStart = (details) {
                  baseScale = zoomLevel;
                }
                ..onUpdate = (details) {
                  // Handle zoom (pinch gesture)
                  if (details.scale != 1.0) {
                    final newZoom = baseScale * details.scale;
                    setState(() {
                      zoomLevel = newZoom.clamp(minZoom, maxZoom);
                    });
                  }

                  // Handle pan (horizontal drag)
                  if (details.focalPointDelta.dx.abs() > 0.1) {
                    final panSensitivity = length / (400 * zoomLevel);
                    final newPan = (panOffset -
                            details.focalPointDelta.dx * panSensitivity)
                        .clamp(-0.5, max(0.0, length - visibleRange) + 0.5);
                    setState(() {
                      panOffset = newPan;
                    });
                  }
                }
                ..onEnd = (details) {
                  baseScale = zoomLevel;
                };
            },
          ),
        },
        child: Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final delta = pointerSignal.scrollDelta.dy;
              setState(() {
                if (delta < 0) {
                  // Zoom in
                  zoomLevel = min(maxZoom, zoomLevel * 1.1);
                } else {
                  // Zoom out
                  zoomLevel = max(minZoom, zoomLevel / 1.1);
                }
              });
            }
          },
          child: LineChart(
            LineChartData(
              clipData: const FlClipData
                  .all(), // Helps fl_chart clip lines to the visible area
              minX: minX,
              maxX: maxX,
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
                    interval: max(1, (visibleRange / 10).ceilToDouble()),
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
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: zoomLevel > 3),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots: spotsB,
                  isCurved: true,
                  color: Colors.orange,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: zoomLevel > 3),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
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

                      // Format value based on parameter type
                      String formatValue(double value) {
                        if (selectedParameter ==
                            WeatherParameter.windDirection) {
                          final direction = degreesToDirection(value);
                          final arrow = getWindArrow(value);
                          return '${value.toStringAsFixed(1)}° ($direction) $arrow';
                        }
                        return value.toStringAsFixed(1);
                      }

                      if (spot.barIndex == 0) {
                        return LineTooltipItem(
                          '$timestamp\nDevice ${deviceAId ?? "A"}: ${formatValue(valueA)}',
                          const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      } else {
                        return LineTooltipItem(
                          '$timestamp\nDevice ${deviceBId ?? "B"}: ${formatValue(valueB)}',
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

/// =======================
/// CUSTOM GESTURE RECOGNIZER
/// =======================
class _PanZoomGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}
