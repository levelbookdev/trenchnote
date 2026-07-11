/// <reference path="../pb_data/types.d.ts" />
//
// items.item_code — the office's reference number for a KIND of thing
// (ADR 0018).
//
// Assets carry `tag_code` (unique, the QR). Bulk items carried no code at
// all — the division's real "Misc-66" K-rail number had to ride inside
// `description`, which isn't structured or searchable. This closes that
// asymmetry: a catalog/reference number that lives on the item.
//
// OPTIONAL and NON-UNIQUE on purpose. Not every catalog entry has an
// office number, and a unique index would reject the second item left
// blank (PocketBase stores empty text as "", not NULL, so blanks would
// collide). Enforcing uniqueness is a separate opt-in decision if the
// office ever wants it (partial index + de-dup pass). Most meaningful for
// bulk items; also fine as a manufacturer/part number on unique items.

migrate((app) => {
  const items = app.findCollectionByNameOrId("items");
  items.fields.add(new Field({ name: "item_code", type: "text" }));
  app.save(items);
}, (app) => {
  const items = app.findCollectionByNameOrId("items");
  items.fields.removeByName("item_code");
  app.save(items);
});
