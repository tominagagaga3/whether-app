import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const WeatherApp());

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Otenki Navi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const WeatherHome(),
    );
  }
}

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  final _controller = TextEditingController(text: 'Tokyo');

  bool _loading = false;
  String? _error;

  // current
  String? _place;
  num? _temp;
  num? _wind;
  int? _code;
  int? _isDay; // 1 day / 0 night

  // daily arrays
  List<String> _days = [];
  List<num> _tmax = [];
  List<num> _tmin = [];
  List<int> _dCode = [];

  Future<void> _search() async {
    final city = _controller.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final geoUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=ja&format=json',
      );
      final geoRes = await http.get(geoUrl);
      if (geoRes.statusCode != 200) throw Exception('Geocoding failed');

      final geoJson = jsonDecode(geoRes.body) as Map<String, dynamic>;
      final results = (geoJson['results'] as List?) ?? [];
      if (results.isEmpty) throw Exception('都市が見つかりませんでした');

      final first = results.first as Map<String, dynamic>;
      final lat = first['latitude'];
      final lon = first['longitude'];
      final name = first['name'];
      final country = first['country'];

      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,wind_speed_10m,weather_code,is_day'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=Asia%2FTokyo',
      );

      final wRes = await http.get(weatherUrl);
      if (wRes.statusCode != 200) throw Exception('Weather fetch failed');

      final wJson = jsonDecode(wRes.body) as Map<String, dynamic>;
      final current = wJson['current'] as Map<String, dynamic>;
      final daily = wJson['daily'] as Map<String, dynamic>;

      setState(() {
        _place = '$name, $country';
        _temp = current['temperature_2m'];
        _wind = current['wind_speed_10m'];
        _code = current['weather_code'];
        _isDay = current['is_day'];

        _days = (daily['time'] as List).cast<String>();
        _tmax = (daily['temperature_2m_max'] as List).cast<num>();
        _tmin = (daily['temperature_2m_min'] as List).cast<num>();
        _dCode = (daily['weather_code'] as List).cast<int>();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  WeatherVisual _visualFromCode(int? code, bool isDay) {
    // Open-Meteo weather_code: https://open-meteo.com/en/docs
    // 0 clear, 1/2/3 mainly clear..overcast
    // 45/48 fog
    // 51..57 drizzle
    // 61..67 rain
    // 71..77 snow
    // 80..82 rain showers
    // 85..86 snow showers
    // 95..99 thunderstorm
    final c = code ?? 0;

    if (c == 0) {
      return isDay
          ? const WeatherVisual('☀️', '快晴', WeatherTheme.sunny)
          : const WeatherVisual('🌙', '快晴（夜）', WeatherTheme.night);
    }
    if ([1, 2].contains(c)) {
      return isDay
          ? const WeatherVisual('🌤️', '晴れ', WeatherTheme.sunny)
          : const WeatherVisual('🌙☁️', '晴れ（夜）', WeatherTheme.night);
    }
    if (c == 3) return const WeatherVisual('☁️', 'くもり', WeatherTheme.cloudy);
    if ([45, 48].contains(c)) return const WeatherVisual('🌫️', '霧', WeatherTheme.fog);
    if (c >= 51 && c <= 57) return const WeatherVisual('🌦️', '霧雨', WeatherTheme.rainy);
    if (c >= 61 && c <= 67) return const WeatherVisual('🌧️', '雨', WeatherTheme.rainy);
    if (c >= 71 && c <= 77) return const WeatherVisual('❄️', '雪', WeatherTheme.snowy);
    if (c >= 80 && c <= 82) return const WeatherVisual('🌧️', 'にわか雨', WeatherTheme.rainy);
    if (c >= 85 && c <= 86) return const WeatherVisual('🌨️', 'にわか雪', WeatherTheme.snowy);
    if (c >= 95 && c <= 99) return const WeatherVisual('⛈️', '雷雨', WeatherTheme.storm);
    return const WeatherVisual('🌡️', '天気', WeatherTheme.sunny);
  }

  List<Color> _backgroundGradient(WeatherTheme theme, bool isDay) {
    switch (theme) {
      case WeatherTheme.sunny:
        return isDay
            ? const [Color(0xFF62C7FF), Color(0xFFFFF2B2)]
            : const [Color(0xFF0B1B3A), Color(0xFF3A2B6F)];
      case WeatherTheme.cloudy:
        return const [Color(0xFF8EA3B0), Color(0xFFD5DEE5)];
      case WeatherTheme.rainy:
        return const [Color(0xFF2E4B63), Color(0xFF0F1E2B)];
      case WeatherTheme.snowy:
        return const [Color(0xFFB7D8FF), Color(0xFFFFFFFF)];
      case WeatherTheme.fog:
        return const [Color(0xFFB7B7B7), Color(0xFFE6E6E6)];
      case WeatherTheme.storm:
        return const [Color(0xFF1F1F2E), Color(0xFF3B2A5A)];
      case WeatherTheme.night:
        return const [Color(0xFF3F51B5), Color(0xFF7986CB)];
    }
  }

  String _md(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length < 3) return isoDate;
    return '${int.parse(parts[1])}/${int.parse(parts[2])}';
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _place != null && _temp != null;
    final isDay = (_isDay ?? 1) == 1;
    final visual = _visualFromCode(_code, isDay);

    final bg = _backgroundGradient(visual.theme, isDay);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bg,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                Row(
                  children: [
                    const Icon(Icons.wb_sunny, size: 22, color: Colors.yellow,),
                    const SizedBox(width: 8),
                    Text(
                      'Otenki Navi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '再検索',
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _Glass(
                  child: Row(
                    children: [
                      const Icon(Icons.search),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: '都市名（例：Tokyo / Osaka / Sapporo）',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      FilledButton(
                        onPressed: _loading ? null : _search,
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('検索'),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_error != null)
                  _Glass(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!)),
                        ],
                      ),
                    ),
                  ),

                if (!hasData) const Spacer(),

                if (hasData) ...[

                  _Glass(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visual.emoji,
                            style: const TextStyle(fontSize: 48),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _place!,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  visual.label,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${_temp!.toStringAsFixed(1)}°',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text('風速：${_wind?.toStringAsFixed(1) ?? "-"} m/s'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _Glass(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '7日間予報',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 160,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _days.length.clamp(0, 7),
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final v = _visualFromCode(_dCode.isNotEmpty ? _dCode[i] : 0, true);
                                return _MiniCard(
                                  day: _md(_days[i]),
                                  emoji: v.emoji,
                                  max: _tmax.isNotEmpty ? _tmax[i] : 0,
                                  min: _tmin.isNotEmpty ? _tmin[i] : 0,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                Opacity(
                  opacity: 0.65,
                  child: Text(
                    'Open-Meteo API • Web対応',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum WeatherTheme { sunny, cloudy, rainy, snowy, fog, storm, night }

class WeatherVisual {
  final String emoji;
  final String label;
  final WeatherTheme theme;
  const WeatherVisual(this.emoji, this.label, this.theme);
}

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String day;
  final String emoji;
  final num max;
  final num min;

  const _MiniCard({
    required this.day,
    required this.emoji,
    required this.max,
    required this.min,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112, 
      padding: const EdgeInsets.all(10), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            '↑ ${max.toStringAsFixed(0)}°',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            '↓ ${min.toStringAsFixed(0)}°',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}