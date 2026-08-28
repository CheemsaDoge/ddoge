import 'dart:convert';
import 'dart:typed_data';

import 'package:ddoge/features/import/parsers/mht_html_extractor.dart';
import 'package:ddoge/features/import/parsers/uestc_eams_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extractor = MhtHtmlExtractor();

  test('extracts quoted-printable UTF-8 HTML from an MHT archive', () {
    const mht = '''MIME-Version: 1.0
Content-Type: multipart/related; boundary="----=_NextPart_000_0000"

------=_NextPart_000_0000
Content-Type: text/html; charset="utf-8"
Content-Transfer-Encoding: quoted-printable

<html><script>var unitCount =3D 12;
activity =3D new TaskActivity("1","=E5=BC=A0=E4=B8=89","1","=E6=B5=8B=E8=AF=95(A1)","1","A101","01100000000000000000000000000000000000000000000000000");
index =3D 0*unitCount+0;
table0.activities[index][0] =3D activity;</script></html>
------=_NextPart_000_0000--
''';

    final html = extractor.extract(Uint8List.fromList(utf8.encode(mht)));

    expect(html, contains('new TaskActivity'));
    expect(html, contains('张三'));
    expect(html, contains('测试(A1)'));
    expect(UestcEamsParser().parse(html, 'semester').single.name, '测试');
  });

  test('extracts Base64 HTML and ignores non-HTML MIME parts', () {
    const html = '<html><body>课表</body></html>';
    final mht =
        '''MIME-Version: 1.0
Content-Type: multipart/related; boundary=boundary42

--boundary42
Content-Type: image/png
Content-Transfer-Encoding: base64

AA==
--boundary42
Content-Type: text/html; charset=utf-8
Content-Transfer-Encoding: base64

${base64.encode(utf8.encode(html))}
--boundary42--
''';

    expect(extractor.extract(Uint8List.fromList(utf8.encode(mht))), html);
  });

  test('rejects MHT archives without an HTML MIME part', () {
    const mht = '''MIME-Version: 1.0
Content-Type: multipart/related; boundary=x

--x
Content-Type: image/png

binary
--x--
''';

    expect(
      () => extractor.extract(Uint8List.fromList(utf8.encode(mht))),
      throwsFormatException,
    );
  });
}
