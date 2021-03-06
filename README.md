[![Build Status](https://travis-ci.org/nightingaleproject/ruby-fhir-death-record.svg?branch=master)](https://travis-ci.org/nightingaleproject/ruby-fhir-death-record)

# ruby-fhir-death-record

This repository includes a Ruby Gem that provides a module for producing and consuming the preliminary version of the Standard Death Record (SDR) Health Level 7 (HL7) Fast Healthcare Interoperability Resources (FHIR). [Click here to view the generated FHIR IG](https://nightingaleproject.github.io/fhir-death-record).

See spec fixtures for an example of the internal data representation that this module produces-from and consumes-to. This internal data representation corresponds to how Nightingale represents death records internally.

## Installation

Include ruby-fhir-death-record in your Gemfile:
```
gem 'ruby-fhir-death-record', git: 'https://github.com/nightingaleproject/ruby-fhir-death-record.git'
```

Then run `bundle install`.

## Usage

### Consuming Example

```
require 'fhirdeathrecord'

# Create FHIR models from XML
fhir_resource = FHIR::Xml.from_xml(...)

# Convert to internal representation (Hash)
death_record = FhirDeathRecord::Consumer.from_fhir(fhir_resource)
```

### Producing Example

```
require 'fhirdeathrecord'

# Convert internal representation to SDR FHIR
fhir_resource = FhirDeathRecord::Poducer.to_fhir(death_record)

# Print XML
puts fhir_resource.to_xml

# Print JSON
puts fhir_resource.to_json
```

## Rake tasks

This Ruby Gem includes a couple of useful Rake tasks for converting between SDR records in XML format to/from the Nightingale representation.

From SDR FHIR XML (or JSON!) to Nightingale format (prints to stdout):
```
bundle exec rake fhirdeathrecord:consumer:to_nightingale RECORD=spec/fixtures/fhir/1.xml
```

From Nightingale format to SDR FHIR JSON (prints to stdout):
```
bundle exec rake fhirdeathrecord:producer:to_fhir_json RECORD=spec/fixtures/internal/1.json
```

From Nightingale format to SDR FHIR XML (prints to stdout):
```
bundle exec rake fhirdeathrecord:producer:to_fhir_xml RECORD=spec/fixtures/internal/1.json
```
