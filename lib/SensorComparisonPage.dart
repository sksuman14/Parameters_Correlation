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
/// DEVICE DATA MODEL
/// =======================
class DeviceData {
  final int deviceId;
  final List<WeatherData> data;
  final Color color;

  DeviceData({
    required this.deviceId,
    required this.data,
    required this.color,
  });
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
  double normalized = degrees % 360;
  if (normalized < 0) normalized += 360;

  if (normalized >= 348.75 || normalized < 11.25) {
    return '↓';
  } else if (normalized >= 11.25 && normalized < 56.25) {
    return '↙';
  } else if (normalized >= 56.25 && normalized < 78.75) {
    return '↙';
  } else if (normalized >= 78.75 && normalized < 101.25) {
    return '←';
  } else if (normalized >= 101.25 && normalized < 146.25) {
    return '↖';
  } else if (normalized >= 146.25 && normalized < 168.75) {
    return '↖';
  } else if (normalized >= 168.75 && normalized < 191.25) {
    return '↑';
  } else if (normalized >= 191.25 && normalized < 236.25) {
    return '↗';
  } else if (normalized >= 236.25 && normalized < 258.75) {
    return '↗';
  } else if (normalized >= 258.75 && normalized < 281.25) {
    return '→';
  } else if (normalized >= 281.25 && normalized < 326.25) {
    return '↘';
  } else {
    return '↘';
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

  static Color getColor(int index) {
    return chartColors[index % chartColors.length];
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
  // List of device IDs to compare
  List<int> selectedDeviceIds = [1, 2];
  final TextEditingController newDeviceController = TextEditingController();

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  WeatherParameter selectedParameter = WeatherParameter.temperature;

  // Store data for each device
  List<DeviceData> devicesData = [];

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

  void addDevice() {
    final deviceId = int.tryParse(newDeviceController.text);
    if (deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid device ID')),
      );
      return;
    }

    if (selectedDeviceIds.contains(deviceId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device already added')),
      );
      return;
    }

    setState(() {
      selectedDeviceIds.add(deviceId);
      newDeviceController.clear();
    });
  }

  void removeDevice(int deviceId) {
    if (selectedDeviceIds.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one device is required')),
      );
      return;
    }

    setState(() {
      selectedDeviceIds.remove(deviceId);
      devicesData.removeWhere((d) => d.deviceId == deviceId);
    });
  }

  Future<void> fetchComparisonData() async {
    if (selectedDeviceIds.isEmpty) {
      setState(() => error = 'Please add at least one device');
      return;
    }

    setState(() {
      loading = true;
      error = null;
      zoomLevel = 1.0;
      panOffset = 0.0;
      baseScale = 1.0;
    });

    try {
      final start = DateFormat('dd-MM-yyyy').format(startDate);
      final end = DateFormat('dd-MM-yyyy').format(endDate);

      List<DeviceData> fetchedData = [];

      // Fetch data for each device
      for (int i = 0; i < selectedDeviceIds.length; i++) {
        final deviceId = selectedDeviceIds[i];
        final url = buildApiUrl(
          deviceId: deviceId,
          startDate: start,
          endDate: end,
        );

        final response = await http.get(Uri.parse(url));

        if (response.statusCode != 200) {
          throw Exception('Failed to load data for device $deviceId');
        }

        final items = json.decode(response.body)['items'] as List;
        final data = items.map((e) => WeatherData.fromJson(e)).toList();

        fetchedData.add(DeviceData(
          deviceId: deviceId,
          data: data,
          color: ColorPalette.getColor(i),
        ));
      }

      setState(() {
        devicesData = fetchedData;
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

  Map<String, Map<int, double>> calculateStatistics() {
    if (devicesData.isEmpty) {
      return {};
    }

    Map<int, List<double>> deviceValues = {};

    // Collect all values for each device
    for (var device in devicesData) {
      deviceValues[device.deviceId] = device.data
          .map((d) => getParameterValue(d, selectedParameter))
          .toList();
    }

    // Calculate statistics for each device
    Map<String, Map<int, double>> stats = {
      'max': {},
      'min': {},
      'avg': {},
    };

    for (var entry in deviceValues.entries) {
      final deviceId = entry.key;
      final values = entry.value;

      if (values.isNotEmpty) {
        stats['max']![deviceId] = values.reduce(max);
        stats['min']![deviceId] = values.reduce(min);
        stats['avg']![deviceId] =
            values.reduce((a, b) => a + b) / values.length;
      }
    }

    return stats;
  }

  Map<String, Map<String, double>> calculateDifferenceStatistics() {
    if (devicesData.length < 2) {
      return {};
    }

    Map<String, Map<String, double>> diffStats = {};

    // Compare each pair of devices
    for (int i = 0; i < devicesData.length - 1; i++) {
      for (int j = i + 1; j < devicesData.length; j++) {
        final deviceA = devicesData[i];
        final deviceB = devicesData[j];

        final length = min(deviceA.data.length, deviceB.data.length);

        if (length == 0) continue;

        double maxDiff = 0.0;
        double minDiff = double.infinity;
        double sumDiff = 0.0;

        for (int k = 0; k < length; k++) {
          final valueA = getParameterValue(deviceA.data[k], selectedParameter);
          final valueB = getParameterValue(deviceB.data[k], selectedParameter);
          final diff = (valueA - valueB).abs();

          if (diff > maxDiff) maxDiff = diff;
          if (diff < minDiff) minDiff = diff;
          sumDiff += diff;
        }

        final pairKey = '${deviceA.deviceId}-${deviceB.deviceId}';
        diffStats[pairKey] = {
          'maxDiff': maxDiff,
          'avgDiff': sumDiff / length,
          'minDiff': minDiff,
        };
      }
    }

    return diffStats;
  }

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
          if (!loading && devicesData.isNotEmpty && zoomLevel > 1.0)
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
            _buildDeviceSelector(),
            const SizedBox(height: 16),
            _buildParameterAndDateSelector(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: Text('Compare ${selectedDeviceIds.length} Devices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              onPressed: loading ? null : fetchComparisonData,
            ),
            const SizedBox(height: 24),
            if (loading) const CircularProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (!loading && devicesData.isNotEmpty) ...[
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

  Widget _buildDeviceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Devices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedDeviceIds.map((deviceId) {
                final index = selectedDeviceIds.indexOf(deviceId);
                final color = ColorPalette.getColor(index);
                return Chip(
                  label: Text(
                    'Device $deviceId',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: color,
                  deleteIcon:
                      const Icon(Icons.close, color: Colors.white, size: 18),
                  onDeleted: () => removeDevice(deviceId),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newDeviceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Add Device ID',
                      border: OutlineInputBorder(),
                      hintText: 'Enter device number',
                    ),
                    onSubmitted: (_) => addDevice(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: addDevice,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterAndDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: devicesData.map((device) {
        return _buildLegendItem('Device ${device.deviceId}', device.color);
      }).toList(),
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
    final diffStats = calculateDifferenceStatistics();
    final unit = parameterUnit(selectedParameter);
    final isWindDirection = selectedParameter == WeatherParameter.windDirection;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
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
            // Individual device statistics
            const Text(
              'Individual Device Values',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatSection('Maximum', stats['max'] ?? {}, unit, Colors.red),
            const SizedBox(height: 12),
            _buildStatSection('Average', stats['avg'] ?? {}, unit, Colors.blue),
            const SizedBox(height: 12),
            _buildStatSection(
                'Minimum', stats['min'] ?? {}, unit, Colors.green),

            // Difference statistics (only if 2+ devices)
            if (diffStats.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Device Comparison Differences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 12),
              _buildDifferenceStatistics(diffStats, unit),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatSection(
      String title, Map<int, double> values, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: values.entries.map((entry) {
            final deviceIndex = selectedDeviceIds.indexOf(entry.key);
            final deviceColor = ColorPalette.getColor(deviceIndex);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: deviceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: deviceColor.withOpacity(0.3)),
              ),
              child: Text(
                'Device ${entry.key}: ${entry.value.toStringAsFixed(2)} $unit',
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
        final pairKey = entry.key;
        final devices = pairKey.split('-');
        final deviceA = int.parse(devices[0]);
        final deviceB = int.parse(devices[1]);

        final maxDiff = entry.value['maxDiff']!;
        final avgDiff = entry.value['avgDiff']!;
        final minDiff = entry.value['minDiff']!;

        final indexA = selectedDeviceIds.indexOf(deviceA);
        final indexB = selectedDeviceIds.indexOf(deviceB);
        final colorA = ColorPalette.getColor(indexA);
        final colorB = ColorPalette.getColor(indexB);

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
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorA,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Device $deviceA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorA,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.compare_arrows,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorB,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Device $deviceB',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorB,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDiffStatItem(
                      'Max Diff',
                      maxDiff,
                      unit,
                      Colors.red,
                      Icons.trending_up,
                    ),
                    _buildDiffStatItem(
                      'Avg Diff',
                      avgDiff,
                      unit,
                      Colors.blue,
                      Icons.show_chart,
                    ),
                    _buildDiffStatItem(
                      'Min Diff',
                      minDiff,
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
      }).toList(),
    );
  }

  Widget _buildDiffStatItem(
      String label, double value, String unit, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(2)} $unit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWindDirectionInfo() {
    if (devicesData.isEmpty) {
      return const SizedBox.shrink();
    }

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
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: devicesData.map((device) {
            if (device.data.isEmpty) return const SizedBox.shrink();
            final latestDirection = device.data.last.windDirection;
            return _buildWindDirectionItem(
              'Device ${device.deviceId}',
              latestDirection,
              device.color,
            );
          }).toList(),
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
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
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
              clipBehavior: Clip.hardEdge,
              child: _buildChart(),
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

  Widget _buildChart() {
    if (devicesData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Find the maximum data length across all devices
    int maxLength = devicesData.map((d) => d.data.length).reduce(max);

    if (maxLength == 0) {
      return const Center(child: Text('No data points available'));
    }

    // Calculate visible range based on zoom and pan
    final visibleRange = maxLength / zoomLevel;
    final maxPanOffset = max(0.0, maxLength - visibleRange);
    final clampedPanOffset = panOffset.clamp(0.0, maxPanOffset);

    final minX = clampedPanOffset;
    final maxX = min(clampedPanOffset + visibleRange, maxLength.toDouble());

    // Create line data for each device
    List<LineChartBarData> lineBars = [];

    for (var device in devicesData) {
      final spots = <FlSpot>[];
      for (int i = 0; i < device.data.length; i++) {
        spots.add(
          FlSpot(i.toDouble(),
              getParameterValue(device.data[i], selectedParameter)),
        );
      }

      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: device.color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: zoomLevel > 3),
          belowBarData: BarAreaData(show: false),
        ),
      );
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
                ..onStart = (details) {
                  baseScale = zoomLevel;
                }
                ..onUpdate = (details) {
                  if (details.scale != 1.0) {
                    final newZoom = baseScale * details.scale;
                    setState(() {
                      zoomLevel = newZoom.clamp(minZoom, maxZoom);
                    });
                  }

                  if (details.focalPointDelta.dx.abs() > 0.1) {
                    final panSensitivity = maxLength / (400 * zoomLevel);
                    final newPan = (panOffset -
                            details.focalPointDelta.dx * panSensitivity)
                        .clamp(-0.5, max(0.0, maxLength - visibleRange) + 0.5);
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
                  zoomLevel = min(maxZoom, zoomLevel * 1.1);
                } else {
                  zoomLevel = max(minZoom, zoomLevel / 1.1);
                }
              });
            }
          },
          child: LineChart(
            LineChartData(
              clipData: const FlClipData.all(),
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
                      // Use the first device's timestamps as reference
                      if (devicesData.isNotEmpty &&
                          index >= 0 &&
                          index < devicesData[0].data.length) {
                        final time = DateFormat('HH:mm')
                            .format(devicesData[0].data[index].timeStamp);
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
                      final index = spot.x.toInt();

                      if (index < 0 || index >= device.data.length) return null;

                      final timestamp = DateFormat('dd-MM-yyyy HH:mm')
                          .format(device.data[index].timeStamp);
                      final value = getParameterValue(
                          device.data[index], selectedParameter);

                      String formatValue(double value) {
                        if (selectedParameter ==
                            WeatherParameter.windDirection) {
                          final direction = degreesToDirection(value);
                          final arrow = getWindArrow(value);
                          return '${value.toStringAsFixed(1)}° ($direction) $arrow';
                        }
                        return value.toStringAsFixed(1);
                      }

                      return LineTooltipItem(
                        '$timestamp\nDevice ${device.deviceId}: ${formatValue(value)}',
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
