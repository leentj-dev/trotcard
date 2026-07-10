/// Developer-only tools (per-song sync adjust + offset export) are compiled in
/// only when built with `--dart-define=DEV_TOOLS=true`. Firebase test builds
/// pass the flag; production Play Store / App Store builds omit it, so these
/// tools never ship to end users. Release mode alone can't distinguish the two
/// (both are `--release`), so a dart-define is used.
const bool kDevTools = bool.fromEnvironment('DEV_TOOLS');
