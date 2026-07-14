import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TriviaService {
  static final Random _random = Random();

  static Future<String> getDailySurprise() async {
    final now = DateTime.now();
    final month = now.month;
    final weekday = now.weekday;

    bool isNorthernHemisphere = true;
    String locationContext = '';

    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json/'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lat = data['lat'] as double?;
        final city = data['city'] as String?;
        final country = data['country'] as String?;

        if (lat != null) {
          isNorthernHemisphere = lat >= 0;
        }
        if (city != null && country != null) {
          locationContext = "Greetings from $city, $country! ";
          try {
            final wikiUrl = Uri.parse(
              'https://en.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro&explaintext&redirects=1&titles=${Uri.encodeComponent(city)}',
            );
            final wikiResp = await http
                .get(wikiUrl)
                .timeout(const Duration(seconds: 2));
            if (wikiResp.statusCode == 200) {
              final wikiData = jsonDecode(wikiResp.body);
              final pages = wikiData['query']['pages'] as Map;
              if (pages.isNotEmpty) {
                final page = pages.values.first;
                if (page['extract'] != null) {
                  String extract = page['extract'];
                  final firstSentence = extract.split('. ').first;
                  if (firstSentence.isNotEmpty &&
                      !firstSentence.contains('may refer to')) {
                    locationContext += "\nDid you know? $firstSentence.";
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      // Fallback
    }

    // Determine season based on hemisphere
    String season = '';
    if (isNorthernHemisphere) {
      if (month >= 3 && month <= 5) {
        season = 'Spring';
      } else if (month >= 6 && month <= 8)
        season = 'Summer';
      else if (month >= 9 && month <= 11)
        season = 'Autumn';
      else
        season = 'Winter';
    } else {
      if (month >= 3 && month <= 5) {
        season = 'Autumn';
      } else if (month >= 6 && month <= 8)
        season = 'Winter';
      else if (month >= 9 && month <= 11)
        season = 'Spring';
      else
        season = 'Summer';
    }

    final List<String> trivia = [];

    // Weekday trivia
    switch (weekday) {
      case DateTime.monday:
        trivia.add(
          "It's Monday! Did you know the word 'Monday' comes from the Old English 'Mōnandæg', meaning 'Moon's day'?",
        );
        break;
      case DateTime.tuesday:
        trivia.add(
          "Happy Tuesday! Tuesday is named after Tiw, the Norse god of single combat and heroic glory.",
        );
        break;
      case DateTime.wednesday:
        trivia.add(
          "Wednesday gets its name from Woden, the chief Anglo-Saxon god.",
        );
        break;
      case DateTime.thursday:
        trivia.add(
          "It's Thursday! Named after Thor, the Norse god of thunder.",
        );
        break;
      case DateTime.friday:
        trivia.add(
          "TGIF! Friday is named after Frigg, the Norse goddess of love and beauty.",
        );
        break;
      case DateTime.saturday:
        trivia.add(
          "Happy Saturday! It's the only day of the week named after a Roman god (Saturn).",
        );
        break;
      case DateTime.sunday:
        trivia.add(
          "It's Sunday, the day of the Sun! A perfect day for creativity.",
        );
        break;
    }

    // Month trivia
    switch (month) {
      case 1:
        trivia.add(
          "It's January, named after Janus, the Roman god of beginnings and transitions.",
        );
        break;
      case 2:
        trivia.add(
          "It's February! The shortest month, named after 'Februa', a Roman festival of purification.",
        );
        break;
      case 3:
        trivia.add(
          "March is named after Mars, the Roman god of war. It was originally the first month of the Roman calendar!",
        );
        break;
      case 4:
        trivia.add(
          "Welcome to April! The name might come from the Latin 'aperire', meaning 'to open', as trees begin to open their leaves.",
        );
        break;
      case 5:
        trivia.add(
          "It's May, named after the Greek goddess Maia, who was associated with growth and plants.",
        );
        break;
      case 6:
        trivia.add(
          "June is named after Juno, the Roman goddess of marriage and childbirth.",
        );
        break;
      case 7:
        trivia.add(
          "July was named by the Roman Senate in honor of Julius Caesar, as it was the month of his birth.",
        );
        break;
      case 8:
        trivia.add(
          "August was named to honor the first Roman emperor, Augustus Caesar.",
        );
        break;
      case 9:
        trivia.add(
          "September means 'the seventh month' in Latin, because it was the 7th month of the original Roman calendar.",
        );
        break;
      case 10:
        trivia.add(
          "October means 'the eighth month', a remnant of the early Roman calendar.",
        );
        break;
      case 11:
        trivia.add(
          "November means 'the ninth month' in Latin, keeping its name from the ancient 10-month Roman calendar.",
        );
        break;
      case 12:
        trivia.add(
          "December means 'the tenth month', the last month of the ancient Roman calendar.",
        );
        break;
    }

    // Season trivia
    if (season == 'Winter') {
      trivia.add(
        "It's Winter! Did you know snow absorbs sound, which is why the world seems so quiet after a fresh snowfall?",
      );
    } else if (season == 'Spring') {
      trivia.add(
        "It's Spring! The first day of Spring is called the vernal equinox, when day and night are almost exactly 12 hours each.",
      );
    } else if (season == 'Summer') {
      trivia.add(
        "It's Summer! The Eiffel Tower actually grows taller in the summer due to thermal expansion of the iron.",
      );
    } else if (season == 'Autumn') {
      trivia.add(
        "It's Autumn! Leaves change color because as days get shorter, chlorophyll breaks down and reveals the hidden pigments.",
      );
    }

    // Date specific
    if (now.day == 1) {
      trivia.add(
        "It's the 1st of the month! A perfect blank canvas for new ideas.",
      );
    } else if (now.day == 31) {
      trivia.add(
        "It's the last day of the month! Time to wrap up those creative masterpieces.",
      );
    }

    // Pick a random trivia from the relevant pool
    String finalTrivia = trivia[_random.nextInt(trivia.length)];
    if (locationContext.isNotEmpty) {
      finalTrivia = "$locationContext\n\n$finalTrivia";
    }
    return finalTrivia;
  }
}
