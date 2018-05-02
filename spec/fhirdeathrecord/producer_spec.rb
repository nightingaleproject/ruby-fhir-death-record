require 'spec_helper'

RSpec.describe FhirDeathRecord::Producer do
  it 'converts nightingale record to SDR FHIR XML for fixture 1' do
    contents = JSON.parse(File.read('spec/fixtures/internal/1.json'))
    source = FhirDeathRecord::Producer.to_fhir({'contents': contents, id: '1'}).to_xml.to_s
    source = ignore_urn_uuid(Nokogiri::XML(source).to_xml)
    fixture = ignore_urn_uuid(File.read('spec/fixtures/fhir/1.xml'))
    expect(source.gsub(/<date value=".*?"\/>/, '')).to eq(fixture.gsub(/<date value=".*?"\/>/, ''))
  end
  it 'converts nightingale record to SDR FHIR XML for fixture 2' do
    contents = JSON.parse(File.read('spec/fixtures/internal/2.json'))
    source = FhirDeathRecord::Producer.to_fhir({'contents': contents, id: '2'}).to_xml.to_s
    source = ignore_urn_uuid(Nokogiri::XML(source).to_xml)
    fixture = ignore_urn_uuid(File.read('spec/fixtures/fhir/2.xml'))
    expect(source.gsub(/<date value=".*?"\/>/, '')).to eq(fixture.gsub(/<date value=".*?"\/>/, ''))
  end
end
