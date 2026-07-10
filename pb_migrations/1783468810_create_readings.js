/// <reference path="../pb_data/types.d.ts" />
//
// Timecard data capture, part 2 of 2 (ADR 0012).
//
// Collection: readings — hour-meter / odometer readings, one record per
// glance at the gauge. APPEND-ONLY, exactly like movements: meters get
// misread, gauges get replaced, and month-end numbers end up on invoices —
// so a reading is never edited or deleted, a correction is a new reading.
// The full history is what settles a billing dispute.
//
// "Latest reading" is DERIVED (newest record per asset), never stored on
// the asset. A reading lower than its predecessor is accepted (replaced
// meter, corrected typo) and FLAGGED at render time by comparing neighbors
// — no stored flag that could disagree with the records it summarizes,
// and out-of-order offline syncs can't bake in a wrong verdict.
//
// The timestamp is the `created` autodate, same convention as movements.
// A reading queued offline gets its server timestamp at sync time — the
// same tradeoff the movements ledger already accepts (ADR 0008).

migrate((app) => {
  const assets = app.findCollectionByNameOrId("assets");

  const readings = new Collection({
    type: "base",
    name: "readings",

    // Born after the Phase 2 lockdown (migration 1783468806), so auth is
    // required from day one — no TODO(auth) grace period.
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.id != ""',
    // APPEND-ONLY: corrections are new readings, never edits.
    updateRule: null,
    deleteRule: null,

    fields: [
      // Readings belong to a specific machine, so the relation targets
      // assets, not the items catalog — "THE skid steer A012 shows 1,240
      // hours", never "skid steers in general".
      { name: "asset", type: "relation", required: true, maxSelect: 1,
        collectionId: assets.id, cascadeDelete: false },

      // NOTE: PocketBase "required" on a number means NON-ZERO. A literal
      // 0.0 reading is therefore not recordable — acceptable, because a
      // zero on the gauge carries no billing information.
      { name: "value", type: "number", required: true, min: 0 },

      // Copied from items.meter at capture time so each ledger record is
      // self-contained even if the catalog entry is later re-flagged.
      {
        name: "reading_type",
        type: "select",
        required: true,
        maxSelect: 1,
        values: ["hours", "odometer"],
      },

      // Free text, not a user relation — consistent with movements.moved_by.
      { name: "recorded_by", type: "text" },

      // Optional photo of the gauge — the "prove it" for month-end numbers.
      { name: "photo", type: "file", maxSelect: 1,
        mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/gif"] },

      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],

    // Every lookup is "this asset's readings, newest first".
    indexes: [
      "CREATE INDEX `idx_readings_asset` ON `readings` (`asset`)",
    ],
  });

  app.save(readings);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("readings"));
});
