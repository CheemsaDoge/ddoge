## 2025-02-18 - Add tooltips to icon-only buttons
**Learning:** Icon-only buttons lacking tooltips are a common accessibility issue across this app, particularly in settings and course edit pages. Users relying on screen readers or mouse hover need text alternatives to understand actions like edit and delete.
**Action:** Always verify if `IconButton` widgets have a `tooltip` property defined, especially when they only contain an icon.
## 2025-02-18 - Tooltips for icon-only buttons
**Learning:** `IconButton` widgets missing the `tooltip` property are a recurring accessibility issue in this app.
**Action:** When adding or modifying `IconButton` widgets, always ensure a `tooltip` property is defined to provide a text alternative for screen readers and mouse hover.
