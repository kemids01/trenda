// trenda_shared/lib/chat/chat_timeline.dart
// Pure layout rules for the chat thread: order, day separators, bubble grouping.
// No widgets here, so every rule is unit-testable. Shared by the customer and
// vendor apps so both draw a thread the same way.
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import 'package:trenda_shared/core/timezone.dart';

/// Consecutive messages from one side within this gap render as one group
/// (one avatar, one timestamp, tight spacing).
const Duration kChatGroupGap = Duration(minutes: 5);

sealed class ChatTimelineItem {
  const ChatTimelineItem();
}

class ChatDayHeader extends ChatTimelineItem {
  final String label;
  const ChatDayHeader(this.label);
}

class ChatMessageItem extends ChatTimelineItem {
  final ChatMessage message;
  final bool isMe;

  /// First (oldest) message of its group — the bubble carries the sender avatar slot.
  final bool isFirstInGroup;

  /// Last (newest) message of its group — the bubble carries the tail + timestamp.
  final bool isLastInGroup;

  const ChatMessageItem({
    required this.message,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });
}

/// Same Philippine calendar day.
bool _sameDay(DateTime a, DateTime b) {
  final x = TrendaTimezone.toLocal(a), y = TrendaTimezone.toLocal(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// "Today" · "Yesterday" · weekday within the last week · "Sep 3" this year ·
/// "Sep 3, 2025" otherwise.
String chatDayLabel(DateTime day, {DateTime? now}) {
  // Compared as Philippine calendar days; [day] itself is what gets formatted.
  final l = TrendaTimezone.toLocal(day), n = TrendaTimezone.toLocal(now ?? DateTime.now());
  final d = DateTime(l.year, l.month, l.day);
  final t = DateTime(n.year, n.month, n.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').formatPh(day);
  if (d.year == t.year) return DateFormat('MMM d').formatPh(day);
  return DateFormat('MMM d, y').formatPh(day);
}

/// Builds the thread NEWEST-FIRST, ready for a `ListView(reverse: true)` so the
/// latest message sits at the bottom next to the composer.
///
/// [messages] may arrive in any order; they are sorted oldest→newest by time
/// (id as the tie-break, so equal timestamps never swap on a rebuild).
List<ChatTimelineItem> buildChatTimeline(
  List<ChatMessage> messages, {
  required String myRole,
  DateTime? now,
}) {
  final sorted = [...messages]..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

  bool joins(ChatMessage a, ChatMessage b) =>
      a.senderRole == b.senderRole &&
      _sameDay(a.createdAt.toLocal(), b.createdAt.toLocal()) &&
      b.createdAt.difference(a.createdAt).abs() <= kChatGroupGap;

  final oldestFirst = <ChatTimelineItem>[];
  for (var i = 0; i < sorted.length; i++) {
    final m = sorted[i];
    final prev = i > 0 ? sorted[i - 1] : null;
    final next = i < sorted.length - 1 ? sorted[i + 1] : null;
    final local = m.createdAt.toLocal();
    if (prev == null || !_sameDay(prev.createdAt.toLocal(), local)) {
      oldestFirst.add(ChatDayHeader(chatDayLabel(local, now: now)));
    }
    oldestFirst.add(ChatMessageItem(
      message: m,
      isMe: m.senderRole == myRole,
      isFirstInGroup: prev == null || !joins(prev, m),
      isLastInGroup: next == null || !joins(m, next),
    ));
  }
  return oldestFirst.reversed.toList();
}
