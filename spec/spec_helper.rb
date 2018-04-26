require 'bundler/setup'
require 'fhirdeathrecord'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def ignore_urn_uuid(contents)
  urn_uuid_pattern = /"urn:uuid.*?"/
  contents.gsub(urn_uuid_pattern) do |match|
    "\"\""
  end
end
