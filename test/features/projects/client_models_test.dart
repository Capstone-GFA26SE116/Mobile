import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/projects/models/project_models.dart';

void main() {
  group('Client Model Tests', () {
    test('ClientModel deserializes from JSON with notes and email', () {
      final json = {
        'id': 'cli-101',
        'name': 'Tech Corp',
        'contactEmail': 'contact@techcorp.io',
        'phone': '+84 901 234 567',
        'notes': 'Payment term Net-15. Contact via Telegram.',
        'createdAt': '2026-11-12T00:00:00Z',
      };

      final client = ClientModel.fromJson(json);
      expect(client.id, 'cli-101');
      expect(client.name, 'Tech Corp');
      expect(client.contactEmail, 'contact@techcorp.io');
      expect(client.phone, '+84 901 234 567');
      expect(client.notes, 'Payment term Net-15. Contact via Telegram.');
      expect(client.createdAt, isNotNull);
    });

    test('ClientModel handles email fallback key', () {
      final json = {
        'id': 'cli-102',
        'name': 'Design Agency',
        'email': 'hello@designagency.com',
      };

      final client = ClientModel.fromJson(json);
      expect(client.contactEmail, 'hello@designagency.com');
      expect(client.notes, isNull);
    });

    test('ClientModel serializes to JSON correctly', () {
      final client = ClientModel(
        id: 'cli-103',
        name: 'Initech',
        contactEmail: 'peter@initech.com',
        phone: '555-0199',
        notes: 'TPS reports review',
      );

      final json = client.toJson();
      expect(json['name'], 'Initech');
      expect(json['contactEmail'], 'peter@initech.com');
      expect(json['phone'], '555-0199');
      expect(json['notes'], 'TPS reports review');
    });
  });
}

