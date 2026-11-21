import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'exit_engine.dart';
import 'exit_rules.dart';

class ExitView extends StatefulWidget {
  final PlayContext ctx;
  const ExitView({super.key, required this.ctx});

  @override
  State<ExitView> createState() => _ExitViewState();
}

class _ExitViewState extends State<ExitView> {
  late ExitLevel level;
  late ExitGame game;
  int? _drag;
  Offset _delta = Offset.zero;
  (int, int)? _hint;
  int _seconds = 0, _hints = 0, _undos = 0;
  Timer? _timer;
  bool _ended = false;
  double _cell = 40;

  PlayContext get ctx => widget.ctx;
  bool get _tr => ctx.lang == 'tr';

  @override
  void initState() {
    super.initState();
    level = ExitRules().finalize(ctx.generated as GeneratedLevel<ExitLevel>);
    final snap = ctx.resume['snap'];
    game = snap is String ? ExitGame.restore(level, snap) : ExitGame(level);
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': _seconds, 'hints': _hints});

  void _move(int i, int dir) {
    final res = game.move(i, dir);
    if (res == 0) {
      ctx.sfx(Sfx.error);
      return;
    }
    ctx.sfx(res == 2 ? Sfx.clear : Sfx.place);
    setState(() => _hint = null);
    _persist();
    if (game.won) _end();
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    ctx.sfx(Sfx.win);
    final perfect = game.moves <= level.optimal;
    ctx.finish(RoundResult(
      won: true,
      score: (game.exited * 30 + (perfect ? 100 : 0) - _hints * 20).clamp(10, 1 << 20),
      stars: ExitRules.stars(game),
      seconds: _seconds,
      moves: game.moves,
      hintsUsed: _hints,
      undosUsed: _undos,
      gameStats: {'blocks_exited': game.exited, 'perfect': perfect ? 1 : 0},
    ));
  }

  Future<void> _useHint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hint = game.hint());
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _cell = math.max(20.0, math.min((cons.maxWidth - 48) / level.w, cons.maxHeight * 0.68 / level.h));
      final pad = _cell * 0.35;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Expanded(
              child: Text(
                  _tr
                      ? 'Hamle: ${game.moves}  ·  En az: ${level.optimal}'
                      : 'Moves: ${game.moves}  ·  Best: ${level.optimal}',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Icon(Icons.timer_outlined, size: 18),
            Text(' ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
          ]),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onPanStart: (d) {
                final p = d.localPosition - Offset(pad, pad);
                final i = game.blockAt((p.dx / _cell).floor(), (p.dy / _cell).floor());
                setState(() {
                  _drag = i >= 0 ? i : null;
                  _delta = Offset.zero;
                });
              },
              onPanUpdate: (d) => setState(() => _delta += d.delta),
              onPanEnd: (_) {
                final i = _drag;
                final dl = _delta;
                setState(() {
                  _drag = null;
                  _delta = Offset.zero;
                });
                if (i == null || dl.distance < _cell * 0.3) return;
                final dir = dl.dx.abs() > dl.dy.abs() ? (dl.dx > 0 ? 1 : 3) : (dl.dy > 0 ? 2 : 0);
                _move(i, dir);
              },
              child: Semantics(
                label: 'board',
                child: SizedBox(
                  width: _cell * level.w + pad * 2,
                  height: _cell * level.h + pad * 2,
                  child: CustomPaint(painter: _Painter(this, pad)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton.filledTonal(onPressed: _ended ? null : _useHint, icon: const Icon(Icons.lightbulb), tooltip: ctx.t('hint')),
            IconButton.filledTonal(
                onPressed: game.canUndo && !_ended
                    ? () {
                        setState(() {
                          game.undo();
                          _undos++;
                        });
                        _persist();
                      }
                    : null,
                icon: const Icon(Icons.undo),
                tooltip: ctx.t('undo')),
          ]),
        ),
      ]);
    });
  }

  Color colorOf(int c) => c < 0 ? const Color(0xFF6B7280) : ctx.pieceColors[c % ctx.pieceColors.length];
}

class _Painter extends CustomPainter {
  final _ExitViewState v;
  final double pad;
  _Painter(this.v, this.pad);

  @override
  void paint(Canvas canvas, Size size) {
    final c = v._cell, l = v.level;
    final board = Rect.fromLTWH(pad, pad, c * l.w, c * l.h);
    canvas.drawRRect(RRect.fromRectAndRadius(board.inflate(pad * 0.6), Radius.circular(pad)),
        Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawRect(board, Paint()..color = Colors.black.withValues(alpha: 0.10));
    // Kapılar
    for (final d in l.doors) {
      final col = v.colorOf(d.color);
      final t = pad * 0.5;
      final Rect r = switch (d.side) {
        0 => Rect.fromLTWH(pad + d.start * c, pad - t, d.len * c, t),
        2 => Rect.fromLTWH(pad + d.start * c, board.bottom, d.len * c, t),
        3 => Rect.fromLTWH(pad - t, pad + d.start * c, t, d.len * c),
        _ => Rect.fromLTWH(board.right, pad + d.start * c, t, d.len * c),
      };
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(t / 2)), Paint()..color = col);
    }
    final g = v.game;
    for (var i = 0; i < g.pos.length; i++) {
      if (g.pos[i] < 0) continue;
      final b = l.blocks[i];
      var r = Rect.fromLTWH(pad + (g.pos[i] ~/ 100) * c, pad + (g.pos[i] % 100) * c, b.w * c, b.h * c).deflate(c * 0.06);
      if (v._drag == i) {
        final dl = v._delta;
        final o = dl.dx.abs() > dl.dy.abs() ? Offset(dl.dx.clamp(-c * 0.4, c * 0.4), 0) : Offset(0, dl.dy.clamp(-c * 0.4, c * 0.4));
        r = r.shift(o);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(c * 0.2)), Paint()..color = v.colorOf(b.color));
      if (!b.stone) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 5, r.top + 4, r.width - 10, r.height * 0.22), Radius.circular(c * 0.1)),
            Paint()..color = Colors.white.withValues(alpha: 0.2));
      }
      if (v.ctx.colorBlind && !b.stone) {
        final tp = TextPainter(
          text: TextSpan(text: v.ctx.symbol(b.color), style: TextStyle(fontSize: c * 0.4, color: Colors.black54)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    final h = v._hint;
    if (h != null && g.pos[h.$1] >= 0) {
      final b = l.blocks[h.$1];
      final r = Rect.fromLTWH(pad + (g.pos[h.$1] ~/ 100) * c, pad + (g.pos[h.$1] % 100) * c, b.w * c, b.h * c);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(c * 0.2)),
          Paint()
            ..color = Colors.amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      final a = [-math.pi / 2, 0.0, math.pi / 2, math.pi][h.$2];
      final ctr = r.center, s = c * 0.3;
      canvas.drawLine(ctr, ctr + Offset(math.cos(a) * s * 2, math.sin(a) * s * 2),
          Paint()
            ..color = Colors.amber
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
