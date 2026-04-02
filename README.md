# Enterprise Program Planner

Flutter web project planner with runtime Firebase Authentication and Cloud Firestore setup.

## Startup Firebase Config

If present, the app automatically loads `assets/firebase_credentials.js` on startup and connects to the Firebase project described in that file. If the asset is not bundled, the app falls back to the browser-saved Firebase config or the manual setup screen.

## Features

- Firebase email/password authentication
- Project dashboards with tasks, issues, risks, actions, and decisions
- Project-level phases and gantt timelines
- Overview gantt chart across all visible projects
- CSV import and export for project work items

