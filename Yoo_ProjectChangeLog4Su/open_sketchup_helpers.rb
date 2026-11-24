# Open SketchUp Framework - Helpers module
# Namespaced copy of open-sketchup-framework/src/open_sketchup_helpers.rb (v0.2.1).
# Each plugin carries its own copy - do not load as a shared library.

module Yoo_ProjectChangeLog4Su
  module ProjectChangeLog
    module Helpers
      VERSION = "0.2.1".freeze

      # =========================================================================
      # UNDO OPERATIONS
      # =========================================================================

      # Wraps a block in a proper SketchUp undo operation.
      # Automatically commits on success, aborts on error, logs backtrace,
      # and shows a friendly error dialog to the user.
      #
      # Usage:
      #   OpenSketchUpHelpers.undo_wrap(model, "My Operation") do
      #     # ... modify the model ...
      #   end
      #
      def self.undo_wrap(model, operation_name, disable_ui: true, transparent: false)
        # disable_ui is caller-controlled; it defaults to true. The cop can't
        # see that, so the literal-boolean check is disabled for these lines.
        if transparent
          model.start_operation(operation_name, disable_ui, false, true) # rubocop:disable SketchupPerformance/OperationDisableUI
        else
          model.start_operation(operation_name, disable_ui) # rubocop:disable SketchupPerformance/OperationDisableUI
        end
        begin
          result = yield
          model.commit_operation
          result
        rescue => e
          model.abort_operation
          puts "Open SketchUp Framework: Operation '#{operation_name}' failed: #{e.message}"
          puts e.backtrace.join("\n") if e.backtrace
          UI.messagebox("Operation '#{operation_name}' failed: #{e.message}")
          raise e
        end
      end

      # =========================================================================
      # ENTITY HELPERS
      # =========================================================================

      # Get all faces from an Entities collection (or nested groups/components).
      #
      # Options:
      #   recursive: false — only top-level entities
      #   recursive: true  — traverse into groups and component instances
      #
      def self.get_faces(entities, recursive: false)
        if recursive
          collect_recursive(entities, Sketchup::Face)
        else
          entities.grep(Sketchup::Face)
        end
      end

      # Get all edges from an Entities collection.
      def self.get_edges(entities, recursive: false)
        if recursive
          collect_recursive(entities, Sketchup::Edge)
        else
          entities.grep(Sketchup::Edge)
        end
      end

      # Get all groups from an Entities collection.
      def self.get_groups(entities, recursive: false)
        if recursive
          collect_recursive(entities, Sketchup::Group)
        else
          entities.grep(Sketchup::Group)
        end
      end

      # Get all component instances from an Entities collection.
      def self.get_components(entities, recursive: false)
        if recursive
          collect_recursive(entities, Sketchup::ComponentInstance)
        else
          entities.grep(Sketchup::ComponentInstance)
        end
      end

      # Recursively collect entities of a given type.
      def self.collect_recursive(entities, type, results = [])
        entities.each do |entity|
          results << entity if entity.is_a?(type)
          if entity.is_a?(Sketchup::Group)
            collect_recursive(entity.entities, type, results)
          elsif entity.is_a?(Sketchup::ComponentInstance)
            collect_recursive(entity.definition.entities, type, results)
          end
        end
        results
      end
      private_class_method :collect_recursive

      # =========================================================================
      # SELECTION HELPERS
      # =========================================================================

      # Filter the current selection by entity type.
      #
      # Usage:
      #   faces = OpenSketchUpHelpers.selection_filter(model, Sketchup::Face)
      #
      def self.selection_filter(model, type)
        model.selection.grep(type)
      end

      # Replace the current selection with the given entities.
      def self.selection_set(model, entities)
        model.selection.clear
        model.selection.add(entities)
        entities
      end

      # =========================================================================
      # GEOMETRY & BOUNDS HELPERS
      # =========================================================================

      # Get the center point (Geom::Point3d) of an entity's bounding box.
      def self.bounds_center(entity)
        entity.bounds.center
      end

      # Get the dimensions [width, height, depth] of an entity's bounding box.
      def self.bounds_dimensions(entity)
        b = entity.bounds
        [b.width, b.height, b.depth]
      end

      # =========================================================================
      # UNIT & CONVERSION HELPERS
      # =========================================================================

      # Convert millimeters to inches (SketchUp internal units).
      def self.to_inches(length_mm)
        length_mm.to_f / 25.4
      end

      # Convert inches (SketchUp internal units) to millimeters.
      def self.to_mm(length_inches)
        length_inches.to_f * 25.4
      end

      # Format an area in square inches to a human-readable string (sq meters or sq feet).
      def self.format_area(area_sq_inches, unit: :sq_m)
        case unit
        when :sq_m, :sq_meters, "m2"
          sq_m = area_sq_inches * 0.00064516
          "#{sq_m.round(2)} m²"
        when :sq_ft, :sq_feet, "ft2"
          sq_ft = area_sq_inches / 144.0
          "#{sq_ft.round(2)} sq ft"
        else
          "#{area_sq_inches.round(2)} sq in"
        end
      end

      # =========================================================================
      # INPUT DIALOG HELPERS
      # =========================================================================

      # Show an input dialog with a simpler API than UI.inputbox.
      # Returns an array of values, or nil if the user cancelled.
      #
      # Usage:
      #   results = OpenSketchUpHelpers.input_dialog(
      #     title: "My Dialog",
      #     prompts: ["Width", "Height", "Material"],
      #     defaults: [10.0, 5.0, "Wood"],
      #     lists: [nil, nil, "Wood|Steel|Concrete"]
      #   )
      #
      def self.input_dialog(title:, prompts:, defaults: nil, lists: nil)
        defaults ||= Array.new(prompts.length, "")
        lists ||= Array.new(prompts.length, "")
        result = UI.inputbox(prompts, defaults, lists, title)
        result == false ? nil : result
      end

      # =========================================================================
      # MATERIAL HELPERS
      # =========================================================================

      # Apply a color to entities. Creates a material if needed.
      #
      # Usage:
      #   OpenSketchUpHelpers.apply_color(model, faces, [255, 0, 0])
      #   OpenSketchUpHelpers.apply_color(model, faces, "Red")
      #   OpenSketchUpHelpers.apply_color(model, faces, Sketchup::Color.new(255, 0, 0))
      #
      def self.apply_color(model, entities, color, material_name: nil)
        color = Sketchup::Color.new(*color) if color.is_a?(Array)
        material_name ||= "OSF_#{color.to_a[0..2].join('_')}"

        material = model.materials[material_name]
        unless material
          material = model.materials.add(material_name)
          material.color = color
        end

        entities = [entities] unless entities.is_a?(Array)
        entities.each { |e| e.material = material }
        material
      end

      # =========================================================================
      # CAPABILITY REGISTRY (DELEGATES TO OpenSketchUp::Registry)
      # =========================================================================

      # Register a capability that this plugin provides.
      def self.registry_register(capability_id, version:, callable:, description: "")
        return nil unless defined?(OpenSketchUp::Registry)

        OpenSketchUp::Registry.register(capability_id, version: version, callable: callable, description: description)
      end

      # Find a registered capability by ID.
      def self.registry_find(capability_id)
        return nil unless defined?(OpenSketchUp::Registry)

        OpenSketchUp::Registry.find(capability_id)
      end

      # List all registered capabilities.
      def self.registry_list
        return {} unless defined?(OpenSketchUp::Registry)

        OpenSketchUp::Registry.list
      end

      # Check if a capability is available.
      def self.registry_available?(capability_id)
        defined?(OpenSketchUp::Registry) && OpenSketchUp::Registry.available?(capability_id)
      end

      # Invoke a registered capability.
      def self.registry_call(capability_id, *args, **kwargs, &block)
        raise LoadError, "Open SketchUp Registry extension is not available." unless defined?(OpenSketchUp::Registry)

        OpenSketchUp::Registry.call(capability_id, *args, **kwargs, &block)
      end

      # =========================================================================
      # MENU HELPERS
      # =========================================================================

      # Add a menu item under Extensions, avoiding duplicates.
      # Creates a submenu if submenu_name is provided.
      #
      # Usage:
      #   OpenSketchUpHelpers.add_menu_item("My Tools", "Do Something") { do_it }
      #
      def self.add_menu_item(submenu_name, item_name, &block)
        extensions_menu = UI.menu("Extensions")
        submenu = extensions_menu.add_submenu(submenu_name)
        submenu.add_item(item_name, &block)
      end

      # =========================================================================
      # VALIDATION HELPERS
      # =========================================================================

      # Check that there is an active model. Shows an error if not.
      def self.require_model
        model = Sketchup.active_model
        unless model
          UI.messagebox("No active model found. Please open or create a model first.")
          return nil
        end
        model
      end

      # Check that there is a selection. Shows an error if empty.
      def self.require_selection(model)
        if model.selection.empty?
          UI.messagebox("Please select at least one entity first.")
          return nil
        end
        model.selection
      end

      # =========================================================================
      # ATTRIBUTE HELPERS
      # =========================================================================

      # Get/set attributes on entities using a consistent dictionary name.
      # Uses "open_sketchup" as the default attribute dictionary.
      #
      # Usage:
      #   OpenSketchUpHelpers.set_attribute(face, "category", "wall")
      #   value = OpenSketchUpHelpers.get_attribute(face, "category")
      #
      def self.set_attribute(entity, key, value, dict_name: "open_sketchup")
        entity.set_attribute(dict_name, key, value)
      end

      def self.get_attribute(entity, key, default: nil, dict_name: "open_sketchup")
        entity.get_attribute(dict_name, key, default)
      end
    end
  end
end
