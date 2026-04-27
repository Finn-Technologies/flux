import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

/// Simple web-search results model.
class SearchResult {
  final String title;
  final String url;
  final String snippet;

  SearchResult({required this.title, required this.url, required this.snippet});
}

/// Lightweight search service that scrapes DuckDuckGo HTML (no-JS version).
/// No API keys required.
class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  /// Search DuckDuckGo HTML (non-JS) and return the top [maxResults] snippets.
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) return [];

    try {
      // Use the DuckDuckGo HTML endpoint which is designed for non-JS clients
      final uri = Uri.https(
        'html.duckduckgo.com',
        '/html/',
        {'q': query.trim(), 'kl': 'us-en'},
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('Search HTTP ${response.statusCode}');
        return [];
      }

      final body = utf8.decode(response.bodyBytes);
      final document = parse(body);
      final results = <SearchResult>[];

      // DuckDuckGo HTML results:
      // Each result is a div with class .result
      // Title + link are in .result__a
      // Snippet is in .result__snippet
      final resultDivs = document.querySelectorAll('div.result');
      print('Search: found ${resultDivs.length} result divs');

      for (var i = 0; i < resultDivs.length && results.length < maxResults; i++) {
        final div = resultDivs[i];
        final anchor = div.querySelector('a.result__a');
        if (anchor == null) continue;

        final title = anchor.text.trim();
        var href = anchor.attributes['href'] ?? '';

        // DuckDuckGo uses relative redirect URLs like //duckduckgo.com/l/?uddg=...
        if (href.startsWith('//')) href = 'https:$href';
        if (href.startsWith('/')) href = 'https://html.duckduckgo.com$href';

        final snippetEl = div.querySelector('a.result__snippet');
        final snippet = snippetEl?.text.trim() ?? '';

        if (title.isNotEmpty) {
          results.add(SearchResult(
            title: title,
            url: href,
            snippet: snippet,
          ));
        }
      }

      print('Search: returning ${results.length} results');
      return results;
    } catch (e, st) {
      print('Search error: $e');
      print(st);
      return [];
    }
  }

  /// Format search results into a concise context string for the model.
  String formatResultsForModel(List<SearchResult> results) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln('=== WEB SEARCH RESULTS ===');
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('[${i + 1}] ${r.title}');
      if (r.snippet.isNotEmpty) buffer.writeln('    ${r.snippet}');
    }
    buffer.writeln('==========================');
    return buffer.toString();
  }
}
