"""
pdf2md.py — Convert PDF to clean Markdown using pymupdf4llm.

Usage:
    python pdf2md.py input.pdf                  # output next to PDF
    python pdf2md.py input.pdf output.md        # explicit output path
    python pdf2md.py input.pdf --no-cleanup     # skip post-processing
"""

import sys
import re
import os

def convert_pdf(pdf_path: str) -> str:
    """Convert PDF to raw markdown using pymupdf4llm."""
    import pymupdf4llm
    return pymupdf4llm.to_markdown(pdf_path)


def cleanup_markdown(md: str) -> str:
    """Post-process pymupdf4llm output for cleaner LLM consumption."""

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
            # These are picture text lines — split into separate lines
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

    result = "\n".join(cleaned).strip() + "\n"
    return result


def main():
    if len(sys.argv) < 2:
        print("Uso: python pdf2md.py <archivo.pdf> [salida.md] [--no-cleanup]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    no_cleanup = "--no-cleanup" in sys.argv

    # Determine output path
    args_without_flags = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args_without_flags) >= 2:
        output_path = args_without_flags[1]
    else:
        output_path = os.path.splitext(pdf_path)[0] + ".md"

    if not os.path.isfile(pdf_path):
        print(f"Error: no se encontró '{pdf_path}'")
        sys.exit(1)

    print(f"Convirtiendo: {pdf_path}")
    raw_md = convert_pdf(pdf_path)

    if no_cleanup:
        final_md = raw_md
        print("Limpieza: omitida (--no-cleanup)")
    else:
        final_md = cleanup_markdown(raw_md)
        raw_len = len(raw_md)
        clean_len = len(final_md)
        reduction = (1 - clean_len / raw_len) * 100 if raw_len > 0 else 0
        print(f"Limpieza: {raw_len:,} → {clean_len:,} chars ({reduction:.1f}% reducción)")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(final_md)

    print(f"Guardado: {output_path}")


if __name__ == "__main__":
    main()
