/// Providers for video camera movement guide.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_movements.dart';

/// All camera movement techniques (static).
final allMovementsProvider = Provider<List<CameraMovement>>((ref) {
  return CameraMovements.all;
});

/// Active category filter (null = show all).
final movementCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Movements filtered by selected category.
final filteredMovementsProvider = Provider<List<CameraMovement>>((ref) {
  final category = ref.watch(movementCategoryFilterProvider);
  return CameraMovements.byCategory(category);
});

/// All distinct movement categories.
final movementCategoriesProvider = Provider<List<String>>((ref) {
  return CameraMovements.categories;
});
