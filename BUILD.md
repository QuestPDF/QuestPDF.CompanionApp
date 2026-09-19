# Companion App Build Instructions

## Regenerate JSON serialization code

```sh
dart run build_runner build --delete-conflicting-outputs
```


## Regenerate Windows icon

`windows/runner/resources/app_icon.ico` must contain multiple frames (16-256 px) so that the taskbar gets a crisp
image at every size. `flutter_launcher_icons` writes a single 256 px frame, so regenerate the `.ico` with ImageMagick:

```sh
magick assets/questpdf-logo.png -define icon:auto-resize=256,128,64,48,32,24,16 windows/runner/resources/app_icon.ico
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