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

1) Download and install: https://support.certum.eu/en/cert-offer-card-manager/
2) Connect SmartCard to PC
3) When running in win-arm64, start the x64 PowerShell, WIN+R:

```
powershell -Command "Start-Process 'C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe' -Verb RunAs"
```

4) Install signtool (only on a fresh environment):

```ps
cd $HOME
Invoke-WebRequest "https://www.nuget.org/api/v2/package/Microsoft.Windows.SDK.BuildTools" -OutFile sdk.zip
Expand-Archive sdk.zip -DestinationPath C:\sdk-buildtools
Get-ChildItem C:\sdk-buildtools -Recurse -Filter signtool.exe | Select-Object FullName
```

5) Find signtool:

```ps
$signtool = (Get-ChildItem C:\sdk-buildtools -Recurse -Filter signtool.exe | Where-Object FullName -like "*\x86\*" | Select-Object -First 1).FullName
& $signtool /?
```

6) Install SmartCard:

```ps
Start-Service CertPropSvc

$ksp = New-Object System.Security.Cryptography.CngProvider "Microsoft Smart Card Key Storage Provider"
$key = [System.Security.Cryptography.CngKey]::Open("2EF870F7266CF7F1367A91CB19BCBD4D19CCF53", $ksp)
$bytes = $key.GetProperty("SmartCardKeyCertificate", "None").GetValue()
[IO.File]::WriteAllBytes("$HOME\cert.cer", $bytes)

certutil -user -addstore My "$HOME\cert.cer"
certutil -user -csp "Microsoft Base Smart Card Crypto Provider" -repairstore My a62ca27b2664393fe05f13238467feb6822617fd
```

7) Download GitHub Actions package with QuestPDF Companion App. Extract. Open containing folder in terminal.

8) Sign the msix installer:

```ps
& $signtool sign /fd SHA256 /sha1 a62ca27b2664393fe05f13238467feb6822617fd /tr http://time.certum.pl /td SHA256 /v /debug "questpdf_companion-2026.8.0-windows.msix"
```

9) Verify:

```ps
& $signtool verify /pa /v "questpdf_companion-2026.8.0-windows.msix"
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
