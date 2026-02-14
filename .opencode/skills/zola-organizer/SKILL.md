---
name: zola-organizer
description: Use this to create new documentation categories (sections) or nested sub-categories.
---
## Rules
1. Every new folder created in `docs/content/` MUST contain an `_index.md` file.
2. If a user asks to "group" items, create a subdirectory and move relevant `.md` files into it.
3. When moving files, update internal links using the `@/` prefix to reflect the new path.
4. The `_index.md` in new folders must include at least:
   +++
   title = "Section Name"
   render = true
   insert_anchor_links = "left"
   +++
