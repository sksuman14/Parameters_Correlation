import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:rainfall_dashboard/SensorComparisonPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rainfall Nowcasting Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const RainfallDashboard(),
    );
  }
}

class WeatherData {
  final DateTime timeStamp;
  final double atmPressure;
  final double lightIntensity;
  final double currentTemperature;
  final double windDirection;
  final double windSpeed;
  final double rainfallWeekly;
  final double rainfallDaily;
  final double batteryVoltage;
  final double currentHumidity;
  final double rainfallHourly;
  final double longitude;
  final double latitude;

  WeatherData({
    required this.timeStamp,
    required this.atmPressure,
    required this.lightIntensity,
    required this.currentTemperature,
    required this.windDirection,
    required this.windSpeed,
    required this.rainfallWeekly,
    required this.rainfallDaily,
    required this.batteryVoltage,
    required this.currentHumidity,
    required this.rainfallHourly,
    required this.longitude,
    required this.latitude,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      timeStamp: DateTime.parse(json['TimeStamp']),
      atmPressure: json['AtmPressure'].toDouble(),
      lightIntensity: json['LightIntensity'].toDouble(),
      currentTemperature: json['CurrentTemperature'].toDouble(),
      windDirection: json['WindDirection'].toDouble(),
      windSpeed: json['WindSpeed'].toDouble(),
      rainfallWeekly: json['RainfallWeekly'].toDouble(),
      rainfallDaily: json['RainfallDaily'].toDouble(),
      batteryVoltage: json['BatteryVoltage'].toDouble(),
      currentHumidity: json['CurrentHumidity'].toDouble(),
      rainfallHourly: json['RainfallHourly'].toDouble(),
      longitude: json['Longitude'].toDouble(),
      latitude: json['Latitude'].toDouble(),
    );
  }
}

class RainfallDashboard extends StatefulWidget {
  const RainfallDashboard({Key? key}) : super(key: key);

  @override
  State<RainfallDashboard> createState() => _RainfallDashboardState();
}

class _RainfallDashboardState extends State<RainfallDashboard> {
  List<WeatherData> weatherData = [];
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController startDateController =
      TextEditingController(text: '29-01-2026');
  final TextEditingController endDateController =
      TextEditingController(text: '29-01-2026');

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final startDate = startDateController.text;
      final endDate = endDateController.text;
      final url =
          'https://d3g5fo66jwc4iw.cloudfront.net/campusdata?deviceid=1&startdate=$startDate&enddate=$endDate';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        setState(() {
          weatherData =
              items.map((item) => WeatherData.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load data: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Date Controls
              _buildDateControls(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare Sensors'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SensorComparisonPage(),
                    ),
                  );
                },
              ),

              // Error Message
              if (errorMessage != null) _buildErrorMessage(),

              // Loading indicator
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Charts
              if (weatherData.isNotEmpty && !isLoading) ...[
                _buildChart(
                  'Rainfall vs Atmospheric Pressure',
                  Colors.blue,
                  Colors.purple,
                  'Rainfall (mm)',
                  'Pressure (hPa)',
                  (data) => data.rainfallHourly,
                  (data) => data.atmPressure,
                ),
                const SizedBox(height: 20),
                _buildChart(
                  'Rainfall vs Light Intensity',
                  Colors.blue,
                  Colors.amber,
                  'Rainfall (mm)',
                  'Light (lux)',
                  (data) => data.rainfallHourly,
                  (data) => data.lightIntensity,
                ),
                const SizedBox(height: 20),
                _buildChart(
                  'Rainfall vs Temperature',
                  Colors.blue,
                  Colors.red,
                  'Rainfall (mm)',
                  'Temperature (°C)',
                  (data) => data.rainfallHourly,
                  (data) => data.currentTemperature,
                ),
                const SizedBox(height: 20),
                _buildChart(
                  'Rainfall vs Humidity',
                  Colors.blue,
                  Colors.cyan,
                  'Rainfall (mm)',
                  'Humidity (%)',
                  (data) => data.rainfallHourly,
                  (data) => data.currentHumidity,
                ),
                const SizedBox(height: 20),
                _buildChart(
                  'Rainfall vs Wind Speed',
                  Colors.blue,
                  Colors.green,
                  'Rainfall (mm)',
                  'Wind Speed (m/s)',
                  (data) => data.rainfallHourly,
                  (data) => data.windSpeed,
                ),
              ],

              if (weatherData.isEmpty && !isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text(
                      'No data available. Please fetch data.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud, color: Colors.blue, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parameters Relation Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rainfall Correlation Analysis - Campus Sensor #1',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (weatherData.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'Location: ${weatherData.first.latitude.toStringAsFixed(4)}, ${weatherData.first.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: startDateController,
              decoration: const InputDecoration(
                labelText: 'Start Date',
                hintText: 'DD-MM-YYYY',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: endDateController,
              decoration: const InputDecoration(
                labelText: 'End Date',
                hintText: 'DD-MM-YYYY',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: isLoading ? null : fetchData,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(isLoading ? 'Loading...' : 'Fetch Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        errorMessage!,
        style: TextStyle(color: Colors.red.shade700),
      ),
    );
  }

  Widget _buildChart(
    String title,
    Color line1Color,
    Color line2Color,
    String leftLabel,
    String rightLabel,
    double Function(WeatherData) getValue1,
    double Function(WeatherData) getValue2,
  ) {
    final spots1 = <FlSpot>[];
    final spots2Normalized = <FlSpot>[];
    final spots2Original = <FlSpot>[];

    for (int i = 0; i < weatherData.length; i++) {
      spots1.add(FlSpot(i.toDouble(), getValue1(weatherData[i])));
      spots2Original.add(FlSpot(i.toDouble(), getValue2(weatherData[i])));
    }

    final values1 = weatherData.map(getValue1).toList();
    final values2 = weatherData.map(getValue2).toList();

    final minY1 = values1.reduce((a, b) => a < b ? a : b);
    final maxY1 = values1.reduce((a, b) => a > b ? a : b);
    final minY2 = values2.reduce((a, b) => a < b ? a : b);
    final maxY2 = values2.reduce((a, b) => a > b ? a : b);

    // Handle Y1 axis (rainfall) - add padding or default range if all zeros
    double adjustedMinY1, adjustedMaxY1;
    if (maxY1 - minY1 == 0) {
      // All values are the same (likely 0)
      adjustedMinY1 = minY1 - 1;
      adjustedMaxY1 = maxY1 + 1;
    } else {
      final y1Padding = (maxY1 - minY1) * 0.15;
      adjustedMinY1 = minY1 - y1Padding;
      adjustedMaxY1 = maxY1 + y1Padding;
    }

    // Normalize second line to fit on the same visual scale as first line
    for (var spot in spots2Original) {
      double normalized;
      if (maxY2 - minY2 == 0) {
        // If all values are the same, place at 75% height
        normalized = adjustedMinY1 + (adjustedMaxY1 - adjustedMinY1) * 0.75;
      } else {
        // Normalize to fit within Y1 axis range
        normalized = ((spot.y - minY2) / (maxY2 - minY2)) *
                (adjustedMaxY1 - adjustedMinY1) +
            adjustedMinY1;
      }
      spots2Normalized.add(FlSpot(spot.x, normalized));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        rightLabel,
                        style: TextStyle(
                            fontSize: 10,
                            color: line2Color,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: (maxY2 - minY2) / 5,
                      getTitlesWidget: (value, meta) {
                        // Convert normalized value back to original Y2 scale
                        if (adjustedMaxY1 - adjustedMinY1 == 0) {
                          return const SizedBox.shrink();
                        }
                        final originalValue = ((value - adjustedMinY1) /
                                    (adjustedMaxY1 - adjustedMinY1)) *
                                (maxY2 - minY2) +
                            minY2;

                        // Only show values within reasonable range
                        if (originalValue < minY2 - (maxY2 - minY2) * 0.2 ||
                            originalValue > maxY2 + (maxY2 - minY2) * 0.2) {
                          return const SizedBox.shrink();
                        }

                        return Text(
                          originalValue.toStringAsFixed(0),
                          style: TextStyle(fontSize: 10, color: line2Color),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: weatherData.length > 20
                          ? (weatherData.length / 10).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < weatherData.length) {
                          final time = DateFormat('HH:mm')
                              .format(weatherData[value.toInt()].timeStamp);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              time,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        leftLabel,
                        style: TextStyle(
                            fontSize: 10,
                            color: line1Color,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(fontSize: 10, color: line1Color),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                minX: 0,
                maxX: (weatherData.length - 1).toDouble(),
                minY: adjustedMinY1,
                maxY: adjustedMaxY1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots1,
                    isCurved: true,
                    color: line1Color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: spots2Normalized,
                    isCurved: true,
                    color: line2Color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final index = barSpot.x.toInt();
                        if (index < 0 || index >= weatherData.length) {
                          return null;
                        }

                        final timestamp = DateFormat('dd-MM-yyyy HH:mm')
                            .format(weatherData[index].timeStamp);
                        final actualValue1 = getValue1(weatherData[index]);
                        final actualValue2 = getValue2(weatherData[index]);

                        if (barSpot.barIndex == 0) {
                          return LineTooltipItem(
                            '$timestamp\n$leftLabel: ${actualValue1.toStringAsFixed(1)}',
                            TextStyle(
                                color: line1Color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          );
                        } else {
                          return LineTooltipItem(
                            '$timestamp\n$rightLabel: ${actualValue2.toStringAsFixed(1)}',
                            TextStyle(
                                color: line2Color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          );
                        }
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(leftLabel, line1Color),
              const SizedBox(width: 24),
              _buildLegendItem(rightLabel, line2Color),
            ],
          ),
        ],
      ),
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

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }
}
