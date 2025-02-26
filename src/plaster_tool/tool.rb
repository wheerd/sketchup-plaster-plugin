# encoding: UTF-8

module Wheerd::Plaster
  class PlasterTool
    AREA_THRESHOLD = 0.3.m * 0.3.m
    GAP_THRESHOLD = 0.15.m

    # @param Sketchup::Face face
    def initialize()
      reset
      face_selection
    end

    def face_selection
      model = Sketchup.active_model
      transform = model.active_path ? Sketchup::InstancePath.new(model.active_path).transformation : Geom::Transformation.new
      selection = model.selection
      if selection.size == 1 && selection[0].is_a?(Sketchup::Face)
        build_plaster_area(selection[0], transform)
      end
    end

    def build_plaster_area(face, transform)
      @normal = face.normal.transform(transform)

      model = Sketchup.active_model
      entities = model.entities
      plane = normalize_plane(face.plane)
      @plane = [plane[0].transform(transform), plane[1].transform(transform)]
      other_faces = coplanar_faces(entities, @plane)

      model.start_operation("Find Faces", true)
      begin
        grp = model.entities.add_group
        inner = grp.entities.add_group
        inner2 = inner.entities.add_group
        other_faces.each { |f|
          if get_area(f) > 0
            inner2.entities.add_face(*f)
          end
        }
        inner2.explode
        @bounds = grp.bounds

        remove_inner_edges(inner.entities)
        inner.explode

        faces = grp.entities.grep(Sketchup::Face).to_a
        @plaster_faces = []

        faces.each { |f|
          next if f.outer_loop.vertices.size < 3
          outer = f.outer_loop.vertices.map { |v| v.position }
          holes = []
          f.loops.each { |l|
            if !l.outer? && l.vertices.size > 2
              inner = l.vertices.map { |v| v.position }
              area = get_area(inner)
              if area > AREA_THRESHOLD && !is_gap?(inner)
                holes << inner
              end
            end
          }
          @plaster_faces << [outer, holes]
        }
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

    def onLButtonDown(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      if ph.picked_face != nil
        face = ph.picked_face
        i = ph.count.times.select { |i| ph.leaf_at(i) == face }.first
        trans = ph.transformation_at(i)
        build_plaster_area(face, trans)
        update_ui
        view.invalidate
      end
    end

    # @param [Sketchup::View] view
    def onCancel(_reason, view)
      plaster_mode = @normal != nil
      reset
      if plaster_mode
        update_ui
      else
        Sketchup.active_model.tools.pop_tool
      end
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

    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      if ph.picked_face != nil || @hover_polygon != nil
        face = ph.picked_face
        if face != nil
          i = ph.count.times.select { |i| ph.leaf_at(i) == face }.first
          trans = ph.transformation_at(i)
          @hover_polygon = face.outer_loop.vertices.map { |v| v.position.transform(trans) }
        else
          @hover_polygon = nil
        end
        view.invalidate
      end
    end

    # @param [Sketchup::View] view
    def draw(view)
      if @normal != nil
        view.line_width = 3
        angle = @normal.angle_between(view.camera.direction)
        scale = angle < Math::PI / 2 ? -@thickness.to_f : @thickness.to_f
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
      elsif @hover_polygon
        view.line_width = 3
        view.drawing_color = "lightblue"
        view.draw(GL_POLYGON, @hover_polygon)
        view.drawing_color = "blue"
        view.draw(GL_LINE_LOOP, @hover_polygon)
      end
    end

    private

    def update_ui
      if @normal != nil
        Sketchup.status_text = "Enter thickness or press enter to create the plaster"
        Sketchup.vcb_label = "Thickness of plaster"
        Sketchup.vcb_value = @thickness.to_s
      else
        Sketchup.status_text = "Select a face to determine the plane of the plaster"
        Sketchup.vcb_label = ""
        Sketchup.vcb_value = ""
      end
    end

    def reset
      @thickness = 0.1.m
      @hover_polygon = nil
      @normal = nil
      @plane = nil
      @bounds = Geom::BoundingBox.new
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
          holeFace.erase! if holeFace != nil
        end
      end

      grp.entities.grep(Sketchup::Face).to_a.each do |f|
        f.reverse! if (f.normal != @normal)
        f.pushpull(thickness)
      end

      grp.entities.grep(Sketchup::Edge).to_a.each { |e|
        next unless e.faces.size == 2
        if e.faces[0].normal.parallel?(e.faces[1].normal)
          e.erase!
        end
      }

      model.close_active until model.entities == model.active_entities
      model.selection.clear
      model.selection.add grp

      model.commit_operation
      model.tools.pop_tool
    end

    def coplanar_faces(entities, plane, transformation = Geom::Transformation.new)
      faces = []
      entities.each { |f|
        next unless f.valid?
        next unless f.visible? && f.layer.visible?
        if f.is_a?(Sketchup::Face)
          normal = f.normal.transform(transformation)
          next unless normal.parallel? plane[1]
          points = f.outer_loop.vertices.map { |v|
            v.position.transform(transformation)
          }
          if points.all? { |p| p.on_plane? plane }
            reverse = f.normal != plane[1]
            faces << (reverse ? points.reverse : points)
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

    def remove_inner_edges(entities)
      entities.grep(Sketchup::Edge).to_a.each do |e|
        merge_connected_faces(e)
      end
    end

    def relevant_edges(entities)
      entities.grep(Sketchup::Edge).
        select { |e| e.faces.size == 1 }.
        map { |e| [e.start.position, e.end.position] }
    end

    def get_area(loop)
      grp = Sketchup.active_model.entities.add_group
      face = grp.entities.add_face(loop)
      begin
        return face.area
      ensure
        grp.erase!
      end
    end

    def merge_connected_faces(edge)
      return false unless edge.valid? && edge.is_a?(Sketchup::Edge)
      return false unless edge.faces.size == 2

      f1, f2 = edge.faces
      return false unless f1.normal.parallel?(f2.normal)
      return false unless edge_safe_to_merge?(edge)
      return false unless faces_coplanar?(f1, f2)

      edge.erase!
      if f1.deleted? && f2.deleted?
        puts "Face merge resulted in lost geometry!"
      end

      true
    end

    def faces_coplanar?(face1, face2)
      vertices = face1.vertices + face2.vertices
      plane = Geom.fit_plane_to_points(vertices)
      vertices.all? { |v| v.position.on_plane?(plane) }
    end

    def edge_safe_to_merge?(edge)
      edge.faces.all? { |face| face_safe_to_merge?(face) }
    end

    def face_safe_to_merge?(face)
      stack = face.outer_loop.edges
      edge = stack.shift
      direction = edge.line[1]
      until stack.empty?
        edge = stack.shift
        return true unless edge.line[1].parallel?(direction)
      end
      false
    end

    def is_gap?(loop)
      grp = Sketchup.active_model.entities.add_group
      face = grp.entities.add_face(loop)
      begin
        lengths = face.edges.map { |e| e.length }.sort
        if lengths.size == 4 && lengths[0] == lengths[1] && lengths[2] == lengths[3]
          return lengths[0] < GAP_THRESHOLD
        end
        return false
      ensure
        grp.erase!
      end
    end
  end # class
end # module
