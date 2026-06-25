#Requires -Version 5.1

function Show-CompletionGuide {
    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host ' BlueLampの導入が完了しました！' -ForegroundColor Green
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host ''
    Write-Host '動作確認には、Windowsターミナル(またはPowerShell)で次を実行してください:'
    Write-Host ''
    Write-Host '  wsl -d Ubuntu -- bluelamp1' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '今後BlueLamp/Claude Codeを使うときは、まず以下でUbuntu環境に入ってください:'
    Write-Host ''
    Write-Host '  wsl -d Ubuntu' -ForegroundColor Yellow
    Write-Host ''
}
