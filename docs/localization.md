# Localization

LlamaPulse's desktop UI is localized through Flutter's `gen_l10n`. This
document records what is localized, what deliberately stays English, and how to
add a locale.

## Toolchain

- `flutter_localizations` (SDK) supplies `GlobalMaterialLocalizations`,
  `GlobalWidgetsLocalizations` and `GlobalCupertinoLocalizations`.
- `intl` is the dependency the generated `AppLocalizations` imports.
- `apps/llama_pulse/l10n.yaml` points the generator at `lib/l10n/`, uses
  `app_en.arb` as the template and writes `app_localizations.dart` with the
  class `AppLocalizations`.
- `apps/llama_pulse/lib/l10n/app_en.arb` is the only editable message source.
  The generated files are committed and never hand-edited.
- `dart run melos run gen` runs `build_runner` (core, then app) and
  `flutter gen-l10n`. A second run must leave `git status` clean.
- `MaterialApp` installs `AppLocalizations.localizationsDelegates` and
  `AppLocalizations.supportedLocales`. `LlamaPulseApp` takes an optional
  `locale` so tests pin a locale instead of following the host.

## What is localized

- Every user-facing string the app owns: labels, buttons, tooltips, hints,
  banners, empty states, dialogs and the parameter panel chrome.
- The app-authored notices and errors of the blocs. The blocs report a
  structured code (`ServerFailureCode`, `InferenceFailureCode`, and the
  app-owned `RuntimeErrorCode` / `RuntimeNoticeCode`), and the UI renders the
  localized headline for that code.
- The plural forms (`Reset 1 parameter in …` / `Reset N parameters in …`,
  `1 sample` / `N samples`) use ICU plural messages in the ARB file.

## What stays English on purpose

- The brand name `LlamaPulse` and the product names (`llama-server`,
  `llama.cpp`).
- The generated llama.cpp parameter catalog: `displayName`, `summary`,
  `description`, `reason`, `warning`, `replacement`, the allowed values and the
  catalog group names. The catalog is generated from the vendored upstream
  source and shared with the CLI and `docs/parameters.md`, so translating it
  would change three surfaces at once. It is a separate project.
- The free-text technical detail that core produces: validator violations,
  `ParameterValueCodec` messages, probe reasons, driver requirements and the
  supervisor messages. They are shown under the localized headline as the
  detail a user can copy into a bug report.
- Identifiers: parameter ids, flags, environment variables, enum wire names,
  file paths and units (`ms`, `tok/s`, `MiB`, `GiB`).
- The `GGUF models` filter label of the native file dialog: it names a file
  type, and the platform layer has no `BuildContext` to read the catalog from.

## Adding a locale

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb` and translate every
   message. Keep the `@@locale` header and the `@key` metadata blocks.
2. Run `dart run melos run gen`; the generator adds the locale to
   `supportedLocales`.
3. Keep the key sets identical. `test/l10n/app_localizations_test.dart` checks
   that every template message is non-empty and that the plural messages pick
   the right form.

The app follows the platform locale; there is no in-app language picker and no
persisted language setting yet.

## Follow-ups

- A structured validation-issue type in core, so validator messages can be
  localized instead of shown as technical detail.
- A translated parameter catalog, which needs the generator and the overrides
  file to carry localized fields.
- An in-app language picker and a `settings.yaml` document for the choice.
- RTL and CJK work: the current layout uses `EdgeInsets.only(left/right)` in a
  few places and needs `EdgeInsetsDirectional`.
