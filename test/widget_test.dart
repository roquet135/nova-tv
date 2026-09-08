import 'package:flutter_test/flutter_test.dart';

import 'package:nova_tv/main.dart';

/// Test de fumee : l'app NOVA TV se construit correctement.
void main() {
  test('NovaApp existe et se construit', () {
    expect(const NovaApp(), isA<NovaApp>());
  });
}
