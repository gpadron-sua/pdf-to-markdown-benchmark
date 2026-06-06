"""
pdf2md.py — Convert PDF to clean Markdown.

Engines:
    pymupdf4llm (default) — fast, rule-based, no GPU needed
    docling               — ML-based, better tables, heavier

Usage:
    python pdf2md.py input.pdf                        # pymupdf4llm, output next to PDF
    python pdf2md.py input.pdf output.md              # explicit output path
    python pdf2md.py input.pdf --engine docling        # use docling for tables
    python pdf2md.py input.pdf --no-cleanup            # skip post-processing
"""

import sys
import re
import os


# ============================================================
# Engines
# ============================================================

def convert_pymupdf(pdf_path: str) -> str:
    import pymupdf4llm
    return pymupdf4llm.to_markdown(pdf_path)


def convert_docling(pdf_path: str) -> str:
    from docling.document_converter import DocumentConverter
    converter = DocumentConverter()
    result = converter.convert(pdf_path)
    return result.document.export_to_markdown()


ENGINES = {
    "pymupdf4llm": convert_pymupdf,
    "docling": convert_docling,
}


# ============================================================
# Cleanup
# ============================================================

def cleanup_pymupdf(md: str) -> str:
    """Post-process pymupdf4llm output."""
    lines = md.split("\n")
    cleaned = []
    seen_lines = set()
    prev_blank = False

    for line in lines:
        stripped = line.strip()

        # Remove image omission markers
        if re.match(r"\*\*==> picture \[\d+ x \d+\] intentionally omitted <==\*\*", stripped):
            continue

        # Convert picture text blocks to cleaner format
        if stripped == "**----- Start of picture text -----**<br>":
            continue
        if stripped == "**----- End of picture text -----**<br>":
            continue

        # Clean <br> tags from picture text content
        if "<br>" in line:
            parts = line.replace("**----- Start of picture text -----**", "")
            parts = parts.replace("**----- End of picture text -----**", "")
            sub_lines = [p.strip() for p in parts.split("<br>") if p.strip()]
            for sub in sub_lines:
                cleaned.append(sub)
            continue

        # Remove standalone page numbers
        if re.match(r"^\d{1,3}$", stripped):
            continue

        # Deduplicate repeated blocks (disclaimers, etc.)
        if len(stripped) > 80:
            if stripped in seen_lines:
                continue
            seen_lines.add(stripped)

        # Collapse multiple blank lines
        if stripped == "":
            if prev_blank:
                continue
            prev_blank = True
        else:
            prev_blank = False

        cleaned.append(line)

    return "\n".join(cleaned).strip() + "\n"


def cleanup_docling(md: str) -> str:
    """Post-process docling output."""
    lines = md.split("\n")
    cleaned = []
    seen_lines = set()
    prev_blank = False

    for line in lines:
        stripped = line.strip()

        # Remove image comment markers
        if stripped == "<!-- image -->":
            continue

        # Remove standalone page numbers
        if re.match(r"^\d{1,3}$", stripped):
            continue

        # Deduplicate repeated blocks (disclaimers, etc.)
        if len(stripped) > 80:
            if stripped in seen_lines:
                continue
            seen_lines.add(stripped)

        # Collapse multiple blank lines
        if stripped == "":
            if prev_blank:
                continue
            prev_blank = True
        else:
            prev_blank = False

        cleaned.append(line)

    return "\n".join(cleaned).strip() + "\n"


CLEANUPS = {
    "pymupdf4llm": cleanup_pymupdf,
    "docling": cleanup_docling,
}


# ============================================================
# Main
# ============================================================

def main():
    if len(sys.argv) < 2:
        print("Uso: python pdf2md.py <archivo.pdf> [salida.md] [--engine pymupdf4llm|docling] [--no-cleanup]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    no_cleanup = "--no-cleanup" in sys.argv

    # Parse engine flag
    engine_name = "pymupdf4llm"
    if "--engine" in sys.argv:
        idx = sys.argv.index("--engine")
        if idx + 1 < len(sys.argv):
            engine_name = sys.argv[idx + 1]

    if engine_name not in ENGINES:
        print(f"Error: engine '{engine_name}' no reconocido. Opciones: {', '.join(ENGINES.keys())}")
        sys.exit(1)

    # Determine output path
    args_without_flags = []
    skip_next = False
    for a in sys.argv[1:]:
        if skip_next:
            skip_next = False
            continue
        if a == "--engine":
            skip_next = True
            continue
        if a.startswith("--"):
            continue
        args_without_flags.append(a)

    if len(args_without_flags) >= 2:
        output_path = args_without_flags[1]
    else:
        output_path = os.path.splitext(pdf_path)[0] + ".md"

    if not os.path.isfile(pdf_path):
        print(f"Error: no se encontró '{pdf_path}'")
        sys.exit(1)

    print(f"Convirtiendo: {pdf_path}")
    print(f"Engine: {engine_name}")

    raw_md = ENGINES[engine_name](pdf_path)

    if no_cleanup:
        final_md = raw_md
        print("Limpieza: omitida (--no-cleanup)")
    else:
        cleanup_fn = CLEANUPS[engine_name]
        final_md = cleanup_fn(raw_md)
        raw_len = len(raw_md)
        clean_len = len(final_md)
        reduction = (1 - clean_len / raw_len) * 100 if raw_len > 0 else 0
        print(f"Limpieza: {raw_len:,} → {clean_len:,} chars ({reduction:.1f}% reducción)")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(final_md)

    print(f"Guardado: {output_path}")


if __name__ == "__main__":
    main()
