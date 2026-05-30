# Life Quest Watch — Product Requirements Document

**Version:** 1.0  
**Date:** 2026-05-29  
**Platform:** watchOS + iOS (companion app)

---

## 1. Overview

Life Quest Watch is a routine-tracking app that brings the Life Quest daily habit system to Apple Watch. Users manage their recurring routines on iPhone and execute them on Apple Watch throughout the day. The app focuses on frictionless task completion with minimal interaction on the wrist.

---

## 2. Platforms

| Component | Platform | Role |
|---|---|---|
| Watch App | watchOS | Primary execution interface — view and complete tasks |
| Companion App | iOS | Data management — create, edit, and delete routines |

---

## 3. Core Concepts

### 3.1 Routine

A **Routine** is a recurring task with the following attributes:

| Field | Type | Description |
|---|---|---|
| `name` | String | Display name of the routine |
| `subtasks` | List\<String\> | Ordered list of sub-steps |
| `scheduledTime` | Time | The time the routine is due (HH:mm) |
| `location` | LocationRef | Optional reference to a location from the location library |
| `recurrence` | Enum | See §3.2 |
| `completionStatus` | Boolean | Whether completed today (resets at 4:00 AM) |

### 3.2 Recurrence Types

| Type | Description | Example |
|---|---|---|
| Daily | Every day | Morning stretches |
| Weekly | Specific day(s) of the week | Monday + Thursday workout |
| Biweekly | Specific day(s) every two weeks; cycle anchored to the **task creation date** | Deep cleaning |
| Monthly | Specific date(s) of the month | Budget review on the 1st |

### 3.3 Task Ordering

Today's routines are sorted as follows:

1. Routines **with** a `scheduledTime`, sorted ascending (earliest first)
2. Routines **without** a `scheduledTime`, sorted by creation date ascending (appended at the bottom)

### 3.4 Sequential Blocking Model

Routines execute in a strict sequential order — a routine does not become "active" until the previous one is completed, regardless of clock time.

- Notifications for a routine are **not** triggered at its `scheduledTime` if the previous routine is still incomplete.
- The notification fires only when the previous routine is marked complete (i.e. when the current routine becomes active), even if that moment is hours past the scheduled time.
- The repeat reminder interval then starts from that activation moment.

---

## 4. Daily Reset

- The reset check runs **on app launch**: if the current time is past 4:00 AM and the last reset date is before today, all completion statuses are cleared.
- No reliance on background timers or scheduled tasks for the reset.
- No historical completion data is stored or displayed.

---

## 5. Watch App

### 5.1 Task List View (Default Screen)

- Displays all routines due **today**, sorted by `scheduledTime` ascending (earliest first).
- Each row shows:
  - Routine name
  - Scheduled time
  - Completion indicator
- Completed routines sink to the bottom of the list; incomplete routines remain at the top.

### 5.2 Active Task View

When a routine is focused (current or tapped):

- **Top area:** Location name on the first line (if set), scheduled time on the second line; if no location is set, show time only
- **Below:** Routine name
- **Below:** Current active subtask name
- On subtask completion (tap/swipe): automatically advances to the next subtask.
- When all subtasks are complete: the routine is marked complete and the view automatically advances to the next incomplete routine.
- If a routine has no subtasks: completing it directly marks it done and advances to the next.

### 5.3 Completing a Task

- User **long-presses** to mark the current subtask complete.
- When the **last subtask** is completed (or a no-subtask routine is completed):
  - Trigger **fireworks animation** on screen.
  - Mark routine as complete.
  - Auto-advance to next incomplete routine.
- When **all routines for the day are complete**:
  - Display a **celebration screen** (e.g. full-screen fireworks or congratulatory message).
  - No further navigation.

### 5.4 Navigation

- Scroll through routines via Digital Crown.
- Tap a routine row to jump directly into its Active Task View.

---

## 6. iPhone Companion App

### 6.1 Routine List

- Displays all configured routines.
- Shows today's completion status (synced from Watch).

### 6.2 Location Library

A dedicated section in the iPhone app for managing reusable locations.

- **Add location:** Enter a name (e.g. "Home", "Gym", "Office")
- **Edit / Delete** existing locations
- Deleting a location that is referenced by existing routines sets those routines' location to empty

### 6.3 Routine Editor

Create or edit a routine with the following fields:

- Name (required)
- Subtasks (ordered list; add/remove/reorder)
- Scheduled time (time picker)
- Location (optional — select from the location library)
- Recurrence type (Daily / Weekly / Biweekly / Monthly)
  - Weekly: select day(s) of the week
  - Biweekly: select day(s) + which week cycle
  - Monthly: select date(s)

### 6.3 Delete Routine

- Swipe-to-delete with confirmation dialog.

---

## 7. Data Sync

- Sync mechanism: **WatchConnectivity** framework (WCSession).
- **Routine definitions** (created/edited on iPhone) are pushed to Watch.
- **Completion status** is bidirectionally synced between iPhone and Watch in real time.
- Sync should occur:
  - When the app becomes active on either device.
  - Immediately upon any status change.

---

## 8. Notifications & Repeat Reminders

### 8.1 Initial Notification

A routine's notification fires only when **both** conditions are met:

1. The previous routine is complete
2. The routine's `scheduledTime` has been reached

This means:
- If the previous routine finishes **after** the scheduled time → notify immediately upon completion
- If the previous routine finishes **before** the scheduled time → wait until the scheduled time, then notify
- Routines without a `scheduledTime` → notify immediately when the previous routine completes

Notification content: routine name + first incomplete subtask (if any). Tapping the notification opens the app directly to that routine's Active Task View.

### 8.2 Repeat Reminders
- If a routine remains incomplete after its `scheduledTime`, the Watch continues to send **repeat haptic reminders** at a configurable interval.
- **Default interval:** 5 minutes.
- **Configurable:** User can adjust the interval per-routine or globally in the iPhone companion app (e.g. 1 / 3 / 5 / 10 / 15 minutes).
- Repeat reminders stop as soon as the routine is marked complete.
- Repeat reminders also stop at the 4:00 AM daily reset.

### 8.3 Implementation Notes
- At any given time, only **one** repeat reminder request is active — the current incomplete routine. When a routine is completed, its repeat request is cancelled before the next routine's reminder is scheduled.
- Cancellation must be triggered either by the user tapping "Mark Done" directly from the notification banner, or by the app becoming active. A "Mark Done" notification action is recommended to handle the case where the app is not in the foreground.
- All notifications are scheduled locally on-device; no server required.
- Notifications are rescheduled automatically after the 4:00 AM daily reset.

---

## 9. Watch Face Complication

- **Type:** Supports at minimum the Graphic Circular and Modular Small complication slots.
- **Display:** Today's completion progress, e.g. `5 / 8` or a progress ring.
- Updates in real time as tasks are completed.
- Tapping the complication launches the Watch app.

---

## 10. Animations & Feedback

| Trigger | Feedback |
|---|---|
| Subtask completed | Light haptic tap |
| Routine completed | Fireworks animation on screen + strong haptic |
| Auto-advance to next routine | Subtle slide transition |

---

## 11. Data Storage

- Routine definitions stored locally on iPhone (e.g. Core Data or JSON in App Group container).
- Shared App Group container used for Watch + Complication access.
- No cloud sync or account required in v1.
- No historical data retained — only current-day completion state is kept in memory/storage.

---

## 12. Out of Scope (v1)

- User accounts / cloud backup
- XP, leveling, or gamification beyond fireworks
- Stats, streaks, or history tracking
- Siri integration
- Android / other platforms

---

## 13. Resolved Design Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Conflicting completion states (offline edits)? | Last-write-wins based on update timestamp |
| 2 | Biweekly recurrence anchor date? | Anchored to task creation date |
| 3 | Daily reset trigger mechanism? | On app launch: check if current time is past 4:00 AM and last reset was before today |
| 4 | Completion gesture on Watch? | Long-press |
| 5 | All tasks completed state? | Full-screen celebration screen |
| 6 | Routines without a scheduled time? | Sorted by creation date, appended after all timed routines; subject to the same sequential blocking model |
