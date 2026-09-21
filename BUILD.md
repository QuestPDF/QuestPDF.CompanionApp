# Companion App Build Instructions

## Regenerate JSON serialization code

```sh
dart run build_runner build --delete-conflicting-outputs
```


## Sign msix file on Windows:

1) Download and install: https://support.certum.eu/en/cert-offer-card-manager/
2) Connect SmartCard to PC
3) Install signtool:

```ps
Invoke-WebRequest "https://www.nuget.org/api/v2/package/Microsoft.Windows.SDK.BuildTools" -OutFile sdk.zip
Expand-Archive sdk.zip -DestinationPath C:\sdk-buildtools
Get-ChildItem C:\sdk-buildtools -Recurse -Filter signtool.exe | Select-Object FullName
```

4) Find signtool:

```ps
$signtool = (Get-ChildItem C:\sdk-buildtools -Recurse -Filter signtool.exe | Where-Object FullName -like "*\x64\*" | Select-Object -First 1).FullName
& $signtool /?
```

5) Download GitHub Actions package with QuestPDF Companion App. Extract. Open containing folder in terminal.

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

7) Sign the msix installer:

```ps
& $signtool sign /fd SHA256 /sha1 a62ca27b2664393fe05f13238467feb6822617fd /tr http://time.certum.pl /td SHA256 /v /debug "questpdf_companion-2026.8.0-windows.msix"
```

8) Verify:

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
