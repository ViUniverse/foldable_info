import 'package:flutter/material.dart';
import 'package:foldable_info/foldable_info.dart';
import 'geometry.dart';
import 'list_detail.dart';
import 'surfaces.dart';
import 'tabletop.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, this.info});
  final FoldableInfo? info;
  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  RecipePreview _preview = RecipePreview.live;
  int _tab = 0;
  bool _rtl = false;
  bool _large = false;

  Widget _observe(Widget Function(BuildContext, FoldableData?) builder) =>
      StreamBuilder<FoldableData>(
        stream: (widget.info ?? FoldableInfo.instance)
            .forView(View.of(context))
            .watch(),
        builder: (context, snapshot) {
          final data = recipeData(
            View.of(context),
            snapshot.hasError ? null : snapshot.data,
            _preview,
          );
          return builder(
            context,
            data ??
                unavailableRecipeData(
                  View.of(context),
                  failed: snapshot.hasError,
                ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Directionality(
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: _large
              ? const TextScaler.linear(2)
              : MediaQuery.textScalerOf(context),
        ),
        child: Builder(
          builder: (context) => SafeArea(
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              appBar: AppBar(title: const Text('Layout recipes')),
              body: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .35,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final entry in [
                                  'List / detail',
                                  'Tabletop player',
                                  'Controls / surfaces',
                                ].indexed)
                                  ChoiceChip(
                                    label: Text(entry.$2),
                                    selected: _tab == entry.$1,
                                    onSelected: (_) =>
                                        setState(() => _tab = entry.$1),
                                  ),
                              ],
                            ),
                            Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                DropdownButton<RecipePreview>(
                                  isExpanded: true,
                                  key: const ValueKey('recipe-preview'),
                                  value: _preview,
                                  items: const [
                                    DropdownMenuItem(
                                      value: RecipePreview.live,
                                      child: Text(
                                        'Live geometry',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: RecipePreview.book,
                                      child: Text(
                                        'Illustrative book',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: RecipePreview.tabletop,
                                      child: Text(
                                        'Illustrative tabletop',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: RecipePreview.noFold,
                                      child: Text(
                                        'Illustrative no fold',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _preview = v!),
                                ),
                                FilterChip(
                                  label: const Text('RTL'),
                                  selected: _rtl,
                                  onSelected: (v) => setState(() => _rtl = v),
                                ),
                                FilterChip(
                                  label: const Text('Text 2×'),
                                  selected: _large,
                                  onSelected: (v) => setState(() => _large = v),
                                ),
                              ],
                            ),
                            Text(
                              _preview == RecipePreview.live
                                  ? 'Native data where available; compact layout when geometry is unavailable.'
                                  : 'Illustrative geometry — not a device measurement.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _observe((context, data) {
                      if (data == null) {
                        return const Center(
                          child: Text(
                            'Waiting for geometry. Choose an illustrative mode to explore.',
                          ),
                        );
                      }
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(data.areas.isReady ? 0 : 8),
                            child: data.areas.isReady
                                ? const SizedBox.shrink()
                                : Text(
                                    data.areas.state == DataState.loading
                                        ? 'Waiting for fold geometry. Ordinary layout is ready.'
                                        : 'Fold geometry unavailable. Showing ordinary layout.',
                                  ),
                          ),
                          Expanded(
                            child: IndexedStack(
                              index: _tab,
                              children: [
                                ListDetailRecipe(data: data),
                                TabletopRecipe(data: data),
                                SurfacesRecipe(data: data, observe: _observe),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
