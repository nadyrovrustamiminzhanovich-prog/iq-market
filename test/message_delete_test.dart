import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/models/message_model.dart';

/// Копия фильтра из ChatService.getMessagesStreamWithChatId. Сам стрим
/// протестировать без Firestore нельзя, но правило отбора — чистая логика,
/// и именно оно решает, увидит ли пользователь то, что «удалил у себя».
List<MessageModel> visibleFor(List<MessageModel> all, String? uid) =>
    all.where((m) => !m.isHiddenFor(uid)).toList();

MessageModel msg(String id, String senderId, {List<String>? deletedFor}) =>
    MessageModel.fromMap({
      'senderId': senderId,
      'text': 'msg $id',
      'type': 'text',
      'timestamp': Timestamp.fromDate(DateTime(2026, 8, 8)),
      if (deletedFor != null) 'deletedFor': deletedFor,
    }, id);

void main() {
  group('MessageModel.deletedFor — парсинг', () {
    test('поле отсутствует → пустой список, а не null', () {
      expect(msg('m1', 'alpha').deletedFor, isEmpty);
    });

    test('список uid парсится как есть', () {
      expect(
        msg('m1', 'alpha', deletedFor: ['beta']).deletedFor,
        equals(['beta']),
      );
    });

    test('нестроковые элементы приводятся к строке, а не роняют парсинг', () {
      // Документ мог быть испорчен вручную или сторонним инструментом —
      // падение парсера здесь означало бы пустой экран чата целиком.
      final m = MessageModel.fromMap({
        'senderId': 'alpha',
        'text': 'x',
        'type': 'text',
        'deletedFor': [42, 'beta'],
      }, 'm1');
      expect(m.deletedFor, equals(['42', 'beta']));
    });

    test('deletedFor не того типа не роняет парсинг', () {
      final m = MessageModel.fromMap({
        'senderId': 'alpha',
        'text': 'x',
        'type': 'text',
        'deletedFor': 'beta',
      }, 'm1');
      expect(m.deletedFor, isEmpty);
    });
  });

  group('isHiddenFor — кому сообщение не видно', () {
    test('скрыто у того, кто себя в deletedFor добавил', () {
      expect(msg('m1', 'alpha', deletedFor: ['beta']).isHiddenFor('beta'), isTrue);
    });

    test('НЕ скрыто у второй стороны — «удалить у меня» её не касается', () {
      expect(msg('m1', 'alpha', deletedFor: ['beta']).isHiddenFor('alpha'), isFalse);
    });

    test('автор может скрыть своё сообщение только у себя', () {
      final m = msg('m1', 'alpha', deletedFor: ['alpha']);
      expect(m.isHiddenFor('alpha'), isTrue);
      expect(m.isHiddenFor('beta'), isFalse);
    });

    test('скрыто у обоих, если каждый удалил у себя', () {
      final m = msg('m1', 'alpha', deletedFor: ['alpha', 'beta']);
      expect(m.isHiddenFor('alpha'), isTrue);
      expect(m.isHiddenFor('beta'), isTrue);
    });

    test('без авторизации ничего не скрывается', () {
      expect(msg('m1', 'alpha', deletedFor: ['beta']).isHiddenFor(null), isFalse);
    });
  });

  group('Фильтр ленты чата', () {
    final all = [
      msg('m1', 'alpha'),
      msg('m2', 'beta', deletedFor: ['alpha']),
      msg('m3', 'alpha', deletedFor: ['alpha']),
      msg('m4', 'beta', deletedFor: ['alpha', 'beta']),
    ];

    test('alpha видит только не скрытое у себя', () {
      expect(visibleFor(all, 'alpha').map((m) => m.id), equals(['m1']));
    });

    test('beta видит всё, кроме скрытого у себя — пометки alpha на него не влияют', () {
      expect(visibleFor(all, 'beta').map((m) => m.id), equals(['m1', 'm2', 'm3']));
    });

    test('порядок сообщений фильтр не меняет', () {
      final ids = visibleFor(all, 'beta').map((m) => m.id).toList();
      expect(ids, equals(['m1', 'm2', 'm3']));
    });
  });
}
