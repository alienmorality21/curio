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

## License

The Curio application code is licensed under the MIT License; see
[LICENSE](LICENSE). This license covers the code in this repository only. It
does not grant rights to Fact Republic's website, facts, images, or other
third-party content. Review the source and reuse notes above before using or
redistributing that content.

## Edit the app or contribute

**Just want to suggest or make a small change in your browser?** Open a file in
the repository on GitHub, select the pencil button, make your edit, and choose
**Commit changes**. If you do not have write access, GitHub will offer to make
the change on a fork and open a pull request instead. Browser edits cannot run
the app's tests.

Start with one of these files:

- [Edit this README](https://github.com/alienmorality21/curio/edit/main/README.md)
  to improve the instructions.
- [Edit the fact screen](https://github.com/alienmorality21/curio/edit/main/lib/screens/discover_screen.dart)
  to change how the feed looks and behaves.
- [Edit settings](https://github.com/alienmorality21/curio/edit/main/lib/screens/settings_screen.dart)
  to change the app's preferences and theme controls.

**Want to edit and run checks in your browser?** Select **Code > Codespaces >
Create codespace on main** on the repository page, or
[open the Codespaces creation page](https://github.com/codespaces/new?repo=alienmorality21%2Fcurio&ref=main).
When setup finishes, open the integrated terminal and run:

```sh
flutter analyze
flutter test
```

Codespaces uses GitHub's included monthly quota, and additional use may be
billed. See [GitHub's Codespaces billing information](https://docs.github.com/en/billing/concepts/product-billing/github-codespaces).
The first Codespace setup downloads the Flutter SDK and may take a few minutes.
In VS Code, you can also open the Command Palette, choose **Tasks: Run Task**,
then select **Curio: Analyze** or **Curio: Run tests**.

**Want to run the app while you edit?** Install
[Flutter](https://docs.flutter.dev/get-started/install) and
[VS Code](https://code.visualstudio.com/), then:

1. Fork this repository on GitHub and clone your fork:

   ```powershell
   git clone https://github.com/YOUR-USERNAME/curio.git
   cd curio
   ```

2. Open the folder in VS Code and install the **Flutter** extension when
   prompted. In the VS Code terminal, run:

   ```powershell
   flutter pub get
   flutter run
   ```

   To run on a phone, connect an Android device with USB debugging enabled and
   use `flutter devices` to find it. Alternatively, install a desktop or web
   target supported by your Flutter setup.

3. Create a branch for your change, run the checks, and commit it:

   ```powershell
   git switch -c my-change
   flutter analyze
   flutter test
   git add .
   git commit -m "Describe your change"
   git push -u origin my-change
   ```

4. Open your fork on GitHub and select **Compare & pull request** so the change
   can be reviewed and merged.

For more detail, see [CONTRIBUTING.md](CONTRIBUTING.md). Contributions to the
code do not grant permission to reuse Fact Republic's content.

## Check changes and get an APK

Every pull request and update to `main` automatically runs `flutter analyze`
and `flutter test`, builds a release APK, and attaches the APK to the
workflow run. To download it, open the successful run under
[GitHub Actions](https://github.com/alienmorality21/curio/actions), then find
the **curio-android-apk** artifact at the bottom of the run summary. Workflow
artifacts are temporary; use [GitHub Releases](https://github.com/alienmorality21/curio/releases/latest)
for the published APK.

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
