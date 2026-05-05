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

/// =======================
/// SENSOR TYPE
/// =======================
enum SensorType { cp, sw, wj, wm }

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
    final rawTs = (json['TimeStamp'] ?? '').toString().trim();
    final normTs = rawTs.replaceFirst(RegExp(r' (?=\d{2}:\d{2})'), 'T');

    return WeatherData(
      timeStamp: DateTime.parse(normTs),
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
/// IMD DATA MODEL
/// =======================
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

    double _parse(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return IMDData(
      timeStamp: DateTime.parse(normTs),
      currTemp: _parse(json['CURR_TEMP']),
      minTemp: _parse(json['MIN_TEMP']),
      maxTemp: _parse(json['MAX_TEMP']),
      relativeHumidity: _parse(json['RH']),
      mslp: _parse(json['MSLP']),
      windSpeed: _parse(json['WIND_SPEED']),
      windDirection: _parse(json['WIND_DIRECTION']),
      station: (json['STATION'] ?? '').toString(),
    );
  }
}

/// =======================
/// IMD COMPARISON PARAMETER
/// =======================
enum IMDCompareParameter {
  temperature,
  humidity,
  pressure,
  windSpeed,
  windDirection,
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

/// =======================
/// MATCHED DATA POINT
/// =======================
class MatchedDataPoint {
  final DateTime timestamp;
  final Map<String, WeatherData> deviceData;

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

  String get key => '${sensorTypeLabel(sensorType)}_$deviceId';
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
        matchedPoints
            .add(MatchedDataPoint(timestamp: bucket, deviceData: deviceMap));
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
/// SENSOR ENTRY
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
/// API BUILDER — chart data
/// =======================
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
  }
}

/// =======================
/// API BUILDER — CSV export
/// =======================
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
  }
}

/// =======================
/// RAW CSV PARSER
/// =======================
class _RawCsvData {
  final Map<String, Map<String, String>> rows;
  final List<String> columns;

  _RawCsvData({required this.rows, required this.columns});
}

_RawCsvData _parseSensorCsv(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }

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
      final colName = headers[ci].trim();
      rowMap[colName] = ci < cells.length ? cells[ci].trim() : '';
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
//  IMD ↔ SW007 COMPARISON SECTION — standalone StatefulWidget
// ════════════════════════════════════════════════════════════

/// Buckets SW007 data to 15-min intervals (to match IMD cadence).
WeatherData? _bucketSW15(List<WeatherData> raw, DateTime bucket) {
  // Collect all raw points in [bucket, bucket+15min)
  final window = raw.where((d) {
    final diff = d.timeStamp.difference(bucket).inMinutes;
    return diff >= 0 && diff < 15;
  }).toList();
  if (window.isEmpty) return null;
  // Average all fields in the window
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
  );
}

class IMDComparisonSection extends StatefulWidget {
  const IMDComparisonSection({Key? key}) : super(key: key);

  @override
  State<IMDComparisonSection> createState() => _IMDComparisonSectionState();
}

class _IMDComparisonSectionState extends State<IMDComparisonSection> {
  // ── state ──────────────────────────────────────────────────────────────────
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  List<IMDData> _imdData = [];

  List<SensorEntry> _selectedSensors = [
    SensorEntry(deviceId: 7, sensorType: SensorType.sw)
  ];
  final TextEditingController _newDeviceController = TextEditingController();
  SensorType _addSensorType = SensorType.sw;

  // We map the sensor key to its data
  Map<String, List<WeatherData>> _sensorRawData = {};
  Map<String, List<WeatherData>> _sensorBucketedData = {};

  bool _loading = false;
  bool _csvLoading = false;
  String? _error;

  List<IMDCompareParameter> _selectedParams = [IMDCompareParameter.temperature];

  // zoom / pan per parameter
  final Map<IMDCompareParameter, double> _zoom = {};
  final Map<IMDCompareParameter, double> _pan = {};
  final Map<IMDCompareParameter, double> _base = {};

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  DateTime? _globalMin;
  double _totalMinutes = 0.0;

  // IMD station ID (hard-coded; could be made configurable)
  static const String _imdStationId = 'CGDAC000';

  // Color assignment
  static const Color _imdColor = Color(0xFF1565C0); // deep blue

  // ── helpers ────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) => DateFormat('d-M-yyyy').format(d);
  String _fmtApiDate(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  void _addSensor() {
    final deviceId = int.tryParse(_newDeviceController.text);
    if (deviceId == null) {
      _snack('Please enter a valid device ID');
      return;
    }
    final entry = SensorEntry(deviceId: deviceId, sensorType: _addSensorType);
    if (_selectedSensors.contains(entry)) {
      _snack('${entry.label} already added');
      return;
    }
    setState(() {
      _selectedSensors.add(entry);
      _newDeviceController.clear();
    });
  }

  void _removeSensor(SensorEntry entry) {
    if (_selectedSensors.length <= 1) {
      _snack('At least one sensor is required');
      return;
    }
    setState(() {
      _selectedSensors.remove(entry);
      _sensorRawData.remove(entry.key);
      _sensorBucketedData.remove(entry.key);
    });
  }

  // ── fetch ──────────────────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    if (_selectedSensors.isEmpty) {
      _snack('Please add at least one sensor');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _zoom.clear();
      _pan.clear();
      _base.clear();
    });

    try {
      // ── IMD ────────────────────────────────────────────────────────────────
      final imdUrl =
          'https://914ed7hixg.execute-api.us-east-1.amazonaws.com/default/IMD_AWS-ARG_Data_API'
          '?ID=$_imdStationId&startdate=${_fmtDate(_startDate)}&enddate=${_fmtDate(_endDate)}';

      final imdResp = await http.get(Uri.parse(imdUrl));
      if (imdResp.statusCode != 200) {
        throw Exception('IMD API error (HTTP ${imdResp.statusCode})');
      }

      final imdBody = json.decode(imdResp.body);
      List<dynamic> imdItems;
      if (imdBody is List) {
        imdItems = imdBody;
      } else if (imdBody is Map && imdBody.containsKey('items')) {
        imdItems = imdBody['items'] as List;
      } else {
        imdItems = [imdBody];
      }
      final imdData = imdItems
          .map((e) => IMDData.fromJson(e as Map<String, dynamic>))
          .toList();

      // ── Other Sensors ──────────────────────────────────────────────────────
      Map<String, List<WeatherData>> rawDataMap = {};
      Map<String, List<WeatherData>> bucketedDataMap = {};

      for (final sensor in _selectedSensors) {
        final sensorUrl = buildApiUrl(
          deviceId: sensor.deviceId,
          sensorType: sensor.sensorType,
          startDate: _fmtApiDate(_startDate),
          endDate: _fmtApiDate(_endDate),
        );

        final resp = await http.get(Uri.parse(sensorUrl));
        if (resp.statusCode != 200) {
          throw Exception(
              '${sensor.label} API error (HTTP ${resp.statusCode})');
        }
        final body = json.decode(resp.body);
        final items = body['items'] as List;
        final rawList = items
            .map((e) => WeatherData.fromJson(e as Map<String, dynamic>))
            .toList();
        rawList.sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
        rawDataMap[sensor.key] = rawList;

        // Build 15-min bucketed data matching IMD timestamps
        final List<WeatherData> bucketedList = [];
        for (final imd in imdData) {
          final bucket = DateTime(imd.timeStamp.year, imd.timeStamp.month,
              imd.timeStamp.day, imd.timeStamp.hour, imd.timeStamp.minute, 0);
          final bw = _bucketSW15(rawList, bucket);
          if (bw != null) bucketedList.add(bw);
        }
        bucketedDataMap[sensor.key] = bucketedList;
      }

      // ── Global time range ─────────────────────────────────────────────
      DateTime? earliest;
      DateTime? latest;
      for (final d in imdData) {
        if (earliest == null || d.timeStamp.isBefore(earliest))
          earliest = d.timeStamp;
        if (latest == null || d.timeStamp.isAfter(latest)) latest = d.timeStamp;
      }

      setState(() {
        _imdData = imdData;
        _sensorRawData = rawDataMap;
        _sensorBucketedData = bucketedDataMap;
        _loading = false;
        _globalMin = earliest;
        _totalMinutes = (earliest != null && latest != null)
            ? latest.difference(earliest).inSeconds / 60.0
            : 0.0;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── CSV download ───────────────────────────────────────────────────────────

  Future<void> _downloadCsv() async {
    if (_imdData.isEmpty) {
      _snack('No IMD data available to download.');
      return;
    }
    setState(() => _csvLoading = true);

    try {
      final headers = [
        'Timestamp',
        'IMD_Temperature_C',
        'IMD_Humidity_%',
        'IMD_Pressure_hPa',
        'IMD_WindSpeed_ms',
        'IMD_WindDirection_deg',
      ];

      for (final sensor in _selectedSensors) {
        headers.addAll([
          '${sensor.key}_Temperature_C',
          '${sensor.key}_Humidity_%',
          '${sensor.key}_Pressure_hPa',
          '${sensor.key}_WindSpeed_ms',
          '${sensor.key}_WindDirection_deg',
          'Diff_${sensor.key}_Temperature_C',
          'Diff_${sensor.key}_Humidity_%',
          'Diff_${sensor.key}_Pressure_hPa',
          'Diff_${sensor.key}_WindSpeed_ms',
          'Diff_${sensor.key}_WindDirection_deg',
        ]);
      }

      // Pre-map bucketed data for quick lookup
      final Map<String, Map<String, WeatherData>> bucketedMap = {};
      for (final sensor in _selectedSensors) {
        bucketedMap[sensor.key] = {
          for (final d in _sensorBucketedData[sensor.key] ?? [])
            DateFormat('yyyy-MM-dd HH:mm:ss').format(d.timeStamp): d
        };
      }

      final lines = [headers.join(',')];

      for (final imd in _imdData) {
        final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(imd.timeStamp);

        String fmt(double? v) => v?.toStringAsFixed(2) ?? '';
        String diff(double? a, double? b) =>
            (a != null && b != null) ? (a - b).abs().toStringAsFixed(2) : '';

        final row = [
          ts,
          fmt(imd.currTemp),
          fmt(imd.relativeHumidity),
          fmt(imd.mslp),
          fmt(imd.windSpeed),
          fmt(imd.windDirection),
        ];

        for (final sensor in _selectedSensors) {
          final sData = bucketedMap[sensor.key]?[ts];
          row.addAll([
            fmt(sData?.currentTemperature),
            fmt(sData?.currentHumidity),
            fmt(sData?.atmPressure),
            fmt(sData?.windSpeed),
            fmt(sData?.windDirection),
            diff(imd.currTemp, sData?.currentTemperature),
            diff(imd.relativeHumidity, sData?.currentHumidity),
            diff(imd.mslp, sData?.atmPressure),
            diff(imd.windSpeed, sData?.windSpeed),
            diff(imd.windDirection, sData?.windDirection),
          ]);
        }

        lines.add(row.join(','));
      }

      final csvContent = lines.join('\n');
      final startStr = DateFormat('yyyyMMdd').format(_startDate);
      final endStr = DateFormat('yyyyMMdd').format(_endDate);
      final fileName = 'IMD_Comparison_${startStr}_$endStr.csv';
      _triggerBrowserDownload(csvContent, fileName);
      _snack('✓ Downloaded $fileName  (${_imdData.length} rows)');
    } catch (e) {
      _snack('CSV download failed: $e');
    } finally {
      setState(() => _csvLoading = false);
    }
  }

  void _triggerBrowserDownload(String content, String fileName) {
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

  // ── chart helpers ──────────────────────────────────────────────────────────

  double _zv(IMDCompareParameter p) => _zoom[p] ?? 1.0;
  double _pv(IMDCompareParameter p) => _pan[p] ?? 0.0;
  double _bv(IMDCompareParameter p) => _base[p] ?? 1.0;

  void _resetZoom(IMDCompareParameter p) => setState(() {
        _zoom[p] = 1.0;
        _pan[p] = 0.0;
        _base[p] = 1.0;
      });

  double _imdVal(IMDData d, IMDCompareParameter p) {
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

  double _sensorVal(WeatherData d, IMDCompareParameter p) {
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

  // ── statistics ─────────────────────────────────────────────────────────────

  /// Returns stats keyed by "imd", and sensor keys.
  Map<String, Map<String, double>> _calcStats(IMDCompareParameter p) {
    if (_imdData.isEmpty) return {};

    final imdVals = _imdData.map((d) => _imdVal(d, p)).toList();

    final Map<String, Map<String, double>> results = {
      'imd': _stats(imdVals),
    };

    for (final sensor in _selectedSensors) {
      final bucketed = _sensorBucketedData[sensor.key] ?? [];
      final swMap = {for (final d in bucketed) _roundTs(d.timeStamp): d};

      final List<double> swVals = [];
      final List<double> diffs = [];
      for (final imd in _imdData) {
        final sw = swMap[_roundTs(imd.timeStamp)];
        if (sw != null) {
          final sv = _sensorVal(sw, p);
          swVals.add(sv);
          diffs.add((_imdVal(imd, p) - sv).abs());
        }
      }

      results[sensor.key] = _stats(swVals);
      results['diff_${sensor.key}'] = _stats(diffs);
    }

    return results;
  }

  Map<String, double> _stats(List<double> v) {
    if (v.isEmpty) return {};
    return {
      'max': v.reduce(max),
      'min': v.reduce(min),
      'avg': v.reduce((a, b) => a + b) / v.length,
    };
  }

  DateTime _roundTs(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

  // ── UI Components ──────────────────────────────────────────────────────────

  Widget _sensorTypeLegendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildSensorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selected Sensors to compare with IMD',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            _sensorTypeLegendDot(Colors.blue),
            const SizedBox(width: 4),
            const Text('CP = Campus  ', style: TextStyle(fontSize: 12)),
            _sensorTypeLegendDot(Colors.teal),
            const SizedBox(width: 4),
            const Text('SW = SW  ', style: TextStyle(fontSize: 12)),
            _sensorTypeLegendDot(Colors.deepOrange),
            const SizedBox(width: 4),
            const Text('WJ = WJ  ', style: TextStyle(fontSize: 12)),
            _sensorTypeLegendDot(Colors.purple),
            const SizedBox(width: 4),
            const Text('WM = WM sensor', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedSensors.map((sensor) {
            final color =
                ColorPalette.getColor(_selectedSensors.indexOf(sensor));
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
              onDeleted: () => _removeSensor(sensor),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
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
                        color:
                            selected ? Colors.deepPurple : Colors.transparent,
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
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _newDeviceController,
                decoration: InputDecoration(
                  hintText: 'Device ID',
                  hintStyle: const TextStyle(fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _addSensor(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _addSensor,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.compare, color: Color(0xFF1565C0)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMD vs Multiple Sensors Comparison',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'IMD Station: CGDAC000 (DAV School, Chandigarh)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Legend chips
                _legendChip('IMD', _imdColor),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            _buildSensorSelector(),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ── Controls ───────────────────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Date pickers
                _dateBtn('Start Date', _startDate, true),
                _dateBtn('End Date', _endDate, false),
                // Fetch button
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Fetch & Compare'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  onPressed: _loading ? null : _fetchData,
                ),
                // Download CSV
                if (_imdData.isNotEmpty)
                  _csvLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download CSV'),
                          onPressed: _downloadCsv,
                        ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Parameter Chips ────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IMDCompareParameter.values.map((p) {
                final sel = _selectedParams.contains(p);
                return FilterChip(
                  label: Text(imdParamLabel(p)),
                  selected: sel,
                  selectedColor: const Color(0xFF1565C0).withOpacity(0.25),
                  checkmarkColor: const Color(0xFF1565C0),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedParams.add(p);
                      } else {
                        if (_selectedParams.length > 1) {
                          _selectedParams.remove(p);
                        } else {
                          _snack('At least one parameter must be selected');
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Loading / Error ────────────────────────────────────────────
            if (_loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: Text('Error: ${_error!}',
                    style: TextStyle(color: Colors.red.shade900)),
              ),

            // ── Charts ─────────────────────────────────────────────────────
            if (!_loading && _imdData.isNotEmpty && _globalMin != null) ...[
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              ..._selectedParams.map((p) {
                final unit = imdParamUnit(p);
                final globalMin = _globalMin!;
                final totalMin = _totalMinutes;

                // Zoom / Pan variables
                final double currentZoom = _zv(p);
                final double currentPan = _pv(p);

                final double visMin = max(10, totalMin / currentZoom);
                final double currentOffset =
                    currentPan.clamp(0.0, max(0.0, totalMin - visMin));

                final double minX = currentOffset;
                final double maxX = currentOffset + visMin;

                // IMD Data Spots
                final List<FlSpot> imdSpots = _imdData.map((d) {
                  final x = d.timeStamp.difference(globalMin).inSeconds / 60.0;
                  final y = _imdVal(d, p);
                  return FlSpot(x, y);
                }).toList();

                // Other Sensors Spots
                final Map<String, List<FlSpot>> sensorSpotsMap = {};
                for (final sensor in _selectedSensors) {
                  final bucketed = _sensorBucketedData[sensor.key] ?? [];
                  sensorSpotsMap[sensor.key] = bucketed.map((d) {
                    final x =
                        d.timeStamp.difference(globalMin).inSeconds / 60.0;
                    final y = _sensorVal(d, p);
                    return FlSpot(x, y);
                  }).toList();
                }

                // Prepare LineBarsData
                final List<LineChartBarData> lineBars = [];
                lineBars.add(LineChartBarData(
                  spots: imdSpots,
                  isCurved: true,
                  color: _imdColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ));

                for (int i = 0; i < _selectedSensors.length; i++) {
                  final sensor = _selectedSensors[i];
                  lineBars.add(LineChartBarData(
                    spots: sensorSpotsMap[sensor.key] ?? [],
                    isCurved: true,
                    color: ColorPalette.getColor(i),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ));
                }

                // Min / Max Y
                double globalMinY = double.infinity;
                double globalMaxY = double.negativeInfinity;
                for (final s in imdSpots) {
                  if (s.y < globalMinY) globalMinY = s.y;
                  if (s.y > globalMaxY) globalMaxY = s.y;
                }
                for (final spots in sensorSpotsMap.values) {
                  for (final s in spots) {
                    if (s.y < globalMinY) globalMinY = s.y;
                    if (s.y > globalMaxY) globalMaxY = s.y;
                  }
                }
                if (globalMinY == double.infinity) {
                  globalMinY = 0;
                  globalMaxY = 10;
                }
                if (globalMaxY == globalMinY) {
                  globalMinY -= 5;
                  globalMaxY += 5;
                }
                final paddingY = (globalMaxY - globalMinY) * 0.1;
                final minY = globalMinY - paddingY;
                final maxY = globalMaxY + paddingY;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Reset Zoom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(imdParamLabel(p),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        if (currentZoom > 1.0)
                          TextButton.icon(
                            icon: const Icon(Icons.zoom_out_map, size: 16),
                            label: const Text('Reset Zoom'),
                            onPressed: () => _resetZoom(p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chart
                    SizedBox(
                      height: 250,
                      child: GestureDetector(
                        onScaleStart: (details) {
                          _base[p] = _zv(p);
                        },
                        onScaleUpdate: (details) {
                          if (details.scale != 1.0) {
                            setState(() {
                              _zoom[p] = (_bv(p) * details.scale)
                                  .clamp(_minZoom, _maxZoom);
                            });
                          }
                          if (details.focalPointDelta.dx != 0 && _zv(p) > 1.0) {
                            setState(() {
                              final ppx = details.focalPointDelta.dx;
                              final spm =
                                  visMin / MediaQuery.of(context).size.width;
                              _pan[p] = _pv(p) - (ppx * spm);
                            });
                          }
                        },
                        child: LineChart(
                          LineChartData(
                            minX: minX,
                            maxX: maxX,
                            minY: minY,
                            maxY: maxY,
                            clipData: const FlClipData.all(),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey.withOpacity(0.2),
                                  strokeWidth: 1),
                              getDrawingVerticalLine: (value) => FlLine(
                                  color: Colors.grey.withOpacity(0.2),
                                  strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 45,
                                  getTitlesWidget: (v, meta) => Text(
                                      v.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 9)),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval:
                                      max(1.0, (visMin / 8).ceilToDouble()),
                                  getTitlesWidget: (v, _) {
                                    final t = globalMin.add(
                                        Duration(seconds: (v * 60).round()));
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(DateFormat('HH:mm').format(t),
                                          style: const TextStyle(fontSize: 9)),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: lineBars,
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) =>
                                    Colors.white.withOpacity(0.8),
                                tooltipBorder: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1),
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipItems: (spots) {
                                  return spots.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final spot = entry.value;
                                    final isImd = spot.barIndex == 0;

                                    Color color;
                                    String label;
                                    if (isImd) {
                                      color = _imdColor;
                                      label = 'IMD';
                                    } else {
                                      final sensorIdx = spot.barIndex - 1;
                                      if (sensorIdx >= 0 &&
                                          sensorIdx < _selectedSensors.length) {
                                        color =
                                            ColorPalette.getColor(sensorIdx);
                                        label =
                                            _selectedSensors[sensorIdx].label;
                                      } else {
                                        color = Colors.grey;
                                        label = 'Unknown';
                                      }
                                    }

                                    // Time
                                    final t = globalMin.add(Duration(
                                        seconds: (spot.x * 60).round()));
                                    String tsStr =
                                        DateFormat('dd-MM-yyyy HH:mm:ss')
                                            .format(t);

                                    List<TextSpan> children = [];

                                    // if it's the last spot, and we are comparing IMD against exactly 1 sensor
                                    if (index == spots.length - 1 &&
                                        spots.length == 2) {
                                      final otherSpot = spots.firstWhere(
                                          (s) => s.barIndex != spot.barIndex);
                                      final diff = (spot.y - otherSpot.y).abs();
                                      children.add(TextSpan(
                                        text:
                                            '\nDifference: ${diff.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11),
                                      ));
                                    }

                                    return LineTooltipItem(
                                      '$tsStr\n',
                                      TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10),
                                      children: [
                                        TextSpan(
                                          text:
                                              '$label: ${spot.y.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        ...children,
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _legendChip('IMD', _imdColor),
                          ..._selectedSensors.map((sensor) {
                            final color = ColorPalette.getColor(
                                _selectedSensors.indexOf(sensor));
                            return _legendChip(sensor.label, color);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }).toList(),

              // ── Statistics Summary ───────────────────────────────────────
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              const Text('Statistical Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              ..._selectedParams.map((p) {
                final stats = _calcStats(p);
                if (stats.isEmpty) return const SizedBox.shrink();

                final unit = imdParamUnit(p);

                List<Widget> rows = [];
                // Add IMD
                rows.add(Expanded(
                    child: _statBlock(
                        'IMD', stats['imd'] ?? {}, unit, _imdColor)));

                for (int i = 0; i < _selectedSensors.length; i++) {
                  final sensor = _selectedSensors[i];
                  rows.add(const SizedBox(width: 12));
                  rows.add(Expanded(
                      child: _statBlock(sensor.label, stats[sensor.key] ?? {},
                          unit, ColorPalette.getColor(i))));
                  rows.add(const SizedBox(width: 12));
                  rows.add(Expanded(
                      child: _statBlock(
                          '|Diff ${sensor.label}|',
                          stats['diff_${sensor.key}'] ?? {},
                          unit,
                          Colors.purple)));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(imdParamLabel(p),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0))),
                    ),
                    const SizedBox(height: 12),
                    // Using SingleChildScrollView horizontally if many sensors
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rows
                              .map((e) => SizedBox(width: 150, child: e))
                              .toList(), // Fixed width for horizontal scroll
                        ),
                      ),
                    ),
                    if (p != _selectedParams.last) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBlock(
      String title, Map<String, double> stats, String unit, Color color) {
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text('$title\nNo data',
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          _statRow('Max', stats['max'], unit, color),
          _statRow('Avg', stats['avg'], unit, color),
          _statRow('Min', stats['min'], unit, color),
        ],
      ),
    );
  }

  Widget _statRow(String label, double? val, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            val != null ? '${val.toStringAsFixed(2)} $unit' : '—',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _dateBtn(String label, DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('$label: ${_fmtDate(date)}',
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(String label, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  ORIGINAL PAGE
// ════════════════════════════════════════════════════════════

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
  bool csvLoading = false;
  String? error;

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

  Future<void> pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          startDate = picked;
        else
          endDate = picked;
      });
    }
  }

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

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
        if (earliest == null || d.timeStamp.isBefore(earliest))
          earliest = d.timeStamp;
        if (latest == null || d.timeStamp.isAfter(latest)) latest = d.timeStamp;
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

  Future<void> downloadCsv() async {
    if (devicesData.isEmpty) {
      _snack('No data loaded yet — please compare sensors first');
      return;
    }
    setState(() => csvLoading = true);

    try {
      final start = DateFormat('dd-MM-yyyy').format(startDate);
      final end = DateFormat('dd-MM-yyyy').format(endDate);

      final List<({SensorEntry sensor, String downloadUrl})> downloadLinks = [];

      for (final sensor in selectedSensors) {
        final apiUrl = buildDownloadApiUrl(
          deviceId: sensor.deviceId,
          sensorType: sensor.sensorType,
          startDate: start,
          endDate: end,
        );

        final resp = await http.get(Uri.parse(apiUrl));
        if (resp.statusCode != 200) {
          throw Exception(
              'Download API failed for ${sensor.label} (HTTP ${resp.statusCode})');
        }

        final body = json.decode(resp.body) as Map<String, dynamic>;
        final downloadUrl = body['download_url'] as String?;
        if (downloadUrl == null || downloadUrl.isEmpty) {
          throw Exception('No download_url returned for ${sensor.label}');
        }

        downloadLinks.add((sensor: sensor, downloadUrl: downloadUrl));
      }

      final List<({SensorEntry sensor, _RawCsvData csv})> sensorCsvs = [];

      for (final link in downloadLinks) {
        final s3Resp = await http.get(Uri.parse(link.downloadUrl));
        if (s3Resp.statusCode != 200) {
          throw Exception(
              'Failed to fetch S3 CSV for ${link.sensor.label} (HTTP ${s3Resp.statusCode})');
        }
        sensorCsvs.add((
          sensor: link.sensor,
          csv: _parseSensorCsv(s3Resp.body),
        ));
      }

      final Set<String> allTimestamps = {};
      for (final sc in sensorCsvs) {
        allTimestamps.addAll(sc.csv.rows.keys);
      }
      final sortedTimestamps = allTimestamps.toList()..sort();

      final List<String> orderedCols = [];
      final Set<String> seenCols = {};
      for (final sc in sensorCsvs) {
        for (final col in sc.csv.columns) {
          if (!seenCols.contains(col)) {
            seenCols.add(col);
            orderedCols.add(col);
          }
        }
      }

      final headerCells = <String>['Timestamp'];
      for (final col in orderedCols) {
        for (final sc in sensorCsvs) {
          headerCells.add('${col}_${sc.sensor.key}');
        }
      }

      final csvLines = <String>[headerCells.join(',')];

      for (final ts in sortedTimestamps) {
        final cells = <String>[ts];
        for (final col in orderedCols) {
          for (final sc in sensorCsvs) {
            final rowData = sc.csv.rows[ts];
            cells.add(rowData?[col] ?? '');
          }
        }
        csvLines.add(cells.join(','));
      }

      final csvContent = csvLines.join('\n');

      final startStr = DateFormat('yyyyMMdd').format(startDate);
      final endStr = DateFormat('yyyyMMdd').format(endDate);
      final sensorKeys = selectedSensors.map((s) => s.key).join('_');
      final fileName =
          'sensor_comparison_${sensorKeys}_${startStr}_$endStr.csv';

      _triggerBrowserDownload(csvContent, fileName);
      _snack('✓ Downloaded $fileName  (${sortedTimestamps.length} rows)');
    } catch (e) {
      _snack('CSV download failed: $e');
    } finally {
      setState(() => csvLoading = false);
    }
  }

  void _triggerBrowserDownload(String content, String fileName) {
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
      const Duration(milliseconds: 200),
      () => html.Url.revokeObjectUrl(url),
    );
  }

  Map<WeatherParameter, Map<String, Map<String, double>>>
      calculateStatistics() {
    if (matchedDataPoints.isEmpty) return {};
    final Map<WeatherParameter, Map<String, Map<String, double>>> allStats = {};
    for (final parameter in selectedParameters) {
      final Map<String, List<double>> deviceValues = {};
      for (final mp in matchedDataPoints) {
        for (final entry in mp.deviceData.entries) {
          deviceValues
              .putIfAbsent(entry.key, () => [])
              .add(getParameterValue(entry.value, parameter));
        }
      }
      final stats = {
        'max': <String, double>{},
        'min': <String, double>{},
        'avg': <String, double>{},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Multi-Sensor Comparison'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (!loading && devicesData.isNotEmpty) ...[
            if (csvLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Download CSV',
                onPressed: downloadCsv,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
              onPressed: fetchComparisonData,
            ),
          ],
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
              _buildDownloadBanner(),
              const SizedBox(height: 16),
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

            // ════════════════════════════════════════════════
            //  IMD vs SW007 SECTION — always visible
            // ════════════════════════════════════════════════
            const SizedBox(height: 32),
            const Divider(thickness: 2),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.cloud_queue, color: Color(0xFF1565C0)),
                SizedBox(width: 8),
                Text(
                  'IMD Reference Station Comparison',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const IMDComparisonSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_chart, color: Colors.deepPurple, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export Raw Sensor Data',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
                Text(
                  'All parameters · ${selectedSensors.length} sensors · grouped by parameter',
                  style: TextStyle(
                      fontSize: 12, color: Colors.deepPurple.shade400),
                ),
              ],
            ),
          ),
          if (csvLoading)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(fontSize: 13),
              ),
              onPressed: downloadCsv,
            ),
        ],
      ),
    );
  }

  Widget _buildSensorSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selected Sensors',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                _sensorTypeLegendDot(Colors.blue),
                const SizedBox(width: 4),
                const Text('CP = Campus  ', style: TextStyle(fontSize: 12)),
                _sensorTypeLegendDot(Colors.teal),
                const SizedBox(width: 4),
                const Text('SW = SW  ', style: TextStyle(fontSize: 12)),
                _sensorTypeLegendDot(Colors.deepOrange),
                const SizedBox(width: 4),
                const Text('WJ = WJ sensor', style: TextStyle(fontSize: 12)),
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

  Widget _buildParameterAndDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Parameters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    final effectiveTotal = totalMinutes < 1.0 ? 1.0 : totalMinutes;
    final visibleMinutes = effectiveTotal / zoomLevel;
    final maxPan = max(0.0, effectiveTotal - visibleMinutes);
    final clampedPan = panOffset.clamp(0.0, maxPan).toDouble();
    final rawMinX = clampedPan;
    final rawMaxX = min(clampedPan + visibleMinutes, effectiveTotal);
    final minXMin = rawMinX;
    final maxXMin = rawMaxX > rawMinX ? rawMaxX : rawMinX + 1.0;

    final List<LineChartBarData> lineBars = [];
    double allYMin = double.infinity;
    double allYMax = double.negativeInfinity;

    for (final device in devicesData) {
      final spots = <FlSpot>[];
      for (final mp in matchedDataPoints) {
        final d = mp.deviceData[device.key];
        if (d != null) {
          final elapsed = d.timeStamp.difference(globalMin).inSeconds / 60.0;
          final yVal = getParameterValue(d, parameter);
          spots.add(FlSpot(elapsed, yVal));
          if (yVal < allYMin) allYMin = yVal;
          if (yVal > allYMax) allYMax = yVal;
        }
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

    if (allYMin == double.infinity) {
      allYMin = 0;
      allYMax = 1;
    } else if (allYMin == allYMax) {
      allYMin -= 1;
      allYMax += 1;
    } else {
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
                    final vis = effectiveTot / _zoom(parameter);
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
              GestureBinding.instance.pointerSignalResolver.register(signal,
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
              });
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
                  getTooltipColor: (touchedSpot) =>
                      Colors.white.withOpacity(0.8),
                  tooltipBorder:
                      BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.asMap().entries.map((entry) {
                      final index = entry.key;
                      final spot = entry.value;
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

                      String diffText = '';
                      if (devicesData.length == 2 &&
                          touchedSpots.length == 2 &&
                          index == touchedSpots.length - 1) {
                        final val1 = touchedSpots[0].y;
                        final val2 = touchedSpots[1].y;
                        final diff = (val1 - val2).abs();
                        String diffFmt(double v) {
                          if (parameter == WeatherParameter.windDirection) {
                            return '${v.toStringAsFixed(1)}°';
                          }
                          return v.toStringAsFixed(1);
                        }

                        diffText = '\nDifference: ${diffFmt(diff)}';
                      }

                      return LineTooltipItem(
                        '$ts\n${device.label}: ${fmt(value)}',
                        TextStyle(
                          color: device.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: diffText.isEmpty
                            ? null
                            : [
                                TextSpan(
                                  text: diffText,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
        Text(title,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: values.entries.map((entry) {
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));

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
