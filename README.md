# PDF to Markdown Benchmark (Windows)

Benchmark and daily-use tools for converting PDFs to clean Markdown optimized for LLM consumption.

## Why this matters

When you feed a 51MB PDF catalog to Claude or GPT, each page counts as an image. A 30-page document burns through your context window fast. Converting to Markdown first means fewer tokens, no image limits, and better structure for the model to work with.

But not all converters are equal — some lose table structure, break reading order, or inflate output with artifacts. This repo includes a benchmark script to test that, and a daily-use converter based on the results.

## Benchmark results

Tested against a 51MB real estate brochure (58 pages, image-heavy, mixed layouts) on Windows 11, Python 3.13, no GPU.

| Tool | Time | Output size | Lines | Status |
|---|---|---|---|---|
| markitdown | **9s** | 11KB | 260 | ⚠️ Prose broken into nonsensical tables |
| pymupdf4llm | **88s** | 15KB | 183 | ✅ Best balance of speed and quality |
| marker | **~50 min** | 8.5KB | 170 | ✅ Cleanest text, impractical without GPU |
| docling | — | — | — | ❌ Failed (Unicode path issue) |

### Findings

- **pymupdf4llm wins for daily use on CPU.** Good reading order, correct headings, preserved lists, and it extracts text from embedded images — something the others miss.
- **markitdown is fast but unreliable.** It fragments paragraph text into broken table cells on visual-heavy documents. Fine for simple text PDFs, unusable for brochures or catalogs.
- **marker produces the cleanest output** but took ~50 minutes on CPU. Only viable with a dedicated GPU.
- **docling fails on Windows paths with accented characters** (e.g. `Padrón` → `Padr¾n`). A known encoding issue in its internal path resolution.

### Post-processing impact

The included cleanup script reduces pymupdf4llm output by **47.5%** (15KB → 8KB) by removing image placeholders, deduplicating repeated blocks (disclaimers, footers), and stripping page numbers — without losing any meaningful content.

## What's in this repo

| File | Purpose |
|---|---|
| `benchmark-pdf-to-md.ps1` | Benchmark script — runs all tools and compares results |
| `pdf2md.py` | Daily-use converter with automatic cleanup |
| `convert-pdf.bat` | Drag-and-drop wrapper — drop a PDF on it, get a clean `.md` |

## Requirements

- Windows 10/11
- Python 3.10+
- PowerShell 5.1+

## Setup

### For daily use (recommended)

```powershell
pip install pymupdf4llm
```

Put `pdf2md.py` and `convert-pdf.bat` in the same folder. Drag any PDF onto the `.bat` file — the `.md` appears next to the original PDF.

Or from the command line:

```powershell
python pdf2md.py input.pdf                 # output next to PDF
python pdf2md.py input.pdf output.md       # explicit output path
python pdf2md.py input.pdf --no-cleanup    # skip post-processing
```

### For benchmarking

```powershell
# Core tools
pip install pymupdf4llm "markitdown[pdf]"

# Marker (optional, ~6GB total with PyTorch + models)
pip install marker-pdf

# Docling (optional, ~2GB)
pip install docling
```

```powershell
.\benchmark-pdf-to-md.ps1 -PdfPath ".\your-file.pdf"
```

Results go to `benchmark-results\<filename>\` with one `.md` per tool, a `summary.csv`, and error logs.

## Evaluation criteria

The script gives you speed and size. Quality you evaluate manually:

1. **Reading order** — Does text flow correctly, or do columns get mixed?
2. **Tables** — Are they preserved as Markdown tables or broken into loose text?
3. **Headings** — Are titles detected with correct hierarchy (h1, h2, h3)?
4. **Artifacts** — Repeated headers/footers, broken characters, junk text?
5. **Token efficiency** — Bloated output = wasted tokens with no added value.

These dimensions are adapted from [Nutrient's benchmark](https://github.com/PSPDFKit/pdf-to-markdown), which uses NID (reading order), TEDS (table structure), and MHS (heading hierarchy) against 200 hand-annotated documents.

### Quick comparison in VS Code

```powershell
code --diff ".\benchmark-results\<name>\pymupdf4llm.md" ".\benchmark-results\<name>\marker.md"
```

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
