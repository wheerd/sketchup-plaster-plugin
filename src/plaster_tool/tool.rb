require "sketchup"

module Wheerd::Plaster
  class PlasterTool
    # @param Sketchup::Face face
    def initialize(face, transform)
      @normal = face.normal.transform(transform)
      @thickness = 10

      model = Sketchup.active_model
      entities = model.entities
      plane = normalize_plane(face.plane)
      @plane = [plane[0].transform(transform), plane[1].transform(transform)]
      other_faces = coplanar_faces(entities, @plane)

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
      angle = @normal.angle_between(view.camera.direction)
      scale = angle < Math::PI / 2 ? -@thickness : @thickness
      offset = Geom::Transformation.translation(@normal.transform(scale))
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
      model = Sketchup.active_model
      model.start_operation("Plaster", true)

      view = Sketchup.active_model.active_view
      angle = @normal.angle_between(view.camera.direction)
      thickness = angle < Math::PI / 2 ? -@thickness : @thickness

      grp = model.entities.add_group
      @plaster_faces.each do |face|
        grp.entities.add_face(*face[0])
        face[1].each do |hole|
          holeFace = grp.entities.add_face(*hole)
          holeFace.erase!
        end
      end

      grp.entities.grep(Sketchup::Face).to_a.each do |f|
        f.reverse! if (f.normal != @normal)
        f.pushpull(thickness)
      end

      model.close_active until model.entities == model.active_entities
      model.selection.clear
      model.selection.add grp

      model.commit_operation
      model.tools.pop_tool
    end

    def coplanar_faces(entities, plane, transformation = Geom::Transformation.new)
      faces = []
      entities.each { |f|
        if f.is_a?(Sketchup::Face)
          if f.visible?
            points = f.outer_loop.vertices.map { |v|
              v.position.transform(transformation)
            }
            if points.all? { |p| p.on_plane? plane }
              faces << points
            end
          end
        elsif f.is_a?(Sketchup::Group)
          faces.concat(coplanar_faces(f.entities, plane, transformation * f.transformation))
        elsif f.is_a?(Sketchup::ComponentInstance)
          faces.concat(coplanar_faces(f.definition.entities, plane, transformation * f.transformation))
        end
      }
      return faces
    end

    def normalize_plane(plane)
      return plane if plane.length == 2
      a, b, c, d = plane
      v = Geom::Vector3d.new(a, b, c)
      p = ORIGIN.offset(v.reverse, d)
      return [p, v]
    end
  end # class
end # module
