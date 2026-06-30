import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';
import '../../core/profile_photo_view.dart';

class ChatScreen extends StatefulWidget {
  final int? initialConversationId;

  const ChatScreen({super.key, this.initialConversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _chatHeader = Color(0xFF075E54);
  static const Color _chatAccent = Color(0xFF128C7E);
  static const Color _chatSurface = Color(0xFFECE5DD);
  static const Color _sentBubble = Color(0xFFDCF8C6);
  static const Color _receivedBubble = Color(0xFFFFFFFF);
  static const Color _messageText = Color(0xFF111B21);
  static const Color _mutedText = Color(0xFF667781);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  String _tab = 'all';
  bool _loadingList = true;
  bool _loadingThread = false;
  bool _sending = false;
  String? _listError;
  String? _threadError;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _conversations = <Map<String, dynamic>>[];
  Map<String, dynamic>? _selectedConversation;
  Map<String, dynamic>? _canSend;
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    final initialId = widget.initialConversationId;
    if (initialId != null && initialId > 0) {
      _openConversationId(initialId);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });

    try {
      final response = await ApiClient.getChats(tab: _tab);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _conversations = _safeMapList(response['conversations']);
          _unreadCount = _asInt(response['unread_count']) ?? 0;
          _loadingList = false;
        });
        return;
      }

      setState(() {
        _listError = _responseMessage(response, AppStrings.chatLoadFailed);
        _loadingList = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listError = '${AppStrings.chatLoadFailed} $error';
        _loadingList = false;
      });
    }
  }

  Future<void> _openConversationId(
    int conversationId, {
    Map<String, dynamic>? conversation,
  }) async {
    setState(() {
      _selectedConversation =
          conversation ?? <String, dynamic>{'id': conversationId};
      _messages = <Map<String, dynamic>>[];
      _canSend = null;
      _threadError = null;
      _loadingThread = true;
    });

    try {
      final response = await ApiClient.getChatThread(conversationId);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _selectedConversation =
              _safeMap(response['conversation']) ?? _selectedConversation;
          _messages = _safeMapList(response['messages']);
          _canSend = _safeMap(response['can_send']);
          _loadingThread = false;
        });
        _scrollMessagesToBottom();
        _loadConversations();
        return;
      }

      setState(() {
        _threadError = _responseMessage(response, AppStrings.chatOpenFailed);
        _loadingThread = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _threadError = '${AppStrings.chatOpenFailed} $error';
        _loadingThread = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final conversationId = _asInt(_selectedConversation?['id']);
    if (conversationId == null || _sending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
      _threadError = null;
    });

    try {
      final response = await ApiClient.sendChatText(
        conversationId: conversationId,
        bodyText: text,
      );
      if (!mounted) return;

      if (_responseSuccess(response)) {
        final message = _safeMap(response['chat_message']);
        setState(() {
          if (message != null) {
            _messages = <Map<String, dynamic>>[..._messages, message];
          }
          _selectedConversation =
              _safeMap(response['conversation']) ?? _selectedConversation;
          _canSend = _safeMap(response['can_send']) ?? _canSend;
          _messageController.clear();
          _sending = false;
        });
        _scrollMessagesToBottom();
        _loadConversations();
        return;
      }

      setState(() {
        _sending = false;
      });
      _showSnackBar(_responseMessage(response, AppStrings.chatSendFailed));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
      });
      _showSnackBar('${AppStrings.chatSendFailed} $error');
    }
  }

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _changeTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
    });
    _loadConversations();
  }

  void _backToInbox() {
    setState(() {
      _selectedConversation = null;
      _messages = <Map<String, dynamic>>[];
      _canSend = null;
      _threadError = null;
      _loadingThread = false;
    });
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedConversation;
    final inThread = selected != null;

    return Scaffold(
      backgroundColor: _chatSurface,
      appBar: AppBar(
        backgroundColor: _chatHeader,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: inThread ? 0 : null,
        leading: inThread
            ? IconButton(
                tooltip: AppStrings.chatInbox,
                onPressed: _backToInbox,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(inThread ? _otherName(selected) : AppStrings.chatInbox),
        actions: [
          IconButton(
            tooltip: AppStrings.refresh,
            onPressed: inThread
                ? () {
                    final id = _asInt(_selectedConversation?['id']);
                    if (id != null) _openConversationId(id);
                  }
                : _loadConversations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: inThread ? _buildThread() : _buildInbox(),
    );
  }

  Widget _buildInbox() {
    return Column(
      children: [
        _buildTabs(),
        Expanded(child: _buildConversationList()),
      ],
    );
  }

  Widget _buildTabs() {
    final tabs = <({String key, String label})>[
      (key: 'all', label: AppStrings.chatAll),
      (key: 'unread', label: AppStrings.chatUnread),
      (key: 'requests', label: AppStrings.chatRequests),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      color: _receivedBubble,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tabs
                  .map((tab) {
                    final selected = _tab == tab.key;
                    return ChoiceChip(
                      label: Text(tab.label),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: _chatAccent,
                      backgroundColor: const Color(0xFFF0F2F5),
                      side: BorderSide(
                        color: selected ? _chatAccent : const Color(0xFFDAD7D2),
                      ),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : _messageText,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) => _changeTab(tab.key),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          if (_unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _chatAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: _chatHeader,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listError != null) {
      return _buildMessageState(
        icon: Icons.error_outline,
        message: _listError!,
        actionLabel: AppStrings.retry,
        onAction: _loadConversations,
      );
    }

    if (_conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.28),
            Icon(Icons.chat_bubble_outline, color: _chatAccent, size: 44),
            const SizedBox(height: 12),
            Text(
              AppStrings.chatEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6E625F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        itemCount: _conversations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _buildConversationCard(conversation);
        },
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final other = _safeMap(conversation['other_profile']);
    final unread = _asInt(conversation['unread_count']) ?? 0;
    final preview = _stringValue(conversation['preview']);
    final lastAt = _displayDate(conversation['last_message_at']);
    final photoUrl = ApiClient.normalizeProfilePhotoUrl(
      other?['profile_photo_url'],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final id = _asInt(conversation['id']);
          if (id != null) {
            _openConversationId(id, conversation: conversation);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProfilePhotoView(
                photoUrl: photoUrl,
                width: 54,
                height: 54,
                circle: true,
                backgroundColor: const Color(0xFFE0F2EA),
                placeholderColor: _chatHeader,
                placeholderIcon: Icons.person_outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _otherName(conversation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF2E2220),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (lastAt.isNotEmpty)
                          Text(
                            lastAt,
                            style: const TextStyle(
                              color: Color(0xFF8A7770),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.isEmpty ? AppStrings.chatTitle : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread > 0 ? _messageText : _mutedText,
                              fontWeight: unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            height: 22,
                            constraints: const BoxConstraints(minWidth: 22),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: const BoxDecoration(
                              color: _chatAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF9B8580)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThread() {
    return Column(
      children: [
        Expanded(
          child: _loadingThread && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _threadError != null
              ? _buildMessageState(
                  icon: Icons.error_outline,
                  message: _threadError!,
                  actionLabel: AppStrings.retry,
                  onAction: () {
                    final id = _asInt(_selectedConversation?['id']);
                    if (id != null) _openConversationId(id);
                  },
                )
              : _buildMessagesList(),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppStrings.chatMessageHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6E625F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _messageScrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final mine = message['is_mine'] == true;
    final readLocked = message['read_locked'] == true;
    final body = _stringValue(message['body_text']).isNotEmpty
        ? _stringValue(message['body_text'])
        : _stringValue(message['preview_text']);
    final sentAt = _displayTime(message['sent_at']);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 5),
          decoration: BoxDecoration(
            color: mine ? _sentBubble : _receivedBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: Radius.circular(mine ? 8 : 2),
              bottomRight: Radius.circular(mine ? 2 : 8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 1.5,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (readLocked)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 15, color: _mutedText),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        AppStrings.chatUpgradeToRead,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              if (readLocked) const SizedBox(height: 5),
              Text(
                body.isEmpty ? AppStrings.chatReadLocked : body,
                style: const TextStyle(
                  color: _messageText,
                  fontSize: 14.5,
                  height: 1.22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (sentAt.isNotEmpty) ...[
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    sentAt,
                    style: const TextStyle(
                      color: _mutedText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final canSend = _canSend?['allowed'] == true;
    final policyMessage = _stringValue(_canSend?['message']);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canSend && policyMessage.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F5EF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB7DCCF)),
                ),
                child: Text(
                  policyMessage,
                  style: const TextStyle(
                    color: _chatHeader,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: canSend && !_sending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: AppStrings.chatMessageHint,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: canSend && !_sending ? _sendMessage : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _chatAccent,
                      disabledBackgroundColor: const Color(0xFFB9C3BE),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      elevation: 0,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _chatAccent, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  String _otherName(Map<String, dynamic>? conversation) {
    final other = _safeMap(conversation?['other_profile']);
    final name = _stringValue(other?['name']);
    return name.isEmpty ? AppStrings.profile : name;
  }

  bool _responseSuccess(Map<String, dynamic> response) {
    final statusCode = _asInt(response['statusCode']) ?? 0;
    return response['success'] == true && statusCode >= 200 && statusCode < 300;
  }

  String _responseMessage(Map<String, dynamic> response, String fallback) {
    final message = _stringValue(response['message']);
    return message.isEmpty ? fallback : message;
  }

  List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text;
  }

  String _displayDate(dynamic value) {
    final parsed = DateTime.tryParse(_stringValue(value));
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return _displayTime(value);
    }
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _displayTime(dynamic value) {
    final parsed = DateTime.tryParse(_stringValue(value));
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
