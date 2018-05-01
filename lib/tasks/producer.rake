namespace :fhirdeathrecord do
  namespace :producer do
    desc %(
      $ bundle exec rake fhirdeathrecord:producer:to_fhir_xml RECORD=spec/fixtures/internal/1.json
    )
    task :to_fhir_xml do
      require 'nokogiri'
      require 'json'
      contents = JSON.parse(File.read(ENV['RECORD']))
      source = FhirDeathRecord::Producer.to_fhir({'contents': contents, id: '1'}).to_xml.to_s
      puts Nokogiri::XML(source).to_xml
    end

    desc %(
      $ bundle exec rake fhirdeathrecord:producer:to_fhir_json RECORD=spec/fixtures/internal/1.json
    )
    task :to_fhir_json do
      require 'json'
      contents = JSON.parse(File.read(ENV['RECORD']))
      puts FhirDeathRecord::Producer.to_fhir({'contents': contents, id: '1'}).to_json
    end
  end
end
