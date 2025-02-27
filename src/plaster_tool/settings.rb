# encoding: UTF-8

module Wheerd::Plaster
  module Settings
    SECTION = "wheerd_plaster_plugin".freeze

    HOLE_MIN_AREA = "hole_min_area".freeze
    GAP_MAX_WIDTH = "gap_max_width".freeze
    SIMPLIFY_TOLERANCE = "simplify_tolerance".freeze
    PLASTER_MIN_AREA = "plaster_min_area".freeze
    DEFAULT_THICKNESS = "default_thickness".freeze
    PLANE_TOLERANCE = "plane_tolerance".freeze

    HOLE_MIN_AREA_DEFAULT = (0.3.m * 0.3.m).to_f
    GAP_MAX_WIDTH_DEFAULT = 0.15.m.to_f
    SIMPLIFY_TOLERANCE_DEFAULT = 1.mm.to_f
    PLASTER_MIN_AREA_DEFAULT = (0.02.m * 0.02.m).to_f
    DEFAULT_THICKNESS_DEFAULT = 10.cm.to_f
    PLANE_TOLERANCE_DEFAULT = 2.mm.to_f

    @hole_min_area = Sketchup.read_default(SECTION, HOLE_MIN_AREA, HOLE_MIN_AREA_DEFAULT).to_l
    @gap_max_width = Sketchup.read_default(SECTION, GAP_MAX_WIDTH, GAP_MAX_WIDTH_DEFAULT).to_l
    @simplify_tolerance = Sketchup.read_default(SECTION, SIMPLIFY_TOLERANCE, SIMPLIFY_TOLERANCE_DEFAULT).to_l
    @plaster_min_area = Sketchup.read_default(SECTION, PLASTER_MIN_AREA, PLASTER_MIN_AREA_DEFAULT).to_l
    @default_thickness = Sketchup.read_default(SECTION, DEFAULT_THICKNESS, DEFAULT_THICKNESS_DEFAULT).to_l
    @plane_tolerance = Sketchup.read_default(SECTION, PLANE_TOLERANCE, PLANE_TOLERANCE_DEFAULT).to_l

    attr_reader :hole_min_area, :gap_max_width, :simplify_tolerance, :plaster_min_area, :default_thickness, :plane_tolerance

    HTML_FILE = File.join(PATH, "html", "settings.html")

    def create_dialog
      options = {
        :dialog_title => "Plaster Tool Settings",
        :style => UI::HtmlDialog::STYLE_DIALOG,
        :width => 500,
        :height => 600,
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_file(HTML_FILE)
      dialog.center
      dialog
    end

    def show_dialog
      @dialog ||= create_dialog
      @dialog.add_action_callback("ready") {
        update_dialog
        nil
      }
      @dialog.add_action_callback("save") { |_, data|
        update_settings(data)
        save
        @dialog.close
        nil
      }
      @dialog.add_action_callback("reset") {
        reset
        save
        nil
      }
      @dialog.visible? ? @dialog.bring_to_front : @dialog.show
    end

    def update_dialog
      return if @dialog.nil?
      settings = {
        hole_min_area: area_no_unit_float(@hole_min_area),
        gap_max_width: length_no_unit_float(@gap_max_width),
        simplify_tolerance: length_no_unit_float(@simplify_tolerance),
        plaster_min_area: area_no_unit_float(@plaster_min_area),
        default_thickness: length_no_unit_float(@default_thickness),
        plane_tolerance: length_no_unit_float(@plane_tolerance),
      }
      json = JSON.pretty_generate(settings)
      @dialog.execute_script("updateSettings(#{json})")
      @dialog.execute_script("updateUnits('#{length_text}', '#{area_text}')")
    end

    def reset
      @hole_min_area = HOLE_MIN_AREA_DEFAULT.to_l
      @gap_max_width = GAP_MAX_WIDTH_DEFAULT.to_l
      @simplify_tolerance = SIMPLIFY_TOLERANCE_DEFAULT.to_l
      @plaster_min_area = PLASTER_MIN_AREA_DEFAULT.to_l
      @default_thickness = DEFAULT_THICKNESS_DEFAULT.to_l
      @plane_tolerance = PLANE_TOLERANCE_DEFAULT.to_l

      update_dialog
    end

    def update_settings(data)
      @hole_min_area = (data["hole_min_area"] * area_factor).to_l
      @gap_max_width = (data["gap_max_width"] * length_factor).to_l
      @simplify_tolerance = (data["simplify_tolerance"] * length_factor).to_l
      @plaster_min_area = (data["plaster_min_area"] * area_factor).to_l
      @default_thickness = (data["default_thickness"] * length_factor).to_l
      @plane_tolerance = (data["plane_tolerance"] * length_factor).to_l
    end

    def save
      Sketchup.write_default(SECTION, HOLE_MIN_AREA, @hole_min_area.to_f)
      Sketchup.write_default(SECTION, GAP_MAX_WIDTH, @gap_max_width.to_f)
      Sketchup.write_default(SECTION, SIMPLIFY_TOLERANCE, @simplify_tolerance.to_f)
      Sketchup.write_default(SECTION, PLASTER_MIN_AREA, @plaster_min_area.to_f)
      Sketchup.write_default(SECTION, DEFAULT_THICKNESS, @default_thickness.to_f)
      Sketchup.write_default(SECTION, PLANE_TOLERANCE, @plane_tolerance.to_f)
    end

    def area_text
      case Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]
      when Length::Inches
        return " in²"
      when Length::Feet
        return " ft²"
      when Length::Millimeter
        return " mm²"
      when Length::Centimeter
        return " cm²"
      when Length::Meter
        return " m²"
      when Length::Yard
        return " yd²"
      else
        return ""
      end
    end

    def area_factor
      case Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]
      when Length::Inches
        return 1.inch * 1.inch
      when Length::Feet
        return 1.feet * 1.feet
      when Length::Millimeter
        return 1.mm * 1.mm
      when Length::Centimeter
        return 1.cm * 1.cm
      when Length::Meter
        return 1.m * 1.m
      when Length::Yard
        return 1.yard * 1.yard
      else
        return 1
      end
    end

    def length_text
      case Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]
      when Length::Inches
        return " in"
      when Length::Feet
        return " ft"
      when Length::Millimeter
        return " mm"
      when Length::Centimeter
        return " cm"
      when Length::Meter
        return " m"
      when Length::Yard
        return " yd"
      else
        return ""
      end
    end

    def length_factor
      case Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]
      when Length::Inches
        return 1.inch
      when Length::Feet
        return 1.feet
      when Length::Millimeter
        return 1.mm
      when Length::Centimeter
        return 1.cm
      when Length::Meter
        return 1.m
      when Length::Yard
        return 1.yard
      else
        return 1
      end
    end

    def area_no_unit_float(number)
      return (number.to_f / area_factor).round(4)
    end

    def length_no_unit_float(number)
      return (number.to_f / length_factor).round(4)
    end

    extend self
  end
end
