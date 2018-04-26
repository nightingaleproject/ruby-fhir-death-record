# Helper module for exporting Nightingale death records as FHIR
module FhirDeathRecord::Producer

  # Given a Nightingale death record, build and return an equivalent FHIR death record bundle
  def self.to_fhir(death_record)
    death_record = death_record.stringify_keys if death_record.is_a? Hash

    # Catagorize values by their LOINC codes (this helps us convert Nightingale's internal
    # death record structure to something that more directly maps to the FHIR death
    # record model)
    death_record_loinc = FhirDeathRecord::Utils.to_loinc(death_record.stringify_keys['contents'])

    # Create a new bundle
    record_id = death_record['id']
    fhir_record = FHIR::Bundle.new(
      'resourceType' => 'Bundle',
      'id' => record_id.to_s,
      'type' => 'document'
    )

    # Create the death record composition
    # https://nightingaleproject.github.io/fhir-death-record/#/volume2/Death-Record-Composition
    composition = FHIR::Composition.new

    # Set the composition type
    composition.type = FHIR::CodeableConcept.new(
      'coding' => {
        'code' => '64297-5',
        'display' => 'Death certificate',
        'system' => 'http://loinc.org'
      }
    )

    # Create a section for the composition
    section = FHIR::Composition::Section.new

    # Set section code
    section.code = FHIR::CodeableConcept.new(
      'coding' => {
        'code' => '69453-9',
        'display' => 'Cause of death',
        'system' => 'http://loinc.org'
      }
    )

    # Create and add the decedent (Patient)
    subject = FhirDeathRecord::Producer.death_decedent(death_record)
    composition.subject = subject.fullUrl
    fhir_record.entry << subject

    # Create and add the certifier (Practitioner)
    author = FhirDeathRecord::Producer.death_certifier(death_record)
    composition.author = author.fullUrl
    fhir_record.entry << author

    # Create and add the cause of death(s) (Conditions)
    cause_of_deaths = []
    cause_of_deaths << FhirDeathRecord::Producer.cause_of_death_condition(death_record_loinc, 0, subject)
    cause_of_deaths << FhirDeathRecord::Producer.cause_of_death_condition(death_record_loinc, 1, subject)
    cause_of_deaths << FhirDeathRecord::Producer.cause_of_death_condition(death_record_loinc, 2, subject)
    cause_of_deaths << FhirDeathRecord::Producer.cause_of_death_condition(death_record_loinc, 3, subject)
    cause_of_deaths.compact!

    # Add the cause of death references to the compositon section
    cause_of_deaths.each do |cod|
      section.entry << cod.fullUrl
    end

    # Add the cause of deaths themselves to the bundle
    fhir_record.entry.push(*cause_of_deaths)

    # Create the observations
    observations = []
    observations << FhirDeathRecord::Producer.actual_or_presumed_date_of_death(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.autopsy_performed(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.autopsy_results_available(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.date_pronounced_dead(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.death_resulted_from_injury_at_work(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.injury_leading_to_death_associated_trans(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.details_of_injury(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.manner_of_death(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.medical_examiner_or_coroner_contacted(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.timing_of_pregnancy_in_relation_to_death(death_record_loinc, subject, death_record)
    observations << FhirDeathRecord::Producer.tobacco_use_contributed_to_death(death_record_loinc, subject, death_record)
    observations.compact!

    # Add the observation references to the compositon section
    observations.each do |obs|
      section.entry << obs.fullUrl
    end

    # Add the observations themselves to the bundle
    fhir_record.entry.push(*observations)

    # Add the section to the composition
    composition.section = section

    # Finally, add the composition itself to the bundle and return the bundle
    fhir_record.entry.unshift(composition) # Make composition the first bundle entry
    fhir_record
  end


  #############################################################################
  # The below section is for building a Patient (the decedent) that is
  # included in a FHIR death record compositon.
  #############################################################################

  # Returns a FHIR entry that covers:
  # https://github.com/nightingaleproject/fhir-death-record/StructureDefinition/Death-Record-Decedent
  #
  # This entry contains a FHIR Patient describing Death-Record-Decedent.
  def self.death_decedent(death_record)
    # Patient options
    options = {}
    # Decedent name
    name = {}
    name['given'] = [death_record['contents']['decedentName.firstName']] unless death_record['contents']['decedentName.firstName'].blank?
    unless death_record['contents']['decedentName.middleName'].blank?
      name['given'] = [] unless name['given']
      name['given'] << death_record['contents']['decedentName.middleName']
    end
    name['family'] = [death_record['contents']['decedentName.lastName']] unless death_record['contents']['decedentName.lastName'].blank?
    name['use'] = 'official'
    options['name'] = [name] unless name.empty?
    # Decedent D.O.B.
    options['birthDate'] = death_record['contents']['dateOfBirth.dateOfBirth'] unless death_record['contents']['dateOfBirth.dateOfBirth'].blank?
    # Date and time of death
    options['deceasedDateTime'] = DateTime.strptime(death_record['contents']['dateOfDeath.dateOfDeath'] + '-' + death_record['contents']['timeOfDeath.timeOfDeath'], '%F-%H:%M').to_s unless death_record['contents']['dateOfDeath.dateOfDeath'].blank? || death_record['contents']['timeOfDeath.timeOfDeath'].blank?
    # Decedent's address
    line = death_record['contents']['decedentAddress.street']
    line += ' ' + death_record['contents']['decedentAddress.apt'] unless line.nil? || death_record['contents']['decedentAddress.apt'].blank?
    address = {}
    address['line'] = [line] unless line.blank?
    address['city'] = death_record['contents']['decedentAddress.city'] unless death_record['contents']['decedentAddress.city'].blank?
    address['state'] = death_record['contents']['decedentAddress.state'] unless death_record['contents']['decedentAddress.state'].blank?
    address['postalCode'] = death_record['contents']['decedentAddress.zip'] unless death_record['contents']['decedentAddress.zip'].blank?
    options['address'] = address
    # Decedent's gender
    options['gender'] = death_record['contents']['sex.sex'].downcase

    # Decedent SSN
    options['identifier'] = {
      'system' => 'http://hl7.org/fhir/sid/us-ssn',
      'value' => "#{death_record['contents']['ssn.ssn1']}#{death_record['contents']['ssn.ssn2']}#{death_record['contents']['ssn.ssn3']}"
    }

    # Build extensions
    options['extension'] = []

    # Decedent race
    race_codes = death_record['contents']['race.race.specify'].gsub(/[^0-9a-z,]/i, ' ')&.split(',').map do |race|
      {
        'url' => 'ombCategory',
        'valueCoding' => {
          'code' => RACE_ETHNICITY_CODES[race.squish]
        }
      }
    end
    race_strings = death_record['contents']['race.race.specify'].gsub(/[^0-9a-z,]/i, ' ')&.split(',').map do |race|
      {
        'url' => 'text',
        'valueString' => race.squish
      }
    end
    options['extension'] << {
      'url' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
      'extension' => race_codes + race_strings
    } if death_record['contents']['race.race.specify']

    # Decedent ethnicity
    ethnicity = death_record['contents']['hispanicOrigin.hispanicOrigin.specify']
    ethnicity = ethnicity.blank? ? { code: '2186-5', display: 'Non Hispanic or Latino' } : { code: '2135-2', display: 'Hispanic or Latino'}
    options['extension'] << {
      'url' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
      'valueCodeableConcept' => {
        'coding' => [{
          'display' => ethnicity.symbolize_keys[:display],
          'code' => ethnicity.symbolize_keys[:code],
          'system' => 'http://hl7.org/fhir/v3/Ethnicity'
        }]
      }
    } if ethnicity

    # Decedent's birth sex
    options['extension'] << {
      'url' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex',
      'valueCode' => death_record['contents']['sex.sex']&.chars&.first
    } if death_record['contents']['sex.sex']

    # Decedent's age at death
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Age-extension',
      'valueUnsignedInt' => FhirDeathRecord::Producer.years_between_dates(death_record['contents']['dateOfBirth.dateOfBirth'], death_record['contents']['dateOfDeath.dateOfDeath'])
    } if death_record['contents']['dateOfBirth.dateOfBirth'] && death_record['contents']['dateOfDeath.dateOfDeath']

    # Decedent place of birth
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Birthplace-extension',
      'valueAddress' => FhirDeathRecord::Producer.build_address_extension(death_record, 'placeOfBirth')
    } if death_record['contents']['placeOfBirth.city'] || death_record['contents']['placeOfBirth.state'] || death_record['contents']['placeOfBirth.zip']

    # Decedent served in armed forces
    served = death_record['contents']['armedForcesService.armedForcesService'] == 'Yes'
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-ServedInArmedForces-extension',
      'valueBoolean' => served
    } if death_record['contents']['armedForcesService.armedForcesService'] && death_record['contents']['armedForcesService.armedForcesService'] != 'Unknown'

    # Decedent marriage status at death
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-MaritalStatusAtDeath-extension',
      'valueCodeableConcept' => {
        'coding' => [{
          'code' => MARITAL_STATUS[death_record['contents']['maritalStatus.maritalStatus']],
          'system' => 'http://hl7.org/fhir/v3/MaritalStatus'
        }]
      }
    } if MARITAL_STATUS[death_record['contents']['maritalStatus.maritalStatus']]

    # Decedent place of death
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-PlaceOfDeath-extension',
      'extension' => [{
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/shr-core-PostalAddress-extension',
        'valueAddress' => FhirDeathRecord::Producer.build_address_extension(death_record, 'locationOfDeath')
      },
      {
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FacilityName-extension',
        'valueString' => death_record['contents']['locationOfDeath.name']
      },
      {
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-PlaceOfDeathType-extension',
        'valueCodeableConcept' => {
          'coding' => [{
            'code' => PLACE_OF_DEATH_TYPE[death_record['contents']['placeOfDeath.placeOfDeath.option']]
          }]
        }
      }]
    }

    # Decedent's disposition
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Disposition-extension',
      'extension' => [{
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-DispositionType-extension',
        'valueCodeableConcept' => {
          'coding' => [{
            'code' => DISPOSITION_TYPE[death_record['contents']['methodOfDisposition.methodOfDisposition.option']]
          }]
        }
      },
      {
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-DispositionFacility-extension',
        'extension' => [{
          'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FacilityName-extension',
          'valueString' => death_record['contents']['placeOfDisposition.name']
        },{
          'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/shr-core-PostalAddress-extension',
          'valueAddress' => FhirDeathRecord::Producer.build_address_extension(death_record, 'placeOfDisposition')
        }]
      },
      {
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FuneralFacility-extension',
        'extension' => [{
          'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FacilityName-extension',
          'valueString' => death_record['contents']['funeralFacility.name']
        },{
          'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/shr-core-PostalAddress-extension',
          'valueAddress' => FhirDeathRecord::Producer.build_address_extension(death_record, 'funeralFacility')
        }]
      }]
    }

    # Decedent's education
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Education-extension',
      'valueCodeableConcept' => {
        'coding' => [{
          'code' => EDUCATION_CODES[death_record['contents']['education.education']]
        }]
      }
    }

    # Decedent's occupation
    options['extension'] << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Occupation-extension',
      'extension' => [{
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Job-extension',
        'valueString' => death_record['contents']['usualOccupation.usualOccupation']
      },
      {
        'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Industry-extension',
        'valueString' => death_record['contents']['kindOfBusiness.kindOfBusiness']
      }]
    }

    # Decedent's mother's maiden name
    options['extension'] << {
      'url' => 'http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName',
      'valueString' => death_record['contents']['motherName.lastName']
    } if death_record['contents']['motherName.lastName']

    patient = FHIR::Patient.new(options)

    # Package patient into entry and return
    entry = FHIR::Bundle::Entry.new
    resource_id = SecureRandom.uuid
    entry.fullUrl = "urn:uuid:#{resource_id}"
    entry.resource = patient
    entry
  end


  #############################################################################
  # The below section is for building a Practitioner (the death certifier)
  # that is included in a FHIR death record compositon.
  #############################################################################

  # Returns a FHIR entry that covers:
  # https://github.com/nightingaleproject/fhir-death-record/StructureDefinition/Death-Certifier
  #
  # This entry contains a FHIR Practitioner describing Death-Certifier.
  def self.death_certifier(death_record)
    # New practitioner
    practitioner = FHIR::Practitioner.new

    extension = FHIR::Extension.new
    extension.url = 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-deathRecord-CertifierType-extension'

    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=1A195A5D-F911-46C6-A58B-4146B722BAB0
    # OID: 2.16.840.1.114222.4.11.6001
    certifier_lookup = {
      'Physician (Certifier)': {concept: '434641000124105', system: 'http://snomed.info/sct', display: 'Physician (Certifier)'},
      'Physician (Pronouncer and Certifier)': {concept: '434651000124107', system: 'http://snomed.info/sct', display: 'Physician (Pronouncer and Certifier)'},
      'Coroner': {concept: '310193003', system: 'http://snomed.info/sct', display: 'Coroner'},
      'Medical Examiner': {concept: '440051000124108', system: 'http://snomed.info/sct', display: 'Medical Examiner'}
    }.stringify_keys
    certifier_type = certifier_lookup[death_record['contents']['certifierType.certifierType']]
    extension.valueCodeableConcept = FHIR::CodeableConcept.new(
      'coding' => {
        'code' => certifier_type[:concept],
        'display' => certifier_type[:display],
        'system' => certifier_type[:system]
      }
    ) unless certifier_type.blank?
    practitioner.extension = extension

    # Certifier name
    name = {}
    name['family'] = [death_record['contents']['personCompletingCauseOfDeathName.lastName']] unless death_record['contents']['personCompletingCauseOfDeathName.lastName'].blank?
    name['given'] = [death_record['contents']['personCompletingCauseOfDeathName.firstName']] unless death_record['contents']['personCompletingCauseOfDeathName.firstName'].blank?
    unless death_record['contents']['personCompletingCauseOfDeathName.middleName'].blank?
      name['given'] = [] unless name['given']
      name['given'] << death_record['contents']['personCompletingCauseOfDeathName.middleName']
    end
    name['suffix'] = death_record['contents']['personCompletingCauseOfDeathName.suffix'] unless death_record['contents']['personCompletingCauseOfDeathName.suffix'].blank?
    practitioner.name = FHIR::HumanName.new(name) unless name.empty?

    # Certifier address
    address = {}
    line = death_record['contents']['personCompletingCauseOfDeathAddress.street']
    line += ' ' + death_record['contents']['personCompletingCauseOfDeathAddress.apt'] unless line.nil? || death_record['contents']['personCompletingCauseOfDeathAddress.apt'].blank?
    address['line'] = [line] unless line.blank?
    address['city'] = death_record['contents']['personCompletingCauseOfDeathAddress.city'] unless death_record['contents']['personCompletingCauseOfDeathAddress.city'].blank?
    address['state'] = death_record['contents']['personCompletingCauseOfDeathAddress.state'] unless death_record['contents']['personCompletingCauseOfDeathAddress.state'].blank?
    address['postalCode'] = death_record['contents']['personCompletingCauseOfDeathAddress.zip'] unless death_record['contents']['personCompletingCauseOfDeathAddress.zip'].blank?
    address['country'] = death_record['contents']['personCompletingCauseOfDeathAddress.country'] unless death_record['contents']['personCompletingCauseOfDeathAddress.country'].blank?
    practitioner.address = FHIR::Address.new(address) unless address.empty?

    # Qualification
    qualification = FHIR::Practitioner::Qualification.new
    qualification.code = FHIR::CodeableConcept.new(
      'coding' => {
        'code' => 'MD', # Assuming MD by default, TODO: Investigate how to better capture this.
        'display' => 'Doctor of Medicine',
        'system' => 'http://hl7.org/fhir/v2/0360/2.7'
      }
    )
    practitioner.qualification = qualification

    # Package practitioner into entry and return
    entry = FHIR::Bundle::Entry.new
    resource_id = SecureRandom.uuid
    entry.fullUrl = "urn:uuid:#{resource_id}"
    entry.resource = practitioner
    entry
  end


  #############################################################################
  # The below section is for building Conditions (causes of deaths) that are
  # included in a FHIR death record compositon.
  #############################################################################

  # Returns a FHIR entry that covers:
  # https://github.com/nightingaleproject/fhir-death-record/StructureDefinition/Cause-of-Death-Condition
  #
  # This entry contains a FHIR Condition describing Cause-of-Death-Condition.
  def self.cause_of_death_condition(death_record_loinc, cod_index, subject)
    # New condition
    condition = FHIR::Condition.new

    # Grab causes and onsets
    causes = death_record_loinc['69453-9']
    return nil if causes.nil? || causes[cod_index].nil? # Return nil if no cause
    onsets = death_record_loinc['69440-6']

    # Grab the causes (and potential onset) for this condition
    cause = causes[cod_index]
    onset = onsets[cod_index] # It's reasonable that this could be nil

    # Set cause
    narrative = FHIR::Narrative.new
    narrative.status = 'additional' # Narrative may contain additional information not found in structured data
    narrative.div = cause
    condition.text = narrative

    # Set onset if it exists
    condition.onsetString = onset unless onset.blank?

    # Set decedent reference
    condition.subject = FHIR::Reference.new
    condition.subject.reference = subject.fullUrl

    # Set clinicalStatus
    condition.clinicalStatus = 'active'

    # Package condition into entry and return
    entry = FHIR::Bundle::Entry.new
    resource_id = SecureRandom.uuid
    entry.fullUrl = "urn:uuid:#{resource_id}"
    entry.resource = condition
    entry
  end


  #############################################################################
  # The below section is for building the various Observations that make up
  # a FHIR death record compositon.
  #############################################################################

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-ActualOrPresumedDateOfDeath
  #
  # This entry contains a FHIR Observation describing Actual-Or-Presumed-Date-Of-Death.
  def self.actual_or_presumed_date_of_death(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '81956-5',
      display: 'Date and time of death',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-ActualOrPresumedDateOfDeath'
    }

    # Convert Nightingale input to the proper FHIR specific output
    obs_value = {
      type: 'valueDateTime',
      value: value.to_s
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-AutopsyPerformed
  #
  # This entry contains a FHIR Observation describing Autopsy-Performed.
  def self.autopsy_performed(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '85699-7',
      display: 'Autopsy was performed',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-AutopsyPerformed'
    }

    # Convert Nightingale input to the proper FHIR specific output
    lookup = {
      'Yes': true,
      'No': false,
    }.stringify_keys
    obs_value = {
      type: 'valueBoolean',
      value: lookup[value]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-AutopsyResultsAvailable
  #
  # This entry contains a FHIR Observation describing Autopsy-Results-Available.
  def self.autopsy_results_available(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '69436-4',
      display: 'Autopsy results available',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-AutopsyResultsAvailable'
    }

    # Convert Nightingale input to the proper FHIR specific output
    lookup = {
      'Yes': true,
      'No': false,
    }.stringify_keys
    obs_value = {
      type: 'valueBoolean',
      value: lookup[value]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DatePronouncedDead
  #
  # This entry contains a FHIR Observation describing Date-Pronounced-Dead.
  def self.date_pronounced_dead(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '80616-6',
      display: 'Date and time pronounced dead',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DatePronouncedDead'
    }

    # Convert Nightingale input to the proper FHIR specific output
    obs_value = {
      type: 'valueDateTime',
      value: value.to_s
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DeathFromWorkInjury
  #
  # This entry contains a FHIR Observation describing Death-Resulted-From-Injury-At-Work.
  def self.death_resulted_from_injury_at_work(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '69444-8',
      display: 'Did death result from injury at work',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DeathFromWorkInjury'
    }

    # Convert Nightingale input to the proper FHIR specific output
    lookup = {
      'Yes': true,
      'No': false
    }.stringify_keys
    obs_value = {
      type: 'valueBoolean',
      value: lookup[value]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DeathFromTransportInjury
  #
  # This entry contains a FHIR Observation describing Injury-Leading-To-Death-Associated-Trans.
  def self.injury_leading_to_death_associated_trans(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '69448-9',
      display: 'Injury leading to death associated with transportation event',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DeathFromTransportInjury'
    }

    # Convert Nightingale input to the proper FHIR specific output
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=F148DC82-63C3-40B1-A7D2-D7AD78416D4A
    # OID: 2.16.840.1.114222.4.11.6005
    lookup = {
      'Vehicle driver': {concept: '236320001', system: 'http://snomed.info/sct', display: 'Vehicle driver'},
      'Passenger': {concept: '257500003', system: 'http://snomed.info/sct', display: 'Passenger'},
      'Pedestrian': {concept: '257518000', system: 'http://snomed.info/sct', display: 'Pedestrian'},
      'Other': {concept: 'OTH', system: 'http://hl7.org/fhir/v3/NullFlavor', display: 'Other'}
    }.stringify_keys
    obs_value = {
      type: 'valueCodeableConcept',
      code: lookup[value][:concept],
      display: lookup[value][:display],
      system: lookup[value][:system]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DetailsOfInjury
  #
  # This entry contains a FHIR Observation describing Details-Of-Injury.
  def self.details_of_injury(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '11374-6',
      display: 'Injury incident description',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DetailsOfInjury'
    }

    obs_value = {
      type: 'valueString',
      value: value,
    }

    # Construct entry
    obs = FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)

    # Injury effective date time
    obs.resource.effectiveDateTime = DateTime.strptime(death_record['contents']['detailsOfInjuryDate.detailsOfInjuryDate'] + '-' + death_record['contents']['detailsOfInjuryTime.detailsOfInjuryTime'], '%F-%H:%M') unless death_record['contents']['detailsOfInjuryDate.detailsOfInjuryDate'].blank? || death_record['contents']['detailsOfInjuryTime.detailsOfInjuryTime'].blank?

    # Extensions
    obs.resource.extension << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-PlaceOfInjury-extension',
      'valueString' => value
    }
    obs.resource.extension << {
      'url' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/shr-core-PostalAddress-extension',
      'valueAddress' => FhirDeathRecord::Producer.build_address_extension(death_record, 'detailsOfInjuryLocation')
    }
    obs
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-MannerOfDeath
  #
  # This entry contains a FHIR Observation describing Manner-Of-Death.
  def self.manner_of_death(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '69449-7',
      display: 'Manner of death',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-MannerOfDeath'
    }

    # Convert Nightingale input to the proper FHIR specific output
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=0D3864B7-5330-410D-BC91-40C1C704BBA4
    # OID: 2.16.840.1.114222.4.11.6002
    lookup = {
      'Natural': {concept: '38605008', system: 'http://snomed.info/sct', display: 'Natural'},
      'Accident': {concept: '7878000', system: 'http://snomed.info/sct', display: 'Accident'},
      'Suicide': {concept: '44301001', system: 'http://snomed.info/sct', display: 'Suicide'},
      'Homicide': {concept: '27935005', system: 'http://snomed.info/sct', display: 'Homicide'},
      'Pending Investigation': {concept: '185973002', system: 'http://snomed.info/sct', display: 'Pending Investigation'},
      'Could not be determined': {concept: '65037004', system: 'http://snomed.info/sct', display: 'Could not be determined'}
    }.stringify_keys
    obs_value = {
      type: 'valueCodeableConcept',
      code: lookup[value][:concept],
      display: lookup[value][:display],
      system: lookup[value][:system]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-MedicalExaminerContacted
  #
  # This entry contains a FHIR Observation describing Medical-Examiner-Or-Coroner-Contacted.
  def self.medical_examiner_or_coroner_contacted(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '74497-9',
      display: 'Medical examiner or coroner was contacted',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-MedicalExaminerContacted'
    }

    # Convert Nightingale input to the proper FHIR specific output
    lookup = {
      'Yes': true,
      'No': false
    }.stringify_keys
    obs_value = {
      type: 'valueBoolean',
      value: lookup[value]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-TimingOfRecentPregnancyInRelationToDeath
  #
  # This entry contains a FHIR Observation describing Timing-Of-Pregnancy-In-Relation-To-Death.
  def self.timing_of_pregnancy_in_relation_to_death(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '69442-2',
      display: 'Timing of recent pregnancy in relation to death',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-TimingOfRecentPregnancyInRelationToDeath'
    }

    # Convert Nightingale input to the proper FHIR specific output
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=C763809B-A38D-4113-8E28-126620B76C2F
    # OID: 2.16.840.1.114222.4.11.6003
    lookup = {
      'Not pregnant within past year': {concept: 'PHC1260', display: 'Not pregnant within past year'},
      'Pregnant at time of death': {concept: 'PHC1261', display: 'Pregnant at time of death'},
      'Not pregnant, but pregnant within 42 days of death': {concept: 'PHC1262', display: 'Not pregnant, but pregnant within 42 days of death'},
      'Not pregnant, but pregnant 43 days to 1 year before death': {concept: 'PHC1263', display: 'Not pregnant, but pregnant 43 days to 1 year before death'},
      'Unknown if pregnant within the past year': {concept: 'PHC1264', display: 'Unknown if pregnant within the past year'},
    }.stringify_keys
    obs_value = {
      type: 'valueCodeableConcept',
      code: lookup[value][:concept],
      display: lookup[value][:display],
      system: lookup[value][:system]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # Returns a FHIR entry that covers:
  # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-TobaccoUseContributedToDeath
  #
  # This entry contains a FHIR Observation describing Tobacco-Use-Contributed-To-Death.
  def self.tobacco_use_contributed_to_death(death_record_loinc, subject, death_record, status = 'final')
    # Coding informations for this observation (helps figure out which part of the record this is)
    obs_code = {
      code: '69443-0',
      display: 'Did tobacco use contribute to death',
      system: 'http://loinc.org'
    }

    # Grab death record value
    value = death_record_loinc[obs_code[:code]]
    return nil unless value # Don't construct observation if the record doesn't have this value

    # Metadata information for this observation
    obs_meta = {
      'profile' => 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-TobaccoUseContributedToDeath'
    }

    # Convert Nightingale input to the proper FHIR specific output
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=FF7F17AE-3D20-473D-9068-E77A08491242
    # OID: 2.16.840.1.114222.4.11.6004
    lookup = {
      'Yes': {concept: '373066001', system: 'http://snomed.info/sct', display: 'Yes'},
      'No': {concept: '373067005', system: 'http://snomed.info/sct', display: 'No'},
      'Probably': {concept: '2931005', system: 'http://snomed.info/sct', display: 'Probably'},
      'Unknown': {concept: 'UNK', system: 'http://hl7.org/fhir/v3/NullFlavor', display: 'Unknown'}
    }.stringify_keys
    obs_value = {
      type: 'valueCodeableConcept',
      code: lookup[value][:concept],
      display: lookup[value][:display],
      system: lookup[value][:system]
    }

    # Construct and return this entry
    FhirDeathRecord::Producer.observation(obs_code, obs_value, obs_meta, subject, status, death_record)
  end

  # FHIR Observation Entry builder
  def self.observation(obs_code, obs_value, obs_meta, obs_subject, obs_status, death_record)
    # New observation
    observation = FHIR::Observation.new

    # Add code (CodeableConcept)
    observation.code = FHIR::CodeableConcept.new(
      'coding' => {
        'code' => obs_code[:code],
        'display' => obs_code[:display],
        'system' => obs_code[:system]
      }
    ) if obs_code

    # Add status
    observation.status = obs_status if obs_status

    # Add metadata
    observation.meta = obs_meta if obs_meta

    # Add subject
    observation.subject = FHIR::Reference.new(
      'reference': obs_subject.fullUrl
    ) if obs_subject

    # Handle type of value
    if obs_value[:type] == 'valueCodeableConcept' # Add valueCodeableConcept (CodeableConcept)
      observation.valueCodeableConcept = FHIR::CodeableConcept.new(
        'coding' => {
          'code' => obs_value[:code],
          'display' => obs_value[:display],
          'system' => obs_value[:system]
        }
      )
    elsif obs_value[:type] == 'valueBoolean' # Add valueBoolean
      observation.valueBoolean = obs_value[:value]
    elsif obs_value[:type] == 'valueDateTime' # Add valueDateTime
      # We need to make sure the date is set as a proper FHIR valueDateTime,
      # thus we need to handle a few situations that might occur given
      # Nightingale user entry.
      # TODO: This needs some polishing...
      date = Date.strptime(obs_value[:value], '%Y-%m-%d') rescue nil # Try date only
      date = Date.parse(obs_value[:value]) unless date # Try regular datetime
      observation.valueDateTime = date.to_datetime.to_s
    elsif obs_value[:type] == 'valueString'
      observation.valueString = obs_value[:value]
    end

    # Package obervation into entry and return
    entry = FHIR::Bundle::Entry.new
    resource_id = SecureRandom.uuid
    entry.fullUrl = "urn:uuid:#{resource_id}"
    entry.resource = observation
    entry
  end


  #############################################################################
  # Type helpers
  #############################################################################

  def self.years_between_dates(date_from, date_to)
    date_to = DateTime.strptime(date_to, '%F')
    date_from = DateTime.strptime(date_from, '%F')
    ((date_to.to_time - date_from.to_time) / 31557600).floor
  end

  def self.build_address_extension(death_record, death_record_key)
    zip = death_record['contents'][death_record_key + '.zip']
    city = death_record['contents'][death_record_key + '.city']
    state = death_record['contents'][death_record_key + '.state']
    country = 'United States' || death_record['contents'][death_record_key + '.country']
    line1 = death_record['contents'][death_record_key + '.street']
    line1 += ' ' + death_record['contents'][death_record_key + '.apt'] unless line1.nil? || death_record['contents'][death_record_key + '.apt'].blank?
    line2 = "#{city} #{state} #{zip}"
    lines = []
    lines << line1.strip.split.join(' ') unless line1.blank?
    lines << line2.strip.split.join(' ') unless line2.blank?
    FHIR::Address.new({country: country, postalCode: zip, city: city, state: state, line: lines, type: 'postal'}).to_hash
  end


  #############################################################################
  # Lookup helpers
  #############################################################################

  EDUCATION_CODES = {
    '8th grade or less' => 'PHC1448',
    '9th through 12th grade; no diploma' => 'PHC1449',
    'High School Graduate or GED Completed' => 'PHC1450',
    'Some college credit, but no degree' => 'PHC1451',
    'Associate Degree' => 'PHC1452',
    "Bachelor's Degree" => 'PHC1453',
    "Master's Degree" => 'PHC1454',
    'Doctorate Degree or Professional Degree' => 'PHC1455',
    'Unknown' => 'UNK',
  }.stringify_keys

  DISPOSITION_TYPE = {
    'Donation' => '449951000124101',
    'Burial' => '449971000124106',
    'Cremation' => '449961000124104',
    'Entombment' => '449931000124108',
    'Removal from state' => '449941000124103',
    'Hospital Disposition' => '455401000124109',
    'Unknown' => 'UNK',
    'Other' => 'OTH',
  }.stringify_keys

  PLACE_OF_DEATH_TYPE = {
    'Dead on arrival at hospital' => '63238001',
    'Death in home' => '440081000124100',
    'Death in hospice' => '440071000124103',
    'Death in hospital' => '16983000',
    'Death in hospital-based emergency department or outpatient department' => '450391000124102',
    'Death in nursing home or long term care facility' => '450381000124100',
    'Unknown' => 'UNK',
    'Other' => 'OTH',
  }.stringify_keys

  MARITAL_STATUS = {
    'Married' => 'M',
    'Married but seperated' => 'M',
    'Widowed' => 'W',
    'Widowed (but not remarried)' => 'W',
    'Divorced (but not remarried)' => 'D',
    'Never married' => 'S',
    'Unknown' => 'UNK',
  }.stringify_keys

  RACE_ETHNICITY_CODES = {
    'White' => '2106-3',
    'Black or African American' => '2054-5',
    'American Indian or Alaskan Native' => '1002-5',
    'Asian' => '2028-5',
    'Native Hawaiian or Other Pacific Islander' => '2076-8',
    'Unkown' => 'UNK'
  }.stringify_keys

end
