/// <reference path="../pb_data/types.d.ts" />
//
// Receiving log (ADR 0013): dispute evidence on delivery movements.
//
// Materials sit in a yard for 12-18 months before installation. When
// startup finds pieces missing, the vendor dispute is settled by whoever
// has evidence — and a delivery logged with a timestamped packing-slip
// photo and an over/short/damaged note IS the evidence.
//
// These are five OPTIONAL fields on the movements collection, meant for
// receive-shaped bulk movements (to_location only — see migration
// 1783468807). They are deliberately NOT restricted to that shape in the
// createRule: an optional field left empty on a transfer hurts nothing,
// and tightening the rule would risk rejecting queued offline moves from
// phones running older frontend code.
//
//   vendor_name   — who delivered ("Ferguson Waterworks"). Free text.
//   po_number     — the PO this delivery arrived against. FREE TEXT that
//                   a human types — TrenchNote does not know what was
//                   ordered, only what arrived. Purchase orders and
//                   procurement live in the accounting department's
//                   spreadsheet, on purpose (see the non-goals list).
//   packing_slip  — photo of the slip, snapped before the driver leaves.
//                   The single highest-value piece of dispute evidence.
//   osd_note      — over/short/damaged, in the receiver's words:
//                   "Received 480 of 500 per slip; 2 crates damaged".
//   photos        — up to 8 extra shots (damage close-ups, the crate on
//                   the truck). maxSelect bounds the upload burst a Pi
//                   on trailer wifi has to swallow in one request.
//
// Same append-only rules as every movement: no updates, no deletes, so
// the slip photo's `created` timestamp is trustworthy in a dispute.

migrate((app) => {
  const movements = app.findCollectionByNameOrId("movements");

  movements.fields.add(new Field({
    name: "vendor_name",
    type: "text",
  }));
  movements.fields.add(new Field({
    name: "po_number",
    type: "text",
  }));
  movements.fields.add(new Field({
    name: "packing_slip",
    type: "file",
    maxSelect: 1,
    mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/gif"],
  }));
  movements.fields.add(new Field({
    name: "osd_note",
    type: "text",
  }));
  movements.fields.add(new Field({
    name: "photos",
    type: "file",
    maxSelect: 8,
    mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/gif"],
  }));

  app.save(movements);
}, (app) => {
  const movements = app.findCollectionByNameOrId("movements");
  movements.fields.removeByName("vendor_name");
  movements.fields.removeByName("po_number");
  movements.fields.removeByName("packing_slip");
  movements.fields.removeByName("osd_note");
  movements.fields.removeByName("photos");
  app.save(movements);
});
