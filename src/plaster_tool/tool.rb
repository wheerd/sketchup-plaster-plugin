require "sketchup"

module Wheerd::Plaster
  class PlasterTool
    # @param Sketchup::Face face
    def initialize(face)
      @face = face
      entities = Sketchup.active_model.entities
      @other_faces = coplanar_faces(entities, @face)
      @thickness = 10

      if @other_faces.size == 0
        UI.messagebox("No other faces found for plaster generation")
        @grp = nil
      else
        @grp = @face.parent.entities.add_group
        @grp.visible = false
        @other_faces.each { |f|
          @grp.entities.add_face(*f)
        }
        inner_edges = []
        @grp.entities.grep(Sketchup::Edge) do |f|
          inner_edges << f if f.faces.size == 2
        end
        @grp.entities.erase_entities(inner_edges)
      end
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

    def onLButtonDoubleClick(_flags, _x, _y, _view)
      commit
    end

    # @param [Sketchup::View] view
    def onCancel(_reason, view)
      reset
      view.invalidate
    end

    # @param [String] text
    # @param [Sketchup::View] view
    def onUserText(text, view)
      @thickness = text.to_i
    ensure
      update_ui
      view.invalidate
    end

    # @return [Geom::BoundingBox]
    def getExtents
      @grp.bounds
    end

    # @param [Sketchup::View] view
    def draw(view)
      view.line_width = 3
      @grp.entities.grep(Sketchup::Face) { |f|
        f.loops.each { |loop|
          points = loop.vertices.map { |v| v.position }
          view.drawing_color = loop.outer? ? "blue" : "orange"
          view.draw_polyline(points)
        }
      }
    end

    private

    def update_ui
      Sketchup.status_text = "Create a plaster"
      Sketchup.vcb_label = "Thickness"
      Sketchup.vcb_value = @thickness
    end

    def reset
      Sketchup.active_model.tools.pop_tool
      @grp.erase!
    end

    def commit
      model = Sketchup.active_model
      model.start_operation("Plaster", true)
      puts @grp.entities.grep(Sketchup::Face).size

      parent = @face.parent
      obsoleteEdges = @face.edges.select { |f| f.faces.size == 1 }.to_a
      @face.erase!
      parent.entities.erase_entities(obsoleteEdges)

      @grp.visible = true
      puts @grp.entities.grep(Sketchup::Face).size
      @grp.entities.grep(Sketchup::Face) do |f|
        #f.pushpull(-@thickness)
      end

      model.commit_operation
      model.tools.pop_tool

      model.selection.clear
      model.selection.add @grp
    end

    def coplanar_faces(entities, face, transformation = Geom::Transformation.new)
      faces = []
      entities.each { |f|
        if f.is_a?(Sketchup::Face)
          if f != face && f.visible?
            points = f.outer_loop.vertices.map { |v|
              v.position.transform(transformation)
            }
            if points.all? { |p|
              type = face.classify_point(p)
              type >= Sketchup::Face::PointInside && type <= Sketchup::Face::PointOnFace
            }
              inner = f.loops.select(&:outer?).map { |loop|
                loop.vertices.map { |v|
                  v.position.transform(transformation)
                }
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
