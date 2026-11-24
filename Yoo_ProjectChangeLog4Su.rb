# Copyright:: Copyright 2024
# License:: The MIT License (MIT)
#
# Root registration file - metadata only. All logic lives in the
# Yoo_ProjectChangeLog4Su/ support folder (Open SketchUp Framework v0.2.1).

require 'sketchup'
require 'extensions'

module Yoo_ProjectChangeLog4Su
  module ProjectChangeLog
    unless file_loaded?(__FILE__)
      EXTENSION = SketchupExtension.new(
        'Project Change Log',
        File.join('Yoo_ProjectChangeLog4Su', 'main')
      )
      EXTENSION.version     = '1.5.0'
      EXTENSION.creator     = 'Jure Judež'
      EXTENSION.description = 'Prompts for a commit message on save and stores ' \
                              'it in a CSV changelog next to the model.'
      EXTENSION.copyright   = '2026, Jure Judež'

      Sketchup.register_extension(EXTENSION, true)
      file_loaded(__FILE__)
    end
  end
end
