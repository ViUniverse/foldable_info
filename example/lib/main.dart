import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foldable_info/foldable_info.dart';
import 'diagnostics.dart';
import 'region_overlay.dart';
import 'recipes/recipes_page.dart';

void main() => runApp(const FoldableApp());

class FoldableApp extends StatelessWidget {
  const FoldableApp({super.key, this.info});
  final FoldableInfo? info;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Foldable info',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: FoldablePage(info: info),
  );
}

class FoldablePage extends StatefulWidget {
  const FoldablePage({super.key, this.info});
  final FoldableInfo? info;

  @override
  State<FoldablePage> createState() => _FoldablePageState();
}

class _FoldablePageState extends State<FoldablePage> {
  bool _showAngles = false;
  bool _showOverlay = true;
  bool _avoidRegions = true;
  FoldableData? _latest;

  @override
  Widget build(BuildContext context) {
    final handle = (widget.info ?? FoldableInfo.instance).forView(
      View.of(context),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Foldable info'),
                actions: [
                  IconButton(
                    tooltip: 'Layout recipes',
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecipesPage(info: widget.info),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Toggle region overlay',
                    onPressed: () =>
                        setState(() => _showOverlay = !_showOverlay),
                    icon: Icon(
                      _showOverlay ? Icons.layers : Icons.layers_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy geometry snapshot',
                    onPressed: () async {
                      final data = _latest;
                      if (data == null) return;
                      await Clipboard.setData(
                        ClipboardData(text: snapshotJson(data)),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Geometry snapshot copied'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live geometry',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Orange: occlusion · Purple: fold/hinge\nLighter fill: inactive region',
                    ),
                    StreamBuilder<FoldableData>(
                      stream: handle.watch(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          _latest = null;
                          return const Text('Read error: geometry unavailable');
                        }
                        final data = snapshot.data;
                        if (data == null) {
                          return const Text('Waiting for view data');
                        }
                        _latest = data;
                        final view = data.view.value;
                        final ios = data.ios.value;
                        final demo = ColoredBox(
                          color: _avoidRegions
                              ? const Color(0xFFDDE9FF)
                              : const Color(0xFFFFDED5),
                          child: Center(
                            child: FilledButton(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Control stays interactive',
                                      ),
                                    ),
                                  ),
                              child: const Text('Protected control'),
                            ),
                          ),
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Avoid regions in demo'),
                              subtitle: const Text(
                                'Same box, same control. Toggle to compare.',
                              ),
                              value: _avoidRegions,
                              onChanged: (value) =>
                                  setState(() => _avoidRegions = value!),
                            ),
                            SizedBox(
                              height: 160,
                              child: ColoredBox(
                                color: const Color(0xFFEDE7F4),
                                child: _avoidRegions
                                    ? FoldableSafeArea(
                                        data: data,
                                        useSafeArea: false,
                                        avoid: const {
                                          AreaType.blocked,
                                          AreaType.hinge,
                                          AreaType.fold,
                                        },
                                        child: demo,
                                      )
                                    : demo,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('View: ${data.viewState.name}'),
                            Text('Size: ${view?.size ?? data.view.state.name}'),
                            Text(
                              'Safe padding: ${view?.padding ?? data.view.state.name}',
                            ),
                            Text(
                              'Keyboard: ${view?.insets.bottom ?? data.view.state.name}',
                            ),
                            Text(
                              'Foldable: ${data.isFoldable.value ?? data.isFoldable.state.name}',
                            ),
                            Text('Folds: ${data.folds.state.name}'),
                            for (final fold in data.folds.value ?? <FoldInfo>[])
                              Text(
                                'Open state: ${fold.openState.value?.name ?? fold.openState.state.name}',
                              ),
                            Text('Areas: ${data.areas.state.name}'),
                            for (final area in data.areas.value ?? <ViewArea>[])
                              Text(
                                '${area.type.name}: ${area.rect} · active: ${area.isActive ?? "unknown"} · margins: ${area.extraSpace ?? "unknown"}',
                              ),
                            Text('iOS traits: ${data.ios.state.name}'),
                            if (ios != null)
                              Text(
                                'Bar side: ${ios.barSide.value?.name ?? ios.barSide.state.name}',
                              ),
                            Text('Layout revision: ${data.revision}'),
                          ],
                        );
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Read fold angle'),
                      value: _showAngles,
                      onChanged: (value) => setState(() => _showAngles = value),
                    ),
                    if (_showAngles)
                      StreamBuilder<FoldAngles>(
                        stream: handle.watchAngles(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text('Angle error: unavailable');
                          }
                          final sample = snapshot.data;
                          final angle =
                              sample?.angles.value?.firstOrNull?.degrees;
                          return Text(
                            'Angle: ${angle == null ? sample?.angles.state.name ?? "loading" : "${angle.toStringAsFixed(1)}°"}',
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Try the keyboard',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showOverlay)
          StreamBuilder<FoldableData>(
            stream: handle.watch(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              return data == null || snapshot.hasError
                  ? const SizedBox.shrink()
                  : RegionOverlay(data: data);
            },
          ),
      ],
    );
  }
}
