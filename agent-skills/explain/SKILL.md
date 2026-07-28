---
name: explain
description: Explain a response, concept, decision, or process in plain language as progressive causal bullets. Use when the user invokes `/explain`, asks to make an explanation simpler, wants a clearer breakdown, or needs to understand how one step leads to the next.
---

# Explain

Turn an opaque or dense explanation into a short causal story that is easy to follow.

## Identify the target

- If the user supplies a body after `/explain`, explain that body.
- If the user invokes `/explain` without a body, infer the target from the most recent relevant assistant response or conversation topic.
- Prefer the specific claim, process, or conclusion that appears hardest to understand. If multiple targets are equally plausible and choosing one would materially change the explanation, ask one concise question.

## Write the explanation

- Lead with the conclusion or the first event in simple language.
- Use progressive bullets: one causal step per bullet, in order.
- Connect steps explicitly: “When X happens, Y happens. That causes Z.”
- Put conditions and exceptions directly after the step they alter: “Unless …, in which case … instead.”
- Define unfamiliar terms at first use or replace them with ordinary words.
- Preserve the important reasoning and tradeoffs; simplify wording, not substance.
- Keep each bullet focused. Add nested bullets only for a genuine branch or exception.
- End with a one-sentence takeaway when it helps anchor the story.

## Shape

Use this pattern when it fits:

> **In short:** [plain-language conclusion]
>
> - First, [starting condition or event].
> - That means [immediate effect].
> - Because of that, [next consequence].
> - Unless [exception], in which case [alternate outcome].
> - So, [practical takeaway].

Do not add ceremonial headings, excessive disclaimers, or a separate “simple version” that repeats the bullets. Answer directly.
