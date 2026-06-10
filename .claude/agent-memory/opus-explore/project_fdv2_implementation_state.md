---
name: fdv2-implementation-state
description: State of the FDv2 (Flag Delivery v2) implementation in the Flutter client SDK as of June 2026 — what's built vs missing
metadata:
  type: project
---

FDv2 implementation in `packages/common_client/lib/src/data_sources/fdv2/` is mid-stream. As of 2026-06-10 (main tip ce4dd4d), phases 1-4 and 6 are merged; the **orchestrator (phase 5, SDK-2186) does not exist**, and phases 7 (DataSystem config/LDClient integration, SDK-2188) and 8 (contract tests, SDK-2189) are not done.

**Why:** Mid-implementation of the FDv2 epic (SDK-1602). The connection-mode work (phase 6) merged out of order before the orchestrator (phase 5).

**How to apply:**
- There is NO `orchestrator.dart`. Nothing implements the `DataSource` interface from FDv2 parts. Comments in `source.dart` and `streaming_synchronizer.dart` reference "the orchestrator" but it's unbuilt.
- `LDCommonClient._composeFactoriesForManager` (ld_common_client.dart ~line 141) produces **FDv1** sources (StreamingDataSource/PollingDataSource) keyed by FDv2ConnectionMode — it does NOT build FDv2 orchestrator sources. So the runtime path is still FDv1.
- There is NO config flag (no DataSystemConfig, no useFdv2). Nothing selects FDv2 over FDv1 at runtime.
- `ld_common_client.dart` only imports `built_in_modes.dart` to read `BuiltInModes.defaultBackgroundPollInterval` (a constant) — not the FDv2 factories.
- The FDv2 entry_factories / source_factory_context / mode_definition are only referenced WITHIN the fdv2 dir + exported in the barrel. Nothing in production wiring consumes `Initializer.run()` / `Synchronizer.results` or translates `FDv2SourceResult` -> `DataSourceEvent`.
- Feature branches SDK-2182/rlamb-sdk-2183/2184/2185 are all OLDER than main (tips Apr-May) and byte-identical to main where they overlap; squash-merges make `git cherry` falsely report `+`. No work newer than main lives in them.
- Streaming Initializer is intentionally dropped; `createInitializerFactoryFromEntry` throws UnsupportedError for StreamingInitializer (only cache + polling initializers exist).
