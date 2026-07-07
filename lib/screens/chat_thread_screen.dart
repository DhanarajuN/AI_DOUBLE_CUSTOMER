import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/new_request_sheet.dart';
import 'profile_screen.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleChipTap(AppState state, String label) async {
    if (label == 'Type my own') {
      state.hideChips();
      _focusNode.requestFocus();
      return;
    }
    if (label == 'New request') {
      state.hideChips();
      final category = await showNewRequestSheet(context);
      if (category != null) {
        state.startIntake(category);
        _scrollToBottom();
      }
      return;
    }
    state.quickReplyTap(label);
    _scrollToBottom();
  }

  void _send(AppState state) {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    state.sendMsg(text);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final convo = state.activeConvo;
    if (convo == null) {
      // Nothing active (e.g. hot-reloaded straight into this route) — bail out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(backgroundColor: AppColors.app);
    }

    final pro = convo.proId != null ? state.pros[convo.proId] : null;
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.chatBg,
      body: SafeArea(
        child: Column(
          children: [
            // ---- chat bar ----
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 8, 12),
              decoration: const BoxDecoration(
                color: AppColors.panel,
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () {
                      state.closeChat();
                      Navigator.of(context).pop();
                    },
                  ),
                  _avatar(convo.isAI, pro),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                convo.isAI ? 'AI Double' : convo.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.body(size: 15.5, weight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('✓', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                          ],
                        ),
                        Text(
                          convo.isAI ? 'assistant · online' : (pro?.role ?? 'professional'),
                          style: AppFonts.mono(
                            size: 10,
                            color: convo.isAI ? AppColors.green : AppColors.dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.dim),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat options'), behavior: SnackBarBehavior.floating),
                    ),
                  ),
                ],
              ),
            ),

            // ---- thread ----
            Expanded(
              child: Container(
                color: AppColors.chatBg,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                  itemCount: convo.messages.length + (state.isTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == convo.messages.length) {
                      return const TypingIndicator();
                    }
                    final m = convo.messages[i];
                    switch (m.kind) {
                      case MessageKind.dayMark:
                        return DayMarkWidget(label: m.text);
                      case MessageKind.proList:
                        return ProListBubble(
                          message: m,
                          pros: state.pros,
                          onTapPro: (id) {
                            state.openProfile(id);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          },
                        );
                      case MessageKind.text:
                        return TextBubble(message: m);
                    }
                  },
                ),
              ),
            ),

            // ---- quick replies ----
            if (state.showChips)
              Container(
                width: double.infinity,
                color: AppColors.chatBg,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: state.chips.map((chip) {
                    return InkWell(
                      onTap: () => _handleChipTap(state, chip),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.08),
                          border: Border.all(color: AppColors.teal),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          chip,
                          style: AppFonts.body(size: 12.5, weight: FontWeight.w500, color: AppColors.teal),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ---- composer ----
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.panel,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.dim),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attach'), behavior: SnackBarBehavior.floating),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _focusNode,
                      style: AppFonts.body(size: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(state),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: AppFonts.body(size: 14, color: AppColors.faint),
                        filled: true,
                        fillColor: AppColors.panel2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: AppColors.line2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _send(state),
                    borderRadius: BorderRadius.circular(21),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward, color: Color(0xFF04120D), size: 19),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(bool isAI, dynamic pro) {
    if (isAI) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(gradient: AppColors.tealGradient, shape: BoxShape.circle),
        child: Stack(
          children: [
            const Center(child: Text('AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.panel, width: 2),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final gradient = pro?.gradient as List<Color>? ?? const [AppColors.teal, AppColors.tealDeep];
    final initials = pro?.initials as String? ?? '';
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), shape: BoxShape.circle),
      child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }
}
