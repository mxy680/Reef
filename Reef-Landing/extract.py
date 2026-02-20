#!/usr/bin/env python3
"""One-time extraction: splits index.html into source partials under src/."""

import os
import re
import shutil


def main():
    with open('index.html', 'r') as f:
        content = f.read()

    # Save original for verification
    shutil.copy2('index.html', 'index.html.orig')

    lines = content.splitlines(keepends=True)
    n = len(lines)
    print(f'Read {n} lines from index.html')
    assert n == 16437, f'Expected 16437 lines, got {n}'

    # --- Helpers ---
    def extract(path, start, end):
        """Write lines[start..end] (1-indexed inclusive) to path."""
        data = lines[start - 1:end]
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.writelines(data)
        print(f'  {path}: L{start}-L{end} ({end - start + 1} lines)')

    def extract_one(path, line_num):
        """Write a single line to path."""
        extract(path, line_num, line_num)

    def line(n):
        """Get line n (1-indexed), stripped of trailing newline."""
        return lines[n - 1].rstrip('\n')

    # --- Boundary assertions ---
    assert '<style data-framer-font-css="">' in line(72)
    assert line(444).strip() == '</style>'
    assert 'preconnect' in line(445)
    assert 'data-framer-css-ssr-minified' in line(449) or 'data-framer-css-ssr-minified' in line(450)
    assert line(6254).strip() == '</style>'
    assert 'headEnd' in line(6255)
    assert line(6259).strip() == '<style>'
    assert line(6337).strip() == '</style>'
    assert line(6338).strip() == '<style>'
    assert line(6371).strip() == '</style>'
    assert 'data-export="framer-hide"' in line(6372)
    assert line(6391).strip() == '</style>'
    assert line(6392).strip() == '</head>'
    assert line(6393).strip() == '<body>'
    assert 'id="main"' in line(6405)
    assert 'id="hero"' in line(6732)
    assert 'id="problem"' in line(7034)
    assert 'id="benefits"' in line(7563)
    assert 'id="integrations"' in line(8342)
    assert 'how-it-work' in line(10776)
    assert 'id="faq"' in line(11181)
    assert 'id="newsletter"' in line(13149)
    assert line(13803).strip() == '<script>'
    assert line(13865).strip() == '<script>'
    assert line(13882).strip() == '<script>'
    assert lines[13918].strip() == ''  # Empty line L13919 (0-indexed: 13918)
    assert line(13920).strip() == '<script>'
    assert 'var animator' in line(13921)
    assert line(14607).strip() == '</script>'
    assert '__framer__appearAnimationsContent' in line(14608)
    assert '__framer__breakpoints' in line(14611)
    assert 'data-framer-appear-animation' in line(14614)
    assert line(14655).strip() == '<script>'
    assert 'NODE_ENV' in line(14659)
    assert '<link' in line(14662)  # start of modulepreloads
    assert 'svg-templates' in line(14695)
    assert 'bodyEnd' in line(16392)
    assert 'data-export="framer-hide"' in line(16396)
    assert line(16435).strip() == '</script>'
    assert '</body>' in line(16436)
    assert '</html>' in line(16437)
    print('All boundary assertions passed.\n')

    # --- HEAD ---
    print('Extracting head partials...')
    extract('src/head/meta.html', 1, 71)
    extract('src/head/fonts.css', 73, 443)
    extract('src/head/connectors.html', 445, 448)
    extract('src/head/main.css', 453, 6253)
    extract('src/head/head-end.html', 6255, 6258)
    extract('src/head/editorbar.css', 6260, 6336)
    extract('src/head/editorbar-frame.css', 6339, 6370)
    extract('src/head/badge-hide.css', 6373, 6390)

    # Extract data-framer-components attribute value
    attr_line = line(451)
    m = re.search(r'data-framer-components="([^"]+)"', attr_line)
    assert m, f'Could not find data-framer-components on line 451'
    attrs = m.group(1)
    with open('src/head/main-css-attrs.txt', 'w') as f:
        f.write(attrs)
    print(f'  src/head/main-css-attrs.txt: attribute value ({len(attrs)} chars)')

    # --- BODY ---
    print('\nExtracting body partials...')
    extract('src/body/analytics.html', 6393, 6403)
    extract('src/body/main-open.html', 6404, 6423)
    extract('src/body/header.html', 6424, 6718)
    extract('src/body/content-open.html', 6719, 6731)
    extract('src/body/hero.html', 6732, 7030)
    extract('src/body/problem.html', 7031, 7559)
    extract('src/body/benefits.html', 7560, 8338)
    extract('src/body/integrations.html', 8339, 10772)
    extract('src/body/how-it-works.html', 10773, 11180)
    extract('src/body/faq.html', 11181, 13145)
    extract('src/body/newsletter.html', 13146, 13414)
    extract('src/body/content-close.html', 13415, 13415)
    extract('src/body/footer-wrapper.html', 13416, 13802)

    # --- SCRIPTS ---
    print('\nExtracting script partials...')
    extract('src/scripts/link-handler.js', 13804, 13863)
    extract('src/scripts/breakpoint-sizes.js', 13866, 13880)
    extract('src/scripts/param-preserve.js', 13883, 13917)
    extract('src/scripts/animator.js', 13921, 14606)
    extract('src/scripts/appear-config.json', 14609, 14609)
    extract('src/scripts/breakpoints.json', 14612, 14612)
    extract('src/scripts/appear-init.js', 14615, 14653)
    extract('src/scripts/node-env.js', 14656, 14660)
    extract('src/scripts/modulepreloads.html', 14662, 14693)
    extract('src/scripts/badge-remove.js', 16397, 16434)

    # --- SVG ---
    print('\nExtracting SVG sprites...')
    extract('src/svg/sprites.html', 14694, 16391)

    # --- TAIL ---
    print('\nExtracting tail...')
    # close.html = bodyEnd comments (L16392-16395) + closing tags (L16436-16437)
    os.makedirs('src/tail', exist_ok=True)
    with open('src/tail/close.html', 'w') as f:
        f.writelines(lines[16391:16395])  # L16392-16395
        f.writelines(lines[16435:16437])  # L16436-16437
    print(f'  src/tail/close.html: L16392-16395 + L16436-16437 (6 lines)')

    # --- Verification ---
    total_lines = (
        71 +        # meta.html
        1 +         # <style data-framer-font-css="">
        371 +       # fonts.css
        1 +         # </style>
        4 +         # connectors.html
        4 +         # <style...> opening tag (L449-452)
        5801 +      # main.css
        1 +         # </style>
        4 +         # head-end.html
        1 +         # <style>
        77 +        # editorbar.css
        1 +         # </style>
        1 +         # <style>
        32 +        # editorbar-frame.css
        1 +         # </style>
        1 +         # <style data-export="framer-hide">
        18 +        # badge-hide.css
        1 +         # </style>
        1 +         # </head>
        11 +        # analytics.html
        20 +        # main-open.html
        295 +       # header.html
        13 +        # content-open.html
        299 +       # hero.html
        529 +       # problem.html
        779 +       # benefits.html
        2434 +      # integrations.html
        408 +       # how-it-works.html
        1965 +      # faq.html
        269 +       # newsletter.html
        1 +         # content-close.html
        387 +       # footer-wrapper.html
        1 +         # <script> link-handler
        60 +        # link-handler.js
        1 +         # </script>
        1 +         # <script> breakpoint-sizes
        15 +        # breakpoint-sizes.js
        1 +         # </script>
        1 +         # <script> param-preserve
        35 +        # param-preserve.js
        1 +         # </script>
        1 +         # empty line
        1 +         # <script> animator
        686 +       # animator.js
        1 +         # </script>
        1 +         # <script type=framer/appear config>
        1 +         # appear-config.json
        1 +         # </script>
        1 +         # <script type=framer/appear breakpoints>
        1 +         # breakpoints.json
        1 +         # </script>
        1 +         # <script appear-init>
        39 +        # appear-init.js
        1 +         # </script>
        1 +         # <script> node-env
        5 +         # node-env.js
        1 +         # </script>
        32 +        # modulepreloads.html
        1698 +      # sprites.html
        4 +         # close.html (bodyEnd part)
        1 +         # <script data-export="framer-hide">
        38 +        # badge-remove.js
        1 +         # </script>
        2           # close.html (closing tags)
    )
    print(f'\nExpected total lines: {total_lines}')
    assert total_lines == 16437, f'Line count mismatch: {total_lines} vs 16437'

    print('\nExtraction complete. Run build.py to reassemble.')


if __name__ == '__main__':
    main()
