import 'package:string_similarity/string_similarity.dart';

class CityMatcher {
  static const List<String> majorCities = [
    "Tokyo",
    "Delhi",
    "Shanghai",
    "Sao Paulo",
    "Mumbai",
    "Beijing",
    "Cairo",
    "Dhaka",
    "Mexico City",
    "Osaka",
    "Karachi",
    "Chongqing",
    "Istanbul",
    "Buenos Aires",
    "Kolkata",
    "Lagos",
    "Kinshasa",
    "Manila",
    "Rio de Janeiro",
    "Guangzhou",
    "Lahore",
    "Shenzhen",
    "Bangalore",
    "Moscow",
    "Tianjin",
    "Jakarta",
    "London",
    "Lima",
    "Bangkok",
    "Chennai",
    "Seoul",
    "Bogota",
    "Ho Chi Minh City",
    "Hyderabad",
    "Chengdu",
    "Tehran",
    "Nanjing",
    "Wuhan",
    "Kabul",
    "Ahmedabad",
    "Kuala Lumpur",
    "New York",
    "Hong Kong",
    "Dongguan",
    "Hangzhou",
    "Foshan",
    "Riyadh",
    "Baghdad",
    "Santiago",
    "Surat",
    "Madrid",
    "Suzhou",
    "Pune",
    "Harbin",
    "Houston",
    "Dallas",
    "Toronto",
    "Dar es Salaam",
    "Miami",
    "Belo Horizonte",
    "Singapore",
    "Philadelphia",
    "Atlanta",
    "Fukuoka",
    "Khartoum",
    "Barcelona",
    "Johannesburg",
    "St. Petersburg",
    "Qingdao",
    "Dalian",
    "Washington",
    "Yangon",
    "Alexandria",
    "Jinan",
    "Guadalajara",
    "Sydney",
    "Melbourne",
    "Brisbane",
    "Perth",
    "Adelaide",
    "Hobart",
    "Darwin",
    "Canberra",
    "Paris",
    "Berlin",
    "Rome",
    "Vienna",
    "Amsterdam",
    "Dublin",
    "Dubai",
    "Doha",
    "Krakow",
    "Warsaw",
    "Los Angeles",
    "Chicago",
    "San Francisco",
    "Seattle",
    "Boston",
    "Austin",
    "Denver",
    "Las Vegas",
    "Vancouver",
    "Montreal",
    "Cape Town",
  ];

  static const Map<String, String> aliases = {
    "bd": "Dhaka",
    "bangladesh": "Dhaka",
    "uk": "London",
    "us": "Washington",
    "usa": "Washington",
    "ny": "New York",
    "la": "Los Angeles",
    "uae": "Dubai",
    "aus": "Canberra",
    "nz": "Wellington",
  };

  static String? findBestMatch(String query, {double threshold = 0.5}) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.length < 2) return null; // Allow 2-letter codes like BD

    // Check aliases first (exact match)
    if (aliases.containsKey(cleanQuery)) {
      return aliases[cleanQuery];
    }

    // Find the best match
    final match = query.bestMatch(majorCities);

    if (match.bestMatch.rating! >= threshold) {
      return match.bestMatch.target;
    }

    return null;
  }
}
