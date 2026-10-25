# Writing and unslop guidelines

Editorial guide for removing AI writing patterns from site copy. When writing or editing documentation, scan for the patterns below and rewrite them. Maintain technical precision, active voice, and a utilitarian tone.

## Content

### Rule 3. Superficial -ing phrases
Delete superficial dangling participles such as "highlighting", "ensuring", "reflecting", "showcasing", and "fostering". State the concrete outcome or source instead.
- Poor: "The engine sets heap limits, ensuring stability on 4 GB laptops."
- Clear: "The engine sets heap limits so 4 GB laptops build without memory errors."

### Rule 5. Vague attributions
Avoid unattributed assertions such as "experts believe", "industry standards recommend", or "critics argue". Name the tool, specification, or source directly, or state the technical requirement plainly.
- Poor: "Experts recommend avoiding global environment overrides."
- Clear: "Session-scoped variables prevent conflicting toolchain paths across Windows terminal sessions."

## Language

### Rule 7. Banned AI vocabulary
Replace inflated AI buzzwords with everyday technical terms.
- Avoid: additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape, pivotal, showcase, tapestry, testament, underscore, vibrant.
- Use plain replacements: also, necessary, examine, long-term, improve, building, gain, interaction, complex, environment, key, display, record, proof, highlight, active.

### Rule 8. Fancy ways to say "is"
Avoid inflated verbs like "serves as", "stands as", "boasts", or "features". Use "is" or "has".
- Poor: "build.bat serves as the main entry point."
- Clear: "build.bat is the primary entry point."

### Rule 9. "Not just X, but Y"
Avoid rhetorical contrast formulas. State the capability directly.
- Poor: "Not just a compiler, but an autonomous build pipeline."
- Clear: "The engine inspects dependencies, configures the environment, and compiles the project."

### Rule 10. Natural counts over the rule of three
Do not force items or arguments into triads. Present the actual number of factors that exist.

### Rule 11. Consistent terminology
Avoid cycling through multiple synonyms for the same concept within a section. Pick the accurate technical term and stick with it.
- Poor: Switching between "module", "subproject", "component", and "target" in consecutive sentences.
- Clear: Use "module" consistently when describing Gradle submodules.

### Rule 12. Meaningful scales over false ranges
Avoid arbitrary spans framed as "from X to Y" when the boundaries do not form a scalar continuum.
- Poor: "Handles everything from memory profiling to license acceptance."
- Clear: "Profiles available memory and accepts SDK licenses non-interactively."

## Style

### Rule 13. Dash and parenthesis policy
Avoid em dashes and en dashes entirely. Use periods or commas to separate clauses. Do not use parentheses in prose copy; weave supplementary details directly into the sentence structure.
- Poor: "The engine writes sdk.dir (using forward slashes) -- preserving other lines."
- Clear: "The engine writes sdk.dir using forward slashes and preserves all other lines."

### Rule 14. Mid-sentence colon restrictions
Use colons only before a code block, numbered list, or bulleted breakdown. Do not use colons as connectors between mid-sentence clauses.
- Poor: "Memory is tight: low-memory flags apply."
- Clear: "When memory is tight, apply the low-memory profile."

### Rule 15. Restrained boldface
Limit bold text to key UI buttons, keyboard shortcuts, or genuine definitions. Avoid bolding acronyms, proper nouns, or standard flags throughout body copy.

### Rule 16. Prose over redundant inline-header lists
Do not prefix list items with bold labels that merely repeat the sentence. A bold lead-in that ends in a period, names the item, and introduces new detail is acceptable.
- Poor: "- **Verification:** Verifies signatures across schemes."
- Clear: "- **Signature verification.** Evaluates v1, v2, v3, and v4 schemes using apksigner."

### Rule 17. Sentence case headings
Format page titles, section headers, and subheaders in sentence case. Capitalize only the initial word and proper nouns such as Android, Gradle, PowerShell, Windows, Java, or SDK.
- Poor: "## How To Use Release Signing"
- Clear: "## How to use release signing"

### Rule 18. No decorative emojis
Do not insert emojis into documentation, headings, lists, or tables.

### Rule 19. Straight quotes only
Use straight single and double quotation marks. Do not use curly quotation marks.

## Communication artifacts

### Rule 20. Chatbot phrasing removal
Eliminate conversational conversationalisms such as "I hope this helps", "Let me know if you need anything else", "Of course", or "Certainly".

### Rule 22. Direct tone over flattery
State instructions and system facts directly. Do not flatter the reader or validate questions.

## Filler

### Rule 23. Concise phrasing
Replace verbose transitions with single words.
- "In order to" becomes "To".
- "Due to the fact that" becomes "Because".
- Delete phrases like "It is important to note that".

### Rule 24. Elimination of hedging
Cut speculative qualifiers such as "could potentially possibly be argued that it might". Use "may" or state the exact behavior.

### Rule 25. Concrete facts over generic conclusions
Do not conclude sections with platitudes like "The future looks bright" or "Building Android apps has never been easier". Close with concrete reference commands, issue links, or next steps.

## Jargon

### Rule 26. Concrete technical nouns over metaphors
Replace abstract metaphors with concrete software mechanisms.
- Avoid: substrate, wedge, vector, locus, vantage, nexus, primitive, harness, scaffolding, modality, paradigm, gold-plating, ratchet, evacuate, endgame, north star, flywheel.
- Use concrete terms: base, approach, mechanism, toolchain, framework, workflow, method.

## Plain speech

### Rule 27. Mechanisms over emotional descriptions
State what the tool executes, not how it feels.
- Poor: "Effortlessly puts Gradle right at your fingertips."
- Clear: "Executes gradlew.bat with session-scoped environment variables."

### Rule 28. Single-idea sentences
Break dense compound sentences with multiple subordinate clauses into shorter, distinct sentences. One idea per sentence.

### Rule 29. Active voice preference
Name the actor directly rather than using passive constructions.
- Poor: "Artifacts are harvested by the script into the output folder."
- Clear: "The engine copies artifacts into the output directory."

### Rule 30. Verbs over propped adverbs
Delete weak adverbs like "quickly", "simply", "easily", or "seamlessly". Use a specific verb or name the measured metric.
- Poor: "Builds easily and runs quickly."
- Clear: "Compiles without IDE overhead and completes in under two minutes."

### Rule 31. Plain terminology
Prefer simple words over pretentious synonyms.
- Use "use" instead of "utilize" or "leverage".
- Use "help" instead of "facilitate".
- Use "many" instead of "numerous".
- Use "if" instead of "in the event that".

### Rule 32. Literal phrasing over rhetorical mannerisms
Avoid stylistic aphorisms, personified code, and figurative verbs.
- Poor: "The wizard holds your hand through the build."
- Clear: "The wizard prompts for your project folder and build variant."

### Rule 33. Whole sentences over compressed symbol-speak
Spell out arrows, symbols, and dropped articles. Write complete sentences with their subjects, verbs, and objects intact.
- Poor: "Parser error -> code 2, exit"
- Clear: "When the parser encounters an invalid version format, it reports code 2 and exits."
