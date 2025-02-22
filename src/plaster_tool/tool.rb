require "sketchup"

module Wheerd::Plaster
  class PlasterTool
    # @param Sketchup::Face face
    def initialize(face)
      @face = face
      @thickness = 10
      @mouse_ip = Sketchup::InputPoint.new
      @mouse_ip_inf = Sketchup::InputPoint.new
      @picked_ip = Sketchup::InputPoint.new
      @picked_plane = nil

      @plaster_faces = []
      @bounds = Geom::BoundingBox.new
      return

      model = Sketchup.active_model
      entities = model.entities
      other_faces = coplanar_faces(entities, @face)

      if other_faces.size == 0
        UI.messagebox("No other faces found for plaster generation")
        @plaster_faces = []
        @bounds = Geom::BoundingBox.new
      else
        model.start_operation("Find Faces", true)
        begin
          grp = model.entities.add_group
          other_faces.each { |f|
            grp.entities.add_face(*f)
          }
          @bounds = grp.bounds
          inner_edges = []
          grp.entities.grep(Sketchup::Edge) do |f|
            inner_edges << f if f.faces.size == 2
          end
          grp.entities.erase_entities(inner_edges)
          faces = grp.entities.grep(Sketchup::Face).to_a
          @plaster_faces = faces.map { |f|
            [f.outer_loop.vertices.map { |v|
              v.position
            }, f.loops.select { |l| !l.outer? && l.vertices.size > 2 }.map { |l|
              l.vertices.map { |v|
                v.position
              }
            }]
          }.to_a
        ensure
          model.abort_operation
        end
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

    def onMouseMove(flags, x, y, view)
      changed = if @picked_ip.valid?
          @mouse_ip_inf.pick(view, x, y, @picked_ip)
        else
          @mouse_ip_inf.pick(view, x, y)
        end
      if changed && @mouse_ip_inf.degrees_of_freedom == 0
        face = @mouse_ip_inf.face
        if !face
          view.pick_helper.do_pick(x, y)
          face = view.pick_helper.picked_face
        end
        @picked_plane = face.plane
        @mouse_ip.copy!(@mouse_ip_inf)
        update_ui
        view.invalidate
      end
    end

    def onLButtonDown(flags, x, y, view)
      @picked_ip.copy!(@mouse_ip)
      update_ui
      view.invalidate
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
      @thickness = text.to_l
    ensure
      update_ui
      view.invalidate
    end

    # @return [Geom::BoundingBox]
    def getExtents
      @bounds
    end

    # @param [Sketchup::View] view
    def draw(view)
      view.line_width = 3
      #angle = @face.normal.angle_between(view.camera.direction)
      @mouse_ip.draw(view) if @mouse_ip.display?
      @picked_ip.draw(view) if @picked_ip.display?
      angle = 0
      scale = angle < Math::PI / 2 ? -@thickness : @thickness
      #offset = Geom::Transformation.translation(@face.normal.transform(scale))
      @plaster_faces.each { |f|
        outer = f[0]
        view.drawing_color = "blue"
        view.draw(GL_LINE_LOOP, outer)
        offsetOuter = outer.map { |v| v.transform(offset) }
        view.draw(GL_LINE_LOOP, offsetOuter)
        f[1].each { |loop|
          view.drawing_color = "orange"
          view.draw(GL_LINE_LOOP, loop)
          offsetLoop = loop.map { |v| v.transform(offset) }
          view.draw(GL_LINE_LOOP, offsetLoop)
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
      @plaster_faces = []
    end

    def commit
      return unless @face.valid?
      model = Sketchup.active_model
      model.start_operation("Plaster", true)

      view = Sketchup.active_model.active_view
      angle = @face.normal.angle_between(view.camera.direction)
      thickness = angle < Math::PI / 2 ? -@thickness : @thickness

      parent = @face.parent
      obsoleteEdges = @face.edges.select { |f| f.faces.size == 1 }.to_a
      @face.erase!
      parent.entities.erase_entities(obsoleteEdges)

      grp = parent.entities.add_group
      @plaster_faces.each do |face|
        grp.entities.add_face(*face[0])
        face[1].each do |hole|
          holeFace = grp.entities.add_face(*hole)
          holeFace.erase!
        end
      end

      grp.entities.grep(Sketchup::Face).to_a.each do |f|
        f.pushpull(thickness)
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
