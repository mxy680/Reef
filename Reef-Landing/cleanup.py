#!/usr/bin/env python3
"""
One-shot script to clean up the SingleFile HTML capture of studyreef.com.

Reads index.html.bak (the raw SingleFile output) and produces index.html:
  1. Removes Framer meta tags, iframe, hydration data, CSP
  2. Removes SingleFile artifacts (comment, sf-hidden styles/classes)
  3. Injects FAQ answer text (accordion was captured collapsed)
  4. Adds vanilla JS for expand/collapse accordion behavior
"""

import re
from bs4 import BeautifulSoup, Comment

FAQ_ANSWERS = [
    "Yes. You can try Reef free for 14 days with full access to all features.",
    "Your notes and documents stay on your device and in your private iCloud. We never use your work to train AI models.",
    "Any subject. Reef recognizes math notation, chemistry formulas, physics diagrams, and more.",
    "Rude. But no. ChatGPT waits for you to ask it something. Reef watches you work and jumps in when you're stuck, like a tutor who can read the room. Also, yes, there are fish.",
    "Our lawyers said we can't guarantee that. But your 2am panic sessions will be significantly more productive.",
    "No. It's seen worse. Much worse.",
    "Is having a tutor cheating? Is going to office hours cheating? Exactly.",
    "Yes. Orbital mechanics, propulsion, the whole thing. We weren't kidding about STEM.",
    "Yes. We have that. You're welcome.",
    "Your notes sync to iCloud. Your dog would need your Apple ID.",
    "We're an app, not a necromancer. But we'll do what we can.",
    "It's an app. Yes.",
    "That's also not a question but we're proud of you.",
    "Sure you do.",
    "There are fish. You'll be fine.",
    "We're not asking where you study.",
    "The iPad is water resistant. You'll be fine.",
    "You read this entire FAQ instead of studying. Yes. Immediately.",
]

ACCORDION_JS = """
<script>
(function() {
  var items = document.querySelectorAll('[data-framer-name="Close"]');
  var openItem = null;

  items.forEach(function(item) {
    var wrapper = item.querySelector('[data-framer-name="wrapper"]');
    var answer = item.querySelector('.faq-answer');
    var arrow = item.querySelector('[data-framer-name="arrow"]');
    if (!wrapper || !answer) return;

    wrapper.style.cursor = 'pointer';

    wrapper.addEventListener('click', function() {
      if (openItem && openItem !== item) {
        var prevAnswer = openItem.querySelector('.faq-answer');
        var prevArrow = openItem.querySelector('[data-framer-name="arrow"]');
        if (prevAnswer) prevAnswer.style.display = 'none';
        if (prevArrow) prevArrow.style.transform = 'none';
      }

      var isOpen = answer.style.display !== 'none';
      if (isOpen) {
        answer.style.display = 'none';
        if (arrow) arrow.style.transform = 'none';
        openItem = null;
      } else {
        answer.style.display = 'block';
        if (arrow) arrow.style.transform = 'rotate(180deg)';
        openItem = item;
      }
    });
  });
})();
</script>
"""


def clean_html(input_path, output_path):
    with open(input_path, "r") as f:
        content = f.read()

    # --- Remove SingleFile comment ---
    content = re.sub(
        r"<!--\s*\n?\s*Page saved with SingleFile\s*\n.*?-->",
        "",
        content,
        flags=re.DOTALL,
    )

    soup = BeautifulSoup(content, "html.parser")

    # --- Remove Framer meta tags ---
    for name in [
        "framer-search-index",
        "framer-search-index-fallback",
        "framer-html-plugin",
    ]:
        tag = soup.find("meta", attrs={"name": name})
        if tag:
            tag.decompose()

    # --- Remove Content-Security-Policy meta ---
    csp = soup.find("meta", attrs={"http-equiv": "Content-Security-Policy"})
    if csp:
        csp.decompose()

    # --- Remove Framer iframe ---
    iframe = soup.find("iframe", id="__framer-editorbar")
    if iframe:
        iframe.decompose()

    # --- Remove data-framer-hydrate-v2 attribute ---
    for el in soup.find_all(attrs={"data-framer-hydrate-v2": True}):
        del el["data-framer-hydrate-v2"]

    # --- Remove other Framer data attributes from body/html ---
    for attr in [
        "data-framer-ssr-released-at",
        "data-framer-page-optimized-at",
        "data-framer-generated-page",
    ]:
        for el in soup.find_all(attrs={attr: True}):
            del el[attr]

    # --- Remove sf-hidden style block ---
    for style in soup.find_all("style"):
        if style.string and "sf-hidden" in style.string:
            # Only remove if it's the SingleFile-injected one
            if "sf-hidden{display:none!important}" in style.string.replace(" ", ""):
                style.decompose()

    # --- Remove sf-hidden class from elements ---
    for el in soup.find_all(class_="sf-hidden"):
        classes = el.get("class", [])
        classes = [c for c in classes if c != "sf-hidden"]
        if classes:
            el["class"] = classes
        else:
            del el["class"]

    # --- Inject FAQ answers ---
    faq_items = soup.find_all(attrs={"data-framer-name": "Close"})
    assert len(faq_items) == 18, f"Expected 18 FAQ items, found {len(faq_items)}"

    for i, item in enumerate(faq_items):
        # The outer wrapper is framer-pm3del, inside the FAQ item
        outer_wrapper = item.find(class_="framer-pm3del")
        if not outer_wrapper:
            # Fallback: first direct child div
            outer_wrapper = item.find("div", recursive=False)

        # Create answer div
        answer_div = soup.new_tag(
            "div",
            **{
                "class": "faq-answer",
                "style": (
                    "display:none;"
                    "padding:0 20px 20px 20px;"
                    "font-family:Epilogue,sans-serif;"
                    "font-size:16px;"
                    "line-height:1.6;"
                    "color:#999;"
                    "letter-spacing:0.02em;"
                ),
            },
        )
        answer_div.string = FAQ_ANSWERS[i]

        # Insert answer after the question wrapper (inside outer_wrapper)
        question_wrapper = outer_wrapper.find(
            attrs={"data-framer-name": "wrapper"}
        )
        if question_wrapper:
            question_wrapper.insert_after(answer_div)
        else:
            outer_wrapper.append(answer_div)

    # --- Add accordion script before </body> ---
    script_soup = BeautifulSoup(ACCORDION_JS, "html.parser")
    body = soup.find("body")
    if body:
        body.append(script_soup)
    else:
        # No explicit body tag — append to end
        soup.append(script_soup)

    # --- Write output ---
    output = str(soup)

    # BeautifulSoup may alter the doctype; ensure it's clean
    if not output.startswith("<!DOCTYPE"):
        output = "<!DOCTYPE html>\n" + output

    with open(output_path, "w") as f:
        f.write(output)

    print(f"Wrote {len(output):,} bytes to {output_path}")
    print(f"  (original was {len(content):,} bytes)")


if __name__ == "__main__":
    clean_html("index.html.bak", "index.html")
