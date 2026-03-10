"""Prompt constants for the document reconstruction pipeline."""

GROUP_PROBLEMS_PROMPT = """\
You are analyzing scanned pages of a homework or assignment document.

Each page has been annotated with numbered red bounding boxes (indices 1 through {total_annotations}).
Each bounding box surrounds a detected layout element (text block, title, figure, table, formula, etc.).

Your task: group these annotation indices into logical problem groups. Only include annotations that are part of a specific problem.

Rules:
- Use the visible problem numbers/identifiers in the document for problem_number.
- Only include annotations that belong to a specific numbered problem (question text, sub-parts, figures, formulas, tables, etc.).
- Pay special attention to figures and pictures — always assign them to the problem they illustrate. Figures usually appear directly above or below the problem text they belong to.
- Skip annotations that are general context: page headers, page footers, document titles, course info, general directions/instructions, or any content not tied to a specific problem.
- Not every annotation index needs to appear — omit ones that aren't part of a problem.
- Use a short descriptive label for each group (e.g. "Problem 1", "Problem 2a-2c").
- Order the problems by their appearance in the document.

Return a JSON object matching the provided schema.
"""

EXTRACT_QUESTION_PROMPT = """\
You are extracting structured question data from scanned homework/exam images.
Extract the content exactly as shown — do NOT solve problems, fill in blanks, or interpret the content.

The images have red numbered annotation boxes overlaid — ignore them.

## Structure
- number: The problem number as shown in the document.
- text: The question stem / preamble. For simple questions with no parts, all content goes here.
- figures: List of figure filenames that belong to the stem (from the list below, if any).
- parts: Labeled sub-questions (a, b, c). Parts can nest recursively (a → i, ii, iii).
  - If a question has unlabeled bullet points or numbered sub-items, use sequential letters (a, b, c...) as labels.
  - IMPORTANT: If a part contains multiple questions that each need a separate answer (e.g. Q1, Q2, Q3... or bullet points asking different things), extract each as a nested sub-part — do NOT combine them into a single \\begin{itemize} list. Each question that needs its own answer space must be its own part.

## CRITICAL: All text fields must be valid LaTeX body content

Every `text` field will be compiled by a LaTeX engine. You are responsible for producing text that compiles without errors.

Rules:
- Escape LaTeX special characters in prose: write \\& not &, \\% not %, \\# not #, \\$ not $ (when not math).
- Inline math: $...$ delimiters. Display math: \\[...\\].
- All LaTeX commands (\\Delta, \\sigma, \\rightarrow, \\text{}, \\frac{}{}, etc.) MUST be inside math delimiters.
- Degree symbols: $^\\circ$ (e.g. $100^\\circ$C). Never use raw ° or \\degree.
- Subscripts/superscripts: always in math mode ($H_2O$, $x^2$, $q_{\\text{rxn}}$).
- Bold text: use \\textbf{...}, NOT markdown **bold**.
- Itemized lists: use \\begin{itemize} \\item ... \\end{itemize}.
- Tables: use \\begin{tabular}{...} with proper & column separators and \\\\ row endings.
- NO Unicode symbols — use LaTeX equivalents (\\rightarrow not →, \\neq not ≠, \\leq not ≤, etc.).
- NO markdown syntax whatsoever.
- Combine all text for a section into a single string — do NOT split into separate blocks.

## Figures
- Figures are a list of filenames, NOT inline content.
- Place figure filenames at the level where they appear (question-level or part-level).

## Tables that define sub-questions
When a problem contains a table whose rows correspond to the labeled sub-parts (e.g. a table with rows a, b, c showing function pairs or data), preserve the table as a \\begin{tabular} in the stem text. The parts should then have EMPTY text (just the label and answer space) since the table already presents the content. Do NOT flatten table rows into separate part text fields — this loses the tabular formatting.

## Answer space
Estimate answer_space_cm at the most specific level (deepest part > parent part > question):
- 1.0: multiple choice / true-false / short factual
- 2.0: one-line calculation or brief explanation
- 3.0: standard calculation or paragraph
- 4.0: multi-step derivation or proof
- 6.0: long proof, graph to sketch, or multi-part calculation
"""

LATEX_FIX_PROMPT = """You are a LaTeX expert. The following LaTeX body content failed to compile. Fix it and return ONLY the corrected LaTeX body content — no preamble, no \\documentclass, no \\begin{{document}}.

## Failed LaTeX
```
{latex_body}
```

## Compilation Error
```
{error_message}
```

## Rules
- Return ONLY the fixed LaTeX body content, nothing else
- Do NOT wrap in code fences or markdown
- Do NOT add \\documentclass, \\usepackage, \\begin{{document}}, or \\end{{document}}
- Fix the specific error shown above
- Preserve all content — do not remove or simplify questions
- Keep all math in $...$ or \\[...\\] delimiters
- Available packages: amsmath, amssymb, amsfonts, graphicx, booktabs, array, xcolor, needspace, algorithm, algorithmic, listings, caption, changepage
"""

VISUAL_VERIFY_PROMPT = """\
You are a LaTeX quality assurance expert reviewing a reconstructed homework/exam problem. You are given two images:

1. **ORIGINAL** (first image): A crop from the original scanned document.
2. **RECONSTRUCTION** (second image): The same problem after being extracted and re-typeset in LaTeX.

Your job: make sure the reconstruction looks like something a teacher would be proud to hand out. Compare against the original AND check for formatting artifacts that would look unprofessional.

## Content fidelity (comparing against original):
- **Missing content**: Text, equations, sub-parts, or instructions present in the original but absent in the reconstruction.
- **Truncated content**: Text that stops mid-sentence or a problem that is cut off before the end.
- **Hallucinated content**: Instructions, hints, or text added by the reconstruction that do NOT appear in the original.
- **Merged/split problems**: Two problems fused into one, or one problem incorrectly split into two.
- **Wrong math**: Incorrect symbols, operators, subscripts, superscripts, fractions, or expressions.
- **Missing figures**: Figures or diagrams referenced in the original but not included.
- **Garbled text**: OCR artifacts, wrong words, or nonsensical content.
- **Cross-references**: "See Figure 1", "use your answer from part (a)", etc. must match the original.

## Math-specific errors:
- **Wrong fraction structure**: Inline a/b where the original shows a display \\frac{{a}}{{b}}, or vice versa.
- **Flattened nesting**: Lost subscript/superscript depth, e.g. $e^x2$ instead of $e^{{x^2}}$.
- **Units not upright**: Physical units like kg, m, s, MPa rendering in italics (math mode) instead of upright \\text{{}}.
- **Missing delimiters**: Parentheses, brackets, or absolute value bars dropped from the original.

## Formatting artifacts (look at the reconstruction image):
- **Duplicate labels**: e.g. "a) a)" or "(b) (b)" — a part label appearing twice in a row.
- **Orphaned labels**: A bare label like "(a)" sitting alone on a line with no content after it.
- **Broken enumeration**: Labels out of order (a, c, b), skipped labels (a, c), or inconsistent style (mixing "a)" and "(a)").
- **Inconsistent label style**: Mixing a) and (a) and a. within the same problem — pick one style and be consistent.
- **Raw LaTeX leaking**: Visible backslash commands, unrendered $...$ delimiters, or literal LaTeX syntax showing as text.
- **Unescaped special characters**: Literal %, &, or # causing missing text or compilation artifacts.
- **Excessive whitespace**: Unnecessary page breaks or content pushed to a second page when it should fit on one. NOTE: \\vspace commands for answer space are INTENTIONAL and must be preserved — do NOT remove them.
- **Misaligned tables**: Columns not lining up, missing cell borders that should be there, or headers merged with data.
- **Nested indentation errors**: Sub-parts at the wrong indentation level, or content that should be nested appearing at the top level.
- **Incorrect problem header**: The header should match the original document's numbering (e.g. "Problem 1.3-9" not "Problem 1").

## Homework/exam-specific:
- **Missing fill-in-the-blank lines**: Underlines or blank spaces where students write answers got dropped.
- **Missing answer space**: Original has a blank box, lined area, or vertical space for answers — reconstruction has none.
- **Point values**: If the original shows "(10 pts)" or similar, it must be preserved.

Minor typographic differences (font size, exact spacing, line breaks) are acceptable and should NOT be flagged.

## Current LaTeX body content:
```
{latex_body}
```

## Instructions:
- If the reconstruction is faithful and looks clean, set `needs_fix` to false and leave `fixed_latex` empty.
- If there are issues, set `needs_fix` to true, list the issues, and provide corrected LaTeX in `fixed_latex`.
- The `fixed_latex` must be ONLY the LaTeX body content — no \\documentclass, no \\usepackage, no \\begin{{document}}.
- Preserve all existing formatting that is correct — only fix what is actually wrong.
- IMPORTANT: Preserve all \\vspace commands and \\needspace commands — these provide answer space for students.
- Available packages: amsmath, amssymb, amsfonts, graphicx, booktabs, array, xcolor, needspace, algorithm, algorithmic, listings, caption, changepage.
- Math must use $...$ for inline and \\[...\\] for display mode.
- Do NOT solve problems or fill in blanks — reproduce the original content exactly.
"""

PARSE_MMD_PROMPT = """\
You are parsing Mathpix MMD (Markdown with math) output from a scanned homework or exam document into structured question data.

## Input
You receive the full MMD text from Mathpix OCR. The text contains:
- Inline math delimited by $...$
- Display math delimited by \\[...\\]
- Markdown formatting (**bold**, tables with pipes, etc.)
- Image references like ![](mathpix_filename.jpg) or \\includegraphics{{mathpix_filename.jpg}}

## Task
Detect question boundaries and extract each problem as a structured Question object.

## Detecting Question Boundaries
Look for patterns like:
- "1.", "2.", "3." at the start of a line (numbered problems)
- "Problem 1", "Question 1", "Exercise 1"
- "(1)", "[1]"
- Bold or header-formatted problem numbers

## Structure
- number: Sequential integer starting from 1 (first question = 1, second = 2, etc.). Do NOT parse the document's own numbering scheme — just count questions in order.
- text: The question stem / preamble ONLY — text that comes before any labeled sub-parts. Strip the leading problem number or label (e.g. "1.", "Problem 2", "(3)") from the text — do NOT include it since we add our own header. **Do NOT repeat part text here.** If the question is entirely made up of parts with no preamble, set text to an empty string.
- figures: List of figure filenames that appear near this question in the MMD text.
- parts: Labeled sub-questions (a, b, c). Parts can nest recursively (a -> i, ii, iii). Each part's text should contain ONLY that part's content — never duplicate content between the question stem and its parts.
  - If a question has unlabeled bullet points or numbered sub-items, use sequential letters (a, b, c...) as labels.
  - If a part contains multiple questions that each need a separate answer, extract each as a nested sub-part.

## CRITICAL: Convert MMD to LaTeX body content

Every `text` field will be compiled by a LaTeX engine. Convert MMD syntax to LaTeX:
- **bold** -> \\textbf{{bold}}
- Pipe tables -> \\begin{{tabular}}{{...}} with & separators and \\\\ row endings
- Bullet lists -> \\begin{{itemize}} \\item ... \\end{{itemize}}
- Numbered lists -> \\begin{{enumerate}} \\item ... \\end{{enumerate}}
- Keep $...$ math as-is (already LaTeX)
- Keep \\[...\\] math as-is (already LaTeX)
- Escape LaTeX special characters in prose: \\& not &, \\% not %, \\# not #, \\$ not $ (when not math)
- Degree symbols: $^\\circ$ (e.g. $100^\\circ$C). Never use raw degree sign.
- NO Unicode symbols — use LaTeX equivalents (\\rightarrow not ->, \\neq not !=, etc.)
- NO markdown syntax in output — everything must be valid LaTeX.

## Figures
Image filenames appear inline in the MMD text as ``![](mathpix_xxx.jpg)`` or ``\\includegraphics{{mathpix_xxx.jpg}}``. Place each filename in the ``figures`` array at the question or part level where it appears in the text.
Only use filenames that actually appear in the MMD text. Do NOT invent filenames.

**CRITICAL:** When you encounter an image reference in the MMD text, extract the filename into the ``figures`` array and REMOVE the image reference from the ``text`` field entirely. Do NOT replace image references with placeholder text like "Placeholder for Image", "[Image]", "See figure", or any other substitute. The rendering system will automatically insert the image from the ``figures`` array — your job is only to move the filename there.

## Tables that define sub-questions
When a problem contains a table whose rows correspond to labeled sub-parts, preserve the table as \\begin{{tabular}} in the stem text. The parts should then have empty text (just label and answer space).

## Preamble / Header Content
Skip any content before the first numbered question: course info, student name fields, general instructions, headers, dates. These are NOT questions.

## Answer Space
Estimate answer_space_cm at the most specific level:
- 1.0: multiple choice / true-false / short factual
- 2.0: one-line calculation or brief explanation
- 3.0: standard calculation or paragraph
- 4.0: multi-step derivation or proof
- 6.0: long proof, graph to sketch, or multi-part calculation

Return a QuestionBatch JSON object containing all extracted questions.
"""

TUTOR_EVALUATE_PROMPT = """\
You are evaluating a student's handwritten work on a math/science problem.

Question: {question_text}
Current step: {step_description}
Expected work: {step_work}
Student's work (LaTeX): {student_work}

Evaluate the student's progress on this specific step:
- progress: 0.0 (nothing relevant written yet) to 1.0 (step fully completed correctly)
- status: "idle" (empty or unrelated work), "working" (partial but correct so far), "mistake" (error detected), "completed" (step done correctly)

If the student's work is empty or completely unrelated to the step, return progress 0.0 and status "idle".
Be generous with partial credit — if the student is on the right track, reflect that in progress.
"""

ANSWER_KEY_PROMPT = """\
You are generating a structured answer key for a homework or exam question. The answer key will be used by an AI tutor to guide students through the solution step by step.

## Question (structured JSON)
```json
{question_json}
```

## Output structure

Break every solution into discrete **steps**. Each step has three fields:

- `description` — A clear, descriptive sentence shown to the student explaining what this step does and why (e.g. "Identify the given values from the problem and assign variables", "Apply Newton's second law to relate the net force to acceleration", "Simplify the resulting expression by combining like terms"). Aim for 10-20 words — enough that a student understands the purpose and approach of the step at a glance.
- `explanation` — A short, punchy hint for the student when they're stuck. One sentence max — like a nudge, not a lecture (e.g. "What does F=ma solve for here?", "Try factoring out the common term", "Check your units"). The student is already confused, so keep it dead simple.
- `work` — The actual solution for this step: just the math or key reasoning, nothing extra. Use LaTeX ($...$ inline, \\[...\\] display). No narration or restatement of the description — just the work itself.

## Rules

- Match `question_number` exactly from the input.
- For each `parts` entry, match `label` exactly ('a', 'b', 'i', 'ii', etc.).
- If the question has **no parts**: put steps and final_answer at the top level. Leave `parts` empty.
- If the question has **parts**: put per-part steps in the `parts` array. Top-level `steps` and `final_answer` can be empty.
- `final_answer` should be the bare answer only — no explanation, no restating the question (e.g. "$x = 5$", "$42$ cm$^2$", "True", "exothermic").
- Use LaTeX for all math: $...$ inline, \\[...\\] display. No Unicode math symbols.
- If the question references a figure you cannot see, state what information would be needed and solve symbolically.
- Be rigorous with units, significant figures, and notation.
- Do NOT skip steps even if they seem obvious — each step should be granular enough to check independently.
- For conceptual / non-calculation questions, each step should cover one key point or reasoning link.
"""
