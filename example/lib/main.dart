import 'package:flutter/material.dart';
import 'package:foldable_info/foldable_info.dart';

void main() => runApp(const FoldableApp());

class FoldableApp extends StatelessWidget {
  const FoldableApp({super.key, this.info});
  final FoldableInfo? info;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Foldable info',
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

  @override
  Widget build(BuildContext context) {
    // An injected fake and multi-view apps can use an explicit view handle.
    // The handle caches its streams; rebuilding does not create a new stream.
    final handle = (widget.info ?? FoldableInfo.instance).forView(
      View.of(context),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Foldable info')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Measurements only. Your app decides the layout.'),
              const SizedBox(height: 16),
              StreamBuilder<FoldableData>(
                stream: handle.watch(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Read error: ${snapshot.error}');
                  }
                  final data = snapshot.data;
                  if (data == null) return const Text('Waiting for view data');
                  final view = data.view.value;
                  final ios = data.ios.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          '${area.type.name}: ${area.rect} · active: ${area.isActive ?? 'unknown'}',
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
              // Removing this StreamBuilder cancels its own angle subscription.
              if (_showAngles)
                StreamBuilder<FoldAngles>(
                  stream: handle.watchAngles(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Angle error: ${snapshot.error}');
                    }
                    final sample = snapshot.data;
                    final angle = sample?.angles.value?.firstOrNull?.degrees;
                    return Text(
                      'Angle: ${angle == null ? sample?.angles.state.name ?? 'loading' : '${angle.toStringAsFixed(1)}°'}',
                    );
                  },
                ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(labelText: 'Try the keyboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
