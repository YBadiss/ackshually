Upload a PDF, ask a question, and get a guided explanation tied to the original pages. The app zooms to and highlights the evidence while explaining it. The user controls when to continue.

Board-game rules are the starting use case. iOS is preferred, with a web prototype acceptable.

# Core experience

1. Open a PDF and ask a question in ordinary language, including approximate terms or follow-ups.

2. The agent finds the evidence, works out the answer, and creates an ordered explanation.

3. The viewer shows each step with short text and the relevant passages or figures.

4. The user can continue, revisit a step, inspect the full page, or ask another question.

# Agent and viewer

The agent returns the main answer, any assumptions or uncertainty, and ordered steps. Each step includes explanation text, source references, and an area to show.

The viewer applies that plan through page navigation, zoom, and highlights. A step may connect several passages across different pages. The explanation order follows the question.

Document preparation can be reused. Each question gets its own answer and explanation path. The app tracks the current step and conversation.

# Example

In a hypothetical rulebook, unused energy is discarded, but a storage item can retain two energy. A user with three energy asks what happens at turn end.

The app shows the general rule, then the storage exception, then explains that two energy remain and one is discarded. The user advances through the steps.

# Experience principles

- Keep the source and surrounding qualifications easy to inspect.

- Use as many steps as the answer needs.

- Ask for missing information when it changes the answer.

- Identify external sources whenever they are used.

- Keep navigation easy to pause or interrupt.

# Choices still open

Decide the first version’s document scope, initial answer presentation, voice controls, follow-up behavior, web research, saved state, and platform. Possible later features include multiple documents and saved explanations.

# Next step

Test speed, accuracy, highlighting, and how much indexing is needed. [Technical Test Plan](https://chatgpt.com/space/page_14af20c557a08191b5f8ee3b5397d89f)
