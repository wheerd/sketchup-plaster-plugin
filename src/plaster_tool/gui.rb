# encoding: UTF-8

module Wheerd::Plaster
  def self.create_plaster_cmd
    cmd = UI::Command.new(EXTENSION[:name]) {
      activate_plaster_tool
    }
    cmd.tooltip = EXTENSION[:name]
    cmd.menu_text = EXTENSION[:name]
    cmd.status_bar_text = "Create plaster from face"
    cmd.small_icon = File.join(PATH, "icon.svg")
    cmd.large_icon = File.join(PATH, "icon.svg")
    cmd
  end

  def self.is_active?
    selection = Sketchup.active_model.selection
    selection.size == 1 && selection[0].is_a?(Sketchup::Face)
  end

  def self.activate_plaster_tool
    tool = PlasterTool.new()
    Sketchup.active_model.select_tool(tool)
  end

  def self.setup_ui
    cmd_activate_plaster_tool = create_plaster_cmd

    menu = UI.menu("Plugins")
    submenu = menu.add_submenu(EXTENSION[:name])
    submenu.add_item cmd_activate_plaster_tool
    submenu.add_item("Settings") {
      Settings.show_dialog
    }

    toolbar = UI::Toolbar.new(EXTENSION[:name])
    toolbar.add_item cmd_activate_plaster_tool
    toolbar.restore

    UI.add_context_menu_handler do |context_menu|
      if is_active?
        context_menu.add_item cmd_activate_plaster_tool
      end
    end
  end

  unless file_loaded?(__FILE__)
    self.setup_ui
  end
end

file_loaded(__FILE__)
