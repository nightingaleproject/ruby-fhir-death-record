namespace :fhirdeathrecord do
  namespace :consumer do
    desc %(
      $ bundle exec rake fhirdeathrecord:consumer:to_nightingale RECORD=spec/fixtures/fhir/1.xml
    )
    task :to_nightingale do
      require 'json'
      resource = FHIR::Xml.from_xml(File.read(ENV['RECORD']))
      contents = FhirDeathRecord::Consumer.from_fhir(resource)
      puts JSON.pretty_generate(JSON.parse(Hash[contents.sort].to_json))
    end
  end
end
