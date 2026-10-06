[CmdletBinding()]
param(
    [string]$Rscript = 'C:/Users/Usuario/AppData/Local/Programs/R/R-4.6.1/bin/x64/Rscript.exe'
)

$ErrorActionPreference = 'Stop'
$qcOutput = Join-Path $PSScriptRoot 'output'
New-Item -ItemType Directory -Path $qcOutput -Force | Out-Null
$qcTranscript = Join-Path $qcOutput 'ejecucion_qc.log'
$qcTranscriptStarted = $false
$qcRunFailed = $false
try {
    Start-Transcript -LiteralPath $qcTranscript -Append | Out-Null
    $qcTranscriptStarted = $true
    Write-Host ('[{0}] INICIO QC; Rscript={1}' -f (Get-Date -Format o), $Rscript)
    foreach ($qcName in @('qc_adsl', 'qc_adae', 'qc_adtte', 'qc_t14_3_1')) {
        $qcProgram = Join-Path $PSScriptRoot ($qcName + '.R')
        $qcStdout = Join-Path $qcOutput ($qcName + '.stdout.log')
        $qcStderr = Join-Path $qcOutput ($qcName + '.stderr.log')
        Write-Host ('[{0}] EJECUTANDO {1}' -f (Get-Date -Format o), $qcProgram)
        if (-not (Test-Path -LiteralPath $qcProgram -PathType Leaf)) {
            throw ('No existe el programa: ' + $qcProgram)
        }
        try {
            $qcProcess = Start-Process -FilePath $Rscript -ArgumentList @('--vanilla', ('"' + $qcProgram + '"')) -RedirectStandardOutput $qcStdout -RedirectStandardError $qcStderr -WindowStyle Hidden -Wait -PassThru
            $qcExit = $qcProcess.ExitCode
        }
        catch {
            Write-Host ('[{0}] ERROR DE ARRANQUE O EJECUCION {1}: {2}' -f (Get-Date -Format o), $qcName, $_.Exception.Message)
            throw
        }
        Write-Host ('[{0}] FIN {1}; exit_code={2}' -f (Get-Date -Format o), $qcName, $qcExit)
        if ($qcExit -ne 0) {
            throw ('Rscript fallo en {0} con codigo {1}. Consulte {2} y {3}.' -f $qcName, $qcExit, $qcStdout, $qcStderr)
        }
    }
    Write-Host ('[{0}] COMPLETADO: cuatro programas ejecutados sin errores.' -f (Get-Date -Format o))
}
catch {
    $qcRunFailed = $true
    Write-Host ('[{0}] QC INCOMPLETO: {1}' -f (Get-Date -Format o), $_.Exception.Message)
}
finally {
    if ($qcTranscriptStarted) { Stop-Transcript | Out-Null }
}
if ($qcRunFailed) { exit 1 }

