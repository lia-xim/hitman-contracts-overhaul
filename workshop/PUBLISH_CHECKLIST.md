# Steam Workshop release checklist

## Prepared fields

- **Title:** `Hitman Contracts Overhaul | Drones, Targets and Stealth`
- **Tags:** `Gameplay`, `Objects`, `Audio`, `Graphics`
- **Version:** `0.14.18-rc52`
- **Game version:** Intravenous 2 `1.4.12HF3`
- **Preview:** `preview.jpg` (512 x 512, below the native 1 MiB limit)
- **Description:** `description.txt` (Steam BBCode)
- **Change note:** `changenote.txt`
- **Gallery captions:** `gallery-captions.txt`

## Publish or update in Intravenous 2

1. Fully close and restart Intravenous 2 after preparing the staging directory.
2. Open **Mods > Steam Workshop**. For an existing item, open your created mods and choose **Update**; otherwise choose **Create mod**.
3. Select `Hitman-Contracts-Overhaul` from `mods_staging`.
4. Select `preview.jpg`.
5. Paste the title above and keep only the four listed tags. Deselect `Weapons`, `Levels` and `Miscellaneous` if an earlier upload retained them.
6. Accept the Steam Workshop Legal Agreement and upload.
7. Open the Workshop item in Steam. New items are private by default.
8. Replace Steam's placeholder description (`Change the description!`) with the full contents of `description.txt`.
9. Upload the eight optimized JPEGs from the prepared `gallery-upload/` folder in numeric order and use `gallery-captions.txt` for their descriptions.
10. Add `changenote.txt` as the release/change note if Steam requests one.
11. Confirm that the title, preview, description, tags and gallery render correctly.
12. Set visibility to **Public** only after the checks below pass.

## Before switching to Public

- Subscribe once and confirm the Workshop copy reaches the main menu without an HCO traceback.
- Disable or remove the local HCO copy first; never enable local and Workshop copies together.
- Start a compatible mission from the beginning and confirm the optional contract/intelligence objective appears.
- Confirm the target marker, target movement, disguise action, passive drone presence and contract completion feedback.
- Confirm an armed drone can detect, fire, take damage and reach its wreck state.
- Confirm a mission reload does not duplicate the contract or pay the reward twice.
- Check the Workshop item's **Files** tab/version timestamp after the upload.

## Updates after the first publish

The game writes `files/metadata` containing the Workshop item ID into the staged folder. Keep that file. Future runs of `scripts/prepare-workshop.ps1` preserve it so Intravenous 2 updates the existing item instead of creating a duplicate.

The Ingame uploader does not replace an existing Workshop description. Update `description.txt` and the public Steam page manually when release copy changes.
