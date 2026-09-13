# Phanes coding guide

These conventions apply to all authored code, including tests and build tools.
Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing project boundaries.

Pascal is the implementation language for runtime logic and project tooling,
including asset import, corpus extraction and validation. Python is not permitted.
Shell scripts orchestrate compilers and platform tools; browser bindings expose
the APIs needed by the Pascal application.

## Pascal language and layout

- Use `{$mode delphi}` and `{$H+}` in every authored unit and program, including
  tests, pas2js workers and Castle Game Engine units. FPC remains the compiler
  for WebAssembly; Delphi is the language mode. Do not switch to ObjFPC syntax.
- Use two spaces, never tabs. Aim for 100 columns; wrap expressions and parameter
  lists at meaningful boundaries. Keep source files UTF-8 with LF line endings.
- Put each record field, class field and local variable declaration on its own
  line. Separate declarations, initialization and distinct operations with blank
  lines. Related parameters of the same type may share a declaration.
- Put `begin` and `end` on separate lines. Expand every conditional and loop
  body, including single-statement guards and exception handlers. Keep each
  assignment or call on its own line. Do not compress a case branch into a row
  of assignments.
- Spell built-in types consistently: `String`, `Integer`, `Boolean`, `Single`,
  `Double`. Keep Pascal keywords lowercase and identifiers in PascalCase,
  except for the lowercase dotted unit namespaces described below.
- Prefer small routines with a clear purpose. When a constraint encoding needs
  several phases, explain their boundaries and the data passed between them.
- Use indexed iteration and record copies when a record loop variable will be
  assigned again later. With the pinned pas2js compiler, a record variable from
  `for ... in` can still reference the final array element; a later assignment
  through that variable can mutate the input array. Native-only checks do not
  expose this browser behavior.
- Initialize dynamic arrays with `SetLength` and indexed assignments in shared
  code. The pinned pas2js compiler does not reliably translate dynamic-array
  type constructors such as `TSelectionCells.Create(5, 10)`; native execution
  alone cannot verify these fixtures.

## Names

| Role | Convention | Examples |
| --- | --- | --- |
| Type | `T` prefix | `TDocument`, `TSettings` |
| Parameter, including `var` and `out` | `A` prefix | `AValue`, `AInput`, `AReason` |
| Local variable | `L` prefix | `LGraph`, `LSourceCell`, `LPreviousValues` |
| Record or class storage field | `F` prefix | `FPaths`, `FState`, `FCount` |
| Exception binding | Descriptive local | `LException` |
| Unavoidable unit/program global | `G` prefix | `GGame`, `GWindow` |
| Local constant | `C` prefix | `CColumnOffsets` |
| Shared named constant | Descriptive PascalCase | `DefaultWidth`, `DefaultSearchBudget` |
| Public property or routine | Descriptive PascalCase | `Tick`, `ValidateDocument` |

`I`, `J` and `K` are allowed for short, obvious loop counters. Use names such as
`LLinkIndex` or `LItemIndex` when the role matters across a larger routine.
Do not turn `P` into `LP`: name the thing, such as `LDocument` or `LWorldPosition`.
Prefer `LSourceCell` and `LTargetCell` to unexplained `A` and `B` locals.

External APIs retain their declared names. For example, WFC's
`TGraphPosition.X`, CGE's `Translation`, and JavaScript's `textContent` are not
Phanes fields to rename. Overrides follow our parameter convention while
preserving the inherited signature and calling convention.

## Dotted unit namespaces

Every Phanes-owned Pascal unit starts with the lowercase `phanes` namespace.
Separate each submodule with a dot: `phanes.app.initialize`, `phanes.app.view`,
`phanes.generation.model`. Use the identical lowercase dotted filename, such as
`phanes.app.view.pas`, and the same spelling in `unit` and `uses` clauses.
Do not use underscores or concatenation to separate namespace components.
Directories group units but do not replace dots in their declarations.

This rule applies to test units too (`phanes.tests.dependencies`). Program
identifiers may use PascalCase; entry-point filenames may use dotted prefixes
(`phanes.tests.lpr`). CGE-generated entry points and third-party units such as
`CastleWindow`, `JOB.JS`, `wfc` and `wfc_lattice` keep their upstream names.

```pascal
unit phanes.example.validation;

{$mode delphi}
{$H+}

interface

function IsValidSize(const AWidth: Integer): Boolean;

implementation

function IsValidSize(const AWidth: Integer): Boolean;
begin
  Result := AWidth > 0;
end;

end.
```

## Comments and constraint models

Explain intent, invariants and tradeoffs near the relevant code. At a WFC model
boundary, document what cells and domain values mean, where constraints come
from, which choices are fixed or weighted, and how decoded results are validated.
Keep acceptance checks independent from rule construction. Bounded or exhausted
search does not prove impossibility, and weights do not prove an optimum.
Longer design explanations belong in repository documentation.

## Browser code, scripts and data

Use descriptive camelCase names in JavaScript and descriptive PowerShell names;
Pascal's `A`/`L`/`F` prefixes do not apply to those languages. Expand control-flow
bodies, keep operations readable, and format authored JavaScript, HTML and CSS
with `.prettierrc.json`. Use readable HTML templates and preserve intentional
whitespace in UI text.

JSON keys, storage keys and messages are contracts. Pascal renames must not
silently change them. Keep future numerical logic deterministic and independent
of the frame rate and wall clock. Validate asynchronous results against their
current job and revision before publishing them.

## Licensing and ownership

Copy the **complete** [MIT notice](../LICENSE), including
`Copyright (c) 2026 mr-highball`, into every new authored source or script file.
Use `(* ... *)` for Pascal, `/* ... */` for JavaScript/CSS, `<# ... #>` for
PowerShell, `#` comments for shell/YAML, and `<!-- ... -->` for HTML/XML. Keep a
shell shebang or XML declaration first. An SPDX-only line does not replace the
full notice requested for this repository.

JSON and other comment-free data formats are covered by the root license where
authored here; do not corrupt their syntax to insert a header. Third-party art,
scores, archives and source editions retain their own licenses and attribution.
Never overwrite those notices with ours. Generated files in `build/` and CGE's
output directories are not hand-maintained source. Update a generator when its
output is tracked, so regeneration retains the header and these conventions.

Do not format or edit `vendor/` submodules as part of an application cleanup.
Keep dependency changes in their own development workflow. Never commit a
contributor's absolute local paths; use repository-relative paths, parameters
or environment variables in source, documentation and build scripts.

## Review and verification

Review semantic changes, inherited signatures, generated output, string literals
and data contracts. Keep dependency pins untouched unless the task changes them.
Use [README.md](../README.md) for local builds and
[PUBLISHING.md](PUBLISHING.md) for CI. Compile the Castle WebAssembly application
and relevant pas2js checks after Pascal changes. Exercise browser startup and
relevant behavior; inspect desktop and phone layouts after UI changes.
Keep generated evidence under ignored `build/`.

Do not introduce a package manager, application target or dependency merely to
format code. Keep implementation explanations in developer documentation unless
they help an application user make a meaningful decision.
