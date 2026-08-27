import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/shell/shell_destinations.dart';

void main() {
  test('tourist gets four destinations in Stitch order', () {
    final d = destinationsForRole('tourist');
    expect(d.map((e) => e.label).toList(),
        ['Explorer', 'Recherche', 'Voyages', 'Profil']);
  });

  test('guide gets three destinations', () {
    final d = destinationsForRole('guide');
    expect(d.map((e) => e.label).toList(), ['Dashboard', 'Agenda', 'Profil']);
  });

  test('unknown role falls back to the tourist set', () {
    expect(destinationsForRole('wizard').length, 4);
  });

  test('every destination has a distinct label', () {
    for (final role in ['tourist', 'guide']) {
      final labels = destinationsForRole(role).map((e) => e.label).toList();
      expect(labels.toSet().length, labels.length, reason: 'duplicate label in $role');
    }
  });
}
