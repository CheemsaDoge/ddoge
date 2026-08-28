import 'dart:convert';
import 'dart:typed_data';

/// Extracts the HTML document stored in an MHT/MHTML archive.
///
/// This is deliberately a small, offline MIME reader: it only reads the
/// `text/html` part and never loads embedded resources or executes scripts.
class MhtHtmlExtractor {
  const MhtHtmlExtractor();

  String extract(Uint8List bytes) {
    // Latin-1 is a lossless byte-to-code-unit mapping, making it safe to find
    // ASCII MIME delimiters before decoding the selected HTML part.
    final source = latin1.decode(bytes, allowInvalid: true);
    final headerEnd = _headerEnd(source);
    if (headerEnd == null) {
      throw const FormatException('MHT 文件缺少 MIME 头部。');
    }

    final headers = _parseHeaders(source.substring(0, headerEnd.start));
    final contentType = headers['content-type'] ?? '';
    final boundary = _boundaryFrom(contentType);
    if (boundary == null || !contentType.toLowerCase().contains('multipart/')) {
      throw const FormatException('不是受支持的 multipart MHT 文件。');
    }

    final parts = source.substring(headerEnd.end).split('--$boundary');
    for (final rawPart in parts.skip(1)) {
      final part = rawPart.replaceFirst(RegExp(r'^\r?\n'), '');
      if (part.startsWith('--')) break;

      final partHeaderEnd = _headerEnd(part);
      if (partHeaderEnd == null) continue;
      final partHeaders = _parseHeaders(part.substring(0, partHeaderEnd.start));
      final partContentType = partHeaders['content-type'] ?? '';
      if (!partContentType.toLowerCase().startsWith('text/html')) continue;

      final encodedBody = part.substring(partHeaderEnd.end);
      final body = _decodeTransferEncoding(
        encodedBody,
        partHeaders['content-transfer-encoding'],
      );
      return _decodeText(body, partContentType);
    }

    throw const FormatException('MHT 文件中未找到 HTML 正文。');
  }

  _HeaderEnd? _headerEnd(String value) {
    final crlf = value.indexOf('\r\n\r\n');
    final lf = value.indexOf('\n\n');
    if (crlf < 0 && lf < 0) return null;
    if (crlf >= 0 && (lf < 0 || crlf <= lf)) {
      return _HeaderEnd(crlf, crlf + 4);
    }
    return _HeaderEnd(lf, lf + 2);
  }

  Map<String, String> _parseHeaders(String value) {
    final unfolded = value.replaceAll(RegExp(r'\r?\n[ \t]+'), ' ');
    final headers = <String, String>{};
    for (final line in unfolded.split(RegExp(r'\r?\n'))) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      headers[line.substring(0, separator).trim().toLowerCase()] = line
          .substring(separator + 1)
          .trim();
    }
    return headers;
  }

  String? _boundaryFrom(String contentType) {
    final match = RegExp(
      r'boundary\s*=\s*(?:"([^"]+)"|([^;\s]+))',
      caseSensitive: false,
    ).firstMatch(contentType);
    return match?.group(1) ?? match?.group(2);
  }

  Uint8List _decodeTransferEncoding(String body, String? encoding) {
    final normalized = encoding?.trim().toLowerCase() ?? '';
    if (normalized == 'base64') {
      try {
        return Uint8List.fromList(
          base64.decode(body.replaceAll(RegExp(r'\s'), '')),
        );
      } on FormatException {
        throw const FormatException('MHT HTML 正文的 Base64 编码无效。');
      }
    }
    if (normalized == 'quoted-printable') {
      return _decodeQuotedPrintable(body);
    }
    return Uint8List.fromList(latin1.encode(body));
  }

  Uint8List _decodeQuotedPrintable(String value) {
    final bytes = <int>[];
    for (var index = 0; index < value.length; index++) {
      final char = value.codeUnitAt(index);
      if (char != 0x3d) {
        bytes.add(char);
        continue;
      }
      if (index + 1 < value.length && value.codeUnitAt(index + 1) == 0x0a) {
        index++;
        continue;
      }
      if (index + 2 < value.length &&
          value.codeUnitAt(index + 1) == 0x0d &&
          value.codeUnitAt(index + 2) == 0x0a) {
        index += 2;
        continue;
      }
      if (index + 2 < value.length) {
        final high = _hexValue(value.codeUnitAt(index + 1));
        final low = _hexValue(value.codeUnitAt(index + 2));
        if (high != null && low != null) {
          bytes.add((high << 4) | low);
          index += 2;
          continue;
        }
      }
      bytes.add(char);
    }
    return Uint8List.fromList(bytes);
  }

  int? _hexValue(int codeUnit) {
    if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
    if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x41 + 10;
    if (codeUnit >= 0x61 && codeUnit <= 0x66) return codeUnit - 0x61 + 10;
    return null;
  }

  String _decodeText(Uint8List bytes, String contentType) {
    final charsetMatch = RegExp(
      r'charset\s*=\s*(?:"([^"]+)"|([^;\s]+))',
      caseSensitive: false,
    ).firstMatch(contentType);
    final charset = (charsetMatch?.group(1) ?? charsetMatch?.group(2) ?? '')
        .toLowerCase();

    if (charset.startsWith('utf-16')) return _decodeUtf16(bytes, charset);
    // EAMS exports created by modern browsers use UTF-8. The permissive decode
    // still leaves the JavaScript structure available for a clear parser error.
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _decodeUtf16(Uint8List bytes, String charset) {
    if (bytes.length.isOdd) {
      throw const FormatException('MHT HTML 正文的 UTF-16 字节长度无效。');
    }
    final littleEndian = bytes.length >= 2
        ? bytes[0] == 0xff && bytes[1] == 0xfe
        : charset != 'utf-16be';
    final start =
        bytes.length >= 2 &&
            ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
                (bytes[0] == 0xfe && bytes[1] == 0xff))
        ? 2
        : 0;
    final codeUnits = <int>[];
    for (var index = start; index < bytes.length; index += 2) {
      codeUnits.add(
        littleEndian
            ? bytes[index] | (bytes[index + 1] << 8)
            : (bytes[index] << 8) | bytes[index + 1],
      );
    }
    return String.fromCharCodes(codeUnits);
  }
}

class _HeaderEnd {
  const _HeaderEnd(this.start, this.end);

  final int start;
  final int end;
}
