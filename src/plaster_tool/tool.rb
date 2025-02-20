require "sketchup"

module Wheerd::Plaster
  class PlasterTool
    # @param Sketchup::Face face
    def initialize(face)
      @face = face
      # UI.messagebox("Tool: #{other_faces.count}")
    end

    def enableVCB?
      true
    end

    def activate
      update_ui
      Sketchup.active_model.active_view.invalidate
    end

    # @param [Sketchup::View] view
    def deactivate(view)
      view.invalidate
    end

    # @param [Sketchup::View] view
    def suspend(view)
      update_ui
      view.invalidate
    end

    # @param [Sketchup::View] view
    def resume(view)
      view.invalidate
    end

    def onReturn(_view)
      commit
    end

    # @param [Sketchup::View] view
    def onCancel(_reason, view)
    end

    # @param [String] text
    # @param [Sketchup::View] view
    def onUserText(text, view)
    ensure
      update_ui
      view.invalidate
    end

    # @return [Geom::BoundingBox]
    def getExtents
      bounds = Geom::BoundingBox.new
      bounds
    end

    # @param [Sketchup::View] view
    def draw(view)
    end

    private

    def update_ui
      Sketchup.status_text = "Create a plaster"
      Sketchup.vcb_label = "Thickness"
    end

    def commit
      model = Sketchup.active_model
      model.start_operation("Plaster", true)

      other_faces = coplanar_faces(model.entities, @face)

      parent = @face.parent
      grp = parent.entities.add_group
      other_faces.each { |f|
        grp.entities.add_face(*f)
      }
      temp = []
      grp.entities.grep(Sketchup::Edge) do |f|
        temp << f if f.faces.size > 1
      end
      grp.entities.erase_entities(temp)
      obsoleteEdges = @face.edges.select { |f| f.faces.size == 1 }.to_a
      @face.erase!
      parent.entities.erase_entities(obsoleteEdges)

      grp.entities.grep(Sketchup::Face) do |f|
        f.pushpull(0.01.m)
      end

      model.commit_operation
      model.tools.pop_tool

      model.selection.clear
      model.selection.add grp
    end

    def coplanar_faces(entities, face, transformation = Geom::Transformation.new)
      faces = []
      entities.each { |f|
        if f.is_a?(Sketchup::Face)
          if f != face
            points = f.outer_loop.vertices.map { |v|
              v.position.transform(transformation)
            }
            if points.all? { |p|
              type = face.classify_point(p)
              type >= Sketchup::Face::PointInside && type <= Sketchup::Face::PointOnFace
            }
              faces << points
            end
          end
        elsif f.is_a?(Sketchup::Group)
          faces.concat(coplanar_faces(f.entities, face, transformation * f.transformation))
        elsif f.is_a?(Sketchup::ComponentInstance)
          faces.concat(coplanar_faces(f.definition.entities, face, transformation * f.transformation))
        end
      }
      return faces
    end
  end # class
end # module
