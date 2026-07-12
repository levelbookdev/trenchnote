/// <reference path="../pb_data/types.d.ts" />
//
// Damage & condition reports, part 1 of 2 (ADR 0019).
//
// Collection: condition_reports — an append-only photo ledger for what a
// person saw when they touched an asset. Damage, ordinary wear, and a
// condition note all use the same record shape; the type says why the photo
// was taken. A condition_note is especially useful at rental delivery and
// before return.
//
// An asset's DAMAGED badge is never stored. It is derived by finding damage
// reports that have no row in condition_resolutions. Keeping the observation
// and its outcome in separate append-only collections preserves both sides of
// the dispute without turning TrenchNote into repair or maintenance software.

migrate((app) => {
  const assets = app.findCollectionByNameOrId("assets");

  const reports = new Collection({
    type: "base",
    name: "condition_reports",

    // Born after the Phase 2 lockdown: auth required from day one.
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.id != ""',
    // APPEND-ONLY: corrections are later reports, never edits or deletes.
    updateRule: null,
    deleteRule: null,

    fields: [
      { name: "asset", type: "relation", required: true, maxSelect: 1,
        collectionId: assets.id, cascadeDelete: false },

      { name: "report_type", type: "select", required: true, maxSelect: 1,
        values: ["damage", "wear", "condition_note"] },

      { name: "description", type: "text", required: true },

      // Required evidence is the point of this ledger. The UI is photo-first,
      // and the server rejects clients that try to bypass that rule.
      { name: "photo", type: "file", required: true, maxSelect: 1,
        mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/gif"] },

      // Free text, matching moved_by/recorded_by: field crews share accounts.
      { name: "reported_by", type: "text", required: true },

      // `created` is the authoritative timestamp: server arrival order, the
      // same offline truth model as movements (ADR 0008). queuedAt remains a
      // local sync aid and is not promoted into disputed evidence.
      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],

    indexes: [
      "CREATE INDEX `idx_condition_reports_asset` ON `condition_reports` (`asset`)",
      "CREATE INDEX `idx_condition_reports_type_created` ON `condition_reports` (`report_type`, `created`)",
    ],
  });

  app.save(reports);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("condition_reports"));
});
