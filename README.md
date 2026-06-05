# PDF to Markdown Benchmark (Windows)

PowerShell script that benchmarks PDF-to-Markdown conversion tools side by side. Built to answer a practical question: **which tool produces the best Markdown for LLM consumption?**

## Why this matters

When you feed a 51MB PDF catalog to Claude or GPT, each page counts as an image. A 30-page document burns through your context window fast. Converting to Markdown first means fewer tokens, no image limits, and better structure for the model to work with.

But not all converters are equal — some lose table structure, break reading order, or inflate output with artifacts. This script measures that.

## What it benchmarks

| Tool | Type | Notes |
|---|---|---|
| [pymupdf4llm](https://github.com/pymupdf/RAG) | Rule-based | Fast, good balance of speed and quality |
| [markitdown](https://github.com/microsoft/markitdown) | Rule-based | Microsoft, lightweight, basic quality |
| [marker](https://github.com/datalab-to/marker) | ML-based | Uses vision models, best for complex layouts. Requires PyTorch |
| [docling](https://github.com/DS4SD/docling) | ML-based | IBM, strongest on tables. Heavy install |

## Requirements

- Windows 10/11
- Python 3.10+
- PowerShell 5.1+

## Setup

```powershell
# Core tools
pip install pymupdf4llm "markitdown[pdf]"

# Marker (optional, ~6GB total with PyTorch + models)
pip install marker-pdf

# Docling (optional, ~2GB)
pip install docling
```

## Usage

```powershell
.\benchmark-pdf-to-md.ps1 -PdfPath ".\your-file.pdf"
```

Results go to `benchmark-results\<filename>\`:

- One `.md` file per tool
- `summary.csv` with timing and size data
- `.errors.log` for any failures

## What to evaluate

The script gives you speed and size. Quality you evaluate manually by checking each `.md` file for:

1. **Reading order** — Does text flow correctly, or do columns get mixed?
2. **Tables** — Are they preserved as Markdown tables or broken into loose text?
3. **Headings** — Are titles detected with correct hierarchy (h1, h2, h3)?
4. **Artifacts** — Repeated headers/footers, broken characters, junk text?
5. **Token efficiency** — Bloated output = wasted tokens with no added value.

### Quick comparison in VS Code

```powershell
code --diff ".\benchmark-results\<name>\pymupdf4llm.md" ".\benchmark-results\<name>\marker.md"
```

## Evaluation framework

The quality criteria are adapted from [Nutrient's PDF-to-Markdown benchmark](https://github.com/PSPDFKit/pdf-to-markdown), which uses three metrics against 200 hand-annotated documents:

- **NID** (Normalized Inverse Distance) — reading order accuracy
- **TEDS** (Tree-Edit Distance Score) — table structure preservation
- **MHS** (Markdown Heading Score) — heading hierarchy fidelity

This script doesn't compute those metrics automatically (that requires annotated ground truth), but uses the same dimensions for manual evaluation.

## Known issues on Windows

- **Accented characters in user path** (e.g. `C:\Users\José\...`): docling and some marker versions fail to resolve internal resource paths. Workaround: use a virtualenv in a short, ASCII-only path like `C:\venv-pdf`.
- **Windows Long Path limit**: if installs fail with `OSError: [Errno 2]`, enable long paths:
  ```powershell
  New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
  ```
- **PowerShell execution policy**: if the script is blocked, run:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
  Unblock-File .\benchmark-pdf-to-md.ps1
  ```

## License

MIT
