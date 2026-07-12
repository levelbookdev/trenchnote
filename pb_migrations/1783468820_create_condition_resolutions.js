/// <reference path="../pb_data/types.d.ts" />
//
// Damage & condition reports, part 2 of 2 (ADR 0019).
//
// Collection: condition_resolutions — append-only outcomes attached to a
// condition report. A later outcome never overwrites the field observation.
// Multiple outcomes are legal: two offline phones may both record true human
// actions, and a unique constraint would turn that honest race into lost data.

migrate((app) => {
  const reports = app.findCollectionByNameOrId("condition_reports");

  const resolutions = new Collection({
    type: "base",
    name: "condition_resolutions",

    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.id != ""',
    // APPEND-ONLY: corrections are later resolution records.
    updateRule: null,
    deleteRule: null,

    fields: [
      { name: "report", type: "relation", required: true, maxSelect: 1,
        collectionId: reports.id, cascadeDelete: false },

      { name: "resolution", type: "select", required: true, maxSelect: 1,
        values: ["repaired", "accepted_as_is", "disposed", "returned_to_vendor"] },

      { name: "note", type: "text" },

      // Free text because shared field accounts identify a crew, not a person.
      { name: "resolved_by", type: "text", required: true },

      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],

    indexes: [
      "CREATE INDEX `idx_condition_resolutions_report` ON `condition_resolutions` (`report`)",
    ],
  });

  app.save(resolutions);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("condition_resolutions"));
});
