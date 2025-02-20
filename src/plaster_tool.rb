require "sketchup"
require "extensions"

module Wheerd
  module Plaster
    file = __FILE__.dup
    # Account for Ruby encoding bug under Windows.
    file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
    # Support folder should be named the same as the root .rb file.
    folder_name = File.basename(file, ".*")

    # Path to the root .rb file (this file).
    PATH_ROOT = File.dirname(file).freeze

    # Path to the support folder.
    PATH = File.join(PATH_ROOT, folder_name).freeze

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new("Plaster Tool", File.join(PATH, "main"))
      ex.description = "Plaster Tool"
      ex.version = "1.0.0"
      ex.copyright = "Wheerd © 2025"
      ex.creator = "Wheerd"
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end
end
