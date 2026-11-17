import 'package:flutter_test/flutter_test.dart';
import 'package:penpal/models/message.dart';
import 'package:penpal/models/profile.dart';

Message messageFromMap(Map<String, dynamic> overrides, {String myUserId = 'user-a'}) {
  return Message.fromMap(
    map: {
      'id': 'msg-1',
      'profile_id': 'user-a',
      'content': 'hola',
      'attachment_path': null,
      'attachment_name': null,
      'created_at': '2026-11-17T10:00:00.000Z',
      ...overrides,
    },
    myUserId: myUserId,
  );
}

void main() {
  group('Message.fromMap', () {
    test('parses all fields', () {
      final message = messageFromMap({
        'attachment_path': 'user-a/123.png',
        'attachment_name': 'foto.png',
      }, myUserId: 'user-b');
      expect(message.id, 'msg-1');
      expect(message.profileId, 'user-a');
      expect(message.content, 'hola');
      expect(message.attachmentPath, 'user-a/123.png');
      expect(message.attachmentName, 'foto.png');
      expect(message.createdAt, DateTime.parse('2026-11-17T10:00:00.000Z'));
      expect(message.isMine, isFalse);
    });

    test('isMine is true when profile_id matches myUserId', () {
      expect(messageFromMap({}, myUserId: 'user-a').isMine, isTrue);
    });

    test('attachment fields default to null', () {
      final message = messageFromMap({});
      expect(message.attachmentPath, isNull);
      expect(message.attachmentName, isNull);
      expect(message.hasImageAttachment, isFalse);
    });
  });

  group('Message.hasImageAttachment', () {
    for (final ext in ['png', 'jpg', 'jpeg', 'gif', 'webp']) {
      test('.$ext counts as an image', () {
        expect(
          messageFromMap({'attachment_path': 'user-a/1.$ext'}).hasImageAttachment,
          isTrue,
        );
      });
    }

    test('extension matching is case-insensitive', () {
      expect(
        messageFromMap({'attachment_path': 'user-a/1.PNG'}).hasImageAttachment,
        isTrue,
      );
    });

    for (final ext in ['pdf', 'txt', 'zip']) {
      test('.$ext does not count as an image', () {
        expect(
          messageFromMap({'attachment_path': 'user-a/1.$ext'}).hasImageAttachment,
          isFalse,
        );
      });
    }
  });

  group('Profile.fromMap', () {
    test('parses all fields', () {
      final profile = Profile.fromMap({
        'id': 'user-a',
        'username': 'penpal',
        'created_at': '2026-11-17T10:00:00.000Z',
      });
      expect(profile.id, 'user-a');
      expect(profile.username, 'penpal');
      expect(profile.createdAt, DateTime.parse('2026-11-17T10:00:00.000Z'));
    });
  });
}
