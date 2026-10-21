## 2025-02-18 - Add tooltips to icon-only buttons
**Learning:** Icon-only buttons lacking tooltips are a common accessibility issue across this app, particularly in settings and course edit pages. Users relying on screen readers or mouse hover need text alternatives to understand actions like edit and delete.
**Action:** Always verify if `IconButton` widgets have a `tooltip` property defined, especially when they only contain an icon.
