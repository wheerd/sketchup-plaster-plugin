# encoding: UTF-8

module Wheerd::Plaster
  module Settings
    SECTION = "wheerd_plaster_plugin".freeze

    HOLE_MIN_AREA = "hole_min_area".freeze
    GAP_MAX_WIDTH = "gap_max_width".freeze
    SIMPLIFY_TOLERANCE = "simplify_tolerance".freeze
    PLASTER_MIN_AREA = "plaster_min_area".freeze
    DEFAULT_THICKNESS = "default_thickness".freeze

    @hole_min_area = Sketchup.read_default(SECTION, HOLE_MIN_AREA, (0.3.m * 0.3.m).to_f).to_l
    @gap_max_width = Sketchup.read_default(SECTION, GAP_MAX_WIDTH, 0.15.m.to_f).to_l
    @simplify_tolerance = Sketchup.read_default(SECTION, SIMPLIFY_TOLERANCE, 1.mm.to_f).to_l
    @plaster_min_area = Sketchup.read_default(SECTION, PLASTER_MIN_AREA, (2.cm * 2.cm).to_f).to_l
    @default_thickness = Sketchup.read_default(SECTION, DEFAULT_THICKNESS, 10.cm.to_f).to_l

    attr_reader :hole_min_area, :gap_max_width, :simplify_tolerance, :plaster_min_area, :default_thickness

    def hole_min_area=(value)
      @hole_min_area = value
      Sketchup.write_default(SECTION, HOLE_MIN_AREA, value.to_f)
    end

    def gap_max_width=(value)
      @gap_max_width = value
      Sketchup.write_default(SECTION, GAP_MAX_WIDTH, value.to_f)
    end

    def simplify_tolerance=(value)
      @simplify_tolerance = value
      Sketchup.write_default(SECTION, SIMPLIFY_TOLERANCE, value.to_f)
    end

    def plaster_min_area=(value)
      @plaster_min_area = value
      Sketchup.write_default(SECTION, PLASTER_MIN_AREA, value.to_f)
    end

    def default_thickness=(value)
      @default_thickness = value
      Sketchup.write_default(SECTION, DEFAULT_THICKNESS, value.to_f)
    end

    extend self
  end
end
