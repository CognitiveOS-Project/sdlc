# Implementation Plan: cpm tune

## Overview
Implement local, non-destructive fine-tuning for `.cgp` patches using PEFT/LoRA. The system allows for the generation of user-specific model adapters that can be hot-swapped at runtime.

## Milestones

### Milestone 1: Foundations (Specs & Schema)
- [x] Create ADR-005 for Local Fine-Tuning.
- [x] Update `cognitive.schema.json` with `training` configuration block.
- [x] Update `cpm-spec.md` with `cpm tune` command and lifecycle.

### Milestone 2: cpm CLI Orchestration
- [ ] Implement `cpm tune` subcommand in `cpm/cmd/`.
- [ ] Implement manifest parsing for the `training` block.
- [ ] Implement the controller logic to communicate with `cognitiveosd` for tuning triggers.
- [ ] Implement `--rollback` to delete local adapters.

### Milestone 3: System Daemon (cognitiveosd) Integration
- [ ] Implement background tuning monitor in `cognitiveosd/internal/daemon/`.
- [ ] Add RPC handlers to allow Wide Model to trigger tuning.
- [ ] Implement the "Hot-swap" signaling mechanism.

### Milestone 4: Inference Engine (Hot-Swapping)
- [ ] Update the inference engine to support dynamic binding of LoRA adapters.
- [ ] Implement adapter loading and unloading logic for GGUF models.

## Verification Strategy
- **Mock Trainer:** Create a dummy MCP tool that simulates training by generating a dummy `.bin` file.
- **End-to-End Test:**
  1. Install a patch with a `training` config.
  2. Generate synthetic interaction logs.
  3. Trigger `cpm tune`.
  4. Verify adapter generation.
  5. Verify the hot-swap signal is sent and processed.
