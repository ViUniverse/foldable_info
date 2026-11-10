import 'dart:async';
import 'package:flutter/material.dart';
import 'package:foldable_info/foldable_info.dart';
import 'geometry.dart';

/// A local playback simulation, without an audio dependency or network request.
class TabletopRecipe extends StatefulWidget {
  const TabletopRecipe({super.key, required this.data});
  final FoldableData data;
  @override
  State<TabletopRecipe> createState() => _TabletopRecipeState();
}

class _TabletopRecipeState extends State<TabletopRecipe> {
  bool _playing = false;
  double _seconds = 0;
  Timer? _timer;
  void _toggle() {
    setState(() {
      if (!_playing && _seconds >= 180) _seconds = 0;
      _playing = !_playing;
    });
    _timer?.cancel();
    if (_playing) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_seconds >= 179) {
          _timer?.cancel();
          setState(() {
            _seconds = 180;
            _playing = false;
          });
        } else {
          setState(() => _seconds++);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RecipeGeometry(
    data: widget.data,
    builder: (context, local) => LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final reported = splitFor(context, local, widget.data);
        // Book folds also keep controls to one side. Only a horizontal fold is
        // described as tabletop; the fallback is an ordinary stacked player.
        final split =
            reported ??
            (
              first: Rect.fromLTWH(0, 0, size.width, size.height * .45),
              second: Rect.fromLTWH(
                0,
                size.height * .45,
                size.width,
                size.height * .55,
              ),
              vertical: false,
            );
        return RecipePanes(
          data: widget.data,
          firstRect: split.first,
          secondRect: split.second,
          first: ColoredBox(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.headphones, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Chapter preview',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  reported == null
                      ? 'Ordinary stacked layout'
                      : reported.vertical
                      ? 'Book: controls in the second pane'
                      : 'Tabletop: preview above, controls below',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          second: Material(
            child: ListView(
              key: const ValueKey('recipe-player-controls'),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Demo playback · no audio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_seconds.toInt()} / 180 seconds',
                  key: const ValueKey('recipe-position'),
                ),
                Slider(
                  label: '${_seconds.toInt()} seconds',
                  value: _seconds,
                  max: 180,
                  onChanged: (v) => setState(() => _seconds = v),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Back 15 seconds',
                      onPressed: () => setState(
                        () => _seconds = (_seconds - 15).clamp(0, 180),
                      ),
                      icon: const Icon(Icons.replay),
                    ),
                    FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      label: Text(_playing ? 'Pause' : 'Play'),
                    ),
                    IconButton(
                      tooltip: 'Forward 15 seconds',
                      onPressed: () => setState(
                        () => _seconds = (_seconds + 15).clamp(0, 180),
                      ),
                      icon: const Icon(Icons.fast_forward),
                    ),
                  ],
                ),
                const Text(
                  'Playback state does not depend on the fold angle. Fold/unfold, rotate, or change preview geometry while playing.',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
