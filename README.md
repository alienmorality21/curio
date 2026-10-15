# Curio

Curio reads facts exclusively from the HTML of Fact Republic's Random Facts
Generator page:

`https://factrepublic.com/random-facts-generator/`

The app does not use Fact Republic's WordPress API, other Fact Republic pages
for fact discovery, or any third-party fact provider. It extracts the numbered
title, image, description, cited source, and Fact Republic share URL from each
`.td-item` on that page. Each fact appears on its own screen; swipe up to move
through the facts. As you approach the end of the current batch, Curio fetches
that same generator page again and appends facts it has not shown yet. It has no
fixed item limit and skips repeats. If the page returns no new facts, the app
offers a retry rather than inventing or repeating facts. Use the refresh button
to start over with a fresh response from the same generator page.

Fact pages adapt to the available screen space. Short descriptions keep their
controls close to the text; long descriptions scroll independently so vertical
swipes can still navigate between facts. Source and Google Search controls can
be collapsed, and images can be hidden for a compact reading view.
Titles and descriptions retain their full content.

Fact images are loaded directly from the URLs attached to the facts and are
never bundled in the app. They preserve their aspect ratio and use a themed
placeholder when unavailable. Fact titles and descriptions can be selected and
copied. Google Search uses the selected text, or the complete fact when no
text is selected; on Android it opens the results in Brave when installed and
otherwise falls back to the default browser. Source links and search queries
are opened externally. Tap a fact image to open a full-screen pinch-to-zoom
viewer.

Settings offers System default, Dark, Light, and OLED black themes, plus
persistent text-size and line-spacing controls.
Theme choices, the loaded fact feed, and bookmarks are stored locally in a
SQLite database. Existing fact and bookmark preferences are imported the first
time the database is opened. Bookmarks are independent of the feed, so removing
a bookmark does not remove a fact from the locally loaded feed.

Previously loaded facts and saved facts remain readable offline. Images are
cached in the app's persistent support directory, with a limit of 400 cached
images and an 8 MB maximum per downloaded image. Image requests time out after
20 seconds; failed or unavailable images show a themed placeholder. Images are
cached opportunistically, so an image that was never downloaded successfully
cannot be guaranteed to display offline. Refresh and load-more failures keep
available facts on screen and offer retry actions.

The page is publicly accessible and `robots.txt` does not disallow it, but an
explicit content/image reuse license was not found and the site's terms URL was
unavailable when checked. Confirm permission with Fact Republic before
redistributing the app or its content. Source links on individual facts are
publisher-provided citations and may lead to third-party sites.

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
