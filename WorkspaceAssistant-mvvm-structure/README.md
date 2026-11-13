<p align="center">
  <img src="WorkspaceAssistant/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="WorkspaceAssistant app icon">
</p>

# WorkspaceAssistant Full

A task list for iPhone with a built-in AI assistant that runs **entirely on device**, using Apple's
[Foundation Models](https://developer.apple.com/documentation/foundationmodels) framework (Apple Intelligence).

Manage tasks by tapping, swiping and dragging, or type something like *"prioritise the network refactor and switch
to Focus"* and watch the assistant do it for you. Everything the assistant does can be undone.

> **This is the complete version.** For a 10-file teaching version with a step-by-step tutorial, see
> **[WorkspaceAssistant-Lite](https://github.com/firasqais/WorkspaceAssistant-Lite)**.

---

## What you'll learn from this project

| Topic | Where to look |
|---|---|
| SwiftUI app structure, `TabView`, sheets, navigation | `WorkspaceAssistantApp.swift`, `Views/Root/` |
| MVVM with Observation (`@Observable`) | `ViewModels/`, `Domain/Store/WorkspaceStore.swift` |
| SwiftData for saving data | `Domain/Services/Persistence/` |
| Foundation Models: sessions, streaming, **tool calling** | `Domain/Services/Assistant/` |
| Undo and redo with `UndoManager` | `Domain/Store/WorkspaceStore.swift` |
| A small design system of reusable components | `Views/Shared/` |
| Accessibility: VoiceOver, Dynamic Type, contrast | Throughout; see `docs/accessibility.md` |
| Unit tests with Swift Testing, UI tests with XCTest | `WorkspaceAssistantTests/`, `WorkspaceAssistantUITests/` |

---

## Requirements

| | Minimum | Notes |
|---|---|---|
| **Mac** | Apple silicon | |
| **Xcode** | 27 or later | The project was created with Xcode 27 |
| **iOS** | 26.0 or later | iPhone only |
| **Swift** | 6 | Builds with strict concurrency and no warnings |
| **Apple Intelligence** | Optional | Needed for the real assistant: a supported iPhone (15 Pro or later), or a simulator on a Mac with Apple Intelligence turned on |
| **Apple developer account** | Free or paid | Needed to run on a physical iPhone |

No API keys, network calls or third-party packages.

**No Apple Intelligence? No problem.** On a simulator or an iPhone without Apple Intelligence, the app automatically
uses a **Simulated assistant**: a rule-based stand-in that understands short requests like the suggestion tiles. It is
clearly labelled in the app, and it uses the same toolbox as the real assistant, so it changes the board in exactly the
same way.

---

## Getting started

1. Clone the repository and open `WorkspaceAssistant.xcodeproj`.
2. Select the **WorkspaceAssistant** target › **Signing & Capabilities**, and choose **your own Team**. Do the same
   for the two test targets. If the bundle identifier is taken, change `au.edu.uts.WorkspaceAssistant` to something unique.
3. Choose an iPhone simulator (for example *iPhone 17*) or your iPhone, and press **⌘R**.
4. To run all tests, press **⌘U**.

### Try these

- Tap a tile to open a task. Tap **+** to add one. Press and hold a tile for more actions.
- Use the view button (top right) to switch between **Grid**, **List**, **Focus** and **Board**.
- Tap **Ask Assistant…** and try *"Add a priority task for code review"* or *"Show my tasks as a Board"*.
- Shake the device, or press **⌘Z** in the simulator, to **undo**, even something the assistant did.

---

## Step-by-step tutorial

The `Tutorial` folder walks through building this app's core path: **8 tutorials, 71 steps**, with code that updates
as you scroll, app previews, diagrams, quizzes and a project download, in the style of Apple's SwiftUI tutorials.

| How | Use it |
|---|---|
| `Tutorial/WorkspaceAssistant Full Tutorial.html` | Double-click to open in any browser. Works offline and prints to PDF |
| `Tutorial/Preview Tutorial.command` | Double-click to serve the DocC tutorial from your Mac |
| `Tutorial/Export Tutorial.command` | Double-click to make a `.doccarchive` that opens in Xcode |
| `Tutorial/WorkspaceAssistantFull.docc` | The DocC source |

| Chapter | Tutorial | Builds |
|---|---|---|
| The Domain | Modelling the Workspace | `TaskItem`, `WorkspaceCommand`, `CommandResult` |
| The Domain | The Store and Undo | `WorkspaceStore` in five stages, `TaskMatcher`, the storage protocols |
| The Domain | Saving with SwiftData | `TaskRecord`, `SwiftDataTaskRepository`, preferences, `AppDependencies` |
| The Interface | View Models and the Board | `BoardViewModel`, the board on screen |
| The Assistant | Tools and the Toolbox | `WorkspaceToolbox`, the nine tools |
| The Assistant | The Assistant Engine | `FoundationModelsEngine`, the scripted and automatic engines |
| The Assistant | The Assistant Panel | `AssistantViewModel`, the transcript, wiring the assistant in |
| The Assistant | Testing Without a Model | Store, toolbox and view-model tests |

The design system, board layouts and assistant views are added as ready-made folders from the project download. The
last step of every file the tutorial builds matches the code in this repository exactly.

The app screens in the tutorial are drawn mockups. To use real screenshots, take them in the simulator (**⌘S**) and save
them over the `wf-preview-*.png` files in `Tutorial/WorkspaceAssistantFull.docc/Resources/Images`, then regenerate the HTML.

---

## The big idea

The whole app is built around one rule:

> **Every change goes through one place, as a command.**

Whether you tap ★ or the AI decides to prioritise a task, the same thing happens:

```
   You tap ★                     AI calls a tool
       │                               │
       ▼                               ▼
  BoardViewModel.togglePriority SetTaskPriorityTool.call
       │                               │
       └──────────────┬────────────────┘
                      ▼
     WorkspaceCommand.setPriority(ids:, .high)
                      ▼
           WorkspaceStore.perform(...)
          ┌───────────┼─────────────────┐
          ▼           ▼                 ▼
     update tasks   save to disk   register undo
                      ▼
           SwiftUI views refresh automatically
```

Why this matters:

- **Undo works for everything**, including AI changes, because each command knows how to reverse itself.
- **The AI can't do anything you can't do**: it only has access to the same commands.
- **It's easy to test**: every behaviour is a command you can run in a unit test.
- **Adding a feature** means adding a command case, handling it in the store, and optionally adding a tool for the AI.

Read these two files side by side; they are the heart of the app:
[`WorkspaceCommand.swift`](WorkspaceAssistant/Domain/Models/WorkspaceCommand.swift), the list of every possible change,
and [`WorkspaceStore.swift`](WorkspaceAssistant/Domain/Store/WorkspaceStore.swift), which applies commands, saves and
registers undo.

---

## How the AI part works

When you type *"prioritise the network refactor"*:

1. **`AssistantViewModel`** sends the text to the engine.
2. **`FoundationModelsEngine`** passes it to a long-lived `LanguageModelSession` created with the app's tools. Keeping
   one session means the model **remembers the conversation**, so follow-ups like "now undo that" make sense.
3. The model decides to call **`setTaskPriority`** with `query: "network refactor", priority: high`.
4. The tool asks **`WorkspaceToolbox`** to find the task (`TaskMatcher` turns "network refactor" into
   "Refactor Network Layer") and performs a `WorkspaceCommand`.
5. The tool returns a **truthful** sentence, such as *"Marked 'Refactor Network Layer' as high priority."* If nothing
   matched, or several tasks did, it says so, and the model is instructed never to claim success a tool didn't report.
6. The reply streams into the chat word by word. The tool call appears as an **action block**, and the changed tile
   pulses on the board.

### The nine tools

| Tool | Does |
|---|---|
| `findTasks` | Looks up tasks by title before acting |
| `addTask` | Creates a task with a category and priority |
| `setTaskPriority` | Prioritises or deprioritises a task |
| `completeTask` | Marks a task as done |
| `deleteTask` | Deletes a task, only when clearly asked; undoable |
| `switchLayout` | Grid, List, Focus or Board |
| `setAccentColor` | Changes the app's accent colour |
| `setTaskColor` | Changes one tile's colour |
| `addStep` | Adds a checklist step to a task |

Tool arguments are `@Generable` enums wherever possible, so the model can only choose valid values:

```swift
@Generable
enum PriorityArgument: String { case normal, high }

struct SetTaskPriorityTool: Tool {
    let name = "setTaskPriority"
    let description = "Sets a task's priority to high (prioritise) or normal (deprioritise)."

    @Generable
    struct Arguments {
        @Guide(description: "The task's title or words from it")
        var query: String
        var priority: PriorityArgument
    }

    func call(arguments: Arguments) async throws -> String {
        // Hop to the main actor, perform a WorkspaceCommand, return what really happened.
    }
}
```

| File | What it shows |
|---|---|
| `Domain/Services/Assistant/Tools/WorkspaceTools.swift` | All nine tools as thin adapters |
| `Domain/Services/Assistant/Toolbox/WorkspaceToolbox.swift` | The logic behind the tools, with honest results |
| `Domain/Services/Assistant/FoundationModels/FoundationModelsEngine.swift` | Session, streaming, cancelling, context-window recovery |
| `Domain/Services/Assistant/FoundationModels/AssistantInstructions.swift` | The system instructions (short and specific works best) |
| `Domain/Services/Assistant/FoundationModels/AssistantErrorMapping.swift` | Turning model errors into user-facing messages |
| `Domain/Services/Assistant/Scripted/ScriptedEngine.swift` | The simulated assistant, using the *same* toolbox |
| `Domain/Services/Assistant/AutomaticAssistantEngine.swift` | Picks the real or simulated engine, re-checking on every prompt |

Both engines follow the same `AssistantEngine` protocol (`Domain/Store/AssistantEngine.swift`), so the UI doesn't care
which one it's talking to.

---

## Project map

The app follows **MVVM** (Model–View–ViewModel), with three top-level folders:

```
WorkspaceAssistant/
  WorkspaceAssistantApp.swift   Start here: the @main app
  AppDependencies.swift         Creates the store, services and view models, and wires them together
  LaunchConfiguration.swift     Test/debug launch switches

  Domain/                       The "Model" in MVVM — plain Swift, no UI code
    Models/                     Data types: TaskItem, WorkspaceCommand, ToolActivity…
    Store/                      WorkspaceStore (the single source of truth), task matching, protocols
    Services/
      Persistence/              Saving tasks with SwiftData; preferences with UserDefaults
      Assistant/                The AI: Foundation Models engine, tools, simulated assistant

  ViewModels/                   Screen state and actions, used by the views
    BoardViewModel.swift        Board: selection, sorting, task actions
    AssistantViewModel.swift    Assistant chat: messages, sending, cancelling
    AppRouter.swift             Which tab / sheet is showing
    Board/  Assistant/  Settings/   Small helper types for each view model

  Views/                        SwiftUI views, one folder per page
    Root/                       Tab bar and keyboard shortcuts
    Board/                      The task board, its 4 layouts and tile cells
    TaskDetail/                 Task editor and new-task sheet
    Collections/  Search/  Assistant/  Settings/
    Shared/                     Reusable components, styles (colours, spacing), previews

  Resources/                    App icon, colours, and all text (Localizable.xcstrings)
WorkspaceAssistantTests/        Unit tests — Domain, Services, ViewModels, Views
WorkspaceAssistantUITests/      UI tests, including automated accessibility audits
docs/                           Accessibility report and app icon files
scripts/                        Helper scripts (sync strings, render the icon)
```

**How the layers talk:** Views read from and call their **ViewModel**; ViewModels issue `WorkspaceCommand`s to the
**store** in `Domain/`; the store saves through a **service**. Only `Domain/Services/Assistant/` imports
FoundationModels and only `Domain/Services/Persistence/` imports SwiftData, so each part is easy to test and swap.

---

## Build your own version, step by step

You don't need to build everything at once. Each step gives you a working app.

**Step 1 — A plain task list (SwiftUI basics)**
- Make a `struct TaskItem: Identifiable` with a `title` and `isDone`.
- Show an array of them in a `List`; add a text field and a button to add tasks.

**Step 2 — One source of truth (Observation)**
- Move the array into an `@Observable` class (your "store") and inject it with `.environment(...)`.
- Views read from the store; buttons call methods on it.

**Step 3 — Commands and undo**
- Create an `enum Command { case add(String), toggle(UUID), delete(UUID) }`.
- Give the store one `perform(_:)` method that switches over the command.
- Before applying a command, work out its *inverse* and register it with `UndoManager`
  (get it from `@Environment(\.undoManager)`). Now shake-to-undo just works.

**Step 4 — Save data (SwiftData)**
- Create a `@Model` class for storage and save after each command. Load on launch.
- Tip: keep your `TaskItem` struct for the UI and convert to/from the `@Model` — see `Domain/Services/Persistence/TaskRecord.swift`.

**Step 5 — Make it look good**
- Build a reusable `TaskTile` view. Use only Dynamic Type text styles (`.headline`, `.caption`…).
- Use a `LazyVGrid` with `GridItem(.adaptive(minimum: 160))` for a Shortcuts-style grid.

**Step 6 — Add the AI**
- Check `SystemLanguageModel.default.availability` first and show a message if it's unavailable.
- Write one tool (e.g. `addTask`) with a `@Generable` `Arguments` struct. Inside `call`, perform your command.
- Create `LanguageModelSession(tools: [AddTaskTool(...)], instructions: "...")` **once** and reuse it.
- Call `session.respond(to:)` first; switch to `streamResponse(to:)` once it works.

**Step 7 — Make the AI trustworthy**
- Return what actually happened from each tool, including "no match" and "already done".
- Show each tool call in the chat so the user can see exactly what changed.

**Step 8 — Test it**
- Write Swift Testing tests for each command and its undo (see `WorkspaceAssistantTests/Domain/`).
- Test your tools by calling `tool.call(arguments:)` directly — no model needed.

---

## Ideas to extend it

- **Due dates**: add `dueDate: Date?` to `TaskItem`, a new command, a date picker in the editor, and a tool argument.
- **An undo tool**: let the assistant undo its last change through the store's `UndoManager`.
- **App Intents**: expose "Add task" to Siri and the Shortcuts app by reusing `WorkspaceCommand`.
- **A widget** showing priority tasks.
- **More languages**: add a translation to `Resources/Localizable.xcstrings`.

---

## Testing and quality

- **⌘U** runs everything: about 100 unit tests plus UI tests.
- UI tests launch the app with `-UITestScriptedAssistant` so they're repeatable (in-memory data, simulated assistant).
- `AccessibilityAuditTests` runs Xcode's built-in accessibility audit on each main screen.
- The code builds with **Swift 6 strict concurrency** and no warnings.

### Useful scripts
- `scripts/sync-strings.sh` — updates the String Catalog after a command-line build (Xcode does this automatically).
- `swift scripts/render-app-icon.swift <out.png> 1` — redraws the app icon (see `docs/app-icon/`).

### Command-line build (optional)
```bash
xcodebuild -project WorkspaceAssistant.xcodeproj -scheme WorkspaceAssistant -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## Troubleshooting

| What you see | What to do |
|---|---|
| A *Simulated assistant* banner | Apple Intelligence isn't available. Turn it on in *Settings › Apple Intelligence & Siri*, use a supported device, or wait for the model to download |
| The assistant asks which task you mean | Your words matched more than one task; reply with more of the title |
| *Signing requires a development team* | Choose your Team for the app and both test targets |
| The project won't open | Use Xcode 27 or later |

## Privacy

Everything runs on the device. Requests, replies and tasks never leave the iPhone; tasks are stored locally with SwiftData.
