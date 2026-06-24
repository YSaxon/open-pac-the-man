# ADR 0001: Godot 4 with a scene-independent simulation core

- Status: accepted
- Date: 2026-06-23

## Context

The project must reproduce a small deterministic 2D game, import resources from a legally
obtained original archive, and run on current Windows, macOS, and Linux systems on x86-64
and ARM64. Fast automated iteration against behavior recovered from the original is more
important than matching its implementation language.

Pac the Man X 1.5.1 was rewritten in Objective-C and Cocoa. Its archive exposes structured
property-list levels and mostly conventional media resources. Consequently, a low-level
C++ port would not preserve a useful source-level architecture; it would primarily recreate
windowing, rendering, input, audio, and UI facilities already provided by an engine.

## Decision

Use Godot 4.7 and GDScript.

Gameplay rules live under `src/core` in scripts that do not depend on scene-tree timing,
rendering nodes, or input singletons. The simulation advances in explicit fixed ticks.
Godot scenes and nodes form a thin adapter around that core for presentation, platform
input, audio, menus, and packaging.

Original resources are never repository inputs. A runtime/import tool validates a
user-supplied original archive and creates derived cache data outside source control.

## Alternatives considered

### C++20 and SDL3

This offers minimal runtime surface area and excellent portability, but requires us to
build more UI, content, audio, and tooling infrastructure. It provides little source-level
fidelity because the target version is Objective-C/Cocoa rather than a portable C++ game.

### .NET and MonoGame

C# would provide a strong simulation and testing environment. MonoGame is viable, but its
content pipeline and platform-specific graphics backends add packaging work without a
corresponding benefit for this small project.

### Rust

Rust provides strong correctness guarantees but adds binding and ecosystem decisions to
every platform-facing subsystem. Memory safety is not the dominant risk in this project;
behavioral fidelity is.

## Consequences

- A playable vertical slice and level editor can be produced quickly.
- Desktop and ARM64 builds use maintained Godot export templates.
- Headless tests can exercise simulation and import logic.
- Core code must be reviewed to prevent scene-tree and frame-rate dependencies from
  leaking into gameplay behavior.
- If Godot becomes unsuitable, the explicit core/presentation boundary makes a later port
  practical, though not free.

