import 'dart:convert';

import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Renkli Blok Çıkışı: bloklar sürüklendiği yönde duvara ya da başka bir
/// bloğa kadar kayar. Duvardaki kendi renginin kapısına tam oturursa çıkar.

const List<List<int>> kDirs = [[0, -1], [1, 0], [0, 1], [-1, 0]]; // yukarı, sağ, aşağı, sol

class CBlock {
  final int w, h, color; // color < 0 = taş (kıpırdamaz)
  const CBlock(this.w, this.h, this.color);
  bool get stone => color < 0;
}

class Door {
  final int side; // 0 üst, 1 sağ, 2 alt, 3 sol
  final int start, len, color;
  const Door(this.side, this.start, this.len, this.color);
  List<int> toJson() => [side, start, len, color];
}

class ExitLevel {
  final int w, h;
  final List<CBlock> blocks;
  final List<int> start; // her blok için x*100+y
  final List<Door> doors;
  final int seed, difficulty, optimal;
  const ExitLevel({
    required this.w,
    required this.h,
    required this.blocks,
    required this.start,
    required this.doors,
    required this.seed,
    required this.difficulty,
    this.optimal = 0,
  });
  ExitLevel withOptimal(int o) =>
      ExitLevel(w: w, h: h, blocks: blocks, start: start, doors: doors, seed: seed, difficulty: difficulty, optimal: o);
}

/// Konumlar: x*100+y, çıkmış blok = -1.
class ExitBoard {
  final ExitLevel l;
  ExitBoard(this.l);

  List<int> _occ(List<int> pos, int except) {
    final occ = List<int>.filled(l.w * l.h, -1);
    for (var i = 0; i < pos.length; i++) {
      if (i == except || pos[i] < 0) continue;
      final b = l.blocks[i], x = pos[i] ~/ 100, y = pos[i] % 100;
      for (var dy = 0; dy < b.h; dy++) {
        for (var dx = 0; dx < b.w; dx++) {
          occ[(y + dy) * l.w + x + dx] = i;
        }
      }
    }
    return occ;
  }

  /// Hamle sonucu yeni konum; -1 çıktı; null geçersiz (hiç kıpırdamıyor).
  int? slide(List<int> pos, int i, int dir) {
    final b = l.blocks[i];
    if (b.stone || pos[i] < 0) return null;
    final occ = _occ(pos, i);
    var x = pos[i] ~/ 100, y = pos[i] % 100;
    final dx = kDirs[dir][0], dy = kDirs[dir][1];
    var moved = 0;
    bool fits(int nx, int ny) {
      if (nx < 0 || ny < 0 || nx + b.w > l.w || ny + b.h > l.h) return false;
      for (var yy = 0; yy < b.h; yy++) {
        for (var xx = 0; xx < b.w; xx++) {
          if (occ[(ny + yy) * l.w + nx + xx] >= 0) return false;
        }
      }
      return true;
    }

    while (fits(x + dx, y + dy)) {
      x += dx;
      y += dy;
      moved++;
    }
    // Duvara dayandı mı ve kapı uyuyor mu?
    final atWall = (dir == 0 && y == 0) || (dir == 2 && y + b.h == l.h) || (dir == 3 && x == 0) || (dir == 1 && x + b.w == l.w);
    if (atWall) {
      final a = (dir == 0 || dir == 2) ? x : y;
      final size = (dir == 0 || dir == 2) ? b.w : b.h;
      for (final d in l.doors) {
        if (d.side == dir && d.color == b.color && a >= d.start && a + size <= d.start + d.len) return -1;
      }
    }
    if (moved == 0) return null;
    return x * 100 + y;
  }

  bool solved(List<int> pos) {
    for (var i = 0; i < pos.length; i++) {
      if (!l.blocks[i].stone && pos[i] >= 0) return false;
    }
    return true;
  }

  /// En kısa çözüm (hamle listesi: blok*4+yön); bulunamazsa null.
  List<int>? solve(List<int> from, {int cap = 60000}) {
    String key(List<int> p) => p.join(',');
    final prev = <String, (String, int)>{};
    final start = key(from);
    prev[start] = ('', -1);
    final q = <List<int>>[from];
    for (var qi = 0; qi < q.length; qi++) {
      final p = q[qi];
      if (solved(p)) {
        final moves = <int>[];
        var k = key(p);
        while (k != start) {
          final e = prev[k]!;
          moves.add(e.$2);
          k = e.$1;
        }
        return moves.reversed.toList();
      }
      if (prev.length > cap) return null;
      final pk = key(p);
      for (var i = 0; i < p.length; i++) {
        if (p[i] < 0 || l.blocks[i].stone) continue;
        for (var d = 0; d < 4; d++) {
          final np = slide(p, i, d);
          if (np == null) continue;
          final n = List<int>.of(p);
          n[i] = np;
          final nk = key(n);
          if (prev.containsKey(nk)) continue;
          prev[nk] = (pk, i * 4 + d);
          q.add(n);
        }
      }
    }
    return null;
  }
}

ExitLevel generateExitLevel(LevelSpec spec) {
  final r = SeededRandom(mixSeed([spec.seed, 8181]));
  final d = spec.difficulty.clamp(1, 10);
  final w = d >= 7 ? 7 : (d >= 4 ? 6 : 5), h = w + (d >= 5 ? 1 : 0);
  final colors = (2 + d ~/ 3).clamp(2, 5);
  final nBlocks = (3 + d ~/ 2).clamp(3, 8);
  final stones = d >= 6 ? r.nextInt(3) : 0;
  final blocks = <CBlock>[];
  final pos = <int>[];
  final occ = List<bool>.filled(w * h, false);
  bool place(CBlock b) {
    for (var t = 0; t < 60; t++) {
      final x = r.nextInt(w - b.w + 1), y = r.nextInt(h - b.h + 1);
      var ok = true;
      for (var yy = 0; yy < b.h && ok; yy++) {
        for (var xx = 0; xx < b.w; xx++) {
          if (occ[(y + yy) * w + x + xx]) {
            ok = false;
            break;
          }
        }
      }
      if (!ok) continue;
      for (var yy = 0; yy < b.h; yy++) {
        for (var xx = 0; xx < b.w; xx++) {
          occ[(y + yy) * w + x + xx] = true;
        }
      }
      blocks.add(b);
      pos.add(x * 100 + y);
      return true;
    }
    return false;
  }

  for (var k = 0; k < nBlocks; k++) {
    const shapes = [[1, 1], [2, 1], [1, 2], [2, 2]];
    final s = shapes[r.nextInt(d >= 3 ? 4 : 3)];
    place(CBlock(s[0], s[1], k < colors ? k : r.nextInt(colors)));
  }
  for (var k = 0; k < stones; k++) {
    place(const CBlock(1, 1, -1));
  }
  // Her renk için bir kapı (zor bölümlerde dar kapılar).
  final doors = <Door>[];
  final usedSides = <String>{};
  for (var c = 0; c < colors; c++) {
    for (var t = 0; t < 20; t++) {
      final side = r.nextInt(4);
      final span = side == 0 || side == 2 ? w : h;
      final len = d >= 6 ? 2 : 3;
      final start = r.nextInt(span - len + 1);
      final k = '$side:${start ~/ 2}';
      if (!usedSides.add(k)) continue;
      doors.add(Door(side, start, len, c));
      break;
    }
  }
  return ExitLevel(w: w, h: h, blocks: blocks, start: pos, doors: doors, seed: spec.seed, difficulty: d);
}

class ExitGame {
  final ExitLevel level;
  late final ExitBoard board;
  late List<int> pos;
  int moves = 0, exited = 0;
  final List<List<int>> _undo = [];

  ExitGame(this.level) {
    board = ExitBoard(level);
    pos = List<int>.of(level.start);
  }

  bool get won => board.solved(pos);
  bool get canUndo => _undo.isNotEmpty;

  int blockAt(int x, int y) {
    for (var i = 0; i < pos.length; i++) {
      if (pos[i] < 0) continue;
      final b = level.blocks[i], bx = pos[i] ~/ 100, by = pos[i] % 100;
      if (x >= bx && x < bx + b.w && y >= by && y < by + b.h) return i;
    }
    return -1;
  }

  /// 2 çıktı, 1 kaydı, 0 geçersiz.
  int move(int i, int dir) {
    final np = board.slide(pos, i, dir);
    if (np == null) return 0;
    _undo.add(List<int>.of(pos));
    pos[i] = np;
    moves++;
    if (np < 0) {
      exited++;
      return 2;
    }
    return 1;
  }

  void undo() {
    if (_undo.isEmpty) return;
    pos = _undo.removeLast();
  }

  (int, int)? hint() {
    final s = board.solve(pos, cap: 30000);
    if (s == null || s.isEmpty) return null;
    return (s.first ~/ 4, s.first % 4);
  }

  String serialize() => jsonEncode({'p': pos, 's': [moves, exited]});

  static ExitGame restore(ExitLevel l, String snap) {
    final g = ExitGame(l);
    final j = jsonDecode(snap) as Map<String, dynamic>;
    g.pos = [for (final v in j['p'] as List) (v as num).toInt()];
    final s = j['s'] as List;
    g.moves = (s[0] as num).toInt();
    g.exited = (s[1] as num).toInt();
    return g;
  }
}
