import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_provider.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late ChatProvider _chatProvider;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _chatProvider.addListener(_handleChatUpdates);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _chatProvider.removeListener(_handleChatUpdates);
    super.dispose();
  }

  void _handleChatUpdates() {
    if (_chatProvider.isSpeaking) {
      setState(() => _isProcessing = true);
    } else {
      setState(() => _isProcessing = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: provider.currentChatMessages.length,
                  itemBuilder: (context, index) {
                    final message = provider.currentChatMessages[index];
                    return MessageWidget(
                      text: message['content'] ?? '',
                      isFromUser: message['role'] == 'user',
                      timestamp: message['timestamp'] != null
                          ? DateTime.parse(message['timestamp'])
                          : null,
                      isSpeaking: provider.isSpeaking &&
                          !(message['isFromUser'] ?? false),
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Scrivi il tuo messaggio...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    suffixIcon: _chatProvider.isSpeaking
                        ? IconButton(
                            icon: const Icon(Icons.stop_circle),
                            onPressed: _chatProvider.stopSpeaking,
                          )
                        : null,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _buildActionButtons(),
            ],
          ),
          const SizedBox(height: 8),
          _buildSpecialCommands(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _isProcessing ? null : _sendMessage,
            icon: Icon(
              _isProcessing ? Icons.hourglass_top : Icons.send_rounded,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialCommands() {
    return Wrap(
      spacing: 8,
      children: [
        ActionChip(
          label: const Text('Nuova Intervista'),
          onPressed: () {
            _chatProvider.startNewChat();
            _focusNode.requestFocus();
          },
        ),
        ActionChip(
          label: const Text('Genera Report'),
          onPressed: () {
            _textController.text = "FORNISCI I RISULTATI DELL'INTERVISTA";
            _sendMessage();
          },
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    _textController.clear();
    _focusNode.unfocus();

    try {
      await _chatProvider.submitUserMessage(message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    } finally {
      if (!_chatProvider.isSpeaking) {
        setState(() => _isProcessing = false);
      }
      _focusNode.requestFocus();
    }
  }
}

class MessageWidget extends StatelessWidget {
  final String text;
  final bool isFromUser;
  final DateTime? timestamp;
  final bool isSpeaking;

  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
    this.timestamp,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Align(
        alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Column(
            crossAxisAlignment:
                isFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isFromUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSpeaking && !isFromUser)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.volume_up, size: 16),
                      ),
                    Flexible(
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isFromUser
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (timestamp != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTimestamp(timestamp!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
