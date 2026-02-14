---
name: zola-frontmatter
description: Use this skill to validate or fix TOML frontmatter (+++) in Zola markdown files.
---
## Instructions
1. Check if the file starts and ends the header with +++.
2. Ensure 'title' and 'weight' are present.
3. Ensure that within the same  directory there are no duplicated weights
4. If 'taxonomies' are missing, suggest adding categories: ["uncategorized"].
