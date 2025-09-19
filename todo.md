# Refactoring Plan: OperationManager, EditorViewModel, and Update Flow

This plan refactors the editing pipeline to reduce coupling, unify update signaling, and hide internal model details behind a stable view model API. Each stage builds and runs independently. Only add tests for functional code that can be tested without heavy mocking or inspecting mutable UI state.

Terminology:
- "VM" refers to `EditorViewModel`.
- "OM" refers to `OperationManager`.
- "Model" refers to the document/tree storage layer.

## Code Review Observations (Added 2025-09-19)

**Key complexities not fully captured in original review:**

1. **Critical UI wiring complexity**: The three closures in `NSTextEditor.swift:46-83` contain sophisticated AppKit-specific logic, especially the `layoutInvalidator` which performs TextKit 2 editing transactions and layout invalidation.

2. **Dual indentation systems**: Two separate places compute paragraph styles:
   - `Coordinator.updateIndentationOfTypingAttributes` (typing attributes for empty lines)
   - `NSTextContentStorageDelegate.textContentStorage` (paragraph display attributes)

   This duplication needs coordination during refactor.

3. **Custom paste behavior**: `MarshlandTextView` has complex copy/paste with custom pasteboard types that needs integration consideration.

4. **Recent addition**: `normalizeIndentationOperations` (commit d2c3c38) adds indentation normalization during delete operations for proper undo/redo. This adds complexity to the operation sequencing that Stage 8 (batching) must account for.

**Impact on plan**: Stage 10 (Coordinator) should be **mandatory**, not optional, due to UI integration complexity. The coordinator must handle TextKit 2 specifics currently embedded in closures.

---

## Stage 0 – Baseline safety and checkpoints

- [x] Create a Git branch for the refactor.
- [x] Build and run the app to ensure baseline is green.

Checkpoints:
- App builds and launches.

---

## Stage 1 – Introduce a typed change enum (non-invasive)

Goal: Add a single, typed way to represent editor changes without removing existing closures yet.

Steps:
1. [x] Create a new file `EditorChange.swift` with:
   - An enum `EditorChange` with cases:
     - `textReplaced(range: NSRange, replacement: String)`
     - `paragraphsInvalidated(NSRange)`
     - `typingAttributesNeedsUpdate`
     - `selectionMoved(from: NSRange, to: NSRange)`
2. [x] Build to verify no breakages (nothing references it yet).

Checkpoints:
- App still builds.

---

## Stage 2 – Add a unified callback to OperationManager (opt-in)

Goal: Introduce a single callback to carry typed changes while keeping existing closures.

Steps:
1. [x] In `OperationManager`, add:
   - `var onChange: ((EditorChange) -&gt; Void)?`
   - Do not remove `textStorageUpdater`, `layoutInvalidator`, or `typingAttributesUpdater` yet.
2. [x] Where OM currently calls the individual closures, also emit the corresponding `onChange` event:
   - After insert/delete: emit `.textReplaced(range:..., replacement: ...)` with the same values used for `textStorageUpdater`.
   - After indent: emit `.paragraphsInvalidated(...)` with the paragraph range.
   - After operations that adjust typing attributes: emit `.typingAttributesNeedsUpdate`.
3. [x] Build and run to verify behavior remains unchanged.

Checkpoints:
- Existing UI still updates via old closures.
- `onChange` is available for consumers but not yet required.

---

## Stage 3 – Encapsulate internal model calls behind stable VM API

Goal: Rename and centralize edit operations in VM so OM doesn’t know about internal storage (e.g., `tendrilTreeInsert`).

Steps:
1. [x] In `EditorViewModel`, add new domain-oriented methods:
   - `func insert(text: String, at location: Int) throws`
   - `func delete(range: NSRange) throws`
   - `func indent(range: NSRange, depth: Int) throws`
   - Also added selection properties: `selection: NSRange` and `setSelection(_ range: NSRange)`
2. [x] Implement these by delegating to the current internal model methods (`tendrilTreeInsert`, `tendrilTreeDelete`, etc.). Keep old methods internal/private if possible.
3. [x] In `OperationManager`, replace calls to `tendrilTreeInsert`/`tendrilTreeDelete`/`indent` with the new VM methods.
4. [x] Build and run.

Checkpoints:
- No functional changes.
- OM no longer references `tendrilTree*` names directly.

---

## Stage 4 – Centralize selection handling and finish moveSelection

Goal: Make selection a VM concern and complete the `.moveSelection` operation.

Steps:
1. [x] Ensure `EditorViewModel` exposes a method to set selection:
   - `func setSelection(_ range: NSRange)` (or equivalent), and to retrieve it if needed.
2. [x] In OM's `.moveSelection` handler, call `viewModel.setSelection(r2)` and register undo to restore `r1`.
3. [x] Emit `onChange(.selectionMoved(from: r1, to: r2))`.
4. [x] Added TODO comment in `insertText()` about future moveSelection Operation integration for consistency and proper undo coalescing.
5. [x] Build and run.

Checkpoints:
- [x] Selection changes propagate via VM and typed change.
- [x] Infrastructure in place for future operations requiring explicit selection control.
- [x] VM selection state synchronized for future undo coalescing logic.

---

## Stage 5 – Reduce UI-specific logic from OperationManager

Goal: OM should not compute AppKit-specific invalidation details when avoidable.

Steps:
1. [x] Move paragraph-range computation responsibility to VM:
   - Modified `EditorViewModel.indent(depth:at:)` to return the paragraph range that needs layout invalidation.
2. [x] In OM `.indent` processing, stop computing paragraph range directly:
   - OM now calls `viewModel?.indent()` and uses the returned paragraph range for `onChange(.paragraphsInvalidated())`.
3. [x] Change VM string property to `content: NSString` to eliminate redundant casting in OM.
4. [x] Update all NSString casts in OperationManager to use new `content` property directly.
5. [x] Update NSTextEditor.swift to cast `viewModel.content as String` for compatibility.
6. [x] Keep `layoutInvalidator` call temporarily since `onChange` handler not yet wired to UI.
7. [x] Add comprehensive doc comment to `indent` method following new documentation guidelines.
8. [x] Add documentation style guidelines to CLAUDE.md.
9. [x] Build and run.

Checkpoints:
- [x] Behavior unchanged; OM is thinner.
- [x] VM encapsulates paragraph range computation logic.
- [x] Eliminated redundant NSString casting throughout OM.
- [x] Single source of truth for layout invalidation via `onChange` (once UI wiring complete).

---

## Stage 6 – Consumers migrate to the typed callback

Goal: Switch the UI layer (view/controller) to consume `onChange` instead of the trio of closures.

Steps:
1. [ ] In the UI wiring code, subscribe to `OperationManager.onChange` and handle cases:
   - For `.textReplaced`, update text storage.
   - For `.paragraphsInvalidated`, invalidate layout.
   - For `.typingAttributesNeedsUpdate`, refresh typing attributes.
   - For `.selectionMoved`, update selection.
2. [ ] Keep the old closures wired temporarily to ensure parity.
3. [ ] Build and run; verify no double-updating or regressions.

Checkpoints:
- UI responds to `onChange`.

---

## Stage 7 – Remove legacy closures

Goal: Remove `textStorageUpdater`, `layoutInvalidator`, `typingAttributesUpdater` after migration.

Steps:
1. [ ] Remove the three closures from `OperationManager`.
2. [ ] Remove all call sites for the old closures.
3. [ ] Ensure all updates flow via `onChange`.
4. [ ] Build and run.

Checkpoints:
- Codebase compiles; behavior preserved.

---

## Stage 8 – Batch changes to reduce churn (**Updated: now accounts for normalization operations**)

Goal: Allow OM to emit batched changes for better performance, handling the new `normalizeIndentationOperations`.

Steps:
1. [ ] Add `var onBatchChange: (([EditorChange]) -&gt; Void)?` to OM.
2. [ ] In `replaceCharacters(in:with:)` and other grouped operations, collect emitted changes in a local array while the undo group is open.
3. [ ] **Important**: Account for the multi-operation sequences from `normalizeIndentationOperations` + delete/insert. Each normalization indent + the main operations should be batched together.
4. [ ] At the end of the group, prefer emitting `onBatchChange(changes)`; if nil, fall back to individual `onChange` calls.
5. [ ] Update UI wiring to prefer batch handling when available.
6. [ ] Build and run.

Checkpoints:
- Fewer redundant UI updates; behavior preserved.
- Indentation normalization + main operations properly batched.

---

## Stage 9 – Optional: Move undo registration to VM or keep in OM consistently

Goal: Choose a single owner for undo registration for consistency.

Steps:
1. [ ] If keeping in OM: Ensure all VM edit methods are “dumb” (pure mutations) and OM consistently registers inverse ops.
2. [ ] If moving to VM: Add inverse registration inside VM methods and make OM only orchestrate sequences without calling `registerUndo` directly.
3. [ ] Pick one approach and refactor accordingly; build and run.

Checkpoints:
- Undo/redo still works as before.

---

## Stage 10 – **MANDATORY**: Introduce a Coordinator for view-specific policy (**Updated: now mandatory**)

Goal: Keep OM and VM platform-agnostic and move UI policy (layout invalidation details, typing attribute policy) into a coordinator.

**This stage is now mandatory due to UI integration complexity discovered in code review.**

Steps:
1. [ ] Create `EditorCoordinator` that subscribes to OM's `onChange`/`onBatchChange`.
2. [ ] Implement translation from `EditorChange` to concrete UI updates:
   - Text storage updates (currently `textStorageUpdater`)
   - TextKit 2 layout invalidation with editing transactions (currently `layoutInvalidator`)
   - Typing attributes updates for empty lines (currently `typingAttributesUpdater`)
3. [ ] Handle dual indentation systems coordination between typing attributes and paragraph display attributes.
4. [ ] Wire the coordinator in the composition root.
5. [ ] Build and run.

Checkpoints:
- OM/VM free of AppKit specifics; UI behavior preserved.
- Complex TextKit 2 logic properly encapsulated in coordinator.

---

## Stage 11 – Tests (only where functional and stable)

Add tests incrementally only for pure or stable components:

- [ ] Stage 1: None (types only).
- [ ] Stage 3: Add tests for VM edit APIs (`insert`, `delete`, `indent`) that verify the VM’s `string` (or exported representation) mutates correctly. No mocking; use real VM/model.
- [ ] Stage 4: If selection is stored in VM, add a simple test verifying `setSelection` stores and retrieves the correct range.
- [ ] Stage 8: If batch emission logic is pure (collecting changes), add a unit test that calls a fake grouped edit and asserts the emitted batch contains expected `EditorChange` items.

Build &amp; Run after each test addition.

---

## Stage 12 – Cleanup and renames

Goal: Remove internal names from public surfaces and improve clarity.

Steps:
1. [ ] Ensure public VM API contains only domain names (no `tendrilTree*`).
2. [ ] Mark internal storage APIs as `internal`/`private`.
3. [ ] Rename any remaining ambiguous properties to domain terms (e.g., `documentChanged()` to a more explicit `didMutateDocument()` or remove if redundant).
4. [ ] Build and run.

Checkpoints:
- Public API is clean and consistent.

---

## Stage 13 – Final verification

- [ ] Manual QA: insert, delete, indent (single and multi-line), undo/redo, selection move.
- [ ] Verify no duplicate updates, no missed layout invalidations.
- [ ] Review diffs and remove dead code.