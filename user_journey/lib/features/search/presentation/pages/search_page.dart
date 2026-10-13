import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/copy/copy_context.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/toast.dart';
import '../../../../di.dart';
import '../../../lesson/presentation/open_lesson.dart';
import '../../domain/search.dart';
import '../bloc/search_bloc.dart';

/// Search screen (SPEC §9.5).
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider<SearchBloc>(create: (_) => sl<SearchBloc>(), child: const SearchView());
}

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final bloc = context.read<SearchBloc>();
    return Scaffold(
      appBar: AppBar(title: Text(copy('search.placeholder')), titleSpacing: 0),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: BlocBuilder<SearchBloc, SearchState>(
        buildWhen: (a, b) => a.sort != b.sort,
        builder: (context, state) => PopupMenuButton<SearchSort>(
          key: const ValueKey('search-sort'),
          initialValue: state.sort,
          onSelected: (sort) => bloc.add(SearchSortChanged(sort)),
          color: AppColors.surface,
          itemBuilder: (_) => [
            for (final sort in SearchSort.values)
              PopupMenuItem(
                key: ValueKey('search-sort-${sort.name}'),
                value: sort,
                child: Row(
                  children: [
                    Icon(sort == state.sort ? Icons.check_rounded : null, size: 18, color: AppColors.completedCheck),
                    const SizedBox(width: 8),
                    Text(copy(sort.copyKey)),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 18),
                const SizedBox(width: 6),
                Text(copy(state.sort.copyKey), style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.gutter, 8, AppSizes.gutter, 8),
            child: TextField(
              key: const ValueKey('search-field'),
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => bloc.add(SearchQueryChanged(value)),
              decoration: InputDecoration(
                hintText: copy('search.placeholder'),
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                  borderSide: const BorderSide(color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) => switch (state.status) {
                SearchStatus.idle => _Message(copy('search.empty.title'), key: const ValueKey('search-empty')),
                SearchStatus.loading => const LoadingView(key: ValueKey('search-loading')),
                SearchStatus.failure => ErrorView(
                  failure: state.failure!,
                  copy: copy,
                  onRetry: () {
                    context.reloadConfigIfFailed();
                    bloc.add(const SearchRetryPressed());
                  },
                ),
                SearchStatus.success when state.results.isEmpty => _Message(
                  copy('search.no_results.title'),
                  key: const ValueKey('search-no-results'),
                ),
                SearchStatus.success => ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: state.results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.surface),
                  itemBuilder: (context, i) => _ResultTile(result: state.results[i]),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    return ListTile(
      key: ValueKey('search-result-${result.lessonId}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter, vertical: 4),
      title: Text(
        result.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: result.isLocked ? AppColors.textSecondary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(result.path, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: result.isLocked
          ? Semantics(
              label: copy('search.result.locked'),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: () => result.isLocked
          ? showToast(context, context.readCopy('journey.locked.message'))
          : openLesson(context, result.lessonId),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}
