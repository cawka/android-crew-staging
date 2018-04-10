require_relative "#{Global::NDK_DIR}/../data/test_tool_methods.rb"

class TestTool < Tool

  include MultiVersion

  desc 'Test Tool'
  url ''

  release version: '1.0.0', crystax_version: 1
  release version: '2.0.0', crystax_version: 1
  release version: '3.0.0', crystax_version: 1
  release version: '4.0.0', crystax_version: 1

  include TestToolMethods
end
