import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherWidget extends StatefulWidget {
  final String city;
  final int days;

  const WeatherWidget({super.key, required this.city, this.days = 3});

  @override
  _WeatherWidgetState createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  late Future<Map<String, dynamic>> _weatherData;

  @override
  void initState() {
    super.initState();
    _weatherData = _fetchWeather();
  }

  @override
  void didUpdateWidget(WeatherWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city || oldWidget.days != widget.days) {
      setState(() {
        _weatherData = _fetchWeather();
      });
    }
  }

  Future<Map<String, dynamic>> _fetchWeather() async {
    // 1. Geocoding
    final geoRes = await http.get(
      Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${widget.city}&count=1&format=json',
      ),
    );
    if (geoRes.statusCode != 200) throw Exception('Geocoding failed');
    final geoData = jsonDecode(geoRes.body);
    if (geoData['results'] == null || geoData['results'].isEmpty) {
      throw Exception('City not found');
    }

    final lat = geoData['results'][0]['latitude'];
    final lon = geoData['results'][0]['longitude'];
    final realCityName = geoData['results'][0]['name'];

    // 2. Weather Forecast
    final weatherRes = await http.get(
      Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=auto',
      ),
    );
    if (weatherRes.statusCode != 200) throw Exception('Weather API failed');

    final weatherData = jsonDecode(weatherRes.body);
    weatherData['real_city_name'] = realCityName; // Inject real city name
    return weatherData;
  }

  String _getWeatherEmoji(int code) {
    // WMO Weather interpretation codes (WW)
    if (code == 0) return '☀️'; // Clear
    if (code == 1 || code == 2 || code == 3) return '⛅'; // Partly cloudy
    if (code >= 45 && code <= 48) return '🌫️'; // Fog
    if (code >= 51 && code <= 67) return '🌧️'; // Drizzle / Rain
    if (code >= 71 && code <= 77) return '❄️'; // Snow
    if (code >= 80 && code <= 82) return '🌧️'; // Rain showers
    if (code >= 85 && code <= 86) return '❄️'; // Snow showers
    if (code >= 95) return '⛈️'; // Thunderstorm
    return '☁️';
  }

  String _getWeatherDesc(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2 || code == 3) return 'Partly cloudy';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.days > 4 ? 680 : 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _weatherData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 200,
              child: Center(
                child: Text('Failed to load weather: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data!;
          final current = data['current_weather'];
          final daily = data['daily'];
          final realCityName = data['real_city_name'];

          final temp = current['temperature'].round();
          final code = current['weathercode'];
          final wind = current['windspeed'];
          final desc = _getWeatherDesc(code);

          // Limit daily array to `widget.days`
          final int length = (daily['time'] as List).length;
          final int displayDays = widget.days.clamp(1, length);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 20,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    realCityName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getWeatherEmoji(code),
                    style: const TextStyle(fontSize: 64),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$temp',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24.0, left: 2),
                    child: Text(
                      '°C',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wind: $wind km/h',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Dynamic Day Forecast
              const Divider(color: Colors.black12),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(displayDays, (index) {
                    final dateStr = daily['time'][index];
                    final date = DateTime.parse(dateStr);
                    final dayName = DateFormat('EEE').format(date);

                    final maxT = (daily['temperature_2m_max'][index] as num)
                        .round();
                    final minT = (daily['temperature_2m_min'][index] as num)
                        .round();
                    final dailyCode = daily['weathercode'][index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          Text(
                            index == 0 ? 'Today' : dayName,
                            style: TextStyle(
                              fontWeight: index == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getWeatherEmoji(dailyCode),
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '$maxT°',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$minT°',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
