import re


def reduced_motion_contract_errors(css: str) -> list[str]:
    source = re.sub(r"/\*[\s\S]*?\*/", "", css)
    media = re.search(
        r"@media\s*\(\s*prefers-reduced-motion\s*:\s*reduce\s*\)\s*\{",
        source,
        re.IGNORECASE,
    )
    if not media:
        return ["missing prefers-reduced-motion: reduce media query"]

    depth = 1
    end = media.end()
    while end < len(source) and depth:
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
        end += 1
    if depth:
        return ["unterminated prefers-reduced-motion media query"]

    body = source[media.end():end - 1]
    errors = []
    declarations = {
        name.lower(): value.strip().lower()
        for name, value in re.findall(r"([\w-]+)\s*:\s*([^;{}]+)", body)
    }
    if not re.search(r"scroll-behavior\s*:\s*auto\s*!important\b", body, re.IGNORECASE):
        errors.append("reduced-motion rule must disable smooth scrolling")
    for property_name in ("animation-duration", "transition-duration"):
        value = declarations.get(property_name, "")
        match = re.fullmatch(r"(0(?:\.0+)?|\.0*1)\s*(ms|s)\s*!important", value)
        if not match or (match.group(2) == "s" and float(match.group(1)) > 0):
            errors.append(f"reduced-motion rule must minimize {property_name} with !important")
    return errors
