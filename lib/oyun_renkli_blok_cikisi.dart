/// Renkli Blok Çıkışı: blokları kendi renginin kapısından çıkar.
/// Blok Oyunları merkez uygulamasının oyunu.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';

import 'src/exit_rules.dart';
import 'src/exit_view.dart';

export 'src/exit_engine.dart';
export 'src/exit_rules.dart';

final renkliCikisConfig = GameConfig(
  gameId: renkliCikisId,
  title: const ['Renkli Kapılar', 'Color Doors', 'Farbtüren', 'Puertas de Color', 'Portes Colorées'],
  tagline: const [
    'Her blok kendi renginin kapısından!',
    'Every block through its own color door!',
    'Jeder Block durch seine Farbtür!',
    '¡Cada bloque por su puerta de color!',
    'Chaque bloc par sa porte de couleur !',
  ],
  seedColor: const Color(0xFF7E57C2),
  icon: Icons.door_sliding_rounded,
  rules: ExitRules(),
  buildPlay: (ctx) => ExitView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.swipe, [
      'Bir bloğu kaydır: duvara ya da başka bir bloğa kadar gider.',
      'Swipe a block: it slides until it hits a wall or another block.',
      'Wische einen Block: er gleitet bis zur Wand oder zum nächsten Block.',
      'Desliza un bloque: avanza hasta una pared u otro bloque.',
      'Glissez un bloc : il avance jusqu\'au mur ou à un autre bloc.',
    ]),
    TutorialStep(Icons.door_front_door, [
      'Kendi renginin kapısına tam oturan blok çıkar. Gri taşlar kıpırdamaz.',
      'A block that lines up with its color door leaves. Grey stones never move.',
      'Ein Block vor seiner Farbtür verlässt das Feld. Graue Steine bleiben.',
      'Un bloque alineado con su puerta sale. Las piedras grises no se mueven.',
      'Un bloc aligné avec sa porte sort. Les pierres grises ne bougent pas.',
    ]),
  ],
);
