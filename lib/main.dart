import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  // Zoom states for each chart
  final Map<String, double> zoomLevels = {};
  final Map<String, double> panOffsets = {};
  final Map<String, double> baseScales = {};

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      zoomLevels.clear();
      panOffsets.clear();
      baseScales.clear();
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
              _buildHeader(),
              const SizedBox(height: 20),
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
              if (errorMessage != null) _buildErrorMessage(),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              const SizedBox(height: 20),
              if (weatherData.isNotEmpty && !isLoading) ...[
                _buildZoomableChart(
                  'chart1',
                  'Rainfall vs Atmospheric Pressure',
                  Colors.blue,
                  Colors.purple,
                  'Rainfall (mm)',
                  'Pressure (hPa)',
                  (data) => data.rainfallHourly,
                  (data) => data.atmPressure,
                ),
                const SizedBox(height: 20),
                _buildZoomableChart(
                  'chart2',
                  'Rainfall vs Light Intensity',
                  Colors.blue,
                  Colors.amber,
                  'Rainfall (mm)',
                  'Light (lux)',
                  (data) => data.rainfallHourly,
                  (data) => data.lightIntensity,
                ),
                const SizedBox(height: 20),
                _buildZoomableChart(
                  'chart3',
                  'Rainfall vs Temperature',
                  Colors.blue,
                  Colors.red,
                  'Rainfall (mm)',
                  'Temperature (°C)',
                  (data) => data.rainfallHourly,
                  (data) => data.currentTemperature,
                ),
                const SizedBox(height: 20),
                _buildZoomableChart(
                  'chart4',
                  'Rainfall vs Humidity',
                  Colors.blue,
                  Colors.cyan,
                  'Rainfall (mm)',
                  'Humidity (%)',
                  (data) => data.rainfallHourly,
                  (data) => data.currentHumidity,
                ),
                const SizedBox(height: 20),
                _buildZoomableChart(
                  'chart5',
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

  Widget _buildZoomableChart(
    String chartId,
    String title,
    Color line1Color,
    Color line2Color,
    String leftLabel,
    String rightLabel,
    double Function(WeatherData) getValue1,
    double Function(WeatherData) getValue2,
  ) {
    zoomLevels.putIfAbsent(chartId, () => 1.0);
    panOffsets.putIfAbsent(chartId, () => 0.0);
    baseScales.putIfAbsent(chartId, () => 1.0);

    return ZoomableChartWidget(
      chartId: chartId,
      title: title,
      line1Color: line1Color,
      line2Color: line2Color,
      leftLabel: leftLabel,
      rightLabel: rightLabel,
      getValue1: getValue1,
      getValue2: getValue2,
      weatherData: weatherData,
      zoomLevel: zoomLevels[chartId]!,
      panOffset: panOffsets[chartId]!,
      onZoomChanged: (newZoom) {
        setState(() {
          zoomLevels[chartId] = newZoom;
        });
      },
      onPanChanged: (newPan) {
        setState(() {
          panOffsets[chartId] = newPan;
        });
      },
      onBaseScaleChanged: (newBase) {
        setState(() {
          baseScales[chartId] = newBase;
        });
      },
      baseScale: baseScales[chartId]!,
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

class ZoomableChartWidget extends StatefulWidget {
  final String chartId;
  final String title;
  final Color line1Color;
  final Color line2Color;
  final String leftLabel;
  final String rightLabel;
  final double Function(WeatherData) getValue1;
  final double Function(WeatherData) getValue2;
  final List<WeatherData> weatherData;
  final double zoomLevel;
  final double panOffset;
  final double baseScale;
  final Function(double) onZoomChanged;
  final Function(double) onPanChanged;
  final Function(double) onBaseScaleChanged;

  const ZoomableChartWidget({
    Key? key,
    required this.chartId,
    required this.title,
    required this.line1Color,
    required this.line2Color,
    required this.leftLabel,
    required this.rightLabel,
    required this.getValue1,
    required this.getValue2,
    required this.weatherData,
    required this.zoomLevel,
    required this.panOffset,
    required this.baseScale,
    required this.onZoomChanged,
    required this.onPanChanged,
    required this.onBaseScaleChanged,
  }) : super(key: key);

  @override
  State<ZoomableChartWidget> createState() => _ZoomableChartWidgetState();
}

class _ZoomableChartWidgetState extends State<ZoomableChartWidget> {
  @override
  Widget build(BuildContext context) {
    final spots1 = <FlSpot>[];
    final spots2Normalized = <FlSpot>[];
    final spots2Original = <FlSpot>[];

    for (int i = 0; i < widget.weatherData.length; i++) {
      spots1.add(FlSpot(i.toDouble(), widget.getValue1(widget.weatherData[i])));
      spots2Original
          .add(FlSpot(i.toDouble(), widget.getValue2(widget.weatherData[i])));
    }

    final values1 = widget.weatherData.map(widget.getValue1).toList();
    final values2 = widget.weatherData.map(widget.getValue2).toList();

    final minY1 = values1.reduce((a, b) => a < b ? a : b);
    final maxY1 = values1.reduce((a, b) => a > b ? a : b);
    final minY2 = values2.reduce((a, b) => a < b ? a : b);
    final maxY2 = values2.reduce((a, b) => a > b ? a : b);

    double adjustedMinY1, adjustedMaxY1;
    if (maxY1 - minY1 == 0) {
      adjustedMinY1 = minY1 - 1;
      adjustedMaxY1 = maxY1 + 1;
    } else {
      final y1Padding = (maxY1 - minY1) * 0.15;
      adjustedMinY1 = minY1 - y1Padding;
      adjustedMaxY1 = maxY1 + y1Padding;
    }

    for (var spot in spots2Original) {
      double normalized;
      if (maxY2 - minY2 == 0) {
        normalized = adjustedMinY1 + (adjustedMaxY1 - adjustedMinY1) * 0.75;
      } else {
        normalized = ((spot.y - minY2) / (maxY2 - minY2)) *
                (adjustedMaxY1 - adjustedMinY1) +
            adjustedMinY1;
      }
      spots2Normalized.add(FlSpot(spot.x, normalized));
    }

    final dataLength = widget.weatherData.length;
    final visibleRange = dataLength / widget.zoomLevel;
    final maxPanOffset =
        (dataLength - visibleRange).clamp(0.0, double.infinity);
    final clampedPanOffset = widget.panOffset.clamp(0.0, maxPanOffset);

    final minX = clampedPanOffset;
    final maxX =
        (clampedPanOffset + visibleRange).clamp(0.0, dataLength.toDouble());

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.zoomLevel > 1.0)
                IconButton(
                  icon: const Icon(Icons.zoom_out_map, size: 20),
                  tooltip: 'Reset Zoom',
                  onPressed: () {
                    widget.onZoomChanged(1.0);
                    widget.onPanChanged(0.0);
                    widget.onBaseScaleChanged(1.0);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: RawGestureDetector(
              gestures: {
                _PanZoomGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                    _PanZoomGestureRecognizer>(
                  () => _PanZoomGestureRecognizer(),
                  (_PanZoomGestureRecognizer instance) {
                    instance
                      ..onStart = (details) {
                        widget.onBaseScaleChanged(widget.zoomLevel);
                      }
                      ..onUpdate = (details) {
                        // Handle zoom
                        if (details.scale != 1.0) {
                          final newZoom = widget.baseScale * details.scale;
                          widget.onZoomChanged(newZoom.clamp(1.0, 10.0));
                        }

                        // Handle pan
                        if (details.focalPointDelta.dx.abs() > 0.1) {
                          final currentZoom = widget.zoomLevel;
                          final currentPan = widget.panOffset;
                          final currentVisibleRange = dataLength / currentZoom;
                          final currentMaxPanOffset =
                              (dataLength - currentVisibleRange)
                                  .clamp(0.0, double.infinity);
                          final panSensitivity =
                              dataLength / (400 * currentZoom);
                          final newPan = (currentPan -
                                  details.focalPointDelta.dx * panSensitivity)
                              .clamp(0.0, currentMaxPanOffset);
                          widget.onPanChanged(newPan);
                        }
                      }
                      ..onEnd = (details) {
                        widget.onBaseScaleChanged(widget.zoomLevel);
                      };
                  },
                ),
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final delta = pointerSignal.scrollDelta.dy;
                    final newZoom = delta < 0
                        ? (widget.zoomLevel * 1.1).clamp(1.0, 10.0)
                        : (widget.zoomLevel / 1.1).clamp(1.0, 10.0);
                    widget.onZoomChanged(newZoom);
                  }
                },
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
                            widget.rightLabel,
                            style: TextStyle(
                                fontSize: 10,
                                color: widget.line2Color,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          interval: (maxY2 - minY2) / 5,
                          getTitlesWidget: (value, meta) {
                            if (adjustedMaxY1 - adjustedMinY1 == 0) {
                              return const SizedBox.shrink();
                            }
                            final originalValue = ((value - adjustedMinY1) /
                                        (adjustedMaxY1 - adjustedMinY1)) *
                                    (maxY2 - minY2) +
                                minY2;

                            if (originalValue < minY2 - (maxY2 - minY2) * 0.2 ||
                                originalValue > maxY2 + (maxY2 - minY2) * 0.2) {
                              return const SizedBox.shrink();
                            }

                            return Text(
                              originalValue.toStringAsFixed(0),
                              style: TextStyle(
                                  fontSize: 10, color: widget.line2Color),
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
                          interval: (visibleRange / 10)
                              .ceilToDouble()
                              .clamp(1.0, double.infinity),
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < widget.weatherData.length) {
                              final time = DateFormat('HH:mm').format(
                                  widget.weatherData[value.toInt()].timeStamp);
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
                            widget.leftLabel,
                            style: TextStyle(
                                fontSize: 10,
                                color: widget.line1Color,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 10, color: widget.line1Color),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    minX: minX,
                    maxX: maxX,
                    minY: adjustedMinY1,
                    maxY: adjustedMaxY1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots1,
                        isCurved: true,
                        color: widget.line1Color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: widget.zoomLevel > 3),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: spots2Normalized,
                        isCurved: true,
                        color: widget.line2Color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: widget.zoomLevel > 3),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final index = barSpot.x.toInt();
                            if (index < 0 ||
                                index >= widget.weatherData.length) {
                              return null;
                            }

                            final timestamp = DateFormat('dd-MM-yyyy HH:mm')
                                .format(widget.weatherData[index].timeStamp);
                            final actualValue1 =
                                widget.getValue1(widget.weatherData[index]);
                            final actualValue2 =
                                widget.getValue2(widget.weatherData[index]);

                            if (barSpot.barIndex == 0) {
                              return LineTooltipItem(
                                '$timestamp\n${widget.leftLabel}: ${actualValue1.toStringAsFixed(1)}',
                                TextStyle(
                                    color: widget.line1Color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              );
                            } else {
                              return LineTooltipItem(
                                '$timestamp\n${widget.rightLabel}: ${actualValue2.toStringAsFixed(1)}',
                                TextStyle(
                                    color: widget.line2Color,
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
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(widget.leftLabel, widget.line1Color),
              const SizedBox(width: 24),
              _buildLegendItem(widget.rightLabel, widget.line2Color),
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
}

class _PanZoomGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}
