param(
  [string]$clientId = "389862699484-5ujvh0ojob2gt8rsmlonjnhq9tbtb75d.apps.googleusercontent.com",
  [string]$backendConfigUrl = "https://love-app-19405-default-rtdb.asia-southeast1.firebasedatabase.app/.json"
)

Write-Host "Running Flutter with GOOGLE_SERVER_CLIENT_ID=$clientId and BACKEND_CONFIG_URL=$backendConfigUrl"
Set-Location -Path "$PSScriptRoot"
if (-not $env:GRADLE_USER_HOME -or [string]::IsNullOrWhiteSpace($env:GRADLE_USER_HOME)) {
  $env:GRADLE_USER_HOME = Join-Path $PSScriptRoot ".gradle-home"
}
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
flutter run `
  --dart-define="GOOGLE_SERVER_CLIENT_ID=$clientId" `
  --dart-define="BACKEND_CONFIG_URL=$backendConfigUrl"
