import 'package:flutter_test/flutter_test.dart';
import 'package:trenzy/models/direct_message.dart';

void main() {
  test('parses a direct message payload', () {
    final message = DirectMessage.fromJson({
      'id': 42,
      'senderFirebaseUid': 'sender',
      'recipientFirebaseUid': 'recipient',
      'message': 'Hello',
      'createdAt': '2026-10-03T12:00:00Z',
    });

    expect(message.id, 42);
    expect(message.senderFirebaseUid, 'sender');
    expect(message.recipientFirebaseUid, 'recipient');
    expect(message.message, 'Hello');
    expect(message.createdAt.toUtc().year, 2026);
  });
}
