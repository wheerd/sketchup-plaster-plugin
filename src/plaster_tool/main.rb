require "sketchup.rb"

module Wheerd
  module PlasterTool
    def self.create_plaster
      model = Sketchup.active_model
      model.start_operation("Create Plaster", true)
      group = model.active_entities.add_group
      entities = group.entities
      points = [
        Geom::Point3d.new(0, 0, 0),
        Geom::Point3d.new(1.m, 0, 0),
        Geom::Point3d.new(1.m, 1.m, 0),
        Geom::Point3d.new(0, 1.m, 0),
      ]
      face = entities.add_face(points)
      face.pushpull(-1.m)
      model.commit_operation
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu("Plugins")
      menu.add_item("Create Plaster") {
        self.create_plaster
      }

      UI.add_context_menu_handler do |context_menu|
        selection = Sketchup.active_model.selection
        if selection.size == 1 && selection[0].is_a?(Sketchup::Face)
          context_menu.add_item("Create Plaster") {
            self.create_plaster
          }
        end
      end

      file_loaded(__FILE__)
    end
  end
end
