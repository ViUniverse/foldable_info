import 'package:flutter/material.dart';
import 'package:foldable_info/foldable_info.dart';
import 'geometry.dart';

typedef RecipeDataBuilder =
    Widget Function(Widget Function(BuildContext, FoldableData?) builder);

class SurfacesRecipe extends StatefulWidget {
  const SurfacesRecipe({super.key, required this.data, required this.observe});
  final FoldableData data;
  final RecipeDataBuilder observe;
  @override
  State<SurfacesRecipe> createState() => _SurfacesRecipeState();
}

class _SurfacesRecipeState extends State<SurfacesRecipe> {
  bool _second = false;
  int _bookmarks = 0;
  String _saved = 'No note saved yet';
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _show(bool sheet) async {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (routeContext, _, _) => Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQuery.of(routeContext).copyWith(textScaler: scaler),
          child: widget.observe((context, data) {
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                child: RecipeGeometry(
                  data: data,
                  builder: (context, local) => LayoutBuilder(
                    builder: (context, constraints) {
                      final split = splitFor(context, local, data);
                      final pane = split == null
                          ? Offset.zero & constraints.biggest
                          : _second
                          ? split.second
                          : split.first;
                      final editor = TextField(
                        controller: _note,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Annotation',
                          border: OutlineInputBorder(),
                        ),
                      );
                      final save = FilledButton(
                        onPressed: () => Navigator.of(context).pop(_note.text),
                        child: const Text('Save note'),
                      );
                      final content = sheet
                          ? Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: .85,
                                child: Material(
                                  elevation: 12,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Pane sheet',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                        const SizedBox(height: 16),
                                        editor,
                                        const SizedBox(height: 16),
                                        save,
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : AlertDialog(
                              scrollable: true,
                              title: const Text('Pane dialog'),
                              content: editor,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                save,
                              ],
                            );
                      // This route watches fresh snapshots itself. No MediaQuery
                      // bridge is installed, and no global dialog behavior changes.
                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: pane,
                            child: FoldableSafeArea(
                              data: data,
                              useSafeArea: false,
                              avoid: const {
                                AreaType.blocked,
                                AreaType.hinge,
                                AreaType.fold,
                              },
                              child: content,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() => _saved = result.isEmpty ? '(Empty note)' : result);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Floating controls & surfaces',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'The actions avoid occlusions and folds. Dialogs and sheets stay inside the chosen pane and remeasure when the window changes.',
            ),
            const SizedBox(height: 16),
            Text('Bookmarks: $_bookmarks'),
            Text(
              'Saved note: $_saved',
              key: const ValueKey('recipe-saved-note'),
            ),
          ],
        ),
      ),
      Positioned.fill(
        child: FoldableSafeArea(
          data: widget.data,
          avoid: const {AreaType.blocked, AreaType.hinge, AreaType.fold},
          useSafeArea: false,
          child: Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DropdownButton<bool>(
                    value: _second,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: false,
                        child: Text(
                          'Primary pane',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(
                          'Secondary pane',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _second = v!),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _show(false),
                        child: const Text('Open dialog'),
                      ),
                      OutlinedButton(
                        onPressed: () => _show(true),
                        child: const Text('Open sheet'),
                      ),
                      FloatingActionButton(
                        tooltip: 'Add bookmark',
                        onPressed: () => setState(() => _bookmarks++),
                        child: const Icon(Icons.bookmark_add_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
