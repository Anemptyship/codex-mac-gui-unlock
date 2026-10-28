# Research and attributions

No third-party source files, binaries, sprites or stock assets are included. The original faceless application icon was generated with the built-in image generation tool; its prompt and provenance are in assets/ICON.md. Original source is MIT. Swift/AppKit, ApplicationServices, Security, SystemConfiguration, IOKit and Darwin are supplied by Apple; Python standard-library scripts add no runtime package dependencies.

Inspected source, without building or executing upstream password code:

- [Juns-g/mac-unlock](https://github.com/Juns-g/mac-unlock), MIT, commit `67f1144b1ba1f296e75a05f1c9f791704c5c3ab4`. Its target/session checks and explicit distinction between event posting and confirmed unlock informed this review. Its public branding build did not establish compatibility with this Mac.
- [ts1/BLEUnlock](https://github.com/ts1/BLEUnlock), README declares MIT, commit `2eeb35dcaa4e34ac994380e5dc9c0a692a6f7394`. `AppDelegate.swift` illustrates Keychain-backed Unicode CGEvents. Its Bluetooth service, wake behavior, global HID event routing and success assumptions are not adopted. Its README attributes icon assets to Google under Apache 2.0; no assets are used here.

The independent implementation uses documented Apple APIs for local Keychain and input operations, alongside implementation-specific read-only lock/session metadata that must remain verifiable. Neither project demonstrates that the new app identity can unlock this Mac.

Primary product documentation reviewed on 2026-10-28:

- [OpenAI Computer Use / Locked use](https://learn.chatgpt.com/docs/computer-use): only an active trusted Computer Use turn may use the official short-lived unlock flow. Local keyboard/pointer input can relock it and pause automatic unlock until a manual unlock. The installed OpenAI plug-in is not a general unlock API for local processes.
- [OpenAI skill packaging](https://developers.openai.com/plugins/build/skills): YAML name/description and skill directory structure. Local registration follows this project's requested `~/.agents/skills` destination and is checked with the actual installed Codex `skills/list` API.

Relevant first-party issue tracker reports (user reports, not confirmed causes on this Mac):

- [#37231](https://github.com/openai/codex/issues/37231): password-field readiness timing after display locks.
- [#43435](https://github.com/openai/codex/issues/43435): reported lock diagnosis after browser timeouts, including cases where the owner says the desktop was unlocked.
- [#36776](https://github.com/openai/codex/issues/36776): reports of unexpected lock/guardian interaction.
- [#39534](https://github.com/openai/codex/issues/39534): reported authorization plug-in rejection. Its system-modification workaround is not used here.

These reports justify testing independently; they do not establish a root cause or a fix. No undocumented OpenAI sockets, authorization mechanisms or plug-in interfaces are invoked.
