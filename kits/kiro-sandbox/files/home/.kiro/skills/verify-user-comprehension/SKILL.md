---
name: verify-user-comprehension
description: Use when file changes need user comprehension verification after agent edits, observed diffs, unstaged changes, or specified commits before new implementation.
---

# Verify User Comprehension

## Overview

After files have changed, verify that the user understands the specific technical consequences of the change before moving on.

This is a hard gate. New feature requests, bug fixes, refactors, or implementation commands must wait until the user gives technically sound answers.

## When to Use

- Immediately after any file modification tool is called.
- After applying patches, editing files, generating code, updating configs, or accepting subagent changes.
- When the user asks to verify comprehension for changes that already exist, even if this agent did not make them in the current conversation.
- When the relevant change is available through a working tree diff, unstaged changes, staged changes, a file-specific diff, or a specified commit hash/range.
- Before starting any unrelated follow-up implementation work.

Do not use this for read-only exploration, planning-only turns, commands that only produce build artifacts or caches, or unrelated dirty worktree changes that the user has not asked to discuss.

## Workflow

1. Privately inspect the relevant diff. Use the freshest available source: the files just changed, `git diff`, `git diff --staged`, a file-specific diff, or the user-provided commit hash/range.
2. Identify the modified logic, state or data flow, public interfaces, and architectural side effects.
3. Formulate exactly two rigorous technical questions about the change.
4. Ask the questions in a bold, interactive format.
5. Wait for the user's answers before accepting any new implementation request.
6. Evaluate whether the answers show real comprehension.

## Question Requirements

Questions must be specific to the actual diff. Good questions ask about:

- Variable scope, lifetime, ownership, or mutation boundaries.
- Memory, performance, concurrency, or caching impacts.
- Data flow through modified functions, components, APIs, or schemas.
- Error handling, fallback behavior, or edge cases introduced by the change.
- Architectural side effects across modules, callers, or persisted data.

Avoid generic prompts such as:

- "Do you understand?"
- "Does this make sense?"
- "Any questions?"
- "Are you okay with these changes?"

## Required Format

Use this format and do not combine it with unrelated next steps:

```md
**Comprehension check before we continue:**

**1. [Technical question tied to the diff]**

**2. [Technical question tied to the diff]**
```

## Evaluating Answers

An answer is technically sound when it:

- Accurately describes the changed behavior.
- References at least one concrete implementation detail from the change.
- Explains a consequence, tradeoff, or failure mode without simply repeating the question.

An answer is not sufficient when it:

- Only says "yes", "looks good", or "I understand".
- Gives a vague restatement with no technical detail.
- Redirects to a new request without addressing the questions.
- Misstates the changed behavior or its side effects.

## If the User Does Not Pass

If the answer is incomplete or incorrect:

1. Briefly explain the missing or incorrect concept.
2. Ask a sharper follow-up question about that same concept.
3. Continue blocking new implementation work until the answer is technically sound.

If the user asks for new work before passing the check, say:

```md
I need to finish the comprehension check for the last change before taking on new implementation work. Please answer the two technical questions above.
```
