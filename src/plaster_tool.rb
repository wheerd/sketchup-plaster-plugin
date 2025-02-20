require "sketchup.rb"
require "extensions.rb"

module Wheerd
  module PlasterTool
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new("Plaster Tool", "plaster_tool/main")
      ex.description = "Plaster Tool"
      ex.version = "1.0.0"
      ex.copyright = "Wheerd © 2025"
      ex.creator = "Wheerd"
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end
end
