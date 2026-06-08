param(
    [string]$BaseUrl = "https://tsea-tcc-rastreabilidade-smart-tolls.fly.dev",
    [string]$WorkerToken = $env:WORKER_TOKEN,
    [switch]$SkipBuild,
    [switch]$IncludeMutating
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkerToken)) {
    Write-Host "Informe o token do worker via -WorkerToken ou variável de ambiente WORKER_TOKEN." -ForegroundColor Red
    exit 1
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details = ""
    )

    $Results.Add([pscustomobject]@{
        Test = $Name
        Status = $Status
        Details = $Details
    }) | Out-Null
}

function Run-Test {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    Write-Host "==> $Name"
    try {
        $details = & $Body
        Add-Result -Name $Name -Status "PASS" -Details ($details -join " ")
        Write-Host "    PASS" -ForegroundColor Green
    }
    catch {
        Add-Result -Name $Name -Status "FAIL" -Details $_.Exception.Message
        Write-Host "    FAIL: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-Api {
    param(
        [string]$Path,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null
    )

    $uri = "$($BaseUrl.TrimEnd('/'))$Path"
    $params = @{
        Uri = $uri
        Method = $Method
        Headers = $Headers
        TimeoutSec = 60
        UseBasicParsing = $true
        SkipHttpErrorCheck = $true
    }

    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = $Body
    }

    Invoke-WebRequest @params
}

Push-Location $ProjectRoot
try {
    if (-not $SkipBuild) {
        Run-Test "Build Backend" {
            dotnet build "Backend\Backend.csproj" -c Release | Out-Null
            Assert-True ($LASTEXITCODE -eq 0) "dotnet build Backend falhou."
            "Backend compilou em Release."
        }

        Run-Test "Build ArduinoBridgeWorker" {
            dotnet build "ArduinoBridgeWorker\ArduinoBridgeWorker.csproj" -c Release | Out-Null
            Assert-True ($LASTEXITCODE -eq 0) "dotnet build ArduinoBridgeWorker falhou."
            "Worker compilou em Release."
        }
    }

    Run-Test "GET /" {
        $res = Invoke-Api "/"
        Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."
        Assert-True ($res.Content -match "<!DOCTYPE|<html|TSEA") "Resposta raiz nao parece HTML do frontend."
        "Frontend respondeu 200."
    }

    Run-Test "GET /ferramentas" {
        $res = Invoke-Api "/ferramentas"
        Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."
        $json = $res.Content | ConvertFrom-Json
        Assert-True ($json -is [array] -or $json.Count -ge 0) "Resposta nao parece lista JSON."
        "Ferramentas retornadas: $($json.Count)."
    }

    Run-Test "GET /status/porta" {
        $res = Invoke-Api "/status/porta"
        Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."
        $json = $res.Content | ConvertFrom-Json
        Assert-True (-not [string]::IsNullOrWhiteSpace($json.status)) "Campo status ausente."
        "Status atual: $($json.status)."
    }

    Run-Test "GET /worker/comandos sem token deve negar" {
        $res = Invoke-Api "/worker/comandos"
        Assert-True ($res.StatusCode -eq 401) "Esperado 401, recebido $($res.StatusCode)."
        "Worker protegido por token."
    }

    Run-Test "GET /worker/comandos com token" {
        $res = Invoke-Api "/worker/comandos" -Headers @{ "X-Worker-Token" = $WorkerToken }
        Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."
        $json = $res.Content | ConvertFrom-Json
        Assert-True ($null -ne $json.id) "Campo id ausente."
        Assert-True ($null -ne $json.comando) "Campo comando ausente."
        "Comando retornado: id=$($json.id), comando='$($json.comando)'."
    }

    Run-Test "GET /relatorio padrao" {
        $res = Invoke-Api "/relatorio"
        Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."
        $json = $res.Content | ConvertFrom-Json
        Assert-True ($json.periodo -eq "DIARIO") "Periodo esperado DIARIO, recebido '$($json.periodo)'."
        Assert-True ($null -ne $json.resumo) "Resumo ausente."
        "Relatorio padrao retornou periodo DIARIO."
    }

    Run-Test "GET /relatorio?tipo=MENSAL" {
        $res = Invoke-Api "/relatorio?tipo=MENSAL"
        Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."
        $json = $res.Content | ConvertFrom-Json
        Assert-True ($json.periodo -eq "MENSAL") "Periodo esperado MENSAL, recebido '$($json.periodo)'."
        "Relatorio mensal OK."
    }

    Run-Test "GET /relatorio/xlsx" {
        $today = Get-Date -Format "yyyy-MM-dd"
        $res = Invoke-Api "/relatorio/xlsx?tipo=DIARIO&dataInicio=$today"
        Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."
        $contentType = [string]$res.Headers["Content-Type"]
        Assert-True ($contentType -match "spreadsheet|octet-stream") "Content-Type inesperado: '$contentType'."
        Assert-True ($res.RawContentLength -gt 0) "Arquivo XLSX veio vazio."
        "XLSX gerado com $($res.RawContentLength) bytes."
    }

    if ($IncludeMutating) {
        Run-Test "POST /worker/evento PORTA_ABERTA" {
            $body = '{"evento":"PORTA_ABERTA"}'
            $res = Invoke-Api "/worker/evento" -Method "POST" -Headers @{ "X-Worker-Token" = $WorkerToken } -Body $body
            Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."

            $check = Invoke-Api "/status/porta"
            $json = $check.Content | ConvertFrom-Json
            Assert-True ($json.status -eq "ABERTA") "Status esperado ABERTA, recebido '$($json.status)'."
            "Evento PORTA_ABERTA processado."
        }

        Run-Test "POST /worker/evento PORTA_FECHADA" {
            $body = '{"evento":"PORTA_FECHADA"}'
            $res = Invoke-Api "/worker/evento" -Method "POST" -Headers @{ "X-Worker-Token" = $WorkerToken } -Body $body
            Assert-True ($res.StatusCode -eq 200) "Esperado 200, recebido $($res.StatusCode)."

            $check = Invoke-Api "/status/porta"
            $json = $check.Content | ConvertFrom-Json
            Assert-True ($json.status -eq "FECHADA") "Status esperado FECHADA, recebido '$($json.status)'."
            "Evento PORTA_FECHADA processado."
        }
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Resumo dos testes"
$Results | Format-Table -AutoSize

$failed = @($Results | Where-Object { $_.Status -eq "FAIL" })
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) teste(s) falharam." -ForegroundColor Red
    exit 1
}

Write-Host "Todos os testes passaram." -ForegroundColor Green
exit 0
