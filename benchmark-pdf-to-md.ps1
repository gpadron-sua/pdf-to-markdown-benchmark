# ============================================================
# benchmark-pdf-to-md.ps1
# Compara herramientas PDF-to-Markdown en Windows
# Uso: .\benchmark-pdf-to-md.ps1 -PdfPath ".\archivo.pdf"
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$PdfPath
)

if (-not (Test-Path $PdfPath)) {
    Write-Error "No se encontro el archivo: $PdfPath"
    exit 1
}

$PdfPath = Resolve-Path $PdfPath
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($PdfPath)
$OutputDir = Join-Path (Join-Path "." "benchmark-results") $BaseName
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " PDF to Markdown Benchmark (Windows)"       -ForegroundColor Cyan
Write-Host " Archivo: $PdfPath"                          -ForegroundColor Cyan
Write-Host " Resultados: $OutputDir\"                    -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Verificar Python ---
try {
    $pyVersion = python --version 2>&1
    Write-Host "Python detectado: $pyVersion" -ForegroundColor Green
} catch {
    Write-Error "Python no encontrado. Instalalo desde https://python.org"
    exit 1
}

# --- Tabla de resultados ---
$results = @()

function Run-Tool {
    param(
        [string]$ToolName,
        [string]$PythonCode,
        [string]$OutputFile
    )

    Write-Host "--- [$ToolName] ---" -ForegroundColor Yellow

    $errorLog = Join-Path $OutputDir "$ToolName.errors.log"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        python -c $PythonCode 2> $errorLog
        $sw.Stop()

        if (Test-Path $OutputFile) {
            $fileInfo = Get-Item $OutputFile
            $lines = (Get-Content $OutputFile | Measure-Object -Line).Lines
            Write-Host "  Tiempo:  $([math]::Round($sw.Elapsed.TotalSeconds, 3))s"
            Write-Host "  Output:  $($fileInfo.Length) bytes, $lines lineas"
            Write-Host "  Archivo: $OutputFile"

            return [PSCustomObject]@{
                Tool    = $ToolName
                Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 3)
                Bytes   = $fileInfo.Length
                Lines   = $lines
                Status  = "OK"
            }
        } else {
            Write-Host "  ERROR - no se genero archivo. Ver $errorLog" -ForegroundColor Red
            return [PSCustomObject]@{
                Tool    = $ToolName
                Seconds = 0
                Bytes   = 0
                Lines   = 0
                Status  = "ERROR"
            }
        }
    } catch {
        $sw.Stop()
        $_ | Out-File $errorLog -Append
        Write-Host "  ERROR - ver $errorLog" -ForegroundColor Red
        return [PSCustomObject]@{
            Tool    = $ToolName
            Seconds = 0
            Bytes   = 0
            Lines   = 0
            Status  = "ERROR"
        }
    }
    Write-Host ""
}

# ============================================================
# 1. pymupdf4llm
# ============================================================
$outFile = Join-Path $OutputDir "pymupdf4llm.md"
$escapedPdf = $PdfPath -replace '\\', '/' -replace "'", "\'"
$escapedOut = (Resolve-Path $OutputDir -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path) -replace '\\', '/'
if (-not $escapedOut) { $escapedOut = ($OutputDir -replace '\\', '/') }
$escapedOut = "$escapedOut/pymupdf4llm.md"

try {
    python -c "import pymupdf4llm" 2>$null
    $code = @"
import pymupdf4llm
md = pymupdf4llm.to_markdown(r'$PdfPath')
with open(r'$outFile', 'w', encoding='utf-8') as f:
    f.write(md)
"@
    $results += Run-Tool -ToolName "pymupdf4llm" -PythonCode $code -OutputFile $outFile
} catch {
    Write-Host "--- [pymupdf4llm] ---" -ForegroundColor Yellow
    Write-Host "  SKIP - no instalado. Ejecuta: pip install pymupdf4llm" -ForegroundColor DarkGray
    $results += [PSCustomObject]@{ Tool="pymupdf4llm"; Seconds=0; Bytes=0; Lines=0; Status="SKIP" }
}
Write-Host ""

# ============================================================
# 2. markitdown (Microsoft)
# ============================================================
$outFile = Join-Path $OutputDir "markitdown.md"

try {
    python -c "from markitdown import MarkItDown" 2>$null
    $code = @"
from markitdown import MarkItDown
md = MarkItDown()
result = md.convert(r'$PdfPath')
with open(r'$outFile', 'w', encoding='utf-8') as f:
    f.write(result.text_content)
"@
    $results += Run-Tool -ToolName "markitdown" -PythonCode $code -OutputFile $outFile
} catch {
    Write-Host "--- [markitdown] ---" -ForegroundColor Yellow
    Write-Host "  SKIP - no instalado. Ejecuta: pip install markitdown" -ForegroundColor DarkGray
    $results += [PSCustomObject]@{ Tool="markitdown"; Seconds=0; Bytes=0; Lines=0; Status="SKIP" }
}
Write-Host ""

# ============================================================
# 3. marker (Datalab) — usa modelos ML, bueno en layouts complejos
#    Requiere PyTorch. Sin GPU funciona pero es mas lento.
# ============================================================
$outFile = Join-Path $OutputDir "marker.md"

try {
    python -c "from marker.converters.pdf import PdfConverter" 2>$null
    $code = @"
from marker.converters.pdf import PdfConverter
from marker.models import create_model_dict

models = create_model_dict()
converter = PdfConverter(artifact_dict=models)
rendered = converter(r'$PdfPath')
with open(r'$outFile', 'w', encoding='utf-8') as f:
    f.write(rendered.markdown)
"@
    $results += Run-Tool -ToolName "marker" -PythonCode $code -OutputFile $outFile
} catch {
    Write-Host "--- [marker] ---" -ForegroundColor Yellow
    Write-Host "  SKIP - no instalado. Ejecuta: pip install marker-pdf" -ForegroundColor DarkGray
    Write-Host "  Nota: requiere PyTorch (~2GB) y modelos ML (~4GB adicionales)" -ForegroundColor DarkGray
    $results += [PSCustomObject]@{ Tool="marker"; Seconds=0; Bytes=0; Lines=0; Status="SKIP" }
}
Write-Host ""

# ============================================================
# 4. docling (IBM) — opcional, pesado pero fuerte en tablas
# ============================================================
$outFile = Join-Path $OutputDir "docling.md"

try {
    python -c "from docling.document_converter import DocumentConverter" 2>$null
    $code = @"
from docling.document_converter import DocumentConverter
converter = DocumentConverter()
result = converter.convert(r'$PdfPath')
md = result.document.export_to_markdown()
with open(r'$outFile', 'w', encoding='utf-8') as f:
    f.write(md)
"@
    $results += Run-Tool -ToolName "docling" -PythonCode $code -OutputFile $outFile
} catch {
    Write-Host "--- [docling] ---" -ForegroundColor Yellow
    Write-Host "  SKIP - no instalado. Ejecuta: pip install docling" -ForegroundColor DarkGray
    $results += [PSCustomObject]@{ Tool="docling"; Seconds=0; Bytes=0; Lines=0; Status="SKIP" }
}
Write-Host ""

# ============================================================
# Resumen
# ============================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Resumen" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$results | Format-Table -AutoSize

# Exportar CSV
$csvPath = Join-Path $OutputDir "summary.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "CSV guardado en: $csvPath"
Write-Host "Archivos .md en: $OutputDir\"
Write-Host ""
Write-Host "Compara los .md lado a lado. En VS Code:" -ForegroundColor Green
Write-Host "  code --diff `"$OutputDir\pymupdf4llm.md`" `"$OutputDir\markitdown.md`"" -ForegroundColor Gray
