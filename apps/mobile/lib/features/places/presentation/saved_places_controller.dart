import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/local_workspace.dart';
import '../domain/place_intent.dart';

final savedPlacesProvider =
    NotifierProvider<SavedPlacesController, List<SavedPlace>>(
      SavedPlacesController.new,
    );

class SavedPlacesController extends Notifier<List<SavedPlace>> {
  @override
  List<SavedPlace> build() =>
      ref.read(localWorkspaceProvider)?.places ?? const [];

  void save(PlaceIntent place) {
    final existing = state.where((e) {
      final other = e.place;
      if (other.source.startsWith('osm/') && place.source.startsWith('osm/')) {
        return other.source == place.source;
      }
      if (other.hasCoordinates && place.hasCoordinates) {
        return other.label.toLowerCase() == place.label.toLowerCase() &&
            (other.latitude! - place.latitude!).abs() < .000001 &&
            (other.longitude! - place.longitude!).abs() < .000001;
      }
      return other.label.toLowerCase() == place.label.toLowerCase();
    }).firstOrNull;
    final saved = SavedPlace(
      id: existing?.id ?? const Uuid().v4(),
      place: place,
    );
    state = List.unmodifiable([
      for (final item in state)
        if (item.id != saved.id) item,
      saved,
    ]);
    ref.read(localWorkspaceProvider)?.savePlaces(state);
  }

  void remove(String id) {
    state = List.unmodifiable(state.where((e) => e.id != id));
    ref.read(localWorkspaceProvider)?.savePlaces(state);
  }
}
