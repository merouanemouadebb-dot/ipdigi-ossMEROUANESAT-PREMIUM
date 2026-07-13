import 'package:xml/xml.dart';

import '../domain/epg_program.dart';

/// Parses an XMLTV string into a flat list of [EpgProgram]s. Hands back
/// the raw collection so callers can build whatever index they need
/// (most call sites group by channel id).
///
/// XMLTV is a community spec - element layout is stable, but date and
/// timezone formatting drift between providers. We accept the canonical
/// `YYYYMMDDhhmmss [TZ]` form (e.g. `20260520140000 +0300`) plus a few
/// near-misses spotted on real IPTV panels: no timezone, no seconds,
/// stray colons in the offset.
class XmltvParser {
  static List<EpgProgram> parse(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final programs = <EpgProgram>[];
    for (final el in doc.findAllElements('programme')) {
      final channel = el.getAttribute('channel');
      final startRaw = el.getAttribute('start');
      final stopRaw = el.getAttribute('stop');
      if (channel == null || startRaw == null || stopRaw == null) continue;
      final start = _parseXmltvDate(startRaw);
      final stop = _parseXmltvDate(stopRaw);
      if (start == null || stop == null) continue;
      final title = el.findElements('title').firstOrNull?.innerText.trim();
      if (title == null || title.isEmpty) continue;
      final desc = el.findElements('desc').firstOrNull?.innerText.trim();
      final categories = <String>[];
      for (final c in el.findElements('category')) {
        final t = c.innerText.trim();
        if (t.isNotEmpty) categories.add(t);
      }
      programs.add(
        EpgProgram(
          channelId: channel,
          title: title,
          description: (desc == null || desc.isEmpty) ? null : desc,
          start: start,
          stop: stop,
          categories: categories,
        ),
      );
    }
    return programs;
  }

  /// XMLTV's date attribute is "YYYYMMDDhhmmss [+|-]HHMM". We split off
  /// the optional offset, parse the 14-digit local stamp, and adjust to
  /// UTC. Returns null on any malformed input - bad rows are dropped
  /// rather than crashing the whole guide.
  static DateTime? _parseXmltvDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // Split off the timezone suffix (everything from the last space, or
    // the last + / - after position 14).
    String body = trimmed;
    String? tz;
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx > 0) {
      body = trimmed.substring(0, spaceIdx);
      tz = trimmed.substring(spaceIdx + 1).trim();
    }
    body = body.replaceAll(RegExp(r'[^0-9]'), '');
    if (body.length < 12) return null;
    // Pad seconds to 14 chars if the panel dropped them.
    if (body.length == 12) body = '${body}00';
    int? section(int from, int len) =>
        int.tryParse(body.substring(from, from + len));
    final y = section(0, 4);
    final mo = section(4, 2);
    final d = section(6, 2);
    final h = section(8, 2);
    final mi = section(10, 2);
    final s = section(12, 2);
    if (y == null || mo == null || d == null || h == null || mi == null) {
      return null;
    }
    // Assemble in UTC, then apply the panel's timezone offset to get the
    // true UTC instant. If the panel didn't include a TZ we assume UTC -
    // the resulting clock is at worst a few hours off, but the duration
    // and progress math stays correct.
    final localAsUtc = DateTime.utc(y, mo, d, h, mi, s ?? 0);
    final offset = _parseOffset(tz);
    return localAsUtc.subtract(offset);
  }

  static Duration _parseOffset(String? tz) {
    if (tz == null || tz.isEmpty) return Duration.zero;
    final cleaned = tz.replaceAll(':', '');
    final m = RegExp(r'^([+\-])(\d{2})(\d{2})$').firstMatch(cleaned);
    if (m == null) return Duration.zero;
    final sign = m.group(1) == '-' ? -1 : 1;
    final hh = int.tryParse(m.group(2)!) ?? 0;
    final mm = int.tryParse(m.group(3)!) ?? 0;
    return Duration(hours: sign * hh, minutes: sign * mm);
  }
}
