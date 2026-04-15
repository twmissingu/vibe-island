# Sound Resources

This directory contains sound files for the SoundManager service.

## Core Notification Sounds (Required)

| File | Type | System Fallback | Description |
|------|------|-----------------|-------------|
| `permission_request.aiff` | `permissionRequest` | `Glass` | Approval request notification |
| `completed.aiff` | `completed` | `Hero` | Task completed notification |
| `error.aiff` | `error` | `Basso` | Error notification |
| `compacting.aiff` | `compacting` | `Pop` | Context compression notification |

## Pet Sound Effects (Reserved)

Add pet sound files here with the naming convention: `{petAction}.aiff`
Examples: `meow.aiff`, `purr.aiff`, `sleep.aiff`

## Format Requirements

- Recommended format: AIFF (`.aiff`) or WAV (`.wav`)
- Sample rate: 44100 Hz or 48000 Hz
- Bit depth: 16-bit or 24-bit
- Keep files small (< 500KB) for quick loading

## Fallback Behavior

If a custom sound file is not found, the SoundManager will automatically fall back
to the corresponding macOS system sound. This ensures the app always has sound
feedback even without custom files.
