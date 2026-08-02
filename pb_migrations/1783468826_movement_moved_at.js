/// <reference path="../pb_data/types.d.ts" />
//
// movements.moved_at — when the move actually HAPPENED (ADR 0023).
//
// A movement has only `created` (server-set at insert), so a move logged
// offline on Friday and synced on Monday was stamped MONDAY. The ledger then
// says the asset sat at the old job all weekend, and every answer derived
// from move history inherits that error — including the equipment-timecard
// handoff (ADR 0022, open issue 3), where a segment boundary lands on the
// sync day and reports the asset at the wrong job number.
//
// The other two append-only ledgers already solved this, for the same stated
// reason: inspections.inspected_at (ADR 0014) and readings.read_at (ADR 0016,
// migration 1783468817). This is the third ledger getting what they have, and
// it mirrors read_at exactly: client-set, date-only at UTC midnight, OPTIONAL.
// Empty moved_at means "unknown / pre-migration" and every derivation falls
// back to `created`. `created` still records when the row entered the system.
//
// Derived answers shift to moved_at order (sort=-moved_at,-created), the same
// refinement ADR 0016 made for readings. Additive field; the fallback
// preserves every existing row's behavior. Set at CAPTURE time so it survives
// the offline queue (ADR 0008) instead of being recomputed on replay.
//
// The ledger stays append-only: update/delete remain superuser-only, so a
// wrong moved_at is corrected with a NEW movement, never an edit.

migrate((app) => {
  const movements = app.findCollectionByNameOrId("movements");
  movements.fields.add(new Field({ name: "moved_at", type: "date" }));
  app.save(movements);
}, (app) => {
  const movements = app.findCollectionByNameOrId("movements");
  movements.fields.removeByName("moved_at");
  app.save(movements);
});
