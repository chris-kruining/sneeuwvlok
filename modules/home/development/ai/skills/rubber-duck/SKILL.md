---
name: rubber-duck
description: Use another model to ask for feedback.
license: MIT
metadata:
  author: chris
  version: "1.0"
  generatedBy: "1.4.1"
---

Gather feedback on the current topic using a different model.

This is an **agent-driven** operation - you will ask a different model for feedback and improvements on the current topic.

**Input**: Optionally specify which model to use. If omitted, check if it can be inferred from conversation context, otherwise omit it entirely. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no model name is provided, prompt for selection**

   Infer this from context, if ambiguous or unclear omit the model parameter for the next steps

2. **Form a prompt**

   Create a prompt which communicates relevant contextual information and asks for feedback

3. **Gather the feedback**

   Run:
   ```bash
   copilot -p "<prompt>" --model "<model>"
   ```

   NOTE: omit `--model "<model>"` if there isn't one known

4. **Show summary**

   Format the feedback into a number list. Then give a verdict on the feedback and advice in the next step to take
