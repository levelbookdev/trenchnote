/// <reference path="../pb_data/types.d.ts" />
//
// readings.read_at — when the gauge was actually READ (ADR 0016).
//
// A reading has only `created` (server-set at insert), so a reading
// transcribed from a paper timecard, or captured offline and synced days
// later, was stamped with the ENTRY time, not the observation time. Meter
// numbers end up on invoices; the month they belong to matters.
//
// This mirrors inspections.inspected_at (ADR 0014) exactly: client-set,
// date-only at UTC midnight, OPTIONAL. Empty read_at means "unknown / not
// set" and the derivation falls back to `created`. `created` still records
// when the row entered the system.
//
// Derived answers shift to read_at order (asset.html): latest reading =
// newest by read_at (fallback created), and the lower-than-previous flag
// compares in that order. Additive field; the fallback preserves old rows'
// behavior. Set at CAPTURE time so it survives the offline queue (ADR 0008).

migrate((app) => {
  const readings = app.findCollectionByNameOrId("readings");
  readings.fields.add(new Field({ name: "read_at", type: "date" }));
  app.save(readings);
}, (app) => {
  const readings = app.findCollectionByNameOrId("readings");
  readings.fields.removeByName("read_at");
  app.save(readings);
});
