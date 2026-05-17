# Meta Glasses Import Paths

## Path A - DAT Direct Capture

Best final path if the native integration works:

```text
glasses camera -> DAT capturePhoto -> app receives PhotoData -> classifier -> wearer result
```

Why it is best:

- no Meta AI app gallery scraping;
- no manual file picker;
- real image bytes enter the app directly.

Blocker:

- DAT setup and permissions must work on the paired phone.

## Path B - Android Gallery Watcher

Best fallback if using Meta AI app import:

```text
glasses photo -> Meta AI app import -> Android gallery -> MediaStore/Tasker/companion watcher -> classifier
```

Why it is good:

- can be close to automatic;
- Android media access is more scriptable than iOS Photos;
- wearer can receive notification/audio on the paired phone.

## Path C - Sync Folder Watcher

Practical laptop fallback:

```text
glasses photo -> phone import -> iCloud/Google/OneDrive/USB/sync -> watched folder -> classifier
```

This is what `scripts/auto-import-watch.ps1` proves. It is fully automated after the image lands in the watched folder.

## Path D - Browser Upload

Use only for testing:

```text
user selects image -> web upload -> classifier
```

This is not fully automated because a person chooses the image.

## Claims To Avoid

- "We read raw images from Meta AI web."
- "The ordinary Ray-Ban Meta lens displays our result."
- "The import is fully automated" if a person still selects a file.
