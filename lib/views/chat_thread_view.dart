import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../repositories/convo_repository.dart';
import '../repositories/pro_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/chat_thread_view_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/new_request_sheet.dart';
import 'agent_chat_view.dart';

class ChatThreadView extends StatelessWidget {
  final String convoId;
  const ChatThreadView({super.key, required this.convoId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ChatThreadViewModel(
        ctx.read<ConvoRepository>(),
        ctx.read<ProRepository>(),
        convoId: convoId,
      ),
      child: const _ChatThreadBody(),
    );
  }
}

class _ChatThreadBody extends StatefulWidget {
  const _ChatThreadBody();

  @override
  State<_ChatThreadBody> createState() => _ChatThreadBodyState();
}

class _ChatThreadBodyState extends State<_ChatThreadBody> {
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

  Future<void> _handleChipTap(ChatThreadViewModel vm, String label) async {
    if (label == 'Type my own') {
      vm.hideChips();
      _focusNode.requestFocus();
      return;
    }
    if (label == 'New request') {
      vm.hideChips();
      final agent = await showNewRequestSheet(context);
      if (agent != null && mounted) {
        await AgentChatView.open(context, agent);
      }
      return;
    }
    vm.quickReplyTap(label);
    _scrollToBottom();
  }

  void _send(ChatThreadViewModel vm) {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    vm.sendMsg(text);
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
    final vm = context.watch<ChatThreadViewModel>();
    final convo = vm.convo;
    final pro = vm.pro;
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.appChatBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---- chat bar ----
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 8, 12),
              decoration: BoxDecoration(
                color: AppColors.appSurfaceColor,
                border: Border(bottom: BorderSide(color: AppColors.appBorderColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
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
                            const Text('✓', style: TextStyle(color: AppColors.appPrimaryColor, fontSize: 12)),
                          ],
                        ),
                        Text(
                          convo.isAI ? 'assistant · online' : (pro?.role ?? 'professional'),
                          style: AppFonts.mono(
                            size: 10,
                            color: convo.isAI ? AppColors.appSuccessColor : AppColors.appTextSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.appTextSecondaryColor),
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
                color: AppColors.appChatBackgroundColor,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                  itemCount: convo.messages.length + (vm.isTyping ? 1 : 0),
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
                          pros: context.read<ProRepository>().getAll(),
                          onTapPro: (id) {
                            Navigator.of(context).pushNamed(AppRoutes.profile, arguments: id);
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
            if (vm.showChips)
              Container(
                width: double.infinity,
                color: AppColors.appChatBackgroundColor,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: vm.chips.map((chip) {
                    return InkWell(
                      onTap: () => _handleChipTap(vm, chip),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.appPrimaryColor.withOpacity(0.08),
                          border: Border.all(color: AppColors.appPrimaryColor),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          chip,
                          style: AppFonts.body(size: 12.5, weight: FontWeight.w500, color: AppColors.appPrimaryColor),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ---- composer ----
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.appSurfaceColor,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.appTextSecondaryColor),
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
                      onSubmitted: (_) => _send(vm),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: AppFonts.body(size: 14, color: AppColors.appTextMutedColor),
                        filled: true,
                        fillColor: AppColors.appSurfaceVariantColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(color: AppColors.appBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(color: AppColors.appBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(color: AppColors.appBorderColorStrong),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _send(vm),
                    borderRadius: BorderRadius.circular(21),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppColors.appPrimaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward, color: AppColors.appOnPrimaryColor, size: 19),
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
        decoration: BoxDecoration(gradient: AppColors.appPrimaryGradient, shape: BoxShape.circle),
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
                  color: AppColors.appSecondaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.appSurfaceColor, width: 2),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final gradient = pro?.gradient as List<Color>? ?? [AppColors.appPrimaryColor, AppColors.appPrimaryDarkColor];
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
