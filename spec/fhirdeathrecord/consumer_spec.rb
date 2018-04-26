require 'spec_helper'

RSpec.describe FhirDeathRecord::Consumer do
  it 'converts SDR FHIR XML to nightingale record for fixture 1' do
    require 'json'
    resource = FHIR::Xml.from_xml(File.read('spec/fixtures/fhir/1.xml'))
    contents = JSON.parse(ignore_urn_uuid(FhirDeathRecord::Consumer.from_fhir(resource).to_json.to_s))
    fixture = JSON.parse(ignore_urn_uuid(File.read('spec/fixtures/internal/1.json')))
    expect(contents).to eq(fixture)
  end
  it 'converts SDR FHIR XML to nightingale record for fixture 2' do
    require 'json'
    resource = FHIR::Xml.from_xml(File.read('spec/fixtures/fhir/2.xml'))
    contents = JSON.parse(ignore_urn_uuid(FhirDeathRecord::Consumer.from_fhir(resource).to_json.to_s))
    fixture = JSON.parse(ignore_urn_uuid(File.read('spec/fixtures/internal/2.json')))
    expect(contents).to eq(fixture)
  end
end
