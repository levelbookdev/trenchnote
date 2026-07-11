/// <reference path="../pb_data/types.d.ts" />
//
// Rental on/off dates on assets (ADR 0015).
//
// A rental's DATES — when it went on rent, when it's due off — are facts
// about the physical asset, the same kind of fact as `vendor` and
// `po_number` that already live here. They are NOT commercial data: the
// RATE is what stays premium-side (ADR 0006/0011, held in Lookahead's
// rental-terms.json). So dates come into the AGPL core; rates do not.
//
//   assets.on_rent_date   — date the asset went on rent (optional)
//   assets.off_rent_date  — date it's due back / off rent (optional)
//
// Both optional and empty on owned assets. Stored date-only at UTC
// midnight, same convention as reservations' needed_by/expected_release —
// so any UI formatting them must use timeZone: 'UTC' or western zones show
// the previous day.
//
// This is an ADDITIVE change to API contract v1 (new optional fields), so
// per docs/API.md's own versioning rule it does NOT bump the contract
// version — but it still gets this ADR and an API.md field-list update,
// because the contract surface grew.

migrate((app) => {
  const assets = app.findCollectionByNameOrId("assets");
  assets.fields.add(new Field({ name: "on_rent_date", type: "date" }));
  assets.fields.add(new Field({ name: "off_rent_date", type: "date" }));
  app.save(assets);
}, (app) => {
  const assets = app.findCollectionByNameOrId("assets");
  assets.fields.removeByName("on_rent_date");
  assets.fields.removeByName("off_rent_date");
  app.save(assets);
});
