/// <reference path="../pb_data/types.d.ts" />
//
// Make assets.tag_code uniqueness CASE-INSENSITIVE.
//
// tag_code is the public identifier the QR encodes and humans type by hand
// (ADR 0010). It is uppercase-canonical by convention: fleet numbers like
// P-138 are stored verbatim as stenciled, and invented codes like A001 are
// uppercase too. But nothing stopped "P-138" and "p-138" from being saved as
// two SEPARATE assets — two labels in the mud pointing at different records.
//
// COLLATE NOCASE on the unique index closes that: the two casings now collide
// as one code, so the second save is rejected.
//
// This does NOT, on its own, make lookups case-insensitive: PocketBase's `=`
// filter compares the column (BINARY), not the index. The scan/type paths in
// asset.html and scan.html normalize codes to uppercase before the lookup for
// that half — the two changes are complementary, not redundant.
//
// EXISTING INSTALLS: if two case-colliding codes already exist, this index
// will refuse to build. Dedupe them in the admin UI first, then re-run.

migrate((app) => {
  const assets = app.findCollectionByNameOrId("assets");
  assets.indexes = [
    "CREATE UNIQUE INDEX `idx_assets_tag_code` ON `assets` (`tag_code` COLLATE NOCASE)",
  ];
  app.save(assets);
}, (app) => {
  // Roll back to the original case-sensitive (BINARY) unique index.
  const assets = app.findCollectionByNameOrId("assets");
  assets.indexes = [
    "CREATE UNIQUE INDEX `idx_assets_tag_code` ON `assets` (`tag_code`)",
  ];
  app.save(assets);
});
