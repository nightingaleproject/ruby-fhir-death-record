# Helper module for importing FHIR death records into Nightingale
module FhirDeathRecord::Consumer

  # Helper method to get the first and last name of the certifier. This
  # will be used to find the doctor in the system that should own the record
  # once it's been consumed.
  def self.certifier_name(fhir_record)
    consumer = FhirDeathRecord::Consumer.certifier(fhir_record.entry[2])
    [consumer['personCompletingCauseOfDeathName.firstName'], consumer['personCompletingCauseOfDeathName.lastName']]
  end

  # Given a FHIR death record, build and return an equivalent Nightingle contents
  # structure (that can be used to create/update the information in a
  # Nightingale death record).
  def self.from_fhir(fhir_record)
    contents = {}

    # TODO: Find a better way to figure out what entry is what

    # Grab decedent and certifier
    contents.merge! FhirDeathRecord::Consumer.decedent(fhir_record.entry[1])
    contents.merge! FhirDeathRecord::Consumer.certifier(fhir_record.entry[2])

    # Grab potential conditions
    index = 3
    (3..6).each do |c|
      entry = fhir_record.entry[c]
      # Stop checking if we've exhausted the cause of deaths
      break unless !entry.nil? && !entry.resource.nil? && entry.resource.text.present? && entry.resource.respond_to?('onsetString')
      index += 1
      contents.merge! FhirDeathRecord::Consumer.cause_of_death_condition(entry, c-3)
    end

    # Grab observations
    (index..fhir_record.entry.count-1).each do |o|
      entry = fhir_record.entry[o]
      case entry&.resource&.code&.coding&.first&.code
      when '81956-5'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-ActualOrPresumedDateOfDeath
        contents.merge! FhirDeathRecord::Consumer.actual_or_presumed_date_of_death(entry)
      when '85699-7'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-AutopsyPerformed
        contents.merge! FhirDeathRecord::Consumer.autopsy_performed(entry)
      when '69436-4'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-AutopsyResultsAvailable
        contents.merge! FhirDeathRecord::Consumer.autopsy_results_available(entry)
      when '80616-6'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DatePronouncedDead
        contents.merge! FhirDeathRecord::Consumer.date_pronounced_dead(entry)
      when '69444-8'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DeathFromWorkInjury
        contents.merge! FhirDeathRecord::Consumer.death_resulted_from_injury_at_work(entry)
      when '69448-9'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DeathFromTransportInjury
        contents.merge! FhirDeathRecord::Consumer.injury_leading_to_death_associated_trans(entry)
      when '11374-6'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-DetailsOfInjury
        contents.merge! FhirDeathRecord::Consumer.details_of_injury(entry)
      when '69449-7'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-MannerOfDeath
        contents.merge! FhirDeathRecord::Consumer.manner_of_death(entry)
      when '74497-9'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-MedicalExaminerContacted
        contents.merge! FhirDeathRecord::Consumer.medical_examiner_or_coroner_contacted(entry)
      when '69442-2'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-TimingOfRecentPregnancyInRelationToDeath
        contents.merge! FhirDeathRecord::Consumer.timing_of_pregnancy_in_relation_to_death(entry)
      when '69443-0'
        # http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-causeOfDeath-TobaccoUseContributedToDeath
        contents.merge! FhirDeathRecord::Consumer.tobacco_use_contributed_to_death(entry)
      end
    end

    contents
  end


  #############################################################################
  # The below section is for consuming the FHIR death record decedent
  # information that is included in a FHIR death record.
  #############################################################################

  # Returns decedent information in Nightingale form given a FHIR death record.
  def self.decedent(decedent_entry)
    return {} if decedent_entry.blank?
    patient = decedent_entry.resource
    decedent = {}
    # Handle name
    if patient.name && patient.name.length > 0
      name = patient.name.first
      decedent['decedentName.firstName'] = name.given.first if name.given && name.given.first.present?
      # All subsequent 'given' names will be combined and included as the 'middle name'
      decedent['decedentName.middleName'] = name.given.drop(1).join(' ') if name.given && name.given.drop(1).any? && !name.given.drop(1).join(' ').blank?
      # All 'family' names will be combined and included as the 'last name'
      if name.family.is_a?(Array)
        decedent['decedentName.lastName'] = name.family.join(' ') if name.family && name.family.any?
      else
        decedent['decedentName.lastName'] = name.family
      end
      decedent['decedentName.suffix'] = name.suffix.join(' ') if name.suffix && name.suffix.any? && !name.suffix.join(' ').blank?
    end
    # Handle date of birth
    decedent['dateOfBirth.dateOfBirth'] = patient.birthDate if patient.birthDate.present?
    # Handle date and time of death
    if patient.deceasedDateTime.present?
      dateTime = DateTime.parse(patient.deceasedDateTime)
      decedent['dateOfDeath.dateOfDeath'] = dateTime.strftime('%F')
      decedent['timeOfDeath.timeOfDeath'] = dateTime.strftime('%H:%M')
    end
    # Handle address
    if patient.address.present?
      address = patient.address.first
      decedent['decedentAddress.street'] = address.line.first if address.line && address.line.first.present?
      decedent['decedentAddress.city'] = address.city.strip if address.city.present?
      decedent['decedentAddress.state'] = address.state.strip if address.state.present?
      decedent['decedentAddress.zip'] = address.postalCode.strip if address.postalCode.present?
    end
    # Handle SSN
    if patient.identifier.present? && patient.identifier.is_a?(Array) && !patient.identifier.first.nil?
      ssn = patient.identifier.first.value
      decedent['ssn.ssn1'] = ssn[0..2] if ssn.length == 9
      decedent['ssn.ssn2'] = ssn[3..4] if ssn.length == 9
      decedent['ssn.ssn3'] = ssn[5..8] if ssn.length == 9
    end
    # The following are extensions
    patient.extension.each do |extension|
      case extension.url
      when 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
        # Handle race
        codes = []
        extension.extension.each do |sub_extension|
          case sub_extension.url
          when 'text'
            codes << sub_extension.valueString
          end
        end
        unless codes.empty?
          decedent['race.race.option'] = 'Known'
          decedent['race.race.specify'] = codes.to_json
        end
      when 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'
        # Handle ethnicity
        if extension.valueCodeableConcept&.coding&.first&.display != nil
          ethnicity = extension.valueCodeableConcept&.coding.first.display
          if ethnicity == 'Hispanic or Latino'
            decedent['hispanicOrigin.hispanicOrigin.specify'] = 'Hispanic or Latino'
            decedent['hispanicOrigin.hispanicOrigin.option'] = 'Yes'
          else
            decedent['hispanicOrigin.hispanicOrigin.specify'] = ''
            decedent['hispanicOrigin.hispanicOrigin.option'] = 'No'
          end
        end
      when 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'
        # Handle sex
        sex = if extension.valueCode == 'M'
          'Male'
        elsif extension.valueCode == 'F'
          'Female'
        elsif extension.valueCode == 'U'
          'Unknown'
        end
        decedent['sex.sex'] = sex if sex.present?
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Age-extension'
        # TODO: Don't need?
      when 'http://hl7.org/fhir/StructureDefinition/birthPlace'
        # Handle birth place
        address = extension.valueAddress
        if address
          decedent['placeOfBirth.zip'] = address.postalCode if address.postalCode.present?
          decedent['placeOfBirth.city'] = address.city if address.city.present?
          decedent['placeOfBirth.state'] = address.state if address.state.present?
          decedent['placeOfBirth.country'] = address.country if address.country.present?
          decedent['placeOfBirth.street'] = address.line.first if address.line && address.line.any? && address.line.count > 0
        end
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-ServedInArmedForces-extension'
        served = extension.valueBoolean ? 'Yes' : 'No'
        decedent['armedForcesService.armedForcesService'] = served
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-MaritalStatusAtDeath-extension'
        marital_status = MARITAL_STATUS[extension.valueCodeableConcept&.coding.first.code]
        decedent['maritalStatus.maritalStatus'] = marital_status
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-PlaceOfDeath-extension'
        extension.extension.each do |sub_extension|
          case sub_extension.url
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/shr-core-PostalAddress-extension'
            decedent['locationOfDeath.city'] = sub_extension.valueAddress.city.strip if sub_extension.valueAddress.city.present?
            decedent['locationOfDeath.state'] = sub_extension.valueAddress.state.strip if sub_extension.valueAddress.state.present?
            decedent['locationOfDeath.zip'] = sub_extension.valueAddress.postalCode.strip if sub_extension.valueAddress.postalCode.present?
            decedent['locationOfDeath.county'] = sub_extension.valueAddress.district.strip if sub_extension.valueAddress.district.present?
            decedent['locationOfDeath.street'] = sub_extension.valueAddress.line.first if sub_extension.valueAddress.line && sub_extension.valueAddress.line.count > 0
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FacilityName-extension'
            decedent['locationOfDeath.name'] = sub_extension.valueString
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-PlaceOfDeathType-extension'
            decedent['placeOfDeath.placeOfDeath.option'] = PLACE_OF_DEATH_TYPE[sub_extension.valueCodeableConcept&.coding.first.code]
          end
        end
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Disposition-extension'
        extension.extension.each do |sub_extension|
          case sub_extension.url
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-DispositionType-extension'
            decedent['methodOfDisposition.methodOfDisposition.option'] = DISPOSITION_TYPE[sub_extension.valueCodeableConcept&.coding.first.code]
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-DispositionFacility-extension'
            sub_extension.extension.each do |sub_sub_extension|
              case sub_sub_extension.url
              when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FacilityName-extension'
                decedent['placeOfDisposition.name'] = sub_sub_extension.valueString
              when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/shr-core-PostalAddress-extension'
                decedent['placeOfDisposition.city'] = sub_sub_extension.valueAddress.city.strip if sub_sub_extension.valueAddress.city.present?
                decedent['placeOfDisposition.state'] = sub_sub_extension.valueAddress.state.strip if sub_sub_extension.valueAddress.state.present?
                decedent['placeOfDisposition.zip'] = sub_sub_extension.valueAddress.postalCode.strip if sub_sub_extension.valueAddress.postalCode.present?
                decedent['placeOfDisposition.country'] = sub_sub_extension.valueAddress.country.strip if sub_sub_extension.valueAddress.country.present?
                decedent['placeOfDisposition.street'] = sub_sub_extension.valueAddress.line.first if sub_sub_extension.valueAddress.line && sub_sub_extension.valueAddress.line.count > 0
              end
            end
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FuneralFacility-extension'
            sub_extension.extension.each do |sub_sub_extension|
              case sub_sub_extension.url
              when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-FacilityName-extension'
                decedent['funeralFacility.name'] = sub_sub_extension.valueString
              when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/shr-core-PostalAddress-extension'
                decedent['funeralFacility.city'] = sub_sub_extension.valueAddress.city.strip if sub_sub_extension.valueAddress.city.present?
                decedent['funeralFacility.state'] = sub_sub_extension.valueAddress.state.strip if sub_sub_extension.valueAddress.state.present?
                decedent['funeralFacility.zip'] = sub_sub_extension.valueAddress.postalCode.strip if sub_sub_extension.valueAddress.postalCode.present?
                decedent['funeralFacility.street'] = sub_sub_extension.valueAddress.line.first if sub_sub_extension.valueAddress.line && sub_sub_extension.valueAddress.line.count > 0
              end
            end
          end
        end
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Education-extension'
        decedent['education.education'] = EDUCATION_CODES[extension.valueCodeableConcept&.coding.first.code]
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Birthplace-extension'
        decedent['placeOfBirth.city'] = extension.valueAddress.city if extension.valueAddress.city.present?
        decedent['placeOfBirth.state'] = extension.valueAddress.state if extension.valueAddress.state.present?
        decedent['placeOfBirth.zip'] = extension.valueAddress.postalCode.strip if extension.valueAddress.postalCode.present?
        decedent['placeOfBirth.country'] = extension.valueAddress.country.strip if extension.valueAddress.country.present?
        decedent['placeOfBirth.street'] = extension.valueAddress.line.first if extension.valueAddress.line && extension.valueAddress.line.count > 0
      when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Occupation-extension'
        extension.extension.each do |sub_extension|
          case sub_extension.url
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Job-extension'
            decedent['usualOccupation.usualOccupation'] = sub_extension.valueString
          when 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-decedent-Industry-extension'
            decedent['kindOfBusiness.kindOfBusiness'] = sub_extension.valueString
          end
        end
      when 'http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName'
        decedent['motherName.lastName'] = extension.valueString
      end
    end

    decedent
  end


  #############################################################################
  # The below section is for consuming the FHIR death certifier information
  # that is included in a FHIR death record.
  #############################################################################

  # Returns certifier information in Nightingale form given a FHIR death record.
  def self.certifier(certifier_entry)
    return {} if certifier_entry.blank?
    practitioner = certifier_entry.resource
    certifier = {}
    # Handle name
    if practitioner.name && practitioner.name.length > 0
      name = practitioner.name.first
      certifier['personCompletingCauseOfDeathName.firstName'] = name.given.first if name.given && name.given.first.present?
      # All subsequent 'given' names will be combined and included as the 'middle name'
      certifier['personCompletingCauseOfDeathName.middleName'] = name.given.drop(1).join(' ') if name.given && name.given.drop(1).any? && !name.given.drop(1).join(' ').blank?
      # All 'family' names will be combined and included as the 'last name'
      if name.family.is_a?(Array)
        certifier['personCompletingCauseOfDeathName.lastName'] = name.family.join(' ') if name.family && name.family.any?
      else
        certifier['personCompletingCauseOfDeathName.lastName'] = name.family
      end
      certifier['personCompletingCauseOfDeathName.suffix'] = name.suffix.join(' ') if name.suffix && name.suffix.any? && !name.suffix.join(' ').blank?
    end
    # Handle address
    if practitioner.address.present?
      address = practitioner.address.first
      certifier['personCompletingCauseOfDeathAddress.street'] = address.line.first if address.line && address.line.first.present?
      certifier['personCompletingCauseOfDeathAddress.city'] = address.city.strip if address.city.present?
      certifier['personCompletingCauseOfDeathAddress.state'] = address.state.strip if address.state.present?
      certifier['personCompletingCauseOfDeathAddress.zip'] = address.postalCode.strip if address.postalCode.present?
      certifier['personCompletingCauseOfDeathAddress.street'] = address.line.first if address.line && address.line.count > 0
    end
    # Handle type
    certifier_lookup = {
      '434641000124105': 'Physician (Certifier)',
      '434651000124107': 'Physician (Pronouncer and Certifier)',
      '310193003': 'Coroner',
      '440051000124108': 'Medical Examiner',
    }.stringify_keys
    if practitioner.extension && practitioner.extension.any?
      practitioner.extension.each do |extension|
        if extension.url == 'http://nightingaleproject.github.io/fhirDeathRecord/StructureDefinition/sdr-deathRecord-CertifierType-extension'
          certifier['certifierType.certifierType'] = certifier_lookup[extension.valueCodeableConcept&.coding&.first&.code] if extension.valueCodeableConcept&.coding&.first&.code
        end
      end
    end
    # NOTE: Certifier qualification is not used in Nightingale

    certifier
  end


  #############################################################################
  # The below section is for consuming FHIR Conditions (causes of deaths)
  # that are included in a FHIR death record.
  #############################################################################

  # Consume FHIR death record Cause-of-Death-Condition.
  def self.cause_of_death_condition(cod_entry, index)
    cause = cod_entry.resource
    cod = {}
    if index == 0
      cod['cod.immediate'] = cause.text.div.gsub(/<.*?>/, '') if cause.text && cause.text.div.present?
      cod['cod.immediateInt'] = cause.onsetString if cause.onsetString.present?
    else
      cod['cod.under' + index.to_s] = cause.text.div.gsub(/<.*?>/, '') if cause.text && cause.text.div.present?
      cod['cod.under' + index.to_s + 'Int'] = cause.onsetString if cause.onsetString.present?
    end
    cod
  end


  #############################################################################
  # The below section is for consuming the various Observations that are
  # included in a FHIR death record.
  #############################################################################

  # Consume FHIR death record Actual-Or-Presumed-Date-Of-Death.
  def self.actual_or_presumed_date_of_death(entry)
    observation = {}
    dateTime = DateTime.parse(entry.resource.valueDateTime)
    observation['dateOfDeath.dateOfDeath'] = dateTime.strftime('%F')
    observation['timeOfDeath.timeOfDeath'] = dateTime.strftime('%H:%M')
    observation
  end

  # Consume FHIR death record Autopsy-Performed.
  def self.autopsy_performed(entry)
    observation = {}

    value = if entry.resource.valueBoolean == true
              'Yes'
            elsif entry.resource.valueBoolean == false
              'No'
            end

    observation['autopsyPerformed.autopsyPerformed'] = value
    observation
  end

  # Consume FHIR death record Autopsy-Results-Available.
  def self.autopsy_results_available(entry)
    observation = {}

    value = if entry.resource.valueBoolean == true
              'Yes'
            elsif entry.resource.valueBoolean == false
              'No'
            end

    observation['autopsyAvailableToCompleteCauseOfDeath.autopsyAvailableToCompleteCauseOfDeath'] = value
    observation
  end

  # Consume FHIR death record Date-Pronounced-Dead.
  def self.date_pronounced_dead(entry)
    observation = {}
    dateTime = DateTime.parse(entry.resource.valueDateTime)
    observation['datePronouncedDead.datePronouncedDead'] = dateTime.strftime('%F')
    observation['timePronouncedDead.timePronouncedDead'] = dateTime.strftime('%H:%M')
    observation
  end

  # Consume FHIR death record Death-Resulted-From-Injury-At-Work.
  def self.death_resulted_from_injury_at_work(entry)
    observation = {}

    value = if entry.resource.valueBoolean == true
              'Yes'
            elsif entry.resource.valueBoolean == false
              'No'
            end

    observation['deathResultedFromInjuryAtWork.deathResultedFromInjuryAtWork'] = value
    observation
  end

  # Consume FHIR death record Injury-Leading-To-Death-Associated-Trans.
  def self.injury_leading_to_death_associated_trans(entry)
    observation = {}

    # Convert Nightingale input to the proper FHIR specific output
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=F148DC82-63C3-40B1-A7D2-D7AD78416D4A
    # OID: 2.16.840.1.114222.4.11.6005
    lookup = {
      '236320001': 'Vehicle Driver',
      '257500003': 'Passenger',
      '257518000': 'Pedestrian',
      'OTH': 'Other',
  }.stringify_keys
    observation['ifTransInjury.ifTransInjury'] = lookup[entry.resource.valueCodeableConcept.coding.first.code]
    observation
  end

  # Consume FHIR death record Details-Of-Injury.
  def self.details_of_injury(entry)
    observation = {}
    observation['detailsOfInjury.detailsOfInjury'] = entry.resource.valueString
    observation['detailsOfInjuryLocation.city'] = entry.resource.extension.last.valueAddress.city
    observation['detailsOfInjuryLocation.state'] = entry.resource.extension.last.valueAddress.state
    observation['detailsOfInjuryLocation.zip'] = entry.resource.extension.last.valueAddress.postalCode
    observation['detailsOfInjuryLocation.street'] = entry.resource.extension.last.valueAddress.line.first if entry.resource.extension.last.valueAddress.line && entry.resource.extension.last.valueAddress.line.count > 0
    date_time = DateTime.parse(entry.resource.effectiveDateTime)
    observation['detailsOfInjuryDate.detailsOfInjuryDate'] = date_time.strftime('%F')
    observation['detailsOfInjuryTime.detailsOfInjuryTime'] = date_time.strftime('%H:%M')
    observation['detailsOfInjuryLocation.name'] = entry.resource.extension.first.valueString
    observation
  end

  # Consume FHIR death record Manner-Of-Death.
  def self.manner_of_death(entry)
    observation = {}

    # Convert FHIR information for use in Nightingale
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=0D3864B7-5330-410D-BC91-40C1C704BBA4
    # OID: 2.16.840.1.114222.4.11.6002
    lookup = {
      '38605008': 'Natural',
      '7878000': 'Accident',
      '44301001': 'Suicide',
      '27935005': 'Homicide',
      '185973002': 'Pending Investigation',
      '65037004': 'Could not be determined'
    }.stringify_keys

    observation['mannerOfDeath.mannerOfDeath'] = lookup[entry.resource.valueCodeableConcept.coding.first.code]
    observation
  end

  # Consume FHIR death record Medical-Examiner-Or-Coroner-Contacted.
  def self.medical_examiner_or_coroner_contacted(entry)
    observation = {}

    value = if entry.resource.valueBoolean == true
              'Yes'
            elsif entry.resource.valueBoolean == false
              'No'
            end

    observation['meOrCoronerContacted.meOrCoronerContacted'] = value
    observation
  end

  # Consume FHIR death record Timing-Of-Pregnancy-In-Relation-To-Death.
  def self.timing_of_pregnancy_in_relation_to_death(entry)
    observation = {}

    # Convert FHIR information for use in Nightingale
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=C763809B-A38D-4113-8E28-126620B76C2F
    # OID: 2.16.840.1.114222.4.11.6003
    lookup = {
      'PHC1260': 'Not pregnant within past year',
      'PHC1261': 'Pregnant at time of death',
      'PHC1262': 'Not pregnant, but pregnant within 42 days of death',
      'PHC1263': 'Not pregnant, but pregnant 43 days to 1 year before death',
      'PHC1264': 'Unknown if pregnant within the past year',
      'N/A': 'Not pregnant within past year' # 'not applicable' is not shown in Nightingale, use 'Not pregnant within past year' instead
    }.stringify_keys

    observation['pregnancyStatus.pregnancyStatus'] = lookup[entry.resource.valueCodeableConcept.coding.first.code]
    observation
  end

  # Consume FHIR death record Tobacco-Use-Contributed-To-Death.
  def self.tobacco_use_contributed_to_death(entry)
    observation = {}

    # Convert FHIR information for use in Nightingale
    # See: https://phinvads.cdc.gov/vads/ViewValueSet.action?id=FF7F17AE-3D20-473D-9068-E77A08491242
    # OID: 2.16.840.1.114222.4.11.6004
    lookup = {
      '373066001': 'Yes',
      '373067005': 'No',
      '2931005': 'Probably',
      'UNK': 'Unknown',
      'NASK': 'Unknown' # 'not asked' is not shown in Nightingale, use 'Unkown' instead
    }.stringify_keys

    observation['didTobaccoUseContributeToDeath.didTobaccoUseContributeToDeath'] = lookup[entry.resource.valueCodeableConcept.coding.first.code]
    observation
  end


  #############################################################################
  # Lookup helpers
  #############################################################################

  EDUCATION_CODES = {
    'PHC1448' => '8th grade or less',
    'PHC1449' => '9th through 12th grade; no diploma',
    'PHC1450' => 'High School Graduate or GED Completed',
    'PHC1451' => 'Some college credit, but no degree',
    'PHC1452' => 'Associate Degree',
    'PHC1453' => "Bachelor's Degree",
    'PHC1454' => "Master's Degree",
    'PHC1455' => 'Doctorate Degree or Professional Degree',
    'UNK' => 'Unknown',
  }.stringify_keys

  DISPOSITION_TYPE = {
    '449951000124101' => 'Donation',
    '449971000124106' => 'Burial',
    '449961000124104' => 'Cremation',
    '449931000124108' => 'Entombment',
    '449941000124103' => 'Removal from state',
    '455401000124109' => 'Hospital Disposition',
    'UNK' => 'Unknown',
    'OTH' => 'Other',
  }.stringify_keys

  PLACE_OF_DEATH_TYPE = {
    '63238001' => 'Dead on arrival at hospital',
    '440081000124100' => 'Death in home',
    '440071000124103' => 'Death in hospice',
    '16983000' => 'Death in hospital',
    '450391000124102' => 'Death in hospital-based emergency department or outpatient department',
    '450381000124100' => 'Death in nursing home or long term care facility',
    'UNK' => 'Unknown',
    'OTH' => 'Other',
  }.stringify_keys

  MARITAL_STATUS = {
    'M' => 'Married',
    'W' => 'Widowed',
    'D' => 'Divorced (but not remarried)',
    'S' => 'Never married',
    'UNK' => 'Unknown',
  }.stringify_keys

  RACE_ETHNICITY_CODES = {
    '2106-3' => 'White',
    '2054-5' => 'Black or African American',
    '1002-5' => 'American Indian or Alaskan Native',
    '2028-5' => 'Asian',
    '2076-8' => 'Native Hawaiian or Other Pacific Islander',
    'UNK' => 'Unkown',
  }.stringify_keys

end
