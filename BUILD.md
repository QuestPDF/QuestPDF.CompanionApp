# Companion App Build Instructions

## Regenerate JSON serialization code

```sh
dart run build_runner build --delete-conflicting-outputs
```


## Regenerate Windows icon

`windows/runner/resources/app_icon.ico` contains 13 frames so that the taskbar, title bar and Explorer get a crisp
image at every size and DPI scale (e.g. 30 px = 24 px at 125%). Automatic downscaling of the logo looks blurry or
jagged below 64 px, so the small frames are drawn by hand and kept as PNG files in
`windows/runner/resources/icon-frames/` (`<size>px.png`). The 128 and 256 px frames come from `assets/questpdf-logo.png`.

The Windows target is intentionally absent from `flutter_launcher_icons.yaml`; it would overwrite the file with a
single 256 px frame.

Assemble the `.ico` with ImageMagick (largest frame first, so file browsers report it as 256x256):

```sh
magick assets/questpdf-logo.png \
  ( -clone 0 -filter Lanczos -resize 128x128 ) \
  windows/runner/resources/icon-frames/64px.png \
  windows/runner/resources/icon-frames/48px.png \
  windows/runner/resources/icon-frames/42px.png \
  windows/runner/resources/icon-frames/40px.png \
  windows/runner/resources/icon-frames/36px.png \
  windows/runner/resources/icon-frames/32px.png \
  windows/runner/resources/icon-frames/30px.png \
  windows/runner/resources/icon-frames/28px.png \
  windows/runner/resources/icon-frames/24px.png \
  windows/runner/resources/icon-frames/20px.png \
  windows/runner/resources/icon-frames/16px.png \
  windows/runner/resources/app_icon.ico
```


## Sign msix file on Windows:

```ps
cd "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0/x64"
certutil -repairstore -user My A62CA27B2664393FE05F13238467FEB6822617FD
./signtool.exe sign /fd SHA256 /sha1 a62ca27b2664393fe05f13238467feb6822617fd /tr http://time.certum.pl /td SHA256 /v /debug "C:\Users\marci\Downloads\questpdf_companion-2026.3.0-windows.msix"
```

## MacOS

### Build app

1. Open XCode and open the project
2. Select "Product" -> "Archive"
3. Select latest archive and click "Distribute App"
4. Select "Direct Distribution" and click "Distribute"
5. Wait for notary service to finish
6. Hover mouse over the archive, click "Export App", and select path

### Create installer:

Do only once:

```sh
npm install --global create-dmg
```

For each new build:

```sh
create-dmg "QuestPDF Companion 2026.2.1.app" --overwrite 
```


### Notarize installer:

Do only once:

```sh
xcrun notarytool store-credentials "QuestPDF Companion Profile" \
  --apple-id "marcin@ziabek.com" \
  --team-id "L57GK9Y59F" \
  --password "<NOTARY_TOOL_PASSWORD>"
```

For each new build:

```sh
xcrun notarytool submit "QuestPDF Companion 2026.2.1.dmg" --keychain-profile "QuestPDF Companion Profile" --wait
xcrun stapler staple "QuestPDF Companion 2026.2.1.dmg"
```