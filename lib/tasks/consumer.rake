namespace :fhirdeathrecord do
  namespace :consumer do
    desc %(
      $ bundle exec rake fhirdeathrecord:consumer:to_nightingale RECORD=spec/fixtures/fhir/1.xml
    )
    task :to_nightingale do
      require 'json'
      record_string = File.read(ENV['RECORD'])
      json_record = JSON.parse(record_string) rescue nil
      resource = FHIR::Xml.from_xml(record_string) unless json_record
      resource = FHIR::Json.from_json(record_string) if json_record
      contents = FhirDeathRecord::Consumer.from_fhir(resource)
      puts JSON.pretty_generate(JSON.parse(Hash[contents.sort].to_json))
    end
  end
end
