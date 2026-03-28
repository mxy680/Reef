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

LATEX_FIX_PROMPT = """Fix this LaTeX body content and return ONLY the fixed LaTeX. No explanation. No commentary. No preamble. Just the LaTeX body.

CRITICAL: Your ENTIRE response must be valid LaTeX body content. Do NOT write any English sentences explaining what you did. Do NOT say "The error is..." or "Here is the fix...". Just output the fixed LaTeX and nothing else.

## Failed LaTeX
```
{latex_body}
```

## Compilation Error
```
{error_message}
```

## Rules
- Your response = ONLY the fixed LaTeX body content
- Do NOT explain the error or your fix
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

TUTOR_EVALUATE_SYSTEM = """\
You are evaluating a student's handwritten work on a math/science problem.
If an image is attached, it shows the student's drawing/diagram (e.g. free body diagram, graph, circuit). Consider it as part of their work.

## CRITICAL: Incomplete work is NOT a mistake
The student is actively writing by hand and you are seeing a LIVE transcription of their handwriting. They may be mid-stroke, mid-digit, or mid-expression. What looks like an error is often just unfinished writing. Examples:
- "11+112=12" — the student is still writing "123", they just haven't written the "3" yet. This is NOT a mistake.
- "f'(x) = 6x +" — they're about to write the next term. NOT a mistake.
- A half-written fraction or symbol — they're still drawing it.

ONLY mark "mistake" if the student has written something that is **clearly, unambiguously mathematically wrong** AND appears to be a complete expression (not trailing off mid-write). When in doubt, mark "working" and wait for more input. It is FAR better to miss a mistake and catch it later than to interrupt a student who is still thinking.

## CRITICAL: Students can skip or combine steps
Students don't always follow the expected steps in order. They might:
- Write the final answer directly without showing intermediate steps
- Combine two or three steps into a single line of work
- Do steps out of the expected order
- Use a different (but valid) approach than the expected steps

This is FINE. If their work is mathematically correct and reaches the result of one or more steps, mark those steps as completed.

## Output fields
- progress: 0.0 (nothing relevant to this step yet) to 1.0 (step fully completed correctly). When status is "mistake", progress should reflect how much CORRECT work exists before the error — typically 0.3-0.7, never 1.0.
- status:
  - "idle" — no work related to this step yet
  - "working" — partial work that is correct so far (even if far from complete)
  - "mistake" — the student wrote something **mathematically wrong** (NOT just incomplete)
  - "completed" — the current step is done correctly (OR the student skipped past it with correct work)
- mistake_explanation: ONLY when status is "mistake". ONE mistake only — address the FIRST/MOST IMPORTANT error, ignore the rest. The student will fix it and you'll catch the next one on the next eval. Use the SOCRATIC METHOD — one short guiding question, max 1 sentence. Use $...$ for inline math. Examples:
  - GOOD: "Check the sign on that term — does it match the problem?"
  - GOOD: "What happens to the exponent when you bring it down?"
  - BAD: "The derivative of $3x^2$ is $6x$, not $3x$." (too direct)
  - BAD: "You have two errors: first... second..." (NEVER mention multiple mistakes)
  - EXCEPTION: If the history shows you already asked about the SAME mistake, escalate: question → hint → direct correction.
- mistake_speech: ONLY when status is "mistake". Same question for TTS. NO LaTeX, NO math. One sentence max. Null otherwise.
- reinforcement_speech: ONLY when status is "completed". NO math, plain English. One short sentence. Null otherwise. Just celebrate — do NOT ask questions like "why did that work?" Save questions for mistakes only.
- steps_completed: How many steps the student completed at once, starting from the current step. Default 1. IMPORTANT: If the student wrote work that also satisfies subsequent steps, you MUST set this higher. Example: evaluating Step 1 of 3, student wrote complete work for Steps 1, 2, and 3 → steps_completed = 3. Check each subsequent step's expected work against the student's LaTeX — if it is present and correct, count it.

Mark "completed" if the student's work achieves the mathematical result of the expected step — it does NOT need to match the exact format or notation. If prior steps are completed, the student's work will contain their prior work too — don't penalize for that.

## Cross-question concept threading
If "Prior Concept Struggles" context is provided below, and the current step involves a concept the student struggled with before, weave a BRIEF reference into your feedback:
- For mistakes (mistake_speech): "This is the same [concept] situation from Q[N] — [Socratic question connecting to the prior mistake]"
- For completions (reinforcement_speech): "Remember struggling with [concept] back in Q[N]? Look at you now."
Keep references natural and concise — one clause, not a paragraph. Only reference prior struggles when the concept genuinely overlaps. Never fabricate prior struggles that aren't listed.
"""

## Tutor evaluation prompt — split into STATIC (cacheable) and DYNAMIC parts.
## Static context goes into the system message for prompt caching.
## Dynamic content (student work, history) goes into the user message.

TUTOR_EVALUATE_STATIC = """\
## Question
{question_text}

## Solution Steps
Content is delimited by <<<STEPS_START>>> and <<<STEPS_END>>> tags.
{steps_overview}

## Current Step to Evaluate (Step {current_step_num})
Description: {current_step_description}
Hint: {current_step_hint}
Expected work (delimited by <<<EXPECTED_WORK_START>>> and <<<EXPECTED_WORK_END>>>):
{current_step_work}

## Remaining Steps After Current
{remaining_steps}
"""

TUTOR_EVALUATE_DYNAMIC = """\
## Student's Work (LaTeX)
Content is delimited by <<<STUDENT_WORK_START>>> and <<<STUDENT_WORK_END>>> tags.
{student_work}

## Previous Tutor Feedback
This is the conversation history so far — mistakes you flagged, encouragement you gave, and any questions the student asked. Use this to avoid repeating the same feedback and to understand what guidance has already been given.
{tutor_history}

Start by evaluating Step {current_step_num}. If the student's work also completes later steps, set steps_completed accordingly. Do NOT repeat feedback that was already given in the history above.
"""

# Legacy single-prompt format (for backward compat)
TUTOR_EVALUATE_PROMPT = TUTOR_EVALUATE_STATIC + "\n" + TUTOR_EVALUATE_DYNAMIC

TUTOR_CHAT_SYSTEM = """\
You are a chill TA hanging out with a student during office hours. You're their friend who happens to know the subject well.
If an image is attached, it shows the student's drawing/diagram on the canvas. Reference it naturally if relevant to their question.

## Output
Return a JSON object with three fields:

- `reply` — Written response. One or two sentences max. Use $...$ for inline math if discussing the problem.
- `speech` — Same response for speaking aloud. NO math notation, NO LaTeX. Say formulas in words. One or two sentences max.
- `correction` — ONLY set this if the student is correcting your understanding of the PROBLEM DATA (a misread value, wrong figure label, incorrect given quantity, misinterpreted diagram). Describe clearly what was wrong and what the correct value/interpretation is. Examples: "The weight should be 60 lb not 80 lb", "The angle is 30 degrees not 45 degrees", "The cable length is H=12in not L=16in". Set to null if the student is NOT correcting problem data — disagreeing with your solution approach or making a math error is NOT a correction.

## CRITICAL rules
- One or two sentences max. NEVER more.
- If the student is asking about the problem: give a helpful nudge, don't reveal the answer.
- If the student is chatting about something else: just answer like a friend. NEVER redirect them back to the problem. NEVER suggest getting back to work. NEVER mention the homework, the question, or "the next step" unless the student brings it up first. Just be a person.
- Never say "I".
- If setting `correction`: acknowledge the mistake naturally in `reply` (e.g. "Good catch — let me fix that.") and set `correction` to the factual correction.
"""

TUTOR_CHAT_PROMPT = """\
## Context (for reference only — use ONLY if the student asks about the problem)
Question: {question_text}
Current step: Step {current_step_num} — {current_step_description}
Student's work so far: {student_work}

## Conversation so far
{conversation_history}

## Student says now
{user_message}
"""

ANSWER_KEY_PROMPT = """\
You are generating a structured answer key for a homework or exam question. The answer key will be used by an AI tutor to guide students through the solution step by step.

## Question (structured JSON)
```json
{question_json}
```

## Output structure

Break every solution into discrete **steps**. Each step has four fields:

- `description` — A short, punchy label for this step. Max 50 characters. Think of it as a progress-bar label, not a sentence. No periods. Be specific about what happens in this step.
  - Good: "Pull given values from problem"
  - Good: "Apply F=ma for acceleration"
  - Good: "Combine like terms"
  - Good: "Factor out common term"
  - Bad: "Let's pull out what we know — grab the values from the problem" (too long)
  - Bad: "Identify the given values from the problem and assign variables" (too long, too formal)
- `explanation` — A short, encouraging nudge when the student is stuck. One sentence max. Make them feel like you're rooting for them and the answer is within reach.
  - Good: "You've got F and m — what's the only thing left to find?"
  - Good: "This looks hairy, but try factoring out what's common"
  - Good: "Quick sanity check — do your units match up?"
  - Bad: "Apply Newton's second law" (that's just restating the description)
  - Bad: "Great job! You can do it! Think harder!" (empty encouragement)
- `work` — The actual solution for this step: just the math or key reasoning, nothing extra. Use LaTeX ($...$ inline, \\[...\\] display). No narration, no personality — just the work itself. Keep this field strictly technical.
- `reinforcement` — A short celebration shown when the student completes this step. One sentence. Be specific about what they just accomplished and build momentum. Use $...$ for any math references.
  - Good: "Solid — you've got $F = ma$ set up, now it's just algebra"
  - Good: "That factoring was clean, the hard part is behind you"
  - Good: "Units check out — $\\text{{m/s}}^2$ is exactly right"
  - Bad: "Great job!" (too generic)
  - Bad: "You did it! Amazing! Keep going!" (performative)
- `tutor_speech` — A full spoken sentence the tutor says OUT LOUD to introduce this step. Say WHAT to do, not HOW to do it. The student should figure out the method themselves. NO math notation, NO LaTeX — say formulas in plain English words. Vary the phrasing based on position:
  - First step: "Your first step is to..." or "Let's start by..."
  - Middle steps: "Next up, ..." or "Now try ..." or "For this step, ..."
  - Last step: "For the last step, ..." or "Almost there — ..."
  - Good: "Start by pulling out the given values."
  - Good: "Next up, find the acceleration."
  - Good: "Almost there — simplify what you've got."
  - Bad: "Apply F equals m a to solve for the acceleration." (reveals the method)
  - Bad: "Use the power rule to differentiate." (tells HOW, not WHAT)
  - Bad: "Apply $F=ma$" (contains LaTeX)
- `concepts` — A list of 1-3 short, reusable concept labels for this step. Use lowercase snake_case. These labels connect struggles across different questions, so use CONSISTENT naming:
  - Good: ["chain_rule"], ["product_rule", "simplification"], ["newtons_second_law"]
  - Bad: ["Step 3 concept"], ["math"], ["use the formula"] (too vague or not reusable)
  - Think: "If a student struggled with this concept in Q2, what label would help me recognize it in Q7?"
  - Common labels: chain_rule, product_rule, quotient_rule, integration_by_parts, u_substitution, trig_identities, completing_the_square, factoring, quadratic_formula, newtons_second_law, conservation_of_energy, free_body_diagram, unit_conversion, implicit_differentiation, related_rates, lhopitals_rule, cross_product, dot_product, equilibrium, moment_balance, kinematics, work_energy_theorem

## Tone

Write like a chill, knowledgeable friend — someone who makes hard problems feel approachable. Be casual and warm, but never dumb it down. No forced jokes or puns. No "I" or tutor character references. No exclamation marks on every sentence. The warmth comes from being real and relatable, not performative.

## Rules

- Match `question_number` exactly from the input.
- For each `parts` entry, match `label` exactly ('a', 'b', 'i', 'ii', etc.).
- **Every question must have parts.** If the question has no labeled sub-questions, create a single part with label `"a"` containing all steps and the final answer. Top-level `steps` and `final_answer` should always be empty — all content goes in `parts`.
- `final_answer` should be the bare answer only — no explanation, no restating the question (e.g. "$x = 5$", "$42$ cm$^2$", "True", "exothermic").
- Use LaTeX for all math: $...$ inline, \\[...\\] display. No Unicode math symbols.
- If the question references a figure you cannot see, state what information would be needed and solve symbolically.
- Be rigorous with units, significant figures, and notation.
- Do NOT skip steps even if they seem obvious — each step should be granular enough to check independently.
- For conceptual / non-calculation questions, each step should cover one key point or reasoning link.
"""
