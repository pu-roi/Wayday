/// Shared semantic policy. Examples teach intent, never classify runtime text.
abstract final class ErrandUnderstandingPolicy {
  static const version = 'errand-intent-v2';
  static const focuses = {
    'destinationPreference',
    'taskRequirements',
    'targetIdentity',
    'timing',
    'dependency',
  };
  static const instruction =
      ' Wayday errand understanding policy errand-intent-v2. '
      'Decision order: read the whole title, notes, explicit place preferences, confirmed fields and supplied saved user answers; '
      'identify the intended outcome; preserve existing arrangements and chosen destinations; infer ordinary low-risk defaults; '
      'choose suitable venue families; only then decide whether one focused question would meaningfully improve the plan. '
      'Missing notes, shopping lists, brands or a preferred destination are not essential ambiguity. '
      'Ordinary errands default to flexible suitable-place recommendations unless there is evidence of an existing order, belongings, appointment or explicit destination. '
      'Use unclear only when materially different interpretations could send the user to the wrong kind of place. '
      'Never ask where the user wants to go merely because Wayday has not selected a business yet. '
      'Offer at most one useful optional question for a broad underspecified errand of ANY type when the answer changes service or venue suitability. '
      'Do not ask a question for every errand; sufficiently specified errands need none. '
      'clarification.focus is destinationPreference, taskRequirements, targetIdentity, timing or dependency. '
      'destinationPreference is always required=false and never changes flexible intent to unclear. '
      'taskRequirements may be required only when the task itself is materially ambiguous; optional refinements never block planning. '
      'Ask only for genuinely missing target identity, essential task meaning, timing or dependencies; never repeat supplied facts or accepted flexibility. '
      'specific destinations use map confirmation, not a duplicate where question. '
      'Ordinary buying defaults to consumer retail, not wholesale/resale. Preserve explicit bulk/resale intent without inventing quantities. '
      'Infer venue suitability, never stock, service availability, people, appointments, medical advice or factual business claims. '
      'Examples (principles, not a dictionary): Laundry / Magpalaba / Laundry muna -> flexible laundry service, optional question about needed service; '
      'Pick up clothes I left at the laundry / Kunin ang iniwan kong damit / Pickup ng deposited laundry -> specific existing shop. '
      'Grocery / Mamili / Grocery muna -> flexible general shopping; optional: Do you have specific items in mind? '
      'Buy rice / Bumili ng bigas / Bili rice para sa bahay -> consumer retailers, supermarkets or public markets, exclude wholesale-primary suppliers; '
      'Buy rice wholesale for resale / Bigas pangnegosyo -> preserve wholesale intent. '
      'Eat lunch / Kumain ng tanghalian / Lunch muna -> flexible food venue, optional dietary or meal preference, never where. '
      'Haircut / Magpagupit -> flexible salon/barber, optional relevant service preference. '
      'Print documents / Magpa-print -> flexible print service, optional relevant printing requirements. '
      'Buy medicine / Bili gamot -> suitable pharmacy, optional requested product, no invented medicine or dose. '
      'Car wash / Palinis ng kotse -> flexible service, optional relevant service needs. '
      'Pay a bill / Bayad bill -> ask which bill or payment service if the destination depends on it. '
      'Send a parcel / Magpadala ng parcel -> flexible courier service; an existing parcel pickup stays at its actual branch. '
      'Visit the bank -> optional transaction type if it improves branch suitability; do not request account details. '
      'Check the court with no activity context -> ask the intended activity when sports versus legal meaning changes the destination. '
      'These defaults apply across unseen errands and paraphrases in English, Filipino and Taglish. ';
}
