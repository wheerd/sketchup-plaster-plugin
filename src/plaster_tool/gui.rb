# encoding: UTF-8

module Wheerd::Plaster
  def self.create_plaster_cmd
    cmd = UI::Command.new("Plaster Tool") {
      activate_plaster_tool
    }
    cmd.tooltip = "Plaster Tool"
    cmd.menu_text = "Plaster Tool"
    cmd.status_bar_text = "Create plaster from face"
    cmd.small_icon = File.join(PATH, "icon.svg")
    cmd.large_icon = File.join(PATH, "icon.svg")
    cmd.set_validation_proc {
      is_active? ? MF_ENABLED : MF_GRAYED
    }
    cmd
  end

  def self.is_active?
    selection = Sketchup.active_model.selection
    selection.size == 1 && selection[0].is_a?(Sketchup::Face)
  end

  def self.activate_plaster_tool
    model = Sketchup.active_model
    transform = model.active_path ? Sketchup::InstancePath.new(model.active_path).transformation : Geom::Transformation.new
    selection = model.selection
    unless selection.size == 1 && selection[0].is_a?(Sketchup::Face)
      UI.messagebox("Select a single face to create plaster from.")
      return
    end
    tool = PlasterTool.new(selection[0], transform)
    model.select_tool(tool)
  end

  def self.setup_ui
    cmd_activate_plaster_tool = create_plaster_cmd

    menu = UI.menu("Plugins")
    menu.add_item cmd_activate_plaster_tool

    toolbar = UI::Toolbar.new("Plaster Tool")
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
