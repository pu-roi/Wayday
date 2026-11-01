import 'planning_models.dart';

enum DiscoveryOutcome { found, noMatches, rejected }

enum PlaceExclusion {
  malformed,
  missingName,
  country,
  closed,
  hours,
  addressOnly,
  brand,
  category,
  duplicate,
}

enum RecommendationOperation {
  refresh,
  corridor,
  anchor,
  seed,
  matrix,
  refinement,
  configuration,
}

enum RecommendationFailureKind {
  configuration,
  access,
  quota,
  invalidRequest,
  network,
  timeout,
  cancelled,
  unexpectedResponse,
  unavailable,
  accounting,
}

class RecommendationFailure extends PlanningFailure {
  RecommendationFailure(
    this.cause,
    this.operation, {
    super.providerStatus,
    this.errandId,
  }) : super(
         _messages[cause]!,
         kind: switch (cause) {
           RecommendationFailureKind.invalidRequest => 'invalid_request',
           RecommendationFailureKind.unexpectedResponse =>
             'unexpected_response',
           _ => cause.name,
         },
       );
  final RecommendationFailureKind cause;
  final RecommendationOperation operation;
  final String? errandId;
  bool get retryable => {
    RecommendationFailureKind.network,
    RecommendationFailureKind.timeout,
    RecommendationFailureKind.unavailable,
  }.contains(cause);
  RecommendationFailure forErrand(String id) => RecommendationFailure(
    cause,
    operation,
    providerStatus: providerStatus,
    errandId: id,
  );
  static const _messages = {
    RecommendationFailureKind.configuration:
        'Place recommendations are not configured correctly in this build.',
    RecommendationFailureKind.access:
        'Google denied access to place recommendations. The app configuration needs checking.',
    RecommendationFailureKind.quota:
        'Google place search capacity is currently unavailable. Your choices are kept.',
    RecommendationFailureKind.invalidRequest:
        'Wayday could not send a valid place request. The request needs checking.',
    RecommendationFailureKind.network:
        'Place search could not connect. Check your internet connection and try again.',
    RecommendationFailureKind.timeout:
        'Place search took too long. Your choices are kept; you can try again.',
    RecommendationFailureKind.cancelled:
        'Place search was cancelled. Your choices are kept.',
    RecommendationFailureKind.unexpectedResponse:
        'Place search returned an unexpected response. Your choices are kept.',
    RecommendationFailureKind.unavailable:
        'Place search is temporarily unavailable. Your choices are kept; you can try again.',
    RecommendationFailureKind.accounting:
        'Place search accounting could not be saved. Retry saving before searching again.',
  };
}

/// Transient retrieval evidence, separate from outages and accepted plans.
class DiscoveryResult {
  DiscoveryResult(
    List<PlanCandidate> candidates, {
    this.returnedCount = 0,
    Map<PlaceExclusion, int> exclusions = const {},
    this.contextsEvaluated = 0,
  }) : candidates = List.unmodifiable(candidates),
       exclusions = Map.unmodifiable(exclusions);
  final List<PlanCandidate> candidates;
  final int returnedCount, contextsEvaluated;
  final Map<PlaceExclusion, int> exclusions;
  DiscoveryOutcome get outcome => candidates.isNotEmpty
      ? DiscoveryOutcome.found
      : returnedCount == 0
      ? DiscoveryOutcome.noMatches
      : DiscoveryOutcome.rejected;
}
