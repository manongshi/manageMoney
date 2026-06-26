String? selectSpeechLocale(
  Iterable<String> availableLocaleIds,
  String? systemLocaleId,
) {
  final available = availableLocaleIds
      .where((id) => id.trim().isNotEmpty)
      .toList();
  final system = systemLocaleId?.trim();

  bool isChinese(String id) {
    final normalized = id.toLowerCase().replaceAll('_', '-');
    return normalized.startsWith('zh') ||
        normalized.startsWith('cmn') ||
        normalized.contains('hans') ||
        normalized.contains('hant');
  }

  if (system != null && system.isNotEmpty && isChinese(system)) {
    return system;
  }

  for (final localeId in available) {
    if (isChinese(localeId)) return localeId;
  }

  if (system != null && system.isNotEmpty) {
    return system;
  }

  return available.isEmpty ? null : available.first;
}
