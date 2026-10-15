# Contributing to Curio

Thanks for helping improve Curio! The app is MIT-licensed, and contributions
are welcome through GitHub pull requests.

## Make a quick browser edit

For a typo or another small change, open the file on GitHub and select the
pencil (**Edit this file**) button. GitHub lets you commit directly if you have
write access; otherwise, it creates a branch in your fork and guides you
through opening a pull request. Browser edits are convenient, but they cannot
run Flutter or the app's tests.

## Set up the app locally

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and
   [VS Code](https://code.visualstudio.com/). In VS Code, install the Flutter
   extension.
2. Fork `alienmorality21/curio` on GitHub, then clone your fork:

   ```powershell
   git clone https://github.com/YOUR-USERNAME/curio.git
   cd curio
   flutter pub get
   code .
   ```

   If the `code` command is unavailable, open the cloned folder from VS Code
   using **File > Open Folder**.

3. In VS Code's terminal, run `flutter run`. Connect a phone with USB debugging
   enabled to run on Android, or choose another target supported by your
   Flutter installation.

## Make and submit a change

Create a branch before editing:

```powershell
git switch -c describe-your-change
```

Make a focused change, then run the project's checks:

```powershell
flutter analyze
flutter test
```

Commit and push your branch:

```powershell
git add .
git commit -m "Describe your change"
git push -u origin describe-your-change
```

On GitHub, open your fork and select **Compare & pull request**. Describe what
you changed and why. A maintainer will review the pull request.

## Content and attribution

Curio reads facts from Fact Republic's Random Facts Generator. The code's MIT
license does not cover Fact Republic's website, facts, images, or other
third-party content. Do not add bundled scraped content or imply that code
licensing grants permission to redistribute it. See the source and reuse notes
in the [README](README.md#where-the-facts-come-from).
