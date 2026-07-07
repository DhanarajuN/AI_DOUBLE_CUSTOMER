enum MessageKind { text, proList, dayMark }

/// A single item rendered inside the chat thread.
/// - [MessageKind.text]    -> plain bubble (me or ai)
/// - [MessageKind.proList] -> ai bubble with a lead-in [text] + a matched-pros card list
/// - [MessageKind.dayMark] -> centered pill like "TODAY" / "YESTERDAY"
class ChatMessage {
  final MessageKind kind;
  final String text;
  final bool isMe;
  final String time;
  final List<String> proIds;

  const ChatMessage.text({
    required this.text,
    required this.isMe,
    required this.time,
  })  : kind = MessageKind.text,
        proIds = const [];

  const ChatMessage.proList({
    required this.text,
    required this.time,
    required this.proIds,
  })  : kind = MessageKind.proList,
        isMe = false;

  const ChatMessage.dayMark(String label)
      : kind = MessageKind.dayMark,
        text = label,
        isMe = false,
        time = '',
        proIds = const [];
}
