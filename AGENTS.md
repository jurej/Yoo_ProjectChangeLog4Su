# Open SketchUp Framework - AI Coding Guidelines
# Framework Version: 0.2.1

When generating SketchUp Ruby plugins, follow these conventions to produce
high-quality, compatible, and reusable extensions designed for Extension Warehouse review.

## File Structure (Extension Warehouse Compatible)

Every plugin must follow this structure:

```
Plugins/
├── AuthorName_PluginName.rb          # Root registration file (metadata only)
└── AuthorName_PluginName/            # Support folder (all logic goes here)
    ├── main.rb                       # Plugin entry point
    ├── open_sketchup_helpers.rb      # Framework helpers (copy from src/)
    ├── open_sketchup_update_checker.rb  # Optional: update notifications (copy from src/)
    └── ... (other files)
```

## Namespace Rules (CRITICAL)

All code MUST be wrapped in the author's unique namespace module. Never define
anything at the global/top level.

```ruby
module AuthorName
  module PluginName
    # ALL plugin code goes inside here
  end
end
```

- Use the developer's company name, full name, or unique identifier as AuthorName
- Never use short initials (too likely to clash)
- Never define global methods, constants, or variables (no `$global_vars`)
- Never monkey-patch Ruby core classes or SketchUp API classes

## Root Registration File Pattern

The root .rb file (in the Plugins/ folder) should ONLY register the extension:

```ruby
# AuthorName_PluginName.rb
require 'sketchup'
require 'extensions'

module AuthorName
  module PluginName
    EXTENSION = SketchupExtension.new(
      "Plugin Display Name",
      File.join("AuthorName_PluginName", "main")
    )
    EXTENSION.version     = "1.0.0"
    EXTENSION.creator     = "Author Name"
    EXTENSION.description = "Brief description of what this plugin does."
    EXTENSION.copyright   = "2026, Author Name"

    Sketchup.register_extension(EXTENSION, true)
  end
end
```

## Main Entry Point Pattern

The main.rb file in the support folder contains the actual logic:

```ruby
# AuthorName_PluginName/main.rb
module AuthorName
  module PluginName
    # Load helpers (namespaced inside this module)
    Sketchup.require(File.join(__dir__, "open_sketchup_helpers"))

    # Plugin implementation goes here...

    # Menu registration (only once)
    unless file_loaded?(__FILE__)
      UI.menu("Extensions").add_item("Plugin Display Name") do
        # ... action ...
      end
      file_loaded(__FILE__)
    end
  end
end
```

## Using Framework Helpers

Include the helpers module inside your namespace (`AuthorName::PluginName::Helpers`). Key utilities:

### Undo Operations (ALWAYS use this for model modifications)
```ruby
Helpers.undo_wrap(model, "Operation Name", disable_ui: true, transparent: false) do
  # All model modifications go here
  # Automatically commits on success, aborts on error, logs backtrace, and alerts user
end
```

### Entity Retrieval
```ruby
faces = Helpers.get_faces(model.active_entities)
edges = Helpers.get_edges(model.active_entities, recursive: true)
groups = Helpers.get_groups(model.active_entities)
components = Helpers.get_components(model.active_entities)
```

### Selection
```ruby
Helpers.selection_set(model, matching_entities)
faces_in_selection = Helpers.selection_filter(model, Sketchup::Face)
```

### Geometry & Bounds
```ruby
center_point = Helpers.bounds_center(entity)
width, height, depth = Helpers.bounds_dimensions(entity)
```

### Units & Conversions
```ruby
inches = Helpers.to_inches(2500) # 2500mm to inches
mm = Helpers.to_mm(inches)
area_text = Helpers.format_area(face.area, unit: :sq_m) # e.g. "12.5 m²"
```

### Input Dialogs
```ruby
results = Helpers.input_dialog(
  title: "My Dialog",
  prompts: ["Width (mm)", "Height (mm)", "Material"],
  defaults: [1000.0, 500.0, "Wood"],
  lists: [nil, nil, "Wood|Steel|Concrete"]
)
return unless results  # User cancelled
width, height, material = results
```

### Material/Color
```ruby
Helpers.apply_color(model, faces, [255, 0, 0])  # RGB array
Helpers.apply_color(model, faces, "Red")         # Color name
```

### Capability Registry (Inter-Plugin Communication)
The optional Open SketchUp Registry extension provides `OpenSketchUp::Registry` for cross-plugin discovery. Generated plugins must never define or reopen `OpenSketchUp`; use the helper adapters only when the separate registry extension is available, and always preserve a local fallback:

```ruby
# Register what your plugin can do without depending on extension load order
def self.register_capabilities
  return true if @capabilities_registered
  return false unless defined?(OpenSketchUp::Registry)

  Helpers.registry_register("select.faces.by_area",
    version: "1.0.0",
    description: "Select faces by area range in sq inches. Args: min_area (Float), max_area (Float)",
    callable: method(:my_method)
  )
  @capabilities_registered = true
end

register_capabilities
UI.start_timer(0, false) { register_capabilities } unless @capabilities_registered

# Discover and use another plugin's capability
if Helpers.registry_available?("select.faces.by_area")
  result = Helpers.registry_call("select.faces.by_area", min_area, max_area)
else
  # Graceful fallback if other plugin is not installed
  result = fallback_method(min_area, max_area)
end
```

### Validation
```ruby
model = Helpers.require_model  # Shows error if no model
return unless model
sel = Helpers.require_selection(model)  # Shows error if nothing selected
return unless sel
```

## Using the Update Checker (Optional)

The optional update checker module (`open_sketchup_update_checker.rb`) lets plugins
check for new versions and notify users via native SketchUp notifications. It does
NOT download or install anything — fully compliant with Extension Warehouse requirements.

Copy the file into your support folder and wrap it in your namespace as `UpdateChecker`,
then call it once from your `main.rb`:

```ruby
# In main.rb, after loading helpers:
Sketchup.require(File.join(__dir__, "open_sketchup_update_checker"))

UpdateChecker.check_for_update(
  extension: EXTENSION,
  current_version: "1.0.0",
  version_url: "https://raw.githubusercontent.com/you/repo/main/version.json",
  download_url: "https://extensions.sketchup.com/extension/YOUR_ID"
)
```

The developer hosts a simple `version.json` file (e.g. on GitHub or any static server):

```json
{
  "version": "1.1.0",
  "download_url": "https://extensions.sketchup.com/extension/YOUR_ID",
  "release_notes": "Fixed crash on large models"
}
```

Only `"version"` is required. The checker:
- Runs asynchronously (does not block SketchUp startup)
- Respects a 24-hour cooldown between checks (configurable)
- Shows a native `UI::Notification` if a newer version exists
- Opens the user's browser to the download URL when they click "Update"
- Requires SketchUp 2017+ (silently skips on older versions)
- Never downloads or installs files (Extension Warehouse compliant)

---

## HTML Dialogs with Modus UI (Optional)

For any dialog needing **more than ~2 fields, validation, or a real layout**, prefer a
`UI::HtmlDialog` styled with **Trimble Modus Web Components** over `UI.inputbox`.
Copy `open_sketchup_html_dialog.rb` into the support folder and wrap it in your
namespace as `HtmlUi`, same as the other framework files.

**Requirements:** SketchUp 2021.1+ (HtmlDialog runs CEF 88 — ES modules and custom
elements). Use `HtmlUi.supported?` and fall back to `Helpers.input_dialog` on older
versions.

**File layout** — HTML assets live in an `html/` subfolder of the support folder:

```
AuthorName_PluginName/
├── main.rb
├── open_sketchup_helpers.rb
├── open_sketchup_html_dialog.rb
└── html/
    ├── dialog.html   # Modus shell: theme bootstrap + pinned jsDelivr tags
    ├── dialog.js     # callRuby() / __rubyReply bridge + form wiring
    ├── dialog.css    # layout only — colors come from Modus tokens
    └── vendor/       # optional offline copies of the CDN assets
```

**Canonical usage:**

```ruby
dialog = HtmlUi.show(html_file: "dialog.html", title: "My Settings",
                     width: 420, height: 480)

HtmlUi.on(dialog, "submit_form") do |ctx|
  values = ctx.payload            # decoded JSON Hash from callRuby()
  # ... do work (undo_wrap for model changes!) ...
  ctx.reply("ok" => true)         # resolves the callRuby Promise in JS
end

HtmlUi.on(dialog, "cancel") { |_ctx| dialog.close }
```

**Conventions:**

- **Pin the Modus version** in the CDN tags (`@trimble-oss/moduswebcomponents@1.19.1`),
  never `@latest`. Keep the JS loader and both CSS files on the same version.
- **Theme bootstrap before the loader** — inline script setting `data-theme`,
  `data-mode`, `class` on `<html>` and seeding `localStorage["modus-theme-config"]`
  as `{ "theme": "modus-modern", "mode": "light|dark" }` (copy it verbatim from
  `templates/modus_plugin/html/dialog.html` or `HtmlUi.theme_bootstrap_script`).
- **Modus 2.x event contract:** every input fires `inputChange`; read text values
  from `e.detail.target.value`, booleans from `e.detail.target.checked`; buttons use
  `buttonClick`. `modus-wc-select` takes an `options` JS property (array of
  `{label, value}`) — never `<option>` children.
- **JS→Ruby payloads are JSON strings** — `callRuby(name, obj)` stringifies; Ruby's
  `ctx.payload` is the decoded Hash. `ctx.reply`/`ctx.reply_error` resolve/reject
  the JS Promise via `__rubyReply(reqId, ok, data)`.
- Wrap all model changes triggered by dialog callbacks in `Helpers.undo_wrap`.
- Do not use navbar/side-navigation components in dialogs — use cards, form
  controls, alerts/toasts. Dialogs are content, not app shells.
- Dev loop: `dialog.html` opens in a normal browser; `window.sketchup` is
  feature-detected so the UI can be built outside SketchUp.
- Offline distribution: vendor the assets per `html/vendor/README.md`.

---

## Standard Capability Taxonomy

When registering capabilities, use hierarchical dot-notation naming:

| Category | Prefix | Examples |
|----------|--------|----------|
| **Selection** | `select.*` | `select.faces.by_area`, `select.edges.by_length`, `select.by_material` |
| **Geometry** | `geom.*` | `geom.align.bottom`, `geom.extrude.faces`, `geom.offset.edges` |
| **Tags / Layers** | `tag.*` | `tag.assign.by_type`, `tag.isolate.selected` |
| **Materials** | `material.*` | `material.apply.by_height`, `material.replace` |
| **Export / Data** | `export.*` | `export.entities.csv`, `export.cutlist` |
| **UI** | `ui.*` | `ui.dialog.form`, `ui.entity_picker` |

---

## Few-Shot Code Examples for AI Prompts

### Example 1: Geometry Manipulation Tool
```ruby
module StudioArch
  module PushPullSelected
    Sketchup.require(File.join(__dir__, "open_sketchup_helpers"))

    def self.extrude_selected_faces(distance_mm)
      model = Helpers.require_model
      return unless model
      selection = Helpers.require_selection(model)
      return unless selection

      faces = Helpers.selection_filter(model, Sketchup::Face)
      if faces.empty?
        UI.messagebox("No faces found in current selection.")
        return
      end

      dist_inches = Helpers.to_inches(distance_mm)

      Helpers.undo_wrap(model, "Extrude Selected Faces") do
        faces.each do |face|
          face.pushpull(dist_inches) if face.valid?
        end
      end
    end

    def self.register_capabilities
      return true if @capabilities_registered
      return false unless defined?(OpenSketchUp::Registry)

      Helpers.registry_register("geom.extrude.faces",
        version: "1.0.0",
        description: "Extrudes faces by distance in mm. Args: distance_mm (Float)",
        callable: method(:extrude_selected_faces)
      )
      @capabilities_registered = true
    end

    register_capabilities
    UI.start_timer(0, false) { register_capabilities } unless @capabilities_registered

    unless file_loaded?(__FILE__)
      UI.menu("Extensions").add_item("Extrude Selected Faces...") do
        res = Helpers.input_dialog(
          title: "Extrude Faces",
          prompts: ["Distance (mm):"],
          defaults: [100.0]
        )
        extrude_selected_faces(res[0].to_f) if res
      end
      file_loaded(__FILE__)
    end
  end
end
```

### Example 2: Parameter Dialog Tool with Fallback
```ruby
module StudioArch
  module FaceColorTagger
    Sketchup.require(File.join(__dir__, "open_sketchup_helpers"))

    def self.tag_and_color_faces(min_area_sqm, max_area_sqm, color_name)
      model = Helpers.require_model
      return unless model

      min_sq_in = min_area_sqm / 0.00064516
      max_sq_in = max_area_sqm / 0.00064516

      # Inter-plugin communication: try finding existing selector capability
      faces = if Helpers.registry_available?("select.faces.by_area")
        Helpers.registry_call("select.faces.by_area", min_sq_in, max_sq_in)
      else
        all_faces = Helpers.get_faces(model.active_entities)
        all_faces.select { |f| f.area.between?(min_sq_in, max_sq_in) }
      end

      return if faces.nil? || faces.empty?

      Helpers.undo_wrap(model, "Tag and Color Faces") do
        Helpers.apply_color(model, faces, color_name)
      end
    end

    unless file_loaded?(__FILE__)
      UI.menu("Extensions").add_item("Color Faces by Area Range...") do
        res = Helpers.input_dialog(
          title: "Color Faces by Area",
          prompts: ["Min Area (m²):", "Max Area (m²):", "Color:"],
          defaults: [1.0, 50.0, "Red"],
          lists: [nil, nil, "Red|Green|Blue|Orange|Yellow"]
        )
        tag_and_color_faces(res[0].to_f, res[1].to_f, res[2]) if res
      end
      file_loaded(__FILE__)
    end
  end
end
```

---

## Web AI System Prompt (Copy & Paste for ChatGPT / Claude)

```text
You are an expert SketchUp Ruby Extension developer following the Open SketchUp Framework v0.2.1 standards:
1. Always namespace everything in AuthorName::PluginName (never top-level globals or monkey-patching).
2. Follow Extension Warehouse structure: root Plugins/AuthorName_PluginName.rb (metadata only) and Plugins/AuthorName_PluginName/main.rb.
3. Use Sketchup.require without file extensions.
4. Wrap every model modification in Helpers.undo_wrap(model, "Operation Name").
5. Optionally use Helpers.registry_register / Helpers.registry_call when the separate Open SketchUp Registry extension is available; never define or reopen OpenSketchUp in another extension.
6. Guard all UI menus with `unless file_loaded?(__FILE__)` / `file_loaded(__FILE__)` under UI.menu("Extensions").
7. Validate active model and selection before performing actions.
8. Optionally use UpdateChecker.check_for_update for version notifications; never download or install RBZ files programmatically (Extension Warehouse policy).
```

---

## Menu Placement Rules

- ALWAYS place plugin menus under `UI.menu("Extensions")`, never under "Plugins"
- Use a submenu for plugins with multiple actions:
  `UI.menu("Extensions").add_submenu("My Tool Suite")`
- ALWAYS guard menu creation with `unless file_loaded?(__FILE__)` / `file_loaded(__FILE__)`

## Undo Rules

- EVERY operation that modifies the model MUST be wrapped in `undo_wrap`
- Use descriptive operation names that make sense in the Edit > Undo menu
- Set `disable_ui: true` (default) for better performance during batch operations

## Error Handling

- Never let exceptions crash SketchUp silently
- Use `undo_wrap` which automatically aborts the operation on error, prints backtrace to console, and shows dialog
- Show user-friendly error messages with `UI.messagebox` for expected errors
- Log unexpected errors to the Ruby console with `puts`

## Code Style

- Use `Sketchup.require` instead of Ruby's `require` (supports encrypted .rbe files)
- Omit file extensions in require paths
- Use 2-space indentation
- Prefer `snake_case` for methods and variables
- Prefer `PascalCase` for modules and classes
- Use `SCREAMING_SNAKE_CASE` for constants

## What NOT to Do

- Do NOT use `$global_variables` for plugin state or cross-plugin registry
- Do NOT use `gem install` or `Gem.install` — bundle dependencies in your plugin folder
- Do NOT define methods or constants outside your namespace module
- Do NOT modify SketchUp API classes or Ruby core classes
- Do NOT use `require_relative` — use `Sketchup.require` instead
- Do NOT hardcode `.rb` file extensions in require paths
- Do NOT put logic in the root registration file
- Do NOT create toolbar buttons without also providing a menu item
- Do NOT assume the selection is non-empty — always validate first
- Do NOT download or install RBZ files programmatically — this violates Extension Warehouse policy
- Do NOT use `Sketchup.install_from_archive` for auto-updates — use the update checker to notify and let the user update manually
