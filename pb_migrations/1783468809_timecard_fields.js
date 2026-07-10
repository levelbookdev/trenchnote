/// <reference path="../pb_data/types.d.ts" />
//
// Timecard data capture, part 1 of 2 (ADR 0012): the fields the office
// needs to bill equipment to jobs, attached to records that already exist.
//
//   locations.job_code     — the accounting job number ("6054.2") the
//                            office bills equipment time against. The
//                            ledger already knows WHERE everything was and
//                            WHEN; this maps where -> what to charge.
//   locations.notify_email — the PM/super who should hear the moment
//                            something scans OFF this site (Phase C hook).
//   items.meter            — whether this KIND of thing has an hour meter
//                            or an odometer (empty = neither). Lives on
//                            the catalog, not the asset: every 19' scissor
//                            lift has an hour meter, so flag it once.
//   assets.assigned_to     — custodianship. Trucks and vehicles belong to
//                            a person even though they rarely move between
//                            jobs like shared tools do. Free text, same as
//                            movements.moved_by — crews don't have accounts.
//
// Deliberately absent (ADR 0012): any stored "current job" or "latest
// reading" column. Current job = current location's job_code; latest
// reading = newest record in the readings ledger (next migration). Stored
// copies drift; derived answers don't.

migrate((app) => {
  const locations = app.findCollectionByNameOrId("locations");
  locations.fields.add(new Field({
    name: "job_code",
    type: "text", // "6054.2", "6101" — accounting formats vary, keep it text
  }));
  locations.fields.add(new Field({
    name: "notify_email",
    type: "email", // typed as email so the admin UI validates the address
  }));
  app.save(locations);

  const items = app.findCollectionByNameOrId("items");
  items.fields.add(new Field({
    name: "meter",
    type: "select",
    maxSelect: 1,
    values: ["hours", "odometer"], // empty = this kind of thing has no meter
  }));
  app.save(items);

  const assets = app.findCollectionByNameOrId("assets");
  assets.fields.add(new Field({
    name: "assigned_to",
    type: "text",
  }));
  app.save(assets);
}, (app) => {
  const locations = app.findCollectionByNameOrId("locations");
  locations.fields.removeByName("job_code");
  locations.fields.removeByName("notify_email");
  app.save(locations);

  const items = app.findCollectionByNameOrId("items");
  items.fields.removeByName("meter");
  app.save(items);

  const assets = app.findCollectionByNameOrId("assets");
  assets.fields.removeByName("assigned_to");
  app.save(assets);
});
