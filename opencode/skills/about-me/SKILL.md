---
name: about-me
description: Look up the user's current background (affiliation, research area, publications, projects, teaching) from their live homepage. Use when a task depends on who the user is, e.g. the user mentions "my research/paper/project/advisor/CV", or asks for writing or recommendations that should reflect their background (bio, related work, statements, emails).
---

# About Me

The user's homepage is the source of truth for their background:
https://qsdrqs.github.io/

- Fetch the homepage when this skill is used. Do not rely on memory or a
  copied summary; the page is updated over time.
- For details not on the homepage (full education and experience history),
  read the CV linked from it (`/files/cv.pdf`).
- Use only the parts the task needs.
- If the sources do not answer a question, ask instead of inferring.
