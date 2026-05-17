# Automated Import Bridge

This is the fastest practical bridge for the demo when direct DAT capture is unreliable.

## What It Automates

Once a glasses/phone photo lands in a watched folder, the script automatically:

1. reads the newest image;
2. sends it to `POST /api/scout/analyze`;
3. saves the structured result JSON;
4. saves a one-line wearer summary;
5. optionally speaks that summary through the current Windows audio output.

If the glasses are connected as the phone/laptop audio output, this is the wearer-facing result path.

## Run Once

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\auto-import-watch.ps1
```

Default watch folder:

```text
%USERPROFILE%\Pictures\DiseaseScoutIncoming
```

## Continuous Watch

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\auto-import-watch.ps1 -Watch -SpeakResult
```

## Fast Demo Mode

Use this when the live model is too slow for the on-stage loop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\auto-import-watch.ps1 -Watch -Provider local-fast -SpeakResult
```

`local-fast` is a conservative pixel-feature triage baseline. It is not a final disease model. Its job is to return the wearer-facing next check quickly while the full dashboard/proof packet can show live-model receipts separately.

Live model mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\auto-import-watch.ps1 -Watch -Provider live -SpeakResult
```

## Hardware Reality

- Fully automated capture is cleanest through DAT `capturePhoto` if the native integration works.
- Without DAT, automation starts after the image reaches the phone gallery or a synced folder.
- Android is the best phone-side automation target because a companion app, Tasker, or MediaStore watcher can detect new imported images and POST them directly.
- iPhone/iCloud can work as a sync-folder fallback, but latency and permissions are less predictable.
