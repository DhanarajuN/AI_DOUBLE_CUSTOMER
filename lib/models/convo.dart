import 'package:flutter/material.dart';
import 'chat_message.dart';

/// One row in the chat list. Mirrors an entry in the CONVOS array.
class Convo {
  final String id;
  String category; // insurance | education | home | health
  String title;
  final bool isAI;
  bool archived;
  int unread;
  String time; // display label e.g. '9:24', 'Yesterday', 'now'
  String preview;
  bool lastFromMe;
  bool complete; // AI intake finished (pro list revealed)
  bool live; // AI intake currently in progress
  int step; // current step index in the category's script
  String? proId; // set when this is a 1:1 chat with a professional
  final List<ChatMessage> messages;

  Convo({
    required this.id,
    required this.category,
    required this.title,
    required this.isAI,
    this.archived = false,
    this.unread = 0,
    this.time = 'now',
    this.preview = '',
    this.lastFromMe = false,
    this.complete = false,
    this.live = false,
    this.step = -1,
    this.proId,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];
}

/// One step of an intake script: quick-reply chips shown, and (optionally)
/// the AI follow-up question asked once the user answers. `ask == null`
/// on the final step signals the flow should reveal matched pros next.
class ScriptStep {
  final List<String> chips;
  final String? ask;
  const ScriptStep({required this.chips, required this.ask});
}

/// Mirrors one entry of the SCRIPTS map: the whole guided-intake
/// conversation for a category (insurance / education / home / health).
class CategoryScript {
  final String categoryLabel;
  final String greet;
  final List<ScriptStep> steps;
  final String reveal;
  final List<String> proIds;
  final List<String> after; // quick replies shown after pros are revealed

  const CategoryScript({
    required this.categoryLabel,
    required this.greet,
    required this.steps,
    required this.reveal,
    required this.proIds,
    required this.after,
  });
}

/// Mirrors CATMETA: metadata shown in the "New request" category picker.
class CategoryMeta {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  const CategoryMeta(this.icon, this.gradient, this.title, this.subtitle);
}
