# frozen_string_literal: true

require 'zeitwerk'

require_relative 'version'
require_relative 'errors'

loader = Zeitwerk::Loader.new
loader.push_dir File.expand_path('..', __dir__)
loader.ignore "#{__dir__}.rb"
loader.ignore __FILE__
loader.ignore "#{__dir__}/version.rb"
loader.ignore "#{__dir__}/errors.rb"
loader.setup
