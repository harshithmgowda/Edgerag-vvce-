# EdgeRAG Knowledge & Incident Synchronization Protocol

## 1. Hotspot Knowledge Synchronization Protocol

The knowledge synchronization protocol ensures that mobile devices receive strictly verified, complete knowledge bundles without risking partial corruption or breaking existing operational capabilities.

### Step-by-Step Sequence

```
Mobile (Flutter)                                      Headquarters (FastAPI)
       |                                                         |
       |  1. POST /api/v1/sync/check                             |
       |     { device_id, installed_packages: { "equip_1": "v1" }|
       |-------------------------------------------------------->|
       |                                                         |
       |  2. CheckResponse                                       |
       |     [ { package_id, equipment_id, version: "v2",        |
       |         sha256_hash, file_size_bytes: 14820120 } ]       |
       |<--------------------------------------------------------|
       |                                                         |
       |  3. Verify Available Storage on Device                  |
       |     (Require at least 2.5x package size free)           |
       |                                                         |
       |  4. GET /api/v1/packages/{package_id}/download          |
       |-------------------------------------------------------->|
       |     Stream binary bytes to temporary file:              |
       |     app_cache/staging_{package_id}.zip                  |
       |                                                         |
       |  5. SHA-256 Checksum Calculation                        |
       |     Digest calculated chunk-by-chunk during download.   |
       |     If digest != server sha256_hash -> ABORT & PURGE    |
       |                                                         |
       |  6. Safe ZIP Extraction (Path Traversal Guard)          |
       |     Validate no entry begins with '/' or '../'          |
       |     Extract:                                            |
       |       - manifest.json                                   |
       |       - knowledge.sqlite                                |
       |                                                         |
       |  7. Manifest Schema & Embedding Spec Validation         |
       |     Verify encoder == "all-MiniLM-L6-v2", dim == 384    |
       |                                                         |
       |  8. Atomic SQLite Activation                            |
       |     File rename:                                        |
       |     staged_knowledge.sqlite -> knowledge_{equip_id}.db  |
       |                                                         |
       |  9. Record Installation in Database A (app_data.db)     |
       |     installed_packages[equipment_id] = "v2"             |
```

### Path Traversal Defense (Zip Slip Mitigation)
When decompressing knowledge ZIP archives on Android:
```dart
for (final file in archive) {
  final filename = file.name;
  if (filename.contains('..') || filename.startsWith('/') || filename.startsWith('\\')) {
    throw SecurityException('Zip traversal attempt detected in entry: $filename');
  }
}
```

---

## 2. Offline Incident Outbox Synchronization

Technicians operating underground or in air-gapped pump houses document equipment abnormalities into their local SQLite database.

### Invariant: Single Permanent UUID & Idempotent Sync
Every incident receives an RFC-4122 V4 UUID generated on the mobile device at creation time. This UUID persists forever.

When LAN connectivity is restored:
1. Flutter reads all records in `app_data.db` where `sync_status = 'PENDING'`.
2. Assembles batch payload conforming to `contracts/incident.schema.json`.
3. Dispatches `POST /api/v1/sync/incidents`.
4. FastAPI processes the list:
   - For each incident UUID:
     - If UUID already exists in MySQL: Mark as `DUPLICATE` (no-op, return success).
     - If UUID is new: Insert incident record, mark status as `OPEN`, create audit entry.
5. FastAPI returns `synced_ids: [uuid1, uuid2]`.
6. Flutter updates local records: `sync_status = 'SYNCED'`, `synced_at = server_time`.
7. Even if network drops mid-sync and Flutter retries, the server will never create duplicate incident tickets.
