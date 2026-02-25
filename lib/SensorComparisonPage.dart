import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// =======================
/// SENSOR TYPE
/// =======================
enum SensorType { cp, sw }

String sensorTypeLabel(SensorType t) {
  switch (t) {
    case SensorType.cp:
      return 'CP';
    case SensorType.sw:
      return 'SW';
  }
}

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
/// MATCHED DATA POINT
/// =======================
class MatchedDataPoint {
  final DateTime timestamp;
  final Map<String, WeatherData> deviceData; // key: "CP_1", "SW_2", etc.

  MatchedDataPoint({
    required this.timestamp,
    required this.deviceData,
  });
}

/// =======================
/// DEVICE DATA MODEL
/// =======================
class DeviceData {
  final int deviceId;
  final SensorType sensorType;
  final List<WeatherData> data;
  final Color color;

  DeviceData({
    required this.deviceId,
    required this.sensorType,
    required this.data,
    required this.color,
  });

  /// Unique key used in matched data maps
  String get key => '${sensorTypeLabel(sensorType)}_$deviceId';

  /// Display label
  String get label => '${sensorTypeLabel(sensorType)} Device $deviceId';
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
  double normalized = degrees % 360;
  if (normalized < 0) normalized += 360;

  if (normalized >= 348.75 || normalized < 11.25) return 'N';
  if (normalized >= 11.25 && normalized < 33.75) return 'NNE';
  if (normalized >= 33.75 && normalized < 56.25) return 'NE';
  if (normalized >= 56.25 && normalized < 78.75) return 'ENE';
  if (normalized >= 78.75 && normalized < 101.25) return 'E';
  if (normalized >= 101.25 && normalized < 123.75) return 'ESE';
  if (normalized >= 123.75 && normalized < 146.25) return 'SE';
  if (normalized >= 146.25 && normalized < 168.75) return 'SSE';
  if (normalized >= 168.75 && normalized < 191.25) return 'S';
  if (normalized >= 191.25 && normalized < 213.75) return 'SSW';
  if (normalized >= 213.75 && normalized < 236.25) return 'SW';
  if (normalized >= 236.25 && normalized < 258.75) return 'WSW';
  if (normalized >= 258.75 && normalized < 281.25) return 'W';
  if (normalized >= 281.25 && normalized < 303.75) return 'WNW';
  if (normalized >= 303.75 && normalized < 326.25) return 'NW';
  return 'NNW';
}

/// Get directional arrow showing where wind is coming FROM
String getWindArrow(double degrees) {
  double normalized = degrees % 360;
  if (normalized < 0) normalized += 360;

  if (normalized >= 348.75 || normalized < 11.25) return '↓';
  if (normalized >= 11.25 && normalized < 56.25) return '↙';
  if (normalized >= 56.25 && normalized < 78.75) return '↙';
  if (normalized >= 78.75 && normalized < 101.25) return '←';
  if (normalized >= 101.25 && normalized < 146.25) return '↖';
  if (normalized >= 146.25 && normalized < 168.75) return '↖';
  if (normalized >= 168.75 && normalized < 191.25) return '↑';
  if (normalized >= 191.25 && normalized < 236.25) return '↗';
  if (normalized >= 236.25 && normalized < 258.75) return '↗';
  if (normalized >= 258.75 && normalized < 281.25) return '→';
  if (normalized >= 281.25 && normalized < 326.25) return '↘';
  return '↘';
}

/// =======================
/// TIMESTAMP MATCHER
/// =======================
class TimestampMatcher {
  static DateTime _bucket(DateTime dt, {int bucketMinutes = 5}) {
    final minuteBucket = (dt.minute ~/ bucketMinutes) * bucketMinutes;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, minuteBucket, 0);
  }

  static List<MatchedDataPoint> matchTimestamps(List<DeviceData> devicesData) {
    if (devicesData.isEmpty) return [];

    final Map<DateTime, Map<String, WeatherData>> bucketMap = {};

    for (final device in devicesData) {
      for (final data in device.data) {
        final bucket = _bucket(data.timeStamp);
        bucketMap.putIfAbsent(bucket, () => {});

        if (!bucketMap[bucket]!.containsKey(device.key)) {
          bucketMap[bucket]![device.key] = data;
        }
      }
    }

    final int requiredCount = devicesData.length;
    final List<MatchedDataPoint> matchedPoints = [];
    final sortedBuckets = bucketMap.keys.toList()..sort();

    for (final bucket in sortedBuckets) {
      final deviceMap = bucketMap[bucket]!;
      if (deviceMap.length >= requiredCount) {
        matchedPoints.add(MatchedDataPoint(
          timestamp: bucket,
          deviceData: deviceMap,
        ));
      }
    }

    return matchedPoints;
  }
}

/// =======================
/// COLOR PALETTE
/// =======================
class ColorPalette {
  static const List<Color> chartColors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
    Colors.lightBlue,
    Colors.lightGreen,
    Colors.deepPurple,
  ];

  static Color getColor(int index) => chartColors[index % chartColors.length];
}

/// =======================
/// SENSOR ENTRY (holds deviceId + sensorType)
/// =======================
class SensorEntry {
  final int deviceId;
  final SensorType sensorType;

  SensorEntry({required this.deviceId, required this.sensorType});

  String get key => '${sensorTypeLabel(sensorType)}_$deviceId';
  String get label => '${sensorTypeLabel(sensorType)} Device $deviceId';

  @override
  bool operator ==(Object other) =>
      other is SensorEntry &&
      other.deviceId == deviceId &&
      other.sensorType == sensorType;

  @override
  int get hashCode => Object.hash(deviceId, sensorType);
}

/// =======================
/// API BUILDER
/// =======================
String buildApiUrl({
  required int deviceId,
  required SensorType sensorType,
  required String startDate,
  required String endDate,
}) {
  if (sensorType == SensorType.sw) {
    return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet1225data'
        '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
  }
  // CP sensors
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
  List<SensorEntry> selectedSensors = [
    SensorEntry(deviceId: 1, sensorType: SensorType.cp),
    SensorEntry(deviceId: 2, sensorType: SensorType.cp),
  ];

  final TextEditingController newDeviceController = TextEditingController();
  SensorType _addSensorType = SensorType.cp;

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  List<WeatherParameter> selectedParameters = [WeatherParameter.temperature];

  List<DeviceData> devicesData = [];
  List<MatchedDataPoint> matchedDataPoints = [];

  bool loading = false;
  String? error;

  // ── Per-chart zoom/pan state
  final Map<WeatherParameter, double> _zoomLevel = {};
  final Map<WeatherParameter, double> _panOffset = {};
  final Map<WeatherParameter, double> _baseScale = {};

  final double minZoom = 1.0;
  final double maxZoom = 10.0;

  double _zoom(WeatherParameter p) => _zoomLevel[p] ?? 1.0;
  double _pan(WeatherParameter p) => _panOffset[p] ?? 0.0;
  double _base(WeatherParameter p) => _baseScale[p] ?? 1.0;

  void _setZoom(WeatherParameter p, double v) =>
      _zoomLevel[p] = v.clamp(minZoom, maxZoom);
  void _setPan(WeatherParameter p, double v) => _panOffset[p] = v;
  void _setBase(WeatherParameter p, double v) => _baseScale[p] = v;

  DateTime? _globalMinTime;
  double _totalMinutes = 0.0;

  // ─── Date Picker ────────────────────────────────────────────────────────────

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

  // ─── Sensor Management ──────────────────────────────────────────────────────

  void addSensor() {
    final deviceId = int.tryParse(newDeviceController.text);
    if (deviceId == null) {
      _snack('Please enter a valid device ID');
      return;
    }
    final entry = SensorEntry(deviceId: deviceId, sensorType: _addSensorType);
    if (selectedSensors.contains(entry)) {
      _snack('${entry.label} already added');
      return;
    }
    setState(() {
      selectedSensors.add(entry);
      newDeviceController.clear();
    });
  }

  void removeSensor(SensorEntry entry) {
    if (selectedSensors.length <= 1) {
      _snack('At least one sensor is required');
      return;
    }
    setState(() {
      selectedSensors.remove(entry);
      devicesData.removeWhere((d) => d.key == entry.key);
      matchedDataPoints = TimestampMatcher.matchTimestamps(devicesData);
      _recalcGlobalTime();
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> fetchComparisonData() async {
    if (selectedSensors.isEmpty) {
      setState(() => error = 'Please add at least one sensor');
      return;
    }

    setState(() {
      loading = true;
      error = null;
      _zoomLevel.clear();
      _panOffset.clear();
      _baseScale.clear();
    });

    try {
      final start = DateFormat('dd-MM-yyyy').format(startDate);
      final end = DateFormat('dd-MM-yyyy').format(endDate);

      final List<DeviceData> fetchedData = [];

      for (int i = 0; i < selectedSensors.length; i++) {
        final sensor = selectedSensors[i];
        final url = buildApiUrl(
          deviceId: sensor.deviceId,
          sensorType: sensor.sensorType,
          startDate: start,
          endDate: end,
        );
        final response = await http.get(Uri.parse(url));

        if (response.statusCode != 200) {
          throw Exception(
              'Failed to load data for ${sensor.label} (HTTP ${response.statusCode})');
        }

        final body = json.decode(response.body);
        final items = body['items'] as List;
        final data = items.map((e) => WeatherData.fromJson(e)).toList();

        fetchedData.add(DeviceData(
          deviceId: sensor.deviceId,
          sensorType: sensor.sensorType,
          data: data,
          color: ColorPalette.getColor(i),
        ));
      }

      final matched = TimestampMatcher.matchTimestamps(fetchedData);

      setState(() {
        devicesData = fetchedData;
        matchedDataPoints = matched;
        loading = false;
        _recalcGlobalTime();
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _recalcGlobalTime() {
    DateTime? earliest;
    DateTime? latest;
    for (final device in devicesData) {
      for (final d in device.data) {
        if (earliest == null || d.timeStamp.isBefore(earliest)) {
          earliest = d.timeStamp;
        }
        if (latest == null || d.timeStamp.isAfter(latest)) {
          latest = d.timeStamp;
        }
      }
    }
    _globalMinTime = earliest;
    _totalMinutes = (earliest != null && latest != null)
        ? latest.difference(earliest).inSeconds / 60.0
        : 0.0;
  }

  void resetZoom(WeatherParameter p) {
    setState(() {
      _zoomLevel[p] = 1.0;
      _panOffset[p] = 0.0;
      _baseScale[p] = 1.0;
    });
  }

  bool get anyChartZoomed => _zoomLevel.values.any((z) => z > 1.0);

  // ─── Statistics ─────────────────────────────────────────────────────────────

  Map<WeatherParameter, Map<String, Map<String, double>>>
      calculateStatistics() {
    if (matchedDataPoints.isEmpty) return {};

    final Map<WeatherParameter, Map<String, Map<String, double>>> allStats = {};

    for (final parameter in selectedParameters) {
      final Map<String, List<double>> deviceValues = {};

      for (final matchedPoint in matchedDataPoints) {
        for (final entry in matchedPoint.deviceData.entries) {
          deviceValues
              .putIfAbsent(entry.key, () => [])
              .add(getParameterValue(entry.value, parameter));
        }
      }

      final Map<String, Map<String, double>> stats = {
        'max': {},
        'min': {},
        'avg': {},
      };

      for (final entry in deviceValues.entries) {
        final values = entry.value;
        if (values.isNotEmpty) {
          stats['max']![entry.key] = values.reduce(max);
          stats['min']![entry.key] = values.reduce(min);
          stats['avg']![entry.key] =
              values.reduce((a, b) => a + b) / values.length;
        }
      }

      allStats[parameter] = stats;
    }

    return allStats;
  }

  Map<WeatherParameter, Map<String, Map<String, double>>>
      calculateDifferenceStatistics() {
    if (matchedDataPoints.isEmpty || selectedSensors.length < 2) return {};

    final Map<WeatherParameter, Map<String, Map<String, double>>> allDiffStats =
        {};

    for (final parameter in selectedParameters) {
      final Map<String, Map<String, double>> diffStats = {};

      for (int i = 0; i < selectedSensors.length - 1; i++) {
        for (int j = i + 1; j < selectedSensors.length; j++) {
          final keyA = selectedSensors[i].key;
          final keyB = selectedSensors[j].key;
          final List<double> differences = [];

          for (final mp in matchedDataPoints) {
            final dataA = mp.deviceData[keyA];
            final dataB = mp.deviceData[keyB];
            if (dataA != null && dataB != null) {
              differences.add(
                (getParameterValue(dataA, parameter) -
                        getParameterValue(dataB, parameter))
                    .abs(),
              );
            }
          }

          if (differences.isNotEmpty) {
            diffStats['$keyA vs $keyB'] = {
              'maxDiff': differences.reduce(max),
              'avgDiff':
                  differences.reduce((a, b) => a + b) / differences.length,
              'minDiff': differences.reduce(min),
            };
          }
        }
      }

      allDiffStats[parameter] = diffStats;
    }

    return allDiffStats;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Multi-Sensor Comparison'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (!loading && devicesData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
              onPressed: fetchComparisonData,
            ),
          if (!loading && devicesData.isNotEmpty && anyChartZoomed)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: 'Reset All Zooms',
              onPressed: () {
                setState(() {
                  _zoomLevel.clear();
                  _panOffset.clear();
                  _baseScale.clear();
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSensorSelector(),
            const SizedBox(height: 16),
            _buildParameterAndDateSelector(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: Text('Compare ${selectedSensors.length} Sensors'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: loading ? null : fetchComparisonData,
            ),
            const SizedBox(height: 24),
            if (loading) const CircularProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (!loading && devicesData.isNotEmpty) ...[
              ...selectedParameters.map(
                (parameter) => Column(
                  children: [
                    _buildChartCard(parameter),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _buildStatisticsCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Sensor Selector Card ───────────────────────────────────────────────────

  Widget _buildSensorSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Sensors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _sensorTypeLegendDot(Colors.blue),
                const SizedBox(width: 4),
                const Text('CP = Campus sensor  ',
                    style: TextStyle(fontSize: 12)),
                _sensorTypeLegendDot(Colors.teal),
                const SizedBox(width: 4),
                const Text('SW = SW sensor', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedSensors.map((sensor) {
                final color =
                    ColorPalette.getColor(selectedSensors.indexOf(sensor));
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: Text(
                      sensorTypeLabel(sensor.sensorType),
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  label: Text(sensor.label,
                      style: const TextStyle(color: Colors.white)),
                  backgroundColor: color,
                  deleteIcon:
                      const Icon(Icons.close, color: Colors.white, size: 18),
                  onDeleted: () => removeSensor(sensor),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Sensor type toggle
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: SensorType.values.map((type) {
                      final selected = _addSensorType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _addSensorType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.deepPurple
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            sensorTypeLabel(type),
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: newDeviceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      border: OutlineInputBorder(),
                      hintText: 'Enter number',
                      isDense: true,
                    ),
                    onSubmitted: (_) => addSensor(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: addSensor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensorTypeLegendDot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ─── Parameter & Date Selector ──────────────────────────────────────────────

  Widget _buildParameterAndDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Parameters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WeatherParameter.values.map((parameter) {
                final isSelected = selectedParameters.contains(parameter);
                return FilterChip(
                  label: Text(parameterLabel(parameter)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedParameters.add(parameter);
                      } else {
                        if (selectedParameters.length > 1) {
                          selectedParameters.remove(parameter);
                        } else {
                          _snack('At least one parameter must be selected');
                        }
                      }
                    });
                  },
                  selectedColor: Colors.deepPurple.withOpacity(0.3),
                  checkmarkColor: Colors.deepPurple,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
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

  // ─── Legend ─────────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: devicesData
          .map((device) => _buildLegendItem(device.label, device.color))
          .toList(),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // ─── Chart Card ─────────────────────────────────────────────────────────────

  Widget _buildChartCard(WeatherParameter parameter) {
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
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  parameterLabel(parameter),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_zoom(parameter) > 1.0)
                  TextButton.icon(
                    icon: const Icon(Icons.zoom_out_map, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    onPressed: () => resetZoom(parameter),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 350,
            child: ClipRect(
              clipBehavior: Clip.hardEdge,
              child: _buildChart(parameter),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  // ─── Chart ──────────────────────────────────────────────────────────────────

  Widget _buildChart(WeatherParameter parameter) {
    if (devicesData.isEmpty || _globalMinTime == null) {
      return const Center(child: Text('No data available'));
    }

    final globalMin = _globalMinTime!;
    final totalMinutes = _totalMinutes;

    if (totalMinutes <= 0) {
      return const Center(child: Text('No data points available'));
    }

    final zoomLevel = _zoom(parameter);
    final panOffset = _pan(parameter);

    // Guard: totalMinutes must be > 0 (already checked above), but ensure
    // the visible window is never zero-width (fl_chart asserts minX < maxX).
    final effectiveTotal = totalMinutes < 1.0 ? 1.0 : totalMinutes;
    final visibleMinutes = effectiveTotal / zoomLevel;
    final maxPan = max(0.0, effectiveTotal - visibleMinutes);
    final clampedPan = panOffset.clamp(0.0, maxPan).toDouble();
    final rawMinX = clampedPan;
    final rawMaxX = min(clampedPan + visibleMinutes, effectiveTotal);
    // Guarantee minX < maxX even for a single data-point edge case
    final minXMin = rawMinX;
    final maxXMin = rawMaxX > rawMinX ? rawMaxX : rawMinX + 1.0;

    final List<LineChartBarData> lineBars = [];
    double allYMin = double.infinity;
    double allYMax = double.negativeInfinity;

    for (final device in devicesData) {
      final spots = <FlSpot>[];
      for (final d in device.data) {
        final elapsed = d.timeStamp.difference(globalMin).inSeconds / 60.0;
        final yVal = getParameterValue(d, parameter);
        spots.add(FlSpot(elapsed, yVal));
        if (yVal < allYMin) allYMin = yVal;
        if (yVal > allYMax) allYMax = yVal;
      }
      if (spots.isNotEmpty) {
        lineBars.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: device.color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: zoomLevel > 3),
          belowBarData: BarAreaData(show: false),
        ));
      }
    }

    // Guard: fl_chart asserts minY < maxY. If all values are identical,
    // add a symmetric padding of 1 unit so the chart renders cleanly.
    if (allYMin == double.infinity) {
      allYMin = 0;
      allYMax = 1;
    } else if (allYMin == allYMax) {
      allYMin -= 1;
      allYMax += 1;
    } else {
      // Add 5 % padding so lines are never flush with the chart border
      final yPad = (allYMax - allYMin) * 0.05;
      allYMin -= yPad;
      allYMax += yPad;
    }

    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: RawGestureDetector(
        gestures: {
          _PanZoomGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_PanZoomGestureRecognizer>(
            () => _PanZoomGestureRecognizer(),
            (_PanZoomGestureRecognizer instance) {
              instance
                ..onStart = (_) {
                  _setBase(parameter, _zoom(parameter));
                }
                ..onUpdate = (details) {
                  if (details.scale != 1.0) {
                    setState(() {
                      _setZoom(parameter, _base(parameter) * details.scale);
                    });
                  }
                  if (details.focalPointDelta.dx.abs() > 0.1) {
                    final effectiveTot =
                        _totalMinutes < 1.0 ? 1.0 : _totalMinutes;
                    final sensitivity = effectiveTot / (400 * _zoom(parameter));
                    final currentZoom = _zoom(parameter);
                    final vis = effectiveTot / currentZoom;
                    final newPan = (_pan(parameter) -
                            details.focalPointDelta.dx * sensitivity)
                        .clamp(0.0, max(0.0, effectiveTot - vis))
                        .toDouble();
                    setState(() => _setPan(parameter, newPan));
                  }
                }
                ..onEnd = (_) {
                  _setBase(parameter, _zoom(parameter));
                };
            },
          ),
        },
        child: Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent &&
                HardwareKeyboard.instance.isShiftPressed) {
              GestureBinding.instance.pointerSignalResolver.register(
                signal,
                (event) {
                  if (event is PointerScrollEvent) {
                    final delta = event.scrollDelta.dy;
                    setState(() {
                      final newZoom = delta < 0
                          ? min(maxZoom, _zoom(parameter) * 1.1)
                          : max(minZoom, _zoom(parameter) / 1.1);
                      _setZoom(parameter, newZoom);
                    });
                  }
                },
              );
            }
          },
          child: LineChart(
            LineChartData(
              clipData: const FlClipData.all(),
              minX: minXMin,
              maxX: maxXMin,
              minY: allYMin,
              maxY: allYMax,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                getDrawingVerticalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.shade300),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      parameterLabel(parameter),
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, _) => Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: max(1.0, (visibleMinutes / 10).ceilToDouble()),
                    getTitlesWidget: (value, _) {
                      final labelTime = globalMin
                          .add(Duration(seconds: (value * 60).round()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('HH:mm').format(labelTime),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: lineBars,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final deviceIndex = spot.barIndex;
                      if (deviceIndex >= devicesData.length) return null;
                      final device = devicesData[deviceIndex];

                      WeatherData? closest;
                      double minDiff = double.infinity;
                      for (final d in device.data) {
                        final elapsed =
                            d.timeStamp.difference(globalMin).inSeconds / 60.0;
                        final diff = (elapsed - spot.x).abs();
                        if (diff < minDiff) {
                          minDiff = diff;
                          closest = d;
                        }
                      }
                      if (closest == null) return null;

                      final ts = DateFormat('dd-MM-yyyy HH:mm:ss')
                          .format(closest.timeStamp);
                      final value = getParameterValue(closest, parameter);

                      String fmt(double v) {
                        if (parameter == WeatherParameter.windDirection) {
                          return '${v.toStringAsFixed(1)}° '
                              '(${degreesToDirection(v)}) ${getWindArrow(v)}';
                        }
                        return v.toStringAsFixed(1);
                      }

                      return LineTooltipItem(
                        '$ts\n${device.label}: ${fmt(value)}',
                        TextStyle(
                          color: device.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
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

  // ─── Statistics Card ────────────────────────────────────────────────────────

  Widget _buildStatisticsCard() {
    final allStats = calculateStatistics();
    final allDiffStats = calculateDifferenceStatistics();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics (Based on Matched Timestamps)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (matchedDataPoints.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'No overlapping timestamps found across all sensors.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 16),
            ...selectedParameters.map((parameter) {
              final stats = allStats[parameter] ?? {};
              final diffStats = allDiffStats[parameter] ?? {};
              final unit = parameterUnit(parameter);
              final isWind = parameter == WeatherParameter.windDirection;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      parameterLabel(parameter),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isWind) ...[
                    _buildWindDirectionInfo(),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Individual Sensor Values',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 12),
                  _buildStatSection(
                      'Maximum', stats['max'] ?? {}, unit, Colors.red),
                  const SizedBox(height: 12),
                  _buildStatSection(
                      'Average', stats['avg'] ?? {}, unit, Colors.blue),
                  const SizedBox(height: 12),
                  _buildStatSection(
                      'Minimum', stats['min'] ?? {}, unit, Colors.green),
                  if (diffStats.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Sensor Comparison Differences',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 12),
                    _buildDifferenceStatistics(diffStats, unit),
                  ],
                  if (parameter != selectedParameters.last) ...[
                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    const SizedBox(height: 24),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSection(
      String title, Map<String, double> values, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: values.entries.map((entry) {
            // Find the device index by key for color lookup
            final deviceIndex =
                devicesData.indexWhere((d) => d.key == entry.key);
            final deviceColor =
                deviceIndex >= 0 ? devicesData[deviceIndex].color : Colors.grey;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: deviceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: deviceColor.withOpacity(0.3)),
              ),
              child: Text(
                '${entry.key}: ${entry.value.toStringAsFixed(2)} $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: deviceColor.withOpacity(0.9),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDifferenceStatistics(
      Map<String, Map<String, double>> diffStats, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: diffStats.entries.map((entry) {
        // entry.key is e.g. "CP_1 vs SW_2"
        final parts = entry.key.split(' vs ');
        final keyA = parts[0];
        final keyB = parts.length > 1 ? parts[1] : '';

        final indexA = devicesData.indexWhere((d) => d.key == keyA);
        final indexB = devicesData.indexWhere((d) => d.key == keyB);
        final colorA = indexA >= 0 ? devicesData[indexA].color : Colors.grey;
        final colorB = indexB >= 0 ? devicesData[indexB].color : Colors.grey;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _dot(colorA),
                    const SizedBox(width: 4),
                    Text(keyA,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorA)),
                    const SizedBox(width: 8),
                    const Icon(Icons.compare_arrows,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    _dot(colorB),
                    const SizedBox(width: 4),
                    Text(keyB,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorB)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDiffStatItem('Max Diff', entry.value['maxDiff']!,
                        unit, Colors.red, Icons.trending_up),
                    _buildDiffStatItem('Avg Diff', entry.value['avgDiff']!,
                        unit, Colors.blue, Icons.show_chart),
                    _buildDiffStatItem('Min Diff', entry.value['minDiff']!,
                        unit, Colors.green, Icons.trending_down),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildDiffStatItem(
      String label, double value, String unit, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(2)} $unit',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── Wind Direction Info ─────────────────────────────────────────────────────

  Widget _buildWindDirectionInfo() {
    if (devicesData.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const Text(
          'Current Wind Direction',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: devicesData.map((device) {
            if (device.data.isEmpty) return const SizedBox.shrink();
            return _buildWindDirectionItem(
              device.label,
              device.data.last.windDirection,
              device.color,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWindDirectionItem(String label, double degrees, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                getWindArrow(degrees),
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.0),
              ),
              const SizedBox(height: 4),
              Text(degreesToDirection(degrees),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text('${degrees.toStringAsFixed(1)}°',
                  style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    newDeviceController.dispose();
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
