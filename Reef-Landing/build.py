#!/usr/bin/env python3
"""Assembles src/ partials into index.html. Zero external dependencies."""

import os
import sys


SRC = os.path.join(os.path.dirname(__file__) or '.', 'src')


def read(path):
    """Read file content as a string."""
    with open(os.path.join(SRC, path), 'r') as f:
        return f.read()


def build():
    parts = []

    # ── HEAD ──────────────────────────────────────────────────────────────

    # 1. Meta / doctype / OG tags (L1-71)
    parts.append(read('head/meta.html'))

    # 2. Font CSS wrapped in <style data-framer-font-css=""> (L72-444)
    parts.append('    <style data-framer-font-css="">\n')
    parts.append(read('head/fonts.css'))
    parts.append('    </style>\n')

    # 3. Preconnect, robots, canonical, og:url (L445-448)
    parts.append(read('head/connectors.html'))

    # 4. Main Framer CSS wrapped in <style> with attributes (L449-6254)
    attrs = read('head/main-css-attrs.txt')
    parts.append('    <style\n')
    parts.append('      data-framer-css-ssr-minified=""\n')
    parts.append(f'      data-framer-components="{attrs}"\n')
    parts.append('    >\n')
    parts.append(read('head/main.css'))
    parts.append('    </style>\n')

    # 5. headEnd comments + empty <style> (L6255-6258)
    parts.append(read('head/head-end.html'))

    # 6. Editor bar CSS (L6259-6337)
    parts.append('    <style>\n')
    parts.append(read('head/editorbar.css'))
    parts.append('    </style>\n')

    # 7. Editor bar frame CSS (L6338-6371)
    parts.append('    <style>\n')
    parts.append(read('head/editorbar-frame.css'))
    parts.append('    </style>\n')

    # 8. Badge hiding CSS (L6372-6391)
    parts.append('    <style data-export="framer-hide">\n')
    parts.append(read('head/badge-hide.css'))
    parts.append('    </style>\n')

    # 9. Close head (L6392)
    parts.append('  </head>\n')

    # ── BODY ──────────────────────────────────────────────────────────────

    # 10. <body> + analytics script + bodyStart comments (L6393-6403)
    parts.append(read('body/analytics.html'))

    # 11. <div id="main"> + layout wrapper open (L6404-6423)
    parts.append(read('body/main-open.html'))

    # 12. Header/navbar (L6424-6718)
    parts.append(read('body/header.html'))

    # 13. Body bg style + data-framer-root open (L6719-6731)
    parts.append(read('body/content-open.html'))

    # 14. Hero section (L6732-7030)
    parts.append(read('body/hero.html'))

    # 15. Problem section (L7031-7559)
    parts.append(read('body/problem.html'))

    # 16. Benefits section (L7560-8338)
    parts.append(read('body/benefits.html'))

    # 17. Integrations + marquee (L8339-10772)
    parts.append(read('body/integrations.html'))

    # 18. How-it-works connector SVGs + steps (L10773-11180)
    parts.append(read('body/how-it-works.html'))

    # 19. FAQ section (L11181-13145)
    parts.append(read('body/faq.html'))

    # 20. Newsletter section (L13146-13414)
    parts.append(read('body/newsletter.html'))

    # 21. Close data-framer-root wrapper (L13415)
    parts.append(read('body/content-close.html'))

    # 22. Overlay + footer + template-overlay + close #main (L13416-13802)
    parts.append(read('body/footer-wrapper.html'))

    # ── SCRIPTS ───────────────────────────────────────────────────────────

    # 23. Link handler (L13803-13864)
    parts.append('    <script>\n')
    parts.append(read('scripts/link-handler.js'))
    parts.append('    </script>\n')

    # 24. Breakpoint sizes rewriter (L13865-13881)
    parts.append('    <script>\n')
    parts.append(read('scripts/breakpoint-sizes.js'))
    parts.append('    </script>\n')

    # 25. URL param preservation (L13882-13918)
    parts.append('    <script>\n')
    parts.append(read('scripts/param-preserve.js'))
    parts.append('    </script>\n')

    # 26. Empty line between param-preserve and animator (L13919)
    parts.append('\n')

    # 27. Animation runtime IIFE (L13920-14607)
    parts.append('    <script>\n')
    parts.append(read('scripts/animator.js'))
    parts.append('    </script>\n')

    # 28. Appear animation config JSON (L14608-14610)
    parts.append('    <script type="framer/appear" id="__framer__appearAnimationsContent">\n')
    parts.append(read('scripts/appear-config.json'))
    parts.append('    </script>\n')

    # 29. Breakpoint hash map JSON (L14611-14613)
    parts.append('    <script type="framer/appear" id="__framer__breakpoints">\n')
    parts.append(read('scripts/breakpoints.json'))
    parts.append('    </script>\n')

    # 30. Appear animation bootstrap (L14614-14654)
    parts.append('    <script data-framer-appear-animation="no-preference">\n')
    parts.append(read('scripts/appear-init.js'))
    parts.append('    </script>\n')

    # 31. process.env.NODE_ENV setup (L14655-14661)
    parts.append('    <script>\n')
    parts.append(read('scripts/node-env.js'))
    parts.append('    </script>\n')

    # 32. Module preloads + main script (L14662-14693)
    parts.append(read('scripts/modulepreloads.html'))

    # 33. SVG sprite sheet (L14694-16391)
    parts.append(read('svg/sprites.html'))

    # ── TAIL ──────────────────────────────────────────────────────────────

    # 34. bodyEnd comments (first 4 lines of close.html = L16392-16395)
    close = read('tail/close.html')
    close_lines = close.splitlines(keepends=True)
    parts.extend(close_lines[:4])

    # 35. Badge removal script (L16396-16435)
    parts.append('    <script data-export="framer-hide">\n')
    parts.append(read('scripts/badge-remove.js'))
    parts.append('    </script>\n')

    # 36. Closing </body></html> (remaining lines of close.html = L16436-16437)
    parts.extend(close_lines[4:])

    return ''.join(parts)


def main():
    output = build()

    with open('index.html', 'w') as f:
        f.write(output)
    print(f'Built index.html ({len(output)} bytes, {output.count(chr(10))} lines)')

    if '--verify' in sys.argv:
        if not os.path.exists('index.html.orig'):
            print('ERROR: index.html.orig not found. Run extract.py first.')
            sys.exit(1)
        with open('index.html.orig', 'r') as f:
            original = f.read()
        if output == original:
            print('VERIFIED: output matches original byte-for-byte.')
        else:
            # Find first difference
            for i, (a, b) in enumerate(zip(output, original)):
                if a != b:
                    ctx_start = max(0, i - 40)
                    ctx_end = min(len(output), i + 40)
                    line_num = output[:i].count('\n') + 1
                    print(f'MISMATCH at byte {i} (line {line_num}):')
                    print(f'  got:      {repr(output[ctx_start:ctx_end])}')
                    print(f'  expected: {repr(original[ctx_start:ctx_end])}')
                    break
            else:
                if len(output) != len(original):
                    print(f'MISMATCH: output is {len(output)} bytes, original is {len(original)} bytes')
                    shorter = min(len(output), len(original))
                    print(f'  Files match for first {shorter} bytes, then diverge.')
            sys.exit(1)


if __name__ == '__main__':
    main()
