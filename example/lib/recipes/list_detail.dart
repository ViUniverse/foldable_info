import 'package:flutter/material.dart';
import 'package:foldable_info/foldable_info.dart';
import 'geometry.dart';

/// App selection and draft text belong to this state, not a device pose.
class ListDetailRecipe extends StatefulWidget {
  const ListDetailRecipe({super.key, required this.data});
  final FoldableData data;
  @override
  State<ListDetailRecipe> createState() => _ListDetailRecipeState();
}

class _ListDetailRecipeState extends State<ListDetailRecipe> {
  int? _selected;
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RecipeGeometry(
    data: widget.data,
    builder: (context, local) => LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final bounds = Offset.zero & size;
        var split = splitFor(context, local, widget.data);
        // A wide ordinary window may use two panes without claiming a fold.
        if (split == null &&
            size.width >= MediaQuery.textScalerOf(context).scale(720)) {
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final leading = Rect.fromLTWH(0, 0, 300, size.height);
          final trailing = Rect.fromLTWH(316, 0, size.width - 316, size.height);
          split = rtl
              ? (
                  first: Rect.fromLTWH(size.width - 300, 0, 300, size.height),
                  second: Rect.fromLTWH(0, 0, size.width - 316, size.height),
                  vertical: true,
                )
              : (first: leading, second: trailing, vertical: true);
        }
        final twoPanes = split != null;
        return RecipePanes(
          data: widget.data,
          firstRect: split?.first ?? bounds,
          secondRect: split?.second ?? bounds,
          showFirst: twoPanes || _selected == null,
          showSecond: twoPanes || _selected != null,
          first: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: ListView(
              key: const PageStorageKey('recipe-articles'),
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Reading list',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                for (var i = 0; i < 20; i++)
                  ListTile(
                    selected: _selected == i,
                    title: Text('Article ${i + 1}'),
                    subtitle: const Text('Open details'),
                    onTap: () => setState(() => _selected = i),
                  ),
              ],
            ),
          ),
          second: Material(
            child: ListView(
              key: const PageStorageKey('recipe-detail'),
              padding: const EdgeInsets.all(16),
              children: [
                if (!twoPanes)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _selected = null);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Reading list'),
                    ),
                  ),
                Text(
                  _selected == null
                      ? 'Choose an article'
                      : 'Article ${_selected! + 1} details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The same list and detail stay mounted as the window changes. Your draft and selection belong to the page.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('recipe-note'),
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Draft note',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
