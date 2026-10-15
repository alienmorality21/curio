# Curio: Random Fact Generator

Curio is a Flutter app for discovering, reading, and saving interesting facts.
It fetches its fact feed from Fact Republic's **Random Facts Generator**:

<https://factrepublic.com/random-facts-generator/>

## Download for Android

Download the latest installable Android APK from
[GitHub Releases](https://github.com/alienmorality21/curio/releases/latest).
On your Android device, download the APK from the release assets and open it
to install. Android may ask you to allow installation from your browser or file
manager.

## Features

- Browse facts one at a time and swipe to move through the feed.
- Load more unique facts from the generator page as you reach the end; refresh
  to start again.
- Read each fact's title and full description, and open its cited source when
  one is provided.
- Bookmark facts and keep the feed and bookmarks stored locally in SQLite.
- Revisit previously loaded facts and bookmarks offline.
- Open a fact image in a full-screen pinch-to-zoom viewer; images are cached
  opportunistically for offline use.
- Select and copy fact text, then search the selection or the whole fact with
  Google. On Android, search opens in Brave when installed, or the default
  browser otherwise.
- Choose System, Dark, Light, or OLED black themes, and adjust text size and
  line spacing.
- Hide images or collapse source and search actions for a more compact view.

## Where the facts come from

Fact discovery uses only the HTML of Fact Republic's Random Facts Generator
page linked above. Curio extracts each fact's title, image URL, description,
publisher-provided cited source, and Fact Republic share URL from the page's
`.td-item` entries. It does not use Fact Republic's WordPress API, other
Fact Republic pages to discover facts, or a third-party fact provider. Images
are loaded directly from the URLs attached to the facts and are not bundled
with the app. Individual cited source links can lead to third-party publishers.

The page is publicly accessible and its `robots.txt` does not disallow it, but
an explicit content or image reuse license was not found, and the site's terms
URL was unavailable when checked. Public access does not itself grant
redistribution rights. Confirm permission with Fact Republic before
redistributing the app or its content.

## Run on an Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it by USB and approve the debugging prompt.
3. Check the phone appears with `flutter devices`.
4. Run the app from this project folder:

   ```powershell
   flutter run -d <device-id>
   ```

While `flutter run` is active, save a Dart file in VS Code or press `r` in the
terminal for Hot Reload. The phone needs an internet connection to refresh
facts and load their images.

## Checks

```powershell
flutter analyze
flutter test
```
