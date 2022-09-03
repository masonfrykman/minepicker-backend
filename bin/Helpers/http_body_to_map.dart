Map<String, String> httpBodyToMap(String body) {
  final params = body.split("&");
  final paramMap = <String, String>{};
  for (String param in params) {
    final ps = param.split("=");
    if (ps.length != 2) {
      continue;
    }
    paramMap.addAll({ps.first: ps.last});
  }
  return paramMap;
}
