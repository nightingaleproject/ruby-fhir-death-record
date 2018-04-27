module FhirDeathRecord::Utils
  # Builds mappings from LOINC codes to Nightingale values.
  def self.to_loinc(contents)
    loinc_contents = {}
    # Loop over each value in the record
    contents.each do |value_path, value|
      current = {}
      current['properties'] = self.jsonschemas
      # Dive into the JSON Schema for this value to find the most nested portion
      value_path.split('.').each do |path_step|
        current = current['properties'][path_step]
      end
      # Set the corresponding LOINC code to equal the proper value representation
      if current['loinc'] && current['loinc']['values']
        # This LOINC code has normative answers
        loinc_contents[current['loinc']['code']] = current['loinc']['values'][value]
      elsif current['loinc'] && current['loinc']['index']
        # Multiple values for a single loinc code (probably cause of death and
        # onset to death fields)
        loinc_contents[current['loinc']['code']] = {} unless loinc_contents[current['loinc']['code']]
        loinc_contents[current['loinc']['code']][current['loinc']['index']] = value
      elsif current['loinc']
        # This LOINC code does NOT have normative answers
        loinc_contents[current['loinc']['code']] = value
      end
    end
    return loinc_contents.stringify_keys
  end
  # TODO: This comes from Nightingale, and is generated using the lastest JSON Schemas. Find a way to
  # grab these from there.
  def self.jsonschemas
    {"decedentName"=>{"title"=>"Decedent's Legal Name", "type"=>"object", "showAkas"=>true, "humanReadable"=>"{lastName}, {firstName} {middleName} {suffix}", "required"=>true, "properties"=>{"firstName"=>{"loinc"=>{"code"=>"45392-8"}, "type"=>"string", "title"=>"First Name"}, "middleName"=>{"loinc"=>{"code"=>"45393-6"}, "type"=>"string", "title"=>"Middle Name"}, "lastName"=>{"loinc"=>{"code"=>"45394-4"}, "type"=>"string", "title"=>"Last Name"}, "suffix"=>{"loinc"=>{"code"=>"45395-1"}, "type"=>"string", "title"=>"Suffix"}, "akas"=>{"type"=>"array", "properties"=>{"firstName"=>{"type"=>"string", "title"=>"First Name"}, "middleName"=>{"type"=>"string", "title"=>"Middle Name"}, "lastName"=>{"type"=>"string", "title"=>"Last Name"}, "suffix"=>{"type"=>"string", "title"=>"Suffix"}}}}}, "ssn"=>{"loinc"=>{"code"=>"45396-9"}, "title"=>"Social Security Number", "type"=>"object", "humanReadable"=>"{ssn1}-{ssn2}-{ssn3}", "required"=>true, "properties"=>{"ssn1"=>{"type"=>"string"}, "ssn2"=>{"type"=>"string"}, "ssn3"=>{"type"=>"string"}}}, "decedentAddress"=>{"title"=>"Decedent's Residence", "type"=>"object", "named"=>false, "humanReadable"=>"{street} {apt}\\n{city}, {county}, {state}\\n{zip}", "required"=>true, "properties"=>{"state"=>{"type"=>"string"}, "county"=>{"type"=>"string"}, "city"=>{"type"=>"string"}, "zip"=>{"type"=>"string"}, "street"=>{"type"=>"string"}, "apt"=>{"type"=>"string"}}}, "sex"=>{"type"=>"object", "title"=>"Sex", "humanReadable"=>"{sex}", "required"=>true, "properties"=>{"sex"=>{"options"=>["Male", "Female", "Unknown"], "loinc"=>{"code"=>"21840-4", "values"=>{"Male"=>"1", "Female"=>"2", "Unknown"=>"5"}}}}}, "dateOfBirth"=>{"type"=>"object", "title"=>"Date of Birth", "humanReadable"=>"{dateOfBirth}", "required"=>true, "properties"=>{"dateOfBirth"=>{"type"=>"string"}}}, "placeOfBirth"=>{"title"=>"Place of Birth", "type"=>"object", "named"=>false, "humanReadable"=>"{country}, {state}, {city}", "required"=>true, "properties"=>{"country"=>{"type"=>"string"}, "state"=>{"type"=>"string"}, "city"=>{"type"=>"string"}}}, "armedForcesService"=>{"type"=>"object", "title"=>"Armed Forces Service", "humanReadable"=>"{armedForcesService}", "properties"=>{"armedForcesService"=>{"options"=>["Yes", "No", "Unknown"]}}}, "maritalStatus"=>{"type"=>"object", "title"=>"Marital Status", "humanReadable"=>"{maritalStatus}", "properties"=>{"maritalStatus"=>{"options"=>["Married", "Married but seperated", "Widowed", "Widowed (but not remarried)", "Divorced (but not remarried)", "Never married", "Unknown"]}}}, "education"=>{"type"=>"object", "title"=>"Education", "humanReadable"=>"{education}", "properties"=>{"education"=>{"options"=>["8th grade or less", "9th through 12th grade; no diploma", "High School Graduate or GED Completed", "Some college credit, but no degree", "Associate Degree", "Bachelor's Degree", "Master's Degree", "Doctorate Degree or Professional Degree", "Unknown"]}}}, "hispanicOrigin"=>{"type"=>"object", "title"=>"Hispanic Origin", "humanReadable"=>"{hispanicOrigin}", "properties"=>{"hispanicOrigin"=>{"type"=>"object", "properties"=>{"option"=>{"type"=>"string"}, "specify"=>{"type"=>"string"}, "specifyInputs"=>{"type"=>"string"}}, "options"=>[{"text"=>"Yes", "show"=>"specify1"}, "No", "Refused", "Not Obtainable", "Unknown"], "specifyOptions"=>{"specify1"=>["Mexican, Mexican American, Chicano", "Puerto Rican", "Cuban", {"text"=>"Other Spanish/Hispanic/Latino (specify)", "input"=>true}]}}}}, "race"=>{"type"=>"object", "title"=>"Race", "humanReadable"=>"{race}", "required"=>true, "properties"=>{"race"=>{"type"=>"object", "properties"=>{"option"=>{"type"=>"string"}, "specify"=>{"type"=>"string"}, "specifyInputs"=>{"type"=>"string"}}, "options"=>[{"text"=>"Known", "show"=>"specify1"}, "Refused", "Not Obtainable", "Unknown"], "specifyOptions"=>{"specify1"=>["White", "Black or African American", "American Indian or Alaskan Native", "Asian", "Native Hawaiian or Other Pacific Islander"]}}}}, "usualOccupation"=>{"type"=>"object", "title"=>"Usual Occupation", "humanReadable"=>"{usualOccupation}", "properties"=>{"usualOccupation"=>{"type"=>"string"}}}, "kindOfBusiness"=>{"type"=>"object", "title"=>"Kind Of Business", "humanReadable"=>"{kindOfBusiness}", "properties"=>{"kindOfBusiness"=>{"type"=>"string"}}}, "spouseName"=>{"title"=>"Surviving Spouse's Name", "type"=>"object", "showAkas"=>false, "showMaiden"=>true, "humanReadable"=>"{lastName}, {firstName} {middleName} {suffix}", "properties"=>{"firstName"=>{"type"=>"string", "title"=>"First Name"}, "middleName"=>{"type"=>"string", "title"=>"Middle Name"}, "lastName"=>{"type"=>"string", "title"=>"Last Name"}, "suffix"=>{"type"=>"string", "title"=>"Suffix"}}}, "fatherName"=>{"title"=>"Father's Name", "type"=>"object", "showAkas"=>false, "humanReadable"=>"{lastName}, {firstName} {middleName} {suffix}", "properties"=>{"firstName"=>{"type"=>"string", "title"=>"First Name"}, "middleName"=>{"type"=>"string", "title"=>"Middle Name"}, "lastName"=>{"type"=>"string", "title"=>"Last Name"}, "suffix"=>{"type"=>"string", "title"=>"Suffix"}}}, "motherName"=>{"title"=>"Mother's Name", "type"=>"object", "showAkas"=>false, "showMaiden"=>true, "humanReadable"=>"{lastName}, {firstName} {middleName} {suffix}", "properties"=>{"firstName"=>{"type"=>"string", "title"=>"First Name"}, "middleName"=>{"type"=>"string", "title"=>"Middle Name"}, "lastName"=>{"type"=>"string", "title"=>"Maiden Name"}, "suffix"=>{"type"=>"string", "title"=>"Suffix"}}}, "methodOfDisposition"=>{"type"=>"object", "title"=>"Method of Disposition", "humanReadable"=>"{methodOfDisposition}", "required"=>true, "properties"=>{"methodOfDisposition"=>{"type"=>"object", "properties"=>{"option"=>{"type"=>"string"}, "specify"=>{"type"=>"string"}, "specifyInputs"=>{"type"=>"string"}}, "options"=>["Burial", "Cremation", "Donation", "Entombment", "Removal from State", "Hospital Disposition", "Unknown", "Other"]}}}, "placeOfDisposition"=>{"title"=>"Place of Disposition", "type"=>"object", "named"=>true, "humanReadable"=>"{name}\\n{city}, {state}, {country}", "required"=>true, "properties"=>{"name"=>{"type"=>"string"}, "country"=>{"type"=>"string"}, "state"=>{"type"=>"string"}, "city"=>{"type"=>"string"}}}, "funeralFacility"=>{"title"=>"Funeral Facility", "type"=>"object", "named"=>true, "humanReadable"=>"{name}\\n{street} {apt}\\n{city}, {county}, {state}\\n{zip}", "required"=>true, "properties"=>{"name"=>{"type"=>"string"}, "state"=>{"type"=>"string"}, "county"=>{"type"=>"string"}, "city"=>{"type"=>"string"}, "zip"=>{"type"=>"string"}, "street"=>{"type"=>"string"}, "apt"=>{"type"=>"string"}}}, "funeralLicenseNumber"=>{"title"=>"Funeral Service License Number", "type"=>"object", "humanReadable"=>"{funeralLicenseNumber}", "required"=>true, "properties"=>{"funeralLicenseNumber"=>{"type"=>"string"}}}, "informantName"=>{"title"=>"Informant's Name", "type"=>"object", "showAkas"=>false, "humanReadable"=>"{lastName}, {firstName} {middleName} {suffix}", "required"=>true, "properties"=>{"firstName"=>{"type"=>"string", "title"=>"First Name"}, "middleName"=>{"type"=>"string", "title"=>"Middle Name"}, "lastName"=>{"type"=>"string", "title"=>"Last Name"}, "suffix"=>{"type"=>"string", "title"=>"Suffix"}}}, "informantAddress"=>{"title"=>"Informant's Address", "type"=>"object", "named"=>false, "humanReadable"=>"{street} {apt}\\n{city}, {county}, {state}\\n{zip}", "properties"=>{"state"=>{"type"=>"string"}, "county"=>{"type"=>"string"}, "city"=>{"type"=>"string"}, "zip"=>{"type"=>"string"}, "street"=>{"type"=>"string"}, "apt"=>{"type"=>"string"}}}, "placeOfDeath"=>{"type"=>"object", "title"=>"Place of Death", "humanReadable"=>"{placeOfDeath}", "required"=>true, "properties"=>{"placeOfDeath"=>{"type"=>"object", "properties"=>{"option"=>{"type"=>"string"}, "specify"=>{"type"=>"string"}, "specifyInputs"=>{"type"=>"string"}}, "options"=>["Dead on arrival at hospital", "Death in home", "Death in hospice", "Death in hospital", "Death in hospital-based emergency department or outpatient department", "Death in nursing home or long term care facility", "Unknown", "Other"]}}}, "locationOfDeath"=>{"title"=>"Location of Death", "type"=>"object", "named"=>true, "humanReadable"=>"{name}\\n{street} {apt}\\n{city}, {county}, {state}\\n{zip}", "required"=>true, "properties"=>{"name"=>{"type"=>"string"}, "state"=>{"type"=>"string"}, "county"=>{"type"=>"string"}, "city"=>{"type"=>"string"}, "zip"=>{"type"=>"string"}, "street"=>{"type"=>"string"}, "apt"=>{"type"=>"string"}}}, "datePronouncedDead"=>{"type"=>"object", "title"=>"Date Pronounced Dead", "humanReadable"=>"{datePronouncedDead}", "required"=>true, "properties"=>{"datePronouncedDead"=>{"type"=>"string", "loinc"=>{"code"=>"80616-6"}}}}, "timePronouncedDead"=>{"type"=>"object", "title"=>"Time Pronounced Dead", "humanReadable"=>"{timePronouncedDead}", "required"=>true, "properties"=>{"timePronouncedDead"=>{"type"=>"string"}}}, "pronouncerLicenseNumber"=>{"title"=>"Pronouncer's License Number", "type"=>"object", "humanReadable"=>"{pronouncerLicenseNumber}", "required"=>true, "properties"=>{"pronouncerLicenseNumber"=>{"type"=>"string"}}}, "dateOfPronouncerSignature"=>{"type"=>"object", "title"=>"Date of Pronouncer's Signature", "humanReadable"=>"{dateOfPronouncerSignature}", "required"=>true, "properties"=>{"dateOfPronouncerSignature"=>{"type"=>"string"}}}, "dateOfDeath"=>{"type"=>"object", "title"=>"Date of Death", "showDateType"=>true, "humanReadable"=>"{dateOfDeath}: {dateType}", "required"=>true, "properties"=>{"dateOfDeath"=>{"type"=>"string", "loinc"=>{"code"=>"81956-5"}}, "dateType"=>{"type"=>"string", "options"=>["Actual", "Approximate", "Presumed"]}}}, "timeOfDeath"=>{"type"=>"object", "title"=>"Time of Death", "showTimeType"=>true, "humanReadable"=>"{timeOfDeath}: {timeType}", "required"=>true, "properties"=>{"timeOfDeath"=>{"type"=>"string"}, "timeType"=>{"type"=>"string", "options"=>["Actual", "Approximate", "Presumed"]}}}, "meOrCoronerContacted"=>{"type"=>"object", "title"=>"ME or Coroner Contacted?", "humanReadable"=>"{meOrCoronerContacted}", "properties"=>{"meOrCoronerContacted"=>{"options"=>["Yes", "No"], "loinc"=>{"code"=>"74497-9"}}}}, "autopsyPerformed"=>{"type"=>"object", "title"=>"Autopsy Performed?", "humanReadable"=>"{autopsyPerformed}", "properties"=>{"autopsyPerformed"=>{"options"=>["Yes", "No"], "loinc"=>{"code"=>"85699-7"}}}}, "autopsyAvailableToCompleteCauseOfDeath"=>{"type"=>"object", "title"=>"Autopsy Available to Complete Cause of Death?", "humanReadable"=>"{autopsyAvailableToCompleteCauseOfDeath}", "properties"=>{"autopsyAvailableToCompleteCauseOfDeath"=>{"options"=>["Yes", "No"], "loinc"=>{"code"=>"69436-4"}}}}, "cod"=>{"title"=>"Cause of Death", "type"=>"object", "humanReadable"=>"{immediate}: {immediateInt}\\n{under1}: {under1Int}\\n{under2}: {under2Int}\\n{under3}: {under3Int}", "required"=>true, "properties"=>{"immediate"=>{"type"=>"string", "loinc"=>{"code"=>"69453-9", "index"=>0}}, "immediateInt"=>{"type"=>"string", "loinc"=>{"code"=>"69440-6", "index"=>0}}, "under1"=>{"type"=>"string", "loinc"=>{"code"=>"69453-9", "index"=>1}}, "under1Int"=>{"type"=>"string", "loinc"=>{"code"=>"69440-6", "index"=>1}}, "under2"=>{"type"=>"string", "loinc"=>{"code"=>"69453-9", "index"=>2}}, "under2Int"=>{"type"=>"string", "loinc"=>{"code"=>"69440-6", "index"=>2}}, "under3"=>{"type"=>"string", "loinc"=>{"code"=>"69453-9", "index"=>3}}, "under3Int"=>{"type"=>"string", "loinc"=>{"code"=>"69440-6", "index"=>3}}}}, "contributingCauses"=>{"type"=>"object", "title"=>"Contributing Causes", "humanReadable"=>"{contributingCauses}", "properties"=>{"contributingCauses"=>{"type"=>"string"}}}, "didTobaccoUseContributeToDeath"=>{"type"=>"object", "title"=>"Did Tobacco Use Contribute to Death?", "humanReadable"=>"{didTobaccoUseContributeToDeath}", "properties"=>{"didTobaccoUseContributeToDeath"=>{"options"=>["Yes", "No", "Probably", "Unknown"], "loinc"=>{"code"=>"69443-0"}}}}, "deathResultedFromInjuryAtWork"=>{"type"=>"object", "title"=>"Death Resulted From Injury At Work?", "humanReadable"=>"{deathResultedFromInjuryAtWork}", "properties"=>{"deathResultedFromInjuryAtWork"=>{"options"=>["Yes", "No"], "loinc"=>{"code"=>"69444-8"}}}}, "ifTransInjury"=>{"type"=>"object", "title"=>"If Transportation Injury, Specify:", "humanReadable"=>"{ifTransInjury}", "properties"=>{"ifTransInjury"=>{"options"=>["Vehicle driver", "Passenger", "Pedestrian", "Other"], "loinc"=>{"code"=>"69448-9"}}}}, "detailsOfInjury"=>{"type"=>"object", "title"=>"Details of Injury", "humanReadable"=>"{detailsOfInjury}", "properties"=>{"detailsOfInjury"=>{"type"=>"string", "loinc"=>{"code"=>"11374-6"}}}}, "detailsOfInjuryDate"=>{"type"=>"object", "title"=>"Details of Injury - Date", "humanReadable"=>"{detailsOfInjuryDate}", "properties"=>{"detailsOfInjuryDate"=>{"type"=>"string"}}}, "detailsOfInjuryTime"=>{"type"=>"object", "title"=>"Details of Injury - Time", "humanReadable"=>"{detailsOfInjuryTime}", "properties"=>{"detailsOfInjuryTime"=>{"type"=>"string"}}}, "detailsOfInjuryLocation"=>{"title"=>"Details of Injury - Location", "type"=>"object", "humanReadable"=>"{name}\\n{street} {apt}\\n{city}, {county}, {state}\\n{zip}", "properties"=>{"state"=>{"type"=>"string"}, "county"=>{"type"=>"string"}, "city"=>{"type"=>"string"}, "zip"=>{"type"=>"string"}, "street"=>{"type"=>"string"}, "apt"=>{"type"=>"string"}}}, "pregnancyStatus"=>{"type"=>"object", "title"=>"Pregnancy Status", "humanReadable"=>"{pregnancyStatus}", "properties"=>{"pregnancyStatus"=>{"options"=>["Not pregnant within past year", "Pregnant at time of death", "Not pregnant, but pregnant within 42 days of death", "Not pregnant, but pregnant 43 days to 1 year before death", "Unknown if pregnant within the past year"], "loinc"=>{"code"=>"69442-2"}}}}, "mannerOfDeath"=>{"type"=>"object", "title"=>"Manner of Death", "humanReadable"=>"{mannerOfDeath}", "required"=>true, "properties"=>{"mannerOfDeath"=>{"options"=>["Natural", "Accident", "Suicide", "Homicide", "Pending Investigation", "Could not be determined"], "loinc"=>{"code"=>"69449-7"}}}}, "personCompletingCauseOfDeathName"=>{"title"=>"Name of Person Completing Cause of Death", "type"=>"object", "showAkas"=>false, "humanReadable"=>"{lastName}, {firstName} {middleName} {suffix}", "required"=>true, "properties"=>{"firstName"=>{"type"=>"string", "title"=>"First Name"}, "middleName"=>{"type"=>"string", "title"=>"Middle Name"}, "lastName"=>{"type"=>"string", "title"=>"Last Name"}, "suffix"=>{"type"=>"string", "title"=>"Suffix"}}}, "personCompletingCauseOfDeathAddress"=>{"title"=>"Address of Person Completing Cause of Death", "type"=>"object", "humanReadable"=>"{street} {apt}\\n{city}, {county}, {state}\\n{zip}", "required"=>true, "properties"=>{"state"=>{"type"=>"string"}, "county"=>{"type"=>"string"}, "city"=>{"type"=>"string"}, "zip"=>{"type"=>"string"}, "street"=>{"type"=>"string"}, "apt"=>{"type"=>"string"}}}, "personCompletingCauseOfDeathLicenseNumber"=>{"title"=>"License Number of Person Completing Cause of Death", "type"=>"object", "humanReadable"=>"{personCompletingCauseOfDeathLicenseNumber}", "required"=>true, "properties"=>{"personCompletingCauseOfDeathLicenseNumber"=>{"type"=>"string"}}}, "certifierType"=>{"type"=>"object", "title"=>"Certifier Type", "humanReadable"=>"{certifierType}", "required"=>true, "properties"=>{"certifierType"=>{"options"=>["Physician (Certifier)", "Physician (Pronouncer and Certifier)", "Coroner", "Medical Examiner"]}}}, "dateCertified"=>{"type"=>"object", "title"=>"Date Certified", "humanReadable"=>"{dateCertified}", "required"=>true, "properties"=>{"dateCertified"=>{"type"=>"string"}}}}
  end
end