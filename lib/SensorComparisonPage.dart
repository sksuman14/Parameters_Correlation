import 'dart:convert';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ════════════════════════════════════════════════════════════
//  SENSOR TYPE
// ════════════════════════════════════════════════════════════

enum SensorType { cp, sw, wj, wm, jw }

String sensorTypeLabel(SensorType t) {
  switch (t) {
    case SensorType.cp:
      return 'CP';
    case SensorType.sw:
      return 'SW';
    case SensorType.wj:
      return 'WJ';
    case SensorType.wm:
      return 'WM';
    case SensorType.jw:
      return 'JW';
  }
}

// ════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════

class WeatherData {
  final DateTime timeStamp;
  final double atmPressure;
  final double currentTemperature;
  final double currentHumidity;
  final double windSpeed;
  final double rainfallHourly;
  final double windDirection;
  final double lightIntensity;

  WeatherData({
    required this.timeStamp,
    required this.atmPressure,
    required this.currentTemperature,
    required this.currentHumidity,
    required this.windSpeed,
    required this.rainfallHourly,
    required this.windDirection,
    required this.lightIntensity,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final rawTs = (json['TimeStamp'] ??
            json['timestamp'] ??
            json['Time_Stamp'] ??
            json['created_at'] ??
            json['datetime'] ??
            json['time'] ??
            json['Date'] ??
            '')
        .toString()
        .trim();
    final normTs = rawTs.replaceFirst(RegExp(r' (?=\d{2}:\d{2})'), 'T');

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(normTs);
    } catch (e) {
      throw FormatException(
          'Invalid date format: "$rawTs". Available keys: ${json.keys.join(', ')}');
    }

    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    double ws = 0.0;
    if (json['WindSpeed'] != null) {
      ws = parseD(json['WindSpeed']);
    } else if (json['now_wind_speed'] != null) {
      ws = parseD(json['now_wind_speed']) * 0.514444; // knots to m/s
    }

    return WeatherData(
      timeStamp: parsedDate,
      atmPressure: parseD(
          json['AtmPressure'] ?? json['pressure'] ?? json['now_pressure']),
      currentTemperature:
          parseD(json['CurrentTemperature'] ?? json['now_temperature']),
      currentHumidity:
          parseD(json['CurrentHumidity'] ?? json['now_relative_humidity']),
      windSpeed: ws,
      rainfallHourly: parseD(json['RainfallHourly'] ?? json['rainfall']),
      windDirection:
          parseD(json['WindDirection'] ?? json['now_wind_direction']),
      lightIntensity: parseD(json['LightIntensity'] ?? json['now_light']),
    );
  }
}

class IMDData {
  final DateTime timeStamp;
  final double currTemp;
  final double minTemp;
  final double maxTemp;
  final double relativeHumidity;
  final double mslp;
  final double windSpeed;
  final double windDirection;
  final String station;

  IMDData({
    required this.timeStamp,
    required this.currTemp,
    required this.minTemp,
    required this.maxTemp,
    required this.relativeHumidity,
    required this.mslp,
    required this.windSpeed,
    required this.windDirection,
    required this.station,
  });

  factory IMDData.fromJson(Map<String, dynamic> json) {
    final rawTs = (json['Timestamp'] ?? '').toString().trim();
    final normTs = rawTs.replaceFirst(RegExp(r' (?=\d{2}:\d{2})'), 'T');
    double p(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return IMDData(
      timeStamp: DateTime.parse(normTs),
      currTemp: p(json['CURR_TEMP']),
      minTemp: p(json['MIN_TEMP']),
      maxTemp: p(json['MAX_TEMP']),
      relativeHumidity: p(json['RH']),
      mslp: p(json['MSLP']),
      windSpeed: p(json['WIND_SPEED']),
      windDirection: p(json['WIND_DIRECTION']),
      station: (json['STATION'] ?? '').toString(),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  ENUMS & HELPERS
// ════════════════════════════════════════════════════════════

enum WeatherParameter {
  temperature,
  humidity,
  pressure,
  windSpeed,
  rainfall,
  windDirection
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

enum IMDCompareParameter {
  temperature,
  humidity,
  pressure,
  windSpeed,
  windDirection
}

String imdParamLabel(IMDCompareParameter p) {
  switch (p) {
    case IMDCompareParameter.temperature:
      return 'Temperature (°C)';
    case IMDCompareParameter.humidity:
      return 'Humidity (%)';
    case IMDCompareParameter.pressure:
      return 'Pressure (hPa)';
    case IMDCompareParameter.windSpeed:
      return 'Wind Speed (m/s)';
    case IMDCompareParameter.windDirection:
      return 'Wind Direction (°)';
  }
}

String imdParamUnit(IMDCompareParameter p) {
  switch (p) {
    case IMDCompareParameter.temperature:
      return '°C';
    case IMDCompareParameter.humidity:
      return '%';
    case IMDCompareParameter.pressure:
      return 'hPa';
    case IMDCompareParameter.windSpeed:
      return 'm/s';
    case IMDCompareParameter.windDirection:
      return '°';
  }
}

String degreesToDirection(double degrees) {
  double n = degrees % 360;
  if (n < 0) n += 360;
  if (n >= 348.75 || n < 11.25) return 'N';
  if (n < 33.75) return 'NNE';
  if (n < 56.25) return 'NE';
  if (n < 78.75) return 'ENE';
  if (n < 101.25) return 'E';
  if (n < 123.75) return 'ESE';
  if (n < 146.25) return 'SE';
  if (n < 168.75) return 'SSE';
  if (n < 191.25) return 'S';
  if (n < 213.75) return 'SSW';
  if (n < 236.25) return 'SW';
  if (n < 258.75) return 'WSW';
  if (n < 281.25) return 'W';
  if (n < 303.75) return 'WNW';
  if (n < 326.25) return 'NW';
  return 'NNW';
}

String getWindArrow(double degrees) {
  double n = degrees % 360;
  if (n < 0) n += 360;
  if (n >= 348.75 || n < 11.25) return '↓';
  if (n < 56.25) return '↙';
  if (n < 78.75) return '↙';
  if (n < 101.25) return '←';
  if (n < 146.25) return '↖';
  if (n < 168.75) return '↖';
  if (n < 191.25) return '↑';
  if (n < 236.25) return '↗';
  if (n < 258.75) return '↗';
  if (n < 281.25) return '→';
  if (n < 326.25) return '↘';
  return '↘';
}

int _detectIntervalMinutes(List<WeatherData> data) {
  if (data.length < 2) return 5; // default

  final diffs = <int>[];
  for (int i = 1; i < data.length && i <= 10; i++) {
    final diff =
        data[i].timeStamp.difference(data[i - 1].timeStamp).inMinutes.abs();
    if (diff > 0) diffs.add(diff);
  }
  if (diffs.isEmpty) return 5;
  diffs.sort();
  return diffs[diffs.length ~/ 2]; // median
}

const int _kCorrectionWindowHours =
    12; // Expanded window to 24h to capture daily min effectively

List<double> applyThermalCorrection(List<WeatherData> data) {
  final result = <double>[];
  if (data.isEmpty) return result;

  final intervalMinutes = _detectIntervalMinutes(data);
  final windowSize =
      (_kCorrectionWindowHours * 60 / intervalMinutes).round().clamp(6, 1000);

  // 1-hour short window for heating rate
  final shortWindow = (60 / intervalMinutes).round().clamp(1, 100);

  for (int i = 0; i < data.length; i++) {
    // 12-hour rolling min — ab raat ka temp bhi capture hoga
    final start = (i - windowSize + 1).clamp(0, i);
    double rollingMin = data[i].currentTemperature;
    for (int j = start; j <= i; j++) {
      if (data[j].currentTemperature < rollingMin)
        rollingMin = data[j].currentTemperature;
    }

    final heatAcc = (data[i].currentTemperature - rollingMin).clamp(0.0, 25.0);

    // Sirf positive rate of change (heating phase boost)
    final lookback = (i - shortWindow).clamp(0, i);
    final dTRecent =
        (data[i].currentTemperature - data[lookback].currentTemperature)
            .clamp(0.0, 15.0);

    final humidity = data[i].currentHumidity;
    final light = data[i].lightIntensity.clamp(0.0, 120000.0);
    final wind = data[i].windSpeed.clamp(0.0, 25.0);

    // Blend thermal accumulation and direct light intensity
    final baseCorrection = (0.14 * heatAcc + 0.000035 * light) +
        0.15 * dTRecent +
        (-0.02) * humidity +
        0.6;

    // Wind cooling: reduces the enclosure heat trap effect
    final windCoolingFactor = (1.0 / (1.0 + 0.04 * wind)).clamp(0.65, 1.0);

    final correction = baseCorrection * windCoolingFactor;

    final corrected = data[i].currentTemperature - correction;
    result.add(corrected < data[i].currentTemperature - 6.0
        ? data[i].currentTemperature - 6.0
        : corrected);
  }
  return result;
}

/// True if this device is CP 39 (the one with enclosure heat-trap issue).
bool isCp39(DeviceData d) => d.sensorType == SensorType.cp && d.deviceId == 39;

/// Accent color for the corrected series line.
const Color _kCorrectedColor = Color(0xFF3FB950); // same as _kGreen

// ════════════════════════════════════════════════════════════
//  SENSOR ENTRY
// ════════════════════════════════════════════════════════════

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

// ════════════════════════════════════════════════════════════
//  DEVICE DATA
// ════════════════════════════════════════════════════════════

class DeviceData {
  final int deviceId;
  final SensorType sensorType;
  final List<WeatherData> data;
  final Color color;

  /// Sorted copy + precomputed corrected temperatures (for CP 39 only).
  late final List<WeatherData> sortedData;
  late final List<double>? correctedTemperatures;

  DeviceData({
    required this.deviceId,
    required this.sensorType,
    required this.data,
    required this.color,
  }) {
    sortedData = [...data]..sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
    correctedTemperatures =
        isCp39(this) ? applyThermalCorrection(sortedData) : null;
  }

  String get key => '${sensorTypeLabel(sensorType)}_$deviceId';
  String get label => '${sensorTypeLabel(sensorType)} Device $deviceId';
}

// ════════════════════════════════════════════════════════════
//  MATCHED DATA POINT
// ════════════════════════════════════════════════════════════

class MatchedDataPoint {
  final DateTime timestamp;
  final Map<String, WeatherData> deviceData;
  MatchedDataPoint({required this.timestamp, required this.deviceData});
}

// ════════════════════════════════════════════════════════════
//  TIMESTAMP MATCHER
// ════════════════════════════════════════════════════════════

class TimestampMatcher {
  static DateTime _bucket(DateTime dt, {int bucketMinutes = 5}) {
    final m = (dt.minute ~/ bucketMinutes) * bucketMinutes;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, m, 0);
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
    final int required = devicesData.length;
    final List<MatchedDataPoint> result = [];
    final sorted = bucketMap.keys.toList()..sort();
    for (final b in sorted) {
      if (bucketMap[b]!.length >= required) {
        result.add(MatchedDataPoint(timestamp: b, deviceData: bucketMap[b]!));
      }
    }
    return result;
  }
}

// ════════════════════════════════════════════════════════════
//  COLOR PALETTE — Precision Instrument Dark Theme
// ════════════════════════════════════════════════════════════

class ColorPalette {
  static const List<Color> chartColors = [
    Color(0xFF00E5FF),
    Color(0xFFFF8F00),
    Color(0xFFFF00FF),
    Color(0xFFFFFF00),
    Color(0xFF2979FF),
    Color(0xFF00E676),
    Color(0xFFFF1744),
    Color(0xFFD500F9),
    Color(0xFFFFAB00),
    Color(0xFF00B0FF),
    Color(0xFFAEEA00),
    Color(0xFF3D5AFE),
    Color(0xFFFF3D00),
    Color(0xFF1DE9B6),
  ];
  static Color getColor(int index) => chartColors[index % chartColors.length];
}

// ════════════════════════════════════════════════════════════
//  API BUILDERS
// ════════════════════════════════════════════════════════════

String buildApiUrl({
  required int deviceId,
  required SensorType sensorType,
  required String startDate,
  required String endDate,
}) {
  switch (sensorType) {
    case SensorType.sw:
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet1225data'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
    case SensorType.wj:
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet0126data'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
    case SensorType.cp:
      if (deviceId == 1 || deviceId == 3) {
        return 'https://d3g5fo66jwc4iw.cloudfront.net/campusdata'
            '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
      } else {
        return 'https://d3dj66m23j48gu.cloudfront.net/campusdata'
            '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
      }
    case SensorType.wm:
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/annam0526data'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
    case SensorType.jw:
      return 'https://5x7thxo9uk.execute-api.us-east-1.amazonaws.com/default/WS_WINDS_JIO_Logger_API'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate';
  }
}

String buildDownloadApiUrl({
  required int deviceId,
  required SensorType sensorType,
  required String startDate,
  required String endDate,
}) {
  switch (sensorType) {
    case SensorType.sw:
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet1225data'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate&mode=download';
    case SensorType.wj:
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/wjmetdata'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate&mode=download';
    case SensorType.cp:
      return 'https://i1g1n1ufu0.execute-api.us-east-1.amazonaws.com/campusdata'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate&mode=download';
    case SensorType.wm:
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/annam0526data'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate&mode=download';
    case SensorType.jw:
      return 'https://5x7thxo9uk.execute-api.us-east-1.amazonaws.com/default/WS_WINDS_JIO_Logger_API'
          '?deviceid=$deviceId&startdate=$startDate&enddate=$endDate&mode=download';
  }
}

// ════════════════════════════════════════════════════════════
//  CSV PARSER
// ════════════════════════════════════════════════════════════

class _RawCsvData {
  final Map<String, Map<String, String>> rows;
  final List<String> columns;
  _RawCsvData({required this.rows, required this.columns});
}

_RawCsvData _parseSensorCsv(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  while (lines.isNotEmpty && lines.last.trim().isEmpty) lines.removeLast();
  if (lines.isEmpty) return _RawCsvData(rows: {}, columns: []);

  final headers = _splitCsvLine(lines[0]);
  final tsIndex = headers.indexWhere((h) {
    final l = h.trim().toLowerCase();
    return l.contains('timestamp') || l == 'time' || l == 'datetime';
  });
  final effectiveTsIndex = tsIndex >= 0 ? tsIndex : 0;
  final dataColumns = <String>[];
  for (int i = 0; i < headers.length; i++) {
    if (i != effectiveTsIndex) dataColumns.add(headers[i].trim());
  }

  final Map<String, Map<String, String>> rows = {};
  for (int li = 1; li < lines.length; li++) {
    final line = lines[li].trim();
    if (line.isEmpty) continue;
    final cells = _splitCsvLine(line);
    if (cells.length <= effectiveTsIndex) continue;
    final ts = cells[effectiveTsIndex].trim();
    final rowMap = <String, String>{};
    for (int ci = 0; ci < headers.length; ci++) {
      if (ci == effectiveTsIndex) continue;
      rowMap[headers[ci].trim()] = ci < cells.length ? cells[ci].trim() : '';
    }
    rows[ts] = rowMap;
  }
  return _RawCsvData(rows: rows, columns: dataColumns);
}

List<String> _splitCsvLine(String line) {
  final result = <String>[];
  final sb = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        sb.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      result.add(sb.toString());
      sb.clear();
    } else {
      sb.write(ch);
    }
  }
  result.add(sb.toString());
  return result;
}

// ════════════════════════════════════════════════════════════
//  IMD BUCKET HELPER
// ════════════════════════════════════════════════════════════

WeatherData? _bucketSW15(List<WeatherData> raw, DateTime bucket) {
  final window = raw.where((d) {
    final diff = d.timeStamp.difference(bucket).inMinutes;
    return diff >= 0 && diff < 15;
  }).toList();
  if (window.isEmpty) return null;
  double avg(double Function(WeatherData) f) =>
      window.map(f).reduce((a, b) => a + b) / window.length;
  return WeatherData(
    timeStamp: bucket,
    atmPressure: avg((d) => d.atmPressure),
    currentTemperature: avg((d) => d.currentTemperature),
    currentHumidity: avg((d) => d.currentHumidity),
    windSpeed: avg((d) => d.windSpeed),
    rainfallHourly: avg((d) => d.rainfallHourly),
    windDirection: avg((d) => d.windDirection),
    lightIntensity: avg((d) => d.lightIntensity),
  );
}

// ════════════════════════════════════════════════════════════
//  CUSTOM GESTURE RECOGNIZER
// ════════════════════════════════════════════════════════════

class _PanZoomGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) => acceptGesture(pointer);
}

// ════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ════════════════════════════════════════════════════════════

const _kBg = Color(0xFF0D1117);
const _kSurface = Color(0xFF161B22);
const _kSurfaceElevated = Color(0xFF1C2333);
const _kBorder = Color(0xFF30363D);
const _kBorderAccent = Color(0xFF3D4A5C);
const _kPrimary = Color(0xFF00D4B8);
const _kPrimaryDim = Color(0xFF00D4B820);
const _kImdColor = Color(0xFF6C8EEF);
const _kImdDim = Color(0xFF6C8EEF20);
const _kTextPrimary = Color(0xFFE6EDF3);
const _kTextSecondary = Color(0xFF8B949E);
const _kTextTertiary = Color(0xFF484F58);
const _kTextMono = Color(0xFF00D4B8);
const _kRed = Color(0xFFFF6B6B);
const _kGreen = Color(0xFF3FB950);
const _kAmber = Color(0xFFFFB020);
const _kPurple = Color(0xFFE07FFF);

const _kRadius = BorderRadius.all(Radius.circular(10));
const _kRadiusSm = BorderRadius.all(Radius.circular(7));
const _kRadiusXs = BorderRadius.all(Radius.circular(4));

// ════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 11,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kTextSecondary,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
}

class _AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  const _AppCard({required this.child, this.padding, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: _kRadius,
          border: Border.all(color: borderColor ?? _kBorder, width: 1),
        ),
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: _kRadiusSm,
          border: Border.all(color: color.withOpacity(0.18), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: _kTextPrimary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
                fontFamily: 'monospace',
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      );
}

class _SensorChip extends StatelessWidget {
  final SensorEntry sensor;
  final Color color;
  final VoidCallback onRemove;
  const _SensorChip(
      {required this.sensor, required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                sensorTypeLabel(sensor.sensorType),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1117),
                  letterSpacing: 0.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              sensor.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 10, color: color),
              ),
            ),
          ],
        ),
      );
}

Widget _legendDot(String label, Color color, {bool dashed = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          Row(children: [
            Container(width: 6, height: 2, color: color),
            const SizedBox(width: 3),
            Container(width: 6, height: 2, color: color),
            const SizedBox(width: 3),
            Container(width: 4, height: 2, color: color),
          ])
        else
          Container(
            width: 20,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        const SizedBox(width: 5),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _kTextSecondary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );

Widget _sectionDivider(String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kTextSecondary,
              letterSpacing: 0.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: _kBorder, thickness: 1)),
        ],
      ),
    );

// ════════════════════════════════════════════════════════════
//  CORRECTION TOGGLE WIDGET  ← NEW
// ════════════════════════════════════════════════════════════

class _CorrectionToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CorrectionToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value ? _kCorrectedColor.withOpacity(0.07) : _kBg,
        borderRadius: _kRadiusSm,
        border: Border.all(
          color: value ? _kCorrectedColor.withOpacity(0.4) : _kBorderAccent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon area
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  (value ? _kCorrectedColor : _kTextTertiary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.auto_fix_high_outlined,
              size: 14,
              color: value ? _kCorrectedColor : _kTextTertiary,
            ),
          ),
          const SizedBox(width: 12),
          // Text area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Thermal Correction',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: value ? _kCorrectedColor : _kTextPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kCorrectedColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: _kCorrectedColor.withOpacity(0.3), width: 1),
                      ),
                      child: const Text(
                        'CP 39',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _kCorrectedColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Toggle switch
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _kCorrectedColor,
            activeTrackColor: _kCorrectedColor.withOpacity(0.25),
            inactiveThumbColor: _kTextTertiary,
            inactiveTrackColor: _kBorder,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SENSOR SELECTOR WIDGET
// ════════════════════════════════════════════════════════════

class _SensorSelectorWidget extends StatefulWidget {
  final List<SensorEntry> sensors;
  final void Function(SensorEntry) onAdd;
  final void Function(SensorEntry) onRemove;

  const _SensorSelectorWidget({
    required this.sensors,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_SensorSelectorWidget> createState() => _SensorSelectorWidgetState();
}

class _SensorSelectorWidgetState extends State<_SensorSelectorWidget> {
  SensorType _addType = SensorType.cp;
  final _controller = TextEditingController();

  void _add() {
    final id = int.tryParse(_controller.text);
    if (id == null) return;
    widget.onAdd(SensorEntry(deviceId: id, sensorType: _addType));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Sensors'),
        const SizedBox(height: 12),
        if (widget.sensors.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.sensors
                .asMap()
                .entries
                .map((e) => _SensorChip(
                      sensor: e.value,
                      color: ColorPalette.getColor(e.key),
                      onRemove: () => widget.onRemove(e.value),
                    ))
                .toList(),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _kBorder),
                borderRadius: _kRadiusSm,
                color: _kBg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: SensorType.values.map((type) {
                  final selected = _addType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _addType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? _kPrimary : Colors.transparent,
                        borderRadius: _kRadiusSm,
                      ),
                      child: Text(
                        sensorTypeLabel(type),
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF0D1117)
                              : _kTextSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextPrimary,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  hintText: 'Device ID',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: _kTextTertiary,
                      fontFamily: 'monospace'),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: _kBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: _kRadiusSm,
                    borderSide: BorderSide(color: _kBorder, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: _kRadiusSm,
                    borderSide: BorderSide(color: _kPrimary, width: 1),
                  ),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _add,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  borderRadius: _kRadiusSm,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF0D1117)),
                    SizedBox(width: 5),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1117),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════
//  DATE RANGE SELECTOR WIDGET
// ════════════════════════════════════════════════════════════

class _DateRangeSelector extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DateRangeSelector({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Date Range'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _dateTile('FROM', startDate, onPickStart)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.arrow_forward,
                    size: 12, color: _kTextSecondary),
              ),
            ),
            Expanded(child: _dateTile('TO', endDate, onPickEnd)),
          ],
        ),
      ],
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: _kRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kBg,
          border: Border.all(color: _kBorder, width: 1),
          borderRadius: _kRadiusSm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  size: 12, color: _kPrimary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: _kTextTertiary,
                    letterSpacing: 1.0,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  CHART WIDGET
// ════════════════════════════════════════════════════════════

class _ChartLegendItem {
  final String label;
  final Color color;
  final bool dashed;
  const _ChartLegendItem(
      {required this.label, required this.color, this.dashed = false});
}

class _ChartWidget extends StatefulWidget {
  final String title;
  final List<LineChartBarData> lineBars;
  final List<_ChartLegendItem> legend;
  final DateTime globalMin;
  final double totalMinutes;
  final List<LineTooltipItem?> Function(List<LineBarSpot>) getTooltipItems;

  const _ChartWidget({
    required this.title,
    required this.lineBars,
    required this.legend,
    required this.globalMin,
    required this.totalMinutes,
    required this.getTooltipItems,
  });

  @override
  State<_ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<_ChartWidget> {
  double _zoom = 1.0;
  double _pan = 0.0;
  double _baseZoom = 1.0;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  void _resetZoom() => setState(() {
        _zoom = 1.0;
        _pan = 0.0;
        _baseZoom = 1.0;
      });

  @override
  Widget build(BuildContext context) {
    final total = widget.totalMinutes < 1.0 ? 1.0 : widget.totalMinutes;
    final visible = total / _zoom;
    final maxPan = max(0.0, total - visible);
    final clampedPan = _pan.clamp(0.0, maxPan);
    final minX = clampedPan;
    final maxX = (clampedPan + visible).clamp(minX, total);

    double allYMin = double.infinity;
    double allYMax = double.negativeInfinity;
    for (final bar in widget.lineBars) {
      for (final s in bar.spots) {
        if (s.y < allYMin) allYMin = s.y;
        if (s.y > allYMax) allYMax = s.y;
      }
    }
    if (allYMin == double.infinity) {
      allYMin = 0;
      allYMax = 10;
    }
    if (allYMin == allYMax) {
      allYMin -= 5;
      allYMax += 5;
    }
    final pad = (allYMax - allYMin) * 0.08;

    return _AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 2,
                    height: 14,
                    decoration: BoxDecoration(
                      color: widget.lineBars.isNotEmpty
                          ? (widget.lineBars.first.color ?? _kPrimary)
                          : _kPrimary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              if (_zoom > 1.0)
                GestureDetector(
                  onTap: _resetZoom,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: _kPrimary.withOpacity(0.3), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_out_map, size: 12, color: _kPrimary),
                        SizedBox(width: 4),
                        Text('Reset',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kPrimary,
                              fontFamily: 'monospace',
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: RawGestureDetector(
              gestures: {
                _PanZoomGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                    _PanZoomGestureRecognizer>(
                  () => _PanZoomGestureRecognizer(),
                  (instance) {
                    instance
                      ..onStart = (_) {
                        _baseZoom = _zoom;
                      }
                      ..onUpdate = (details) {
                        if (details.scale != 1.0) {
                          setState(() => _zoom = (_baseZoom * details.scale)
                              .clamp(_minZoom, _maxZoom));
                        }
                        if (details.focalPointDelta.dx.abs() > 0.1 &&
                            _zoom > 1.0) {
                          final sensitivity = total / (400 * _zoom);
                          final newPan =
                              (_pan - details.focalPointDelta.dx * sensitivity)
                                  .clamp(0.0, max(0.0, total - visible))
                                  .toDouble();
                          setState(() => _pan = newPan);
                        }
                      }
                      ..onEnd = (_) {
                        _baseZoom = _zoom;
                      };
                  },
                ),
              },
              child: Listener(
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent &&
                      HardwareKeyboard.instance.isShiftPressed) {
                    GestureBinding.instance.pointerSignalResolver
                        .register(signal, (event) {
                      if (event is PointerScrollEvent) {
                        setState(() {
                          _zoom = event.scrollDelta.dy < 0
                              ? min(_maxZoom, _zoom * 1.1)
                              : max(_minZoom, _zoom / 1.1);
                        });
                      }
                    });
                  }
                },
                child: LineChart(
                  LineChartData(
                    clipData: const FlClipData.all(),
                    minX: minX,
                    maxX: maxX,
                    minY: allYMin - pad,
                    maxY: allYMax + pad,
                    backgroundColor: _kBg,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFF21262D), strokeWidth: 1),
                      getDrawingVerticalLine: (_) => const FlLine(
                          color: Color(0xFF21262D), strokeWidth: 1),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: _kBorder, width: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (v, _) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              v.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10,
                                color: _kTextPrimary,
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: max(1.0, (visible / 8).ceilToDouble()),
                          getTitlesWidget: (v, _) {
                            final t = widget.globalMin
                                .add(Duration(seconds: (v * 60).round()));
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('HH:mm').format(t),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _kTextPrimary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: widget.lineBars,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            _kSurfaceElevated.withOpacity(0.8),
                        tooltipMargin: 20,
                        tooltipBorder:
                            const BorderSide(color: _kBorderAccent, width: 1),
                        tooltipRoundedRadius: 7,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: widget.getTooltipItems,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: widget.legend
                .map((l) => _legendDot(l.label, l.color, dashed: l.dashed))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  MAIN PAGE
// ════════════════════════════════════════════════════════════

class SensorComparisonPage extends StatefulWidget {
  const SensorComparisonPage({Key? key}) : super(key: key);

  @override
  State<SensorComparisonPage> createState() => _SensorComparisonPageState();
}

class _SensorComparisonPageState extends State<SensorComparisonPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isImdTab => _tabController.index == 1;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        backgroundColor: _kSurfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: _kRadiusSm,
          side: const BorderSide(color: _kBorder),
        ),
      ));

  // ── Sensor-vs-Sensor state ────────────────────────────────────────────────
  List<SensorEntry> _sensors = [
    SensorEntry(deviceId: 1, sensorType: SensorType.cp),
    SensorEntry(deviceId: 2, sensorType: SensorType.cp),
  ];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<WeatherParameter> _selectedParams = [WeatherParameter.temperature];

  List<DeviceData> _devicesData = [];
  List<MatchedDataPoint> _matched = [];
  bool _loading = false;
  bool _csvLoading = false;
  String? _error;

  DateTime? _globalMinTime;
  double _totalMinutes = 0.0;

  /// NEW: thermal correction toggle state
  bool _showCorrected = false;

  // ── IMD state ─────────────────────────────────────────────────────────────
  List<SensorEntry> _imdSensors = [
    SensorEntry(deviceId: 7, sensorType: SensorType.sw)
  ];
  DateTime _imdStart = DateTime.now();
  DateTime _imdEnd = DateTime.now();
  List<IMDCompareParameter> _imdParams = [IMDCompareParameter.temperature];
  List<IMDData> _imdData = [];
  Map<String, List<WeatherData>> _imdRawData = {};
  Map<String, List<WeatherData>> _imdBucketedData = {};
  bool _imdLoading = false;
  bool _imdCsvLoading = false;
  String? _imdError;
  DateTime? _imdGlobalMin;
  double _imdTotalMinutes = 0.0;
  static const String _imdStationId = 'CGDAC000';

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtApi(DateTime d) => DateFormat('dd-MM-yyyy').format(d);
  String _fmtImdApi(DateTime d) => DateFormat('d-M-yyyy').format(d);

  /// Returns true if any loaded device is CP 39 and temp param is selected.
  bool get _canShowCorrection =>
      _devicesData.any(isCp39) &&
      _selectedParams.contains(WeatherParameter.temperature);

  Future<void> _pickDate(bool isStart, {bool imd = false}) async {
    final current = imd
        ? (isStart ? _imdStart : _imdEnd)
        : (isStart ? _startDate : _endDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kPrimary,
            onPrimary: Color(0xFF0D1117),
            surface: _kSurface,
            onSurface: _kTextPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (imd) {
        if (isStart)
          _imdStart = picked;
        else
          _imdEnd = picked;
      } else {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      }
    });
  }

  // ── Sensor-vs-Sensor fetch ────────────────────────────────────────────────

  Future<void> _fetchSensorData() async {
    if (_sensors.isEmpty) {
      _snack('Add at least one sensor');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _showCorrected = false; // reset on fresh fetch
    });
    try {
      final start = _fmtApi(_startDate);
      final end = _fmtApi(_endDate);
      final List<DeviceData> fetched = [];
      for (int i = 0; i < _sensors.length; i++) {
        final s = _sensors[i];
        final url = buildApiUrl(
            deviceId: s.deviceId,
            sensorType: s.sensorType,
            startDate: start,
            endDate: end);
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode != 200)
          throw Exception('${s.label} failed (HTTP ${resp.statusCode})');
        final body = json.decode(resp.body);
        final items = body['items'] as List;
        fetched.add(DeviceData(
          deviceId: s.deviceId,
          sensorType: s.sensorType,
          data: items.map((e) => WeatherData.fromJson(e)).toList(),
          color: ColorPalette.getColor(i),
        ));
      }
      final matched = TimestampMatcher.matchTimestamps(fetched);
      DateTime? earliest, latest;
      for (final d in fetched) {
        for (final w in d.data) {
          if (earliest == null || w.timeStamp.isBefore(earliest))
            earliest = w.timeStamp;
          if (latest == null || w.timeStamp.isAfter(latest))
            latest = w.timeStamp;
        }
      }
      setState(() {
        _devicesData = fetched;
        _matched = matched;
        _globalMinTime = earliest;
        _totalMinutes = (earliest != null && latest != null)
            ? latest!.difference(earliest!).inSeconds / 60.0
            : 0.0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadSensorCsv() async {
    if (_devicesData.isEmpty) {
      _snack('No data loaded');
      return;
    }
    setState(() => _csvLoading = true);
    try {
      final start = _fmtApi(_startDate);
      final end = _fmtApi(_endDate);
      final links = <({SensorEntry sensor, String url})>[];

      for (final s in _sensors) {
        final apiUrl = buildDownloadApiUrl(
            deviceId: s.deviceId,
            sensorType: s.sensorType,
            startDate: start,
            endDate: end);
        final resp = await http.get(Uri.parse(apiUrl));
        if (resp.statusCode != 200)
          throw Exception('Download failed for ${s.label}');
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final dlUrl = body['download_url'] as String?;
        if (dlUrl == null || dlUrl.isEmpty)
          throw Exception('No download_url for ${s.label}');
        links.add((sensor: s, url: dlUrl));
      }

      final csvs = <({SensorEntry sensor, _RawCsvData csv})>[];
      for (final l in links) {
        final s3 = await http.get(Uri.parse(l.url));
        if (s3.statusCode != 200)
          throw Exception('S3 fetch failed for ${l.sensor.label}');
        csvs.add((sensor: l.sensor, csv: _parseSensorCsv(s3.body)));
      }

      final allTs = <String>{};
      for (final c in csvs) allTs.addAll(c.csv.rows.keys);
      final sortedTs = allTs.toList()..sort();

      final orderedCols = <String>[];
      final seenCols = <String>{};
      for (final c in csvs) {
        for (final col in c.csv.columns) {
          if (seenCols.add(col)) orderedCols.add(col);
        }
      }

      // Add corrected temperature column for CP 39 if correction is active
      final cp39Csv = csvs
          .where((c) =>
              c.sensor.deviceId == 39 && c.sensor.sensorType == SensorType.cp)
          .firstOrNull;
      final hasCp39 = cp39Csv != null;

      final headers = [
        'Timestamp',
        ...orderedCols
            .expand((col) => csvs.map((c) => '${col}_${c.sensor.key}')),
        if (hasCp39) 'CurrentTemperature_CP_39_corrected',
      ];

      // Precompute correction map for CP39
      Map<String, double> correctedMap = {};
      if (hasCp39) {
        final cp39Device = _devicesData.where(isCp39).firstOrNull;
        if (cp39Device != null) {
          for (int i = 0; i < cp39Device.sortedData.length; i++) {
            final ts = DateFormat('yyyy-MM-dd HH:mm:ss')
                .format(cp39Device.sortedData[i].timeStamp);
            correctedMap[ts] = cp39Device.correctedTemperatures![i];
          }
        }
      }

      final lines = [headers.join(',')];
      for (final ts in sortedTs) {
        final cells = [
          ts,
          ...orderedCols
              .expand((col) => csvs.map((c) => c.csv.rows[ts]?[col] ?? '')),
          if (hasCp39) correctedMap[ts]?.toStringAsFixed(2) ?? '',
        ];
        lines.add(cells.join(','));
      }

      final sKeys = _sensors.map((s) => s.key).join('_');
      _triggerDownload(lines.join('\n'),
          'comparison_${sKeys}_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv');
      _snack('Downloaded ${sortedTs.length} rows'
          '${hasCp39 ? ' (includes CP39 corrected temp)' : ''}');
    } catch (e) {
      _snack('Download failed: $e');
    } finally {
      setState(() => _csvLoading = false);
    }
  }

  // ── IMD fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchImdData() async {
    if (_imdSensors.isEmpty) {
      _snack('Add at least one sensor');
      return;
    }
    setState(() {
      _imdLoading = true;
      _imdError = null;
    });
    try {
      final imdUrl =
          'https://914ed7hixg.execute-api.us-east-1.amazonaws.com/default/IMD_AWS-ARG_Data_API'
          '?ID=$_imdStationId&startdate=${_fmtImdApi(_imdStart)}&enddate=${_fmtImdApi(_imdEnd)}';
      final imdResp = await http.get(Uri.parse(imdUrl));
      if (imdResp.statusCode != 200)
        throw Exception('IMD API error (HTTP ${imdResp.statusCode})');

      final imdBody = json.decode(imdResp.body);
      final imdItems = imdBody is List
          ? imdBody
          : (imdBody is Map && imdBody.containsKey('items')
              ? imdBody['items'] as List
              : [imdBody]);
      final imdData = imdItems
          .map((e) => IMDData.fromJson(e as Map<String, dynamic>))
          .toList();

      final Map<String, List<WeatherData>> rawMap = {};
      final Map<String, List<WeatherData>> bucketedMap = {};

      for (final sensor in _imdSensors) {
        final sUrl = buildApiUrl(
            deviceId: sensor.deviceId,
            sensorType: sensor.sensorType,
            startDate: _fmtApi(_imdStart),
            endDate: _fmtApi(_imdEnd));
        final resp = await http.get(Uri.parse(sUrl));
        if (resp.statusCode != 200) throw Exception('${sensor.label} failed');
        final body = json.decode(resp.body);
        final rawList = (body['items'] as List)
            .map((e) => WeatherData.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
        rawMap[sensor.key] = rawList;

        final bucketed = <WeatherData>[];
        for (final imd in imdData) {
          final bucket = DateTime(imd.timeStamp.year, imd.timeStamp.month,
              imd.timeStamp.day, imd.timeStamp.hour, imd.timeStamp.minute, 0);
          final bw = _bucketSW15(rawList, bucket);
          if (bw != null) bucketed.add(bw);
        }
        bucketedMap[sensor.key] = bucketed;
      }

      DateTime? earliest, latest;
      for (final d in imdData) {
        if (earliest == null || d.timeStamp.isBefore(earliest))
          earliest = d.timeStamp;
        if (latest == null || d.timeStamp.isAfter(latest)) latest = d.timeStamp;
      }

      setState(() {
        _imdData = imdData;
        _imdRawData = rawMap;
        _imdBucketedData = bucketedMap;
        _imdGlobalMin = earliest;
        _imdTotalMinutes = (earliest != null && latest != null)
            ? latest!.difference(earliest!).inSeconds / 60.0
            : 0.0;
        _imdLoading = false;
      });
    } catch (e) {
      setState(() {
        _imdError = e.toString();
        _imdLoading = false;
      });
    }
  }

  Future<void> _downloadImdCsv() async {
    if (_imdData.isEmpty) {
      _snack('No IMD data');
      return;
    }
    setState(() => _imdCsvLoading = true);
    try {
      final headers = [
        'Timestamp',
        'IMD_Temp_C',
        'IMD_Humidity_%',
        'IMD_Pressure_hPa',
        'IMD_WindSpeed_ms',
        'IMD_WindDir_deg'
      ];
      for (final s in _imdSensors) {
        headers.addAll([
          '${s.key}_Temp_C',
          '${s.key}_Humidity_%',
          '${s.key}_Pressure_hPa',
          '${s.key}_WindSpeed_ms',
          '${s.key}_WindDir_deg',
          'Diff_${s.key}_Temp',
          'Diff_${s.key}_Humidity',
          'Diff_${s.key}_Pressure',
          'Diff_${s.key}_WindSpeed',
          'Diff_${s.key}_WindDir',
        ]);
      }
      final bucketedMaps = {
        for (final s in _imdSensors)
          s.key: {
            for (final d in _imdBucketedData[s.key] ?? [])
              DateFormat('yyyy-MM-dd HH:mm:ss').format(d.timeStamp): d
          }
      };
      String fmt(double? v) => v?.toStringAsFixed(2) ?? '';
      String diff(double? a, double? b) =>
          (a != null && b != null) ? (a - b).abs().toStringAsFixed(2) : '';
      final lines = [headers.join(',')];
      for (final imd in _imdData) {
        final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(imd.timeStamp);
        final row = [
          ts,
          fmt(imd.currTemp),
          fmt(imd.relativeHumidity),
          fmt(imd.mslp),
          fmt(imd.windSpeed),
          fmt(imd.windDirection)
        ];
        for (final s in _imdSensors) {
          final sd = bucketedMaps[s.key]?[ts];
          row.addAll([
            fmt(sd?.currentTemperature),
            fmt(sd?.currentHumidity),
            fmt(sd?.atmPressure),
            fmt(sd?.windSpeed),
            fmt(sd?.windDirection),
            diff(imd.currTemp, sd?.currentTemperature),
            diff(imd.relativeHumidity, sd?.currentHumidity),
            diff(imd.mslp, sd?.atmPressure),
            diff(imd.windSpeed, sd?.windSpeed),
            diff(imd.windDirection, sd?.windDirection),
          ]);
        }
        lines.add(row.join(','));
      }
      _triggerDownload(lines.join('\n'),
          'IMD_Comparison_${DateFormat('yyyyMMdd').format(_imdStart)}_${DateFormat('yyyyMMdd').format(_imdEnd)}.csv');
      _snack('Downloaded ${_imdData.length} rows');
    } catch (e) {
      _snack('Download failed: $e');
    } finally {
      setState(() => _imdCsvLoading = false);
    }
  }

  void _triggerDownload(String content, String fileName) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    Future.delayed(
        const Duration(milliseconds: 200), () => html.Url.revokeObjectUrl(url));
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  Map<String, double> _stats(List<double> v) {
    if (v.isEmpty) return {};
    return {
      'max': v.reduce(max),
      'min': v.reduce(min),
      'avg': v.reduce((a, b) => a + b) / v.length
    };
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isBusy =
        _isImdTab ? (_imdLoading || _imdCsvLoading) : (_loading || _csvLoading);
    final hasData = _isImdTab ? _imdData.isNotEmpty : _devicesData.isNotEmpty;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _kBg,
        colorScheme: const ColorScheme.dark(
          primary: _kPrimary,
          surface: _kSurface,
        ),
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Container(
            color: _kSurface,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _kPrimary.withOpacity(0.4), width: 1),
                          ),
                          child: const Icon(Icons.sensors,
                              size: 16, color: _kPrimary),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WEATHER SENSOR DASHBOARD',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                                letterSpacing: 1.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              'Real-time meteorological comparison',
                              style: TextStyle(
                                fontSize: 10,
                                color: _kTextSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (hasData) ...[
                          if (isBusy)
                            Container(
                              width: 28,
                              height: 28,
                              padding: const EdgeInsets.all(6),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: _kPrimary),
                            )
                          else ...[
                            _AppBarButton(
                              icon: Icons.download_outlined,
                              tooltip: 'Export CSV',
                              onTap: _isImdTab
                                  ? _downloadImdCsv
                                  : _downloadSensorCsv,
                            ),
                            const SizedBox(width: 8),
                            _AppBarButton(
                              icon: Icons.refresh_outlined,
                              tooltip: 'Refresh',
                              onTap:
                                  _isImdTab ? _fetchImdData : _fetchSensorData,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: _kBorder, width: 1)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: _kPrimary,
                      unselectedLabelColor: _kTextPrimary,
                      indicatorColor: _kPrimary,
                      indicatorWeight: 2,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontFamily: 'monospace',
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      tabs: const [
                        Tab(text: 'SENSOR vs SENSOR'),
                        Tab(text: 'IMD COMPARISON'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSensorTab(),
            _buildImdTab(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SENSOR vs SENSOR TAB
  // ════════════════════════════════════════════════════════════

  Widget _buildSensorTab() {
    // Check if CP 39 is in sensor list (before data is loaded, for toggle preview)
    final cp39InList =
        _sensors.any((s) => s.deviceId == 39 && s.sensorType == SensorType.cp);
    final showCorrectionToggle =
        cp39InList && _selectedParams.contains(WeatherParameter.temperature);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SensorSelectorWidget(
                  sensors: _sensors,
                  onAdd: (entry) {
                    if (_sensors.contains(entry)) {
                      _snack('${entry.label} already added');
                      return;
                    }
                    setState(() => _sensors.add(entry));
                  },
                  onRemove: (entry) {
                    if (_sensors.length <= 1) {
                      _snack('At least one sensor required');
                      return;
                    }
                    setState(() {
                      _sensors.remove(entry);
                      _devicesData.removeWhere((d) => d.key == entry.key);
                      _matched = TimestampMatcher.matchTimestamps(_devicesData);
                      // Reset correction if CP39 removed
                      if (entry.deviceId == 39 &&
                          entry.sensorType == SensorType.cp) {
                        _showCorrected = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 18),
                const Divider(color: _kBorder, thickness: 1),
                const SizedBox(height: 14),
                _DateRangeSelector(
                  startDate: _startDate,
                  endDate: _endDate,
                  onPickStart: () => _pickDate(true),
                  onPickEnd: () => _pickDate(false),
                ),
                const SizedBox(height: 18),
                const Divider(color: _kBorder, thickness: 1),
                const SizedBox(height: 14),
                const _SectionLabel('Parameters'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WeatherParameter.values.map((p) {
                    final sel = _selectedParams.contains(p);
                    return _ParamChip(
                      label: parameterLabel(p),
                      selected: sel,
                      onTap: () => setState(() {
                        if (sel) {
                          if (_selectedParams.length > 1)
                            _selectedParams.remove(p);
                          else
                            _snack('At least one parameter required');
                        } else {
                          _selectedParams.add(p);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Center(
                  child: _ActionButton(
                    label: _loading ? 'LOADING...' : 'COMPARE SENSORS',
                    icon: _loading ? null : Icons.compare_arrows,
                    loading: _loading,
                    color: _kPrimary,
                    onTap: _loading ? null : _fetchSensorData,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(_error!),
          ],
          if (!_loading &&
              _devicesData.isNotEmpty &&
              _globalMinTime != null) ...[
            const SizedBox(height: 16),

            // Correction toggle shown inline above charts too (when data loaded)
            if (_canShowCorrection) ...[
              _CorrectionToggle(
                value: _showCorrected,
                onChanged: (v) => setState(() => _showCorrected = v),
              ),
              const SizedBox(height: 12),
            ],

            ..._selectedParams.map((p) {
              final globalMin = _globalMinTime!;

              // ── Build line bars ──────────────────────────────────────────
              final lineBars = <LineChartBarData>[];
              final legend = <_ChartLegendItem>[];

              for (final device in _devicesData) {
                // Raw spots (from matched timestamps for alignment)
                final spots = <FlSpot>[];
                for (final mp in _matched) {
                  final d = mp.deviceData[device.key];
                  if (d != null) {
                    spots.add(FlSpot(
                        d.timeStamp.difference(globalMin).inSeconds / 60.0,
                        getParameterValue(d, p)));
                  }
                }
                lineBars.add(LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: device.color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false)));
                legend.add(_ChartLegendItem(
                    label: '${device.label} (raw)', color: device.color));

                // ── Corrected line for CP 39 + Temperature ───────────────
                if (_showCorrected &&
                    isCp39(device) &&
                    p == WeatherParameter.temperature) {
                  final corrected = <FlSpot>[];
                  for (int i = 0; i < device.sortedData.length; i++) {
                    corrected.add(FlSpot(
                      device.sortedData[i].timeStamp
                              .difference(globalMin)
                              .inSeconds /
                          60.0,
                      device.correctedTemperatures![i],
                    ));
                  }
                  lineBars.add(LineChartBarData(
                      spots: corrected,
                      isCurved: true,
                      color: _kCorrectedColor,
                      barWidth: 2,
                      dashArray: [6, 3],
                      dotData: const FlDotData(show: false)));
                  legend.add(const _ChartLegendItem(
                      label: 'CP 39 — corrected',
                      color: _kCorrectedColor,
                      dashed: true));
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChartWidget(
                  title: parameterLabel(p),
                  lineBars: lineBars,
                  legend: legend,
                  globalMin: globalMin,
                  totalMinutes: _totalMinutes,
                  getTooltipItems: (spots) => spots.asMap().entries.map((e) {
                    final spot = e.value;
                    // Determine whether this spot is a corrected series
                    // Corrected bars are added right after their raw counterpart
                    // We track by checking color
                    final isCorrectedBar = spot.bar.color == _kCorrectedColor;
                    final color = spot.bar.color ?? _kPrimary;

                    // Find original device for label
                    String deviceLabel;
                    if (isCorrectedBar) {
                      deviceLabel = 'CP 39 corrected';
                    } else {
                      // Map barIndex back to device (corrected bars are interleaved)
                      int rawIdx = 0;
                      int bi = 0;
                      for (final device in _devicesData) {
                        if (bi == spot.barIndex) {
                          rawIdx = _devicesData.indexOf(device);
                          break;
                        }
                        bi++;
                        if (_showCorrected &&
                            isCp39(device) &&
                            p == WeatherParameter.temperature) {
                          bi++;
                        }
                      }
                      deviceLabel = rawIdx < _devicesData.length
                          ? _devicesData[rawIdx].label
                          : 'Sensor';
                    }

                    String diffText = '';
                    if (spots.length == 2 && e.key == spots.length - 1) {
                      diffText =
                          '\nΔ ${(spots[0].y - spots[1].y).abs().toStringAsFixed(1)} ${parameterUnit(p)}';
                    }

                    final t =
                        globalMin.add(Duration(seconds: (spot.x * 60).round()));
                    final label = isCorrectedBar
                        ? '$deviceLabel: ${spot.y.toStringAsFixed(1)}°C'
                        : '$deviceLabel: ${spot.y.toStringAsFixed(1)} ${parameterUnit(p)}';

                    return LineTooltipItem(
                      '${DateFormat('dd/MM HH:mm').format(t)}\n$label',
                      TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                      children: diffText.isEmpty
                          ? null
                          : [
                              TextSpan(
                                text: diffText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                    );
                  }).toList(),
                ),
              );
            }),
            _buildSensorStats(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSensorStats() {
    if (_matched.isEmpty) return const SizedBox.shrink();
    return _AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.analytics_outlined,
                    size: 14, color: _kPrimary),
              ),
              const SizedBox(width: 10),
              const Text(
                'STATISTICS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                  letterSpacing: 0.8,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(
                  '${_matched.length} pts',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _kTextSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          ..._selectedParams.map((p) {
            final unit = parameterUnit(p);
            final Map<String, List<double>> vals = {};
            for (final mp in _matched) {
              for (final e in mp.deviceData.entries) {
                vals
                    .putIfAbsent(e.key, () => [])
                    .add(getParameterValue(e.value, p));
              }
            }

            final isWind = p == WeatherParameter.windDirection;
            final isTemp = p == WeatherParameter.temperature;

            final statRows = <Widget>[];
            for (int i = 0; i < _devicesData.length; i++) {
              final d = _devicesData[i];
              final s = _stats(vals[d.key] ?? []);
              if (s.isEmpty) continue;
              final latestWind = isWind && d.data.isNotEmpty
                  ? d.data.last.windDirection
                  : null;

              // Corrected stats for CP 39
              Map<String, double>? corrStats;
              if (_showCorrected && isCp39(d) && isTemp) {
                corrStats = _stats(d.correctedTemperatures ?? []);
              }

              statRows.add(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: d.color, shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      Text(
                        d.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: d.color,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (isCp39(d) && isTemp) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kBorderAccent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'RAW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kTextSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: _MetricCard(
                              label: 'MAX',
                              value: '${s['max']!.toStringAsFixed(1)} $unit',
                              color: _kRed)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _MetricCard(
                              label: 'AVG',
                              value: '${s['avg']!.toStringAsFixed(1)} $unit',
                              color: _kPrimary)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _MetricCard(
                              label: 'MIN',
                              value: '${s['min']!.toStringAsFixed(1)} $unit',
                              color: _kGreen)),
                    ]),
                    if (isWind && latestWind != null) ...[
                      const SizedBox(height: 8),
                      _WindDirectionCard(
                          label: 'CURRENT',
                          degrees: latestWind,
                          color: d.color),
                    ],

                    // ── Corrected stats block ────────────────────────────
                    if (corrStats != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: _kCorrectedColor,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 7),
                        const Text(
                          'CP 39 — corrected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kCorrectedColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kCorrectedColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: _kCorrectedColor.withOpacity(0.3),
                                width: 1),
                          ),
                          child: const Text(
                            'CORRECTED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kCorrectedColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _MetricCard(
                                label: 'MAX',
                                value:
                                    '${corrStats['max']!.toStringAsFixed(1)} $unit',
                                color: _kRed)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _MetricCard(
                                label: 'AVG',
                                value:
                                    '${corrStats['avg']!.toStringAsFixed(1)} $unit',
                                color: _kCorrectedColor)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _MetricCard(
                                label: 'MIN',
                                value:
                                    '${corrStats['min']!.toStringAsFixed(1)} $unit',
                                color: _kGreen)),
                      ]),
                    ],
                  ],
                ),
              ));
            }

            // Differences
            final diffWidgets = <Widget>[];
            for (int i = 0; i < _devicesData.length - 1; i++) {
              for (int j = i + 1; j < _devicesData.length; j++) {
                final ka = _devicesData[i].key;
                final kb = _devicesData[j].key;
                final diffs = <double>[];
                for (final mp in _matched) {
                  final da = mp.deviceData[ka];
                  final db = mp.deviceData[kb];
                  if (da != null && db != null) {
                    diffs.add(
                        (getParameterValue(da, p) - getParameterValue(db, p))
                            .abs());
                  }
                }
                if (diffs.isEmpty) continue;
                final ds = _stats(diffs);
                diffWidgets.add(Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: _kRadiusSm,
                    border: Border.all(color: _kBorderAccent, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: _devicesData[i].color,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(_devicesData[i].key,
                            style: TextStyle(
                              fontSize: 11,
                              color: _devicesData[i].color,
                              fontFamily: 'monospace',
                            )),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7),
                            child: Text('↔',
                                style: TextStyle(
                                    fontSize: 12, color: _kTextTertiary))),
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: _devicesData[j].color,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(_devicesData[j].key,
                            style: TextStyle(
                              fontSize: 11,
                              color: _devicesData[j].color,
                              fontFamily: 'monospace',
                            )),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _MetricCard(
                                label: 'MAX Δ',
                                value: '${ds['max']!.toStringAsFixed(2)} $unit',
                                color: _kRed)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _MetricCard(
                                label: 'AVG Δ',
                                value: '${ds['avg']!.toStringAsFixed(2)} $unit',
                                color: _kAmber)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _MetricCard(
                                label: 'MIN Δ',
                                value: '${ds['min']!.toStringAsFixed(2)} $unit',
                                color: _kGreen)),
                      ]),
                    ],
                  ),
                ));
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionDivider(parameterLabel(p)),
                ...statRows,
                if (diffWidgets.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(Icons.compare_arrows,
                          size: 12, color: _kTextPrimary),
                      SizedBox(width: 6),
                      Text('DIFFERENCES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kTextPrimary,
                            letterSpacing: 0.8,
                            fontFamily: 'monospace',
                          )),
                    ]),
                  ),
                  ...diffWidgets,
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  IMD TAB  (unchanged)
  // ════════════════════════════════════════════════════════════

  Widget _buildImdTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _AppCard(
            borderColor: _kImdColor.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _kImdColor.withOpacity(0.08),
                    borderRadius: _kRadiusSm,
                    border: Border.all(
                        color: _kImdColor.withOpacity(0.25), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kImdColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'IMD',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D1117),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Station: CGDAC000 — DAV School, Chandigarh',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kImdColor,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SensorSelectorWidget(
                  sensors: _imdSensors,
                  onAdd: (entry) {
                    if (_imdSensors.contains(entry)) {
                      _snack('${entry.label} already added');
                      return;
                    }
                    setState(() => _imdSensors.add(entry));
                  },
                  onRemove: (entry) {
                    if (_imdSensors.length <= 1) {
                      _snack('At least one sensor required');
                      return;
                    }
                    setState(() {
                      _imdSensors.remove(entry);
                      _imdRawData.remove(entry.key);
                      _imdBucketedData.remove(entry.key);
                    });
                  },
                ),
                const SizedBox(height: 18),
                const Divider(color: _kBorder, thickness: 1),
                const SizedBox(height: 14),
                _DateRangeSelector(
                  startDate: _imdStart,
                  endDate: _imdEnd,
                  onPickStart: () => _pickDate(true, imd: true),
                  onPickEnd: () => _pickDate(false, imd: true),
                ),
                const SizedBox(height: 18),
                const Divider(color: _kBorder, thickness: 1),
                const SizedBox(height: 14),
                const _SectionLabel('Parameters'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: IMDCompareParameter.values.map((p) {
                    final sel = _imdParams.contains(p);
                    return _ParamChip(
                      label: imdParamLabel(p),
                      selected: sel,
                      accentColor: _kImdColor,
                      onTap: () => setState(() {
                        if (sel) {
                          if (_imdParams.length > 1)
                            _imdParams.remove(p);
                          else
                            _snack('At least one parameter required');
                        } else {
                          _imdParams.add(p);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Center(
                  child: _ActionButton(
                    label: _imdLoading ? 'LOADING...' : 'COMPARE SENSORS',
                    icon: _imdLoading ? null : Icons.sync,
                    loading: _imdLoading,
                    color: _kImdColor,
                    onTap: _imdLoading ? null : _fetchImdData,
                  ),
                ),
              ],
            ),
          ),
          if (_imdError != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(_imdError!),
          ],
          if (!_imdLoading && _imdData.isNotEmpty && _imdGlobalMin != null) ...[
            const SizedBox(height: 16),
            ..._imdParams.map((p) {
              final globalMin = _imdGlobalMin!;
              final unit = imdParamUnit(p);

              double imdVal(IMDData d) {
                switch (p) {
                  case IMDCompareParameter.temperature:
                    return d.currTemp;
                  case IMDCompareParameter.humidity:
                    return d.relativeHumidity;
                  case IMDCompareParameter.pressure:
                    return d.mslp;
                  case IMDCompareParameter.windSpeed:
                    return d.windSpeed;
                  case IMDCompareParameter.windDirection:
                    return d.windDirection;
                }
              }

              double sensorVal(WeatherData d) {
                switch (p) {
                  case IMDCompareParameter.temperature:
                    return d.currentTemperature;
                  case IMDCompareParameter.humidity:
                    return d.currentHumidity;
                  case IMDCompareParameter.pressure:
                    return d.atmPressure;
                  case IMDCompareParameter.windSpeed:
                    return d.windSpeed;
                  case IMDCompareParameter.windDirection:
                    return d.windDirection;
                }
              }

              final imdSpots = _imdData
                  .map((d) => FlSpot(
                      d.timeStamp.difference(globalMin).inSeconds / 60.0,
                      imdVal(d)))
                  .toList();
              final lineBars = [
                LineChartBarData(
                    spots: imdSpots,
                    isCurved: true,
                    color: _kImdColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false)),
                ..._imdSensors.asMap().entries.map((e) {
                  final bucketed = _imdBucketedData[e.value.key] ?? [];
                  final spots = bucketed
                      .map((d) => FlSpot(
                          d.timeStamp.difference(globalMin).inSeconds / 60.0,
                          sensorVal(d)))
                      .toList();
                  return LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: ColorPalette.getColor(e.key),
                      barWidth: 2,
                      dotData: const FlDotData(show: false));
                }),
              ];

              final legend = [
                const _ChartLegendItem(label: 'IMD', color: _kImdColor),
                ..._imdSensors.asMap().entries.map((e) => _ChartLegendItem(
                      label: e.value.label,
                      color: ColorPalette.getColor(e.key),
                    )),
              ];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChartWidget(
                  title: imdParamLabel(p),
                  lineBars: lineBars,
                  legend: legend,
                  globalMin: globalMin,
                  totalMinutes: _imdTotalMinutes,
                  getTooltipItems: (spots) => spots.asMap().entries.map((e) {
                    final spot = e.value;
                    final isImd = spot.barIndex == 0;
                    final color = isImd
                        ? _kImdColor
                        : ColorPalette.getColor(spot.barIndex - 1);
                    final label = isImd
                        ? 'IMD'
                        : (spot.barIndex - 1 < _imdSensors.length
                            ? _imdSensors[spot.barIndex - 1].label
                            : 'Sensor');
                    final t =
                        globalMin.add(Duration(seconds: (spot.x * 60).round()));
                    String diffText = '';
                    if (spots.length == 2 && e.key == spots.length - 1) {
                      diffText =
                          '\nΔ ${(spots[0].y - spots[1].y).abs().toStringAsFixed(1)} $unit';
                    }
                    return LineTooltipItem(
                      '${DateFormat('dd/MM HH:mm').format(t)}\n$label: ${spot.y.toStringAsFixed(1)} $unit',
                      TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                      children: diffText.isEmpty
                          ? null
                          : [
                              TextSpan(
                                text: diffText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                    );
                  }).toList(),
                ),
              );
            }),
            _buildImdStats(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildImdStats() {
    return _AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _kImdColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.analytics_outlined,
                    size: 14, color: _kImdColor),
              ),
              const SizedBox(width: 10),
              const Text(
                'STATISTICAL SUMMARY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                  letterSpacing: 0.8,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(
                  '${_imdData.length} pts',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _kTextSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          ..._imdParams.map((p) {
            final unit = imdParamUnit(p);

            double imdVal(IMDData d) {
              switch (p) {
                case IMDCompareParameter.temperature:
                  return d.currTemp;
                case IMDCompareParameter.humidity:
                  return d.relativeHumidity;
                case IMDCompareParameter.pressure:
                  return d.mslp;
                case IMDCompareParameter.windSpeed:
                  return d.windSpeed;
                case IMDCompareParameter.windDirection:
                  return d.windDirection;
              }
            }

            double sensorVal(WeatherData d) {
              switch (p) {
                case IMDCompareParameter.temperature:
                  return d.currentTemperature;
                case IMDCompareParameter.humidity:
                  return d.currentHumidity;
                case IMDCompareParameter.pressure:
                  return d.atmPressure;
                case IMDCompareParameter.windSpeed:
                  return d.windSpeed;
                case IMDCompareParameter.windDirection:
                  return d.windDirection;
              }
            }

            final imdStats = _stats(_imdData.map(imdVal).toList());
            final isWind = p == IMDCompareParameter.windDirection;
            DateTime roundTs(DateTime dt) =>
                DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionDivider(imdParamLabel(p)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: _kImdColor, shape: BoxShape.circle)),
                          const SizedBox(width: 7),
                          const Text('IMD',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kImdColor,
                                fontFamily: 'monospace',
                              )),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: _MetricCard(
                                  label: 'MAX',
                                  value:
                                      '${imdStats['max']!.toStringAsFixed(1)} $unit',
                                  color: _kRed)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _MetricCard(
                                  label: 'AVG',
                                  value:
                                      '${imdStats['avg']!.toStringAsFixed(1)} $unit',
                                  color: _kImdColor)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _MetricCard(
                                  label: 'MIN',
                                  value:
                                      '${imdStats['min']!.toStringAsFixed(1)} $unit',
                                  color: _kGreen)),
                        ]),
                        if (isWind && _imdData.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _WindDirectionCard(
                            label: 'CURRENT (IMD)',
                            degrees: _imdData.last.windDirection,
                            color: _kImdColor,
                          ),
                        ],
                      ]),
                ),
                ..._imdSensors.asMap().entries.map((e) {
                  final sensor = e.value;
                  final color = ColorPalette.getColor(e.key);
                  final bucketed = _imdBucketedData[sensor.key] ?? [];
                  final swMap = {
                    for (final d in bucketed) roundTs(d.timeStamp): d
                  };
                  final swVals = <double>[];
                  final diffs = <double>[];
                  for (final imd in _imdData) {
                    final sw = swMap[roundTs(imd.timeStamp)];
                    if (sw != null) {
                      swVals.add(sensorVal(sw));
                      diffs.add((imdVal(imd) - sensorVal(sw)).abs());
                    }
                  }
                  final ss = _stats(swVals);
                  final ds = _stats(diffs);
                  if (ss.isEmpty) return const SizedBox.shrink();
                  final latestBucketedWind = isWind && bucketed.isNotEmpty
                      ? bucketed.last.windDirection
                      : null;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle)),
                                  const SizedBox(width: 7),
                                  Text(sensor.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                        fontFamily: 'monospace',
                                      )),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Expanded(
                                      child: _MetricCard(
                                          label: 'MAX',
                                          value:
                                              '${ss['max']!.toStringAsFixed(1)} $unit',
                                          color: _kRed)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _MetricCard(
                                          label: 'AVG',
                                          value:
                                              '${ss['avg']!.toStringAsFixed(1)} $unit',
                                          color: _kPrimary)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _MetricCard(
                                          label: 'MIN',
                                          value:
                                              '${ss['min']!.toStringAsFixed(1)} $unit',
                                          color: _kGreen)),
                                ]),
                                if (isWind && latestBucketedWind != null) ...[
                                  const SizedBox(height: 8),
                                  _WindDirectionCard(
                                    label: 'CURRENT (${sensor.label})',
                                    degrees: latestBucketedWind,
                                    color: color,
                                  ),
                                ],
                              ]),
                        ),
                        if (ds.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _kBg,
                              borderRadius: _kRadiusSm,
                              border:
                                  Border.all(color: _kBorderAccent, width: 1),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.compare_arrows,
                                        size: 12, color: _kTextTertiary),
                                    const SizedBox(width: 6),
                                    Text('|IMD − ${sensor.label}|',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _kTextSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                        )),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                        child: _MetricCard(
                                            label: 'MAX Δ',
                                            value:
                                                '${ds['max']!.toStringAsFixed(2)} $unit',
                                            color: _kRed)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _MetricCard(
                                            label: 'AVG Δ',
                                            value:
                                                '${ds['avg']!.toStringAsFixed(2)} $unit',
                                            color: _kAmber)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _MetricCard(
                                            label: 'MIN Δ',
                                            value:
                                                '${ds['min']!.toStringAsFixed(2)} $unit',
                                            color: _kGreen)),
                                  ]),
                                ]),
                          ),
                      ]);
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SMALL SHARED WIDGETS
// ════════════════════════════════════════════════════════════

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _AppBarButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kSurfaceElevated,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: Icon(icon, size: 16, color: _kTextSecondary),
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            color: onTap != null ? color : color.withOpacity(0.3),
            borderRadius: _kRadiusSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF0D1117)),
                )
              else if (icon != null)
                Icon(icon, size: 16, color: const Color(0xFF0D1117)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1117),
                  letterSpacing: 0.8,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      );
}

class _WindDirectionCard extends StatelessWidget {
  final String label;
  final double degrees;
  final Color color;

  const _WindDirectionCard({
    required this.label,
    required this.degrees,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final direction = degreesToDirection(degrees);
    final angle = degrees * 3.14159265358979 / 180.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: _kRadiusSm,
        border: Border.all(color: color.withOpacity(0.22), width: 1),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: _kTextPrimary,
                    letterSpacing: 1.0,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 6),
              Transform.rotate(
                angle: angle,
                child: Icon(Icons.navigation, size: 30, color: _kTextPrimary),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(direction,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary,
                    fontFamily: 'monospace',
                    letterSpacing: -0.5,
                  )),
              Text('${degrees.toStringAsFixed(1)}°',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextPrimary.withOpacity(0.6),
                    fontFamily: 'monospace',
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;
  const _ParamChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.accentColor});

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _kPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.12) : _kBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? accent.withOpacity(0.5) : _kBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? accent : _kTextSecondary,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kRed.withOpacity(0.07),
          borderRadius: _kRadiusSm,
          border: Border.all(color: _kRed.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.error_outline, size: 14, color: _kRed),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kRed,
                    fontFamily: 'monospace',
                  )),
            ),
          ],
        ),
      );
}
