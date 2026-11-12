import 'package:eimzo_flutter/eimzo_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The link an app makes for the SDK must be the very one an E-IMZO site
/// would put in its QR code. The three below came from test.e-imzo.uz's demo
/// page (2026-11-02); the Android and iOS SDKs test the same three.
void main() {
  const samples = [
    ('20e2', '937E4984', '17055ec4958507c957eba8576c0445a1fd5ac4457a4adaaa0c23c58d02d3153e', '22b8ea24'),
    ('20e2', '85757F10', '4da19aeecf29ffe2b7397db89e39c98647fb99012970e18f39e47585ce909ca5', '27480a45'),
    ('20e2', '3DB216AC', 'daaec72d3b8950f90a71cbc80d171e0c7890ff7fa27419b9e2992a4baed78d22', '60b6be20'),
  ];

  test('the link is the site\'s own, CRC and all', () {
    for (final (siteId, documentId, hash, crc) in samples) {
      expect(
        EimzoSignLink.create(siteId: siteId, documentId: documentId, hash: hash),
        'eimzo://sign?qc=$siteId$documentId$hash$crc',
      );
    }
  });

  test('values out of form are refused, not turned into a link that fails later', () {
    final (_, _, hash, _) = samples.first;
    void refused(String siteId, String documentId, String hash) => expect(
        () => EimzoSignLink.create(siteId: siteId, documentId: documentId, hash: hash),
        throwsArgumentError);

    refused('20e', '937E4984', hash);
    refused('20g2', '937E4984', hash);
    refused('20e2', '937E498', hash);
    refused('20e2', '937E4984', hash.substring(1));
    refused('20e2', '937E4984', '$hash ');
  });
}
