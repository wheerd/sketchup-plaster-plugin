require "sketchup"

require "plaster_tool/tool"

module Wheerd
  module Plaster
    unless file_loaded?(__FILE__)
      cmd = UI::Command.new("Plaster Tool") {
        activate_plaster_tool
      }
      cmd.tooltip = "Plaster Tool"
      cmd.menu_text = "Plaster Tool"
      cmd.status_bar_text = "Create plaster from face"
      cmd.small_icon = File.join(PATH, "icon.svg")
      cmd.large_icon = File.join(PATH, "icon.svg")
      cmd.set_validation_proc {
        selection = Sketchup.active_model.selection
        if selection.size == 1 && selection[0].is_a?(Sketchup::Face)
          MF_ENABLED
        else
          MF_GRAYED
        end
      }
      cmd_activate_plaster_tool = cmd

      menu = UI.menu("Plugins")
      menu.add_item cmd_activate_plaster_tool

      toolbar = UI::Toolbar.new("Plaster Tool")
      toolbar.add_item cmd_activate_plaster_tool
      toolbar.restore

      UI.add_context_menu_handler do |context_menu|
        selection = Sketchup.active_model.selection
        if selection.size == 1 && selection[0].is_a?(Sketchup::Face)
          context_menu.add_item cmd_activate_plaster_tool
        end
      end

      def self.activate_plaster_tool
        model = Sketchup.active_model
        selection = model.selection
        unless selection.size == 1 && selection[0].is_a?(Sketchup::Face)
          UI.messagebox("Select a single face to create plaster from.")
          return
        end
        tool = PlasterTool.new(selection[0])
        model.select_tool(tool)
      end

      file_loaded(__FILE__)
    end
  end
end
