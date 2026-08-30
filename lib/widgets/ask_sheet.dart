import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event_intelligence.dart';
import '../models/event_item.dart';
import '../services/api_client.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'primitives.dart';

/// Ask a question about one event.
///
/// The design decision that matters here is the **refusal state**. When we have
/// nothing sourced, the answer is styled exactly like a real answer — same
/// weight, same position, no error icon, no apologetic red. Dressing a refusal
/// up as a failure teaches users that "I don't know" is a malfunction. Here it
/// is simply the answer, and it carries an explanation of what the app is
/// allowed to answer from.
Future<void> showAskSheet({
  required BuildContext context,
  required EventItem event,
  required EventVerdict? verdict,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AskSheet(event: event, verdict: verdict),
    ),
  );
}

class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.event, required this.verdict});
  final EventItem event;
  final EventVerdict? verdict;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _api = ApiClient();
  final _thread = <QaMessage>[];
  bool _thinking = false;

  static const _starters = [
    'Is this beginner-friendly?',
    'What should I bring?',
    'Is it really a workshop?',
    'Who usually shows up?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    if (question.trim().isEmpty || _thinking) return;
    setState(() {
      _thread.add(QaMessage(question: question, pending: true));
      _thinking = true;
      _controller.clear();
    });

    QaMessage reply;
    try {
      reply = await _api.ask(widget.event.id, question);
    } on ApiException catch (e) {
      reply = QaMessage(
        question: question,
        refused: true,
        answer: e.isRateLimited
            ? "You've reached today's question limit. It resets tomorrow."
            : "Couldn't reach the server for that one. Try again in a moment.",
      );
    } catch (_) {
      reply = QaMessage(
        question: question,
        refused: true,
        answer: 'No connection, so there is nothing I can answer from right now.',
      );
    }

    if (!mounted) return;
    setState(() {
      _thread
        ..removeLast()
        ..add(reply);
      _thinking = false;
    });

    await Future<void>.delayed(Motion.fast);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.base,
        curve: Motion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, outer) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s12),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: p.borderStrong,
                borderRadius: Radii.rPill,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, 0, Space.gutter, Space.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ASK ABOUT THIS EVENT',
                    style: AppType.label(color: p.accent)),
                const SizedBox(height: Space.s8),
                Text(
                  widget.event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.titleL(color: p.ink),
                ),
                const SizedBox(height: Space.s6),
                Text(
                  'Answered only from this event, its past editions, and what '
                  'the organiser has published.',
                  style: AppType.bodyS(color: p.inkMuted),
                ),
              ],
            ),
          ),
          const Hairline(),
          Expanded(
            child: _thread.isEmpty
                ? _Starters(onPick: _ask, scrollController: outer)
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutter, Space.s20, Space.gutter, Space.s24),
                    itemCount: _thread.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.s24),
                    itemBuilder: (context, i) => _Turn(message: _thread[i]),
                  ),
          ),
          const Hairline(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s12, Space.s12, Space.s20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _ask,
                    style: AppType.body(color: p.ink),
                    decoration: const InputDecoration(
                      hintText: 'Ask something…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Space.s8),
                IconButton.filled(
                  onPressed: _thinking ? null : () => _ask(_controller.text),
                  style: IconButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    minimumSize: const Size(52, 52),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Starters extends StatelessWidget {
  const _Starters({required this.onPick, required this.scrollController});
  final ValueChanged<String> onPick;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s20, Space.gutter, Space.s24),
      children: [
        Text('TRY ASKING', style: AppType.labelS(color: p.inkFaint)),
        const SizedBox(height: Space.s12),
        for (final (i, s) in _AskSheetState._starters.indexed)
          Reveal(
            delay: Motion.stagger(i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s8),
              child: InkWell(
                onTap: () => onPick(s),
                borderRadius: Radii.rMd,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.s16, vertical: Space.s16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: Radii.rMd,
                    border: Border.all(color: p.border, width: Strokes.hair),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s, style: AppType.body(color: p.ink)),
                      ),
                      Icon(Icons.arrow_forward_rounded,
                          size: 15, color: p.inkFaint),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Turn extends StatelessWidget {
  const _Turn({required this.message});
  final QaMessage message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The question, set in mono — it is a query, not prose.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('›', style: AppType.numeric(color: p.accent, size: 14)),
            const SizedBox(width: Space.s8),
            Expanded(
              child: Text(message.question,
                  style: AppType.numeric(color: p.ink, size: 13)),
            ),
          ],
        ),
        const SizedBox(height: Space.s12),
        if (message.pending)
          const _Thinking()
        else ...[
          Text(message.answer ?? '', style: AppType.body(color: p.ink)),
          if (message.refused) ...[
            const SizedBox(height: Space.s12),
            Row(
              children: [
                Icon(Icons.horizontal_rule_rounded, size: 14, color: p.inkFaint),
                const SizedBox(width: Space.s6),
                Text('NOTHING SOURCED', style: AppType.labelS(color: p.inkFaint)),
              ],
            ),
          ],
          if (message.citations.isNotEmpty) ...[
            const SizedBox(height: Space.s12),
            Wrap(
              spacing: Space.s6,
              runSpacing: Space.s6,
              children: [
                for (final (i, c) in message.citations.indexed)
                  InkWell(
                    onTap: () {
                      final uri = Uri.tryParse(c.sourceUrl);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: Radii.rSm,
                    child: MetaPill('${i + 1} · ${c.host}',
                        color: p.accent, background: p.accentSoft),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Three ticking dots. Deliberately not a spinner — a spinner reads as loading
/// a page; this reads as someone composing a reply.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: Space.s6),
              child: Opacity(
                opacity: 0.3 +
                    0.7 * (((_c.value * 3 - i) % 3).clamp(0.0, 1.0) > 0.5 ? 1 : 0),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.inkMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
