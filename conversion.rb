require 'linkeddata'
require 'nokogiri'
require_relative 'lib/configuration.rb'
require_relative 'lib/access_db.rb'
require_relative 'lib/linked_db.rb'
require_relative 'lib/convert_mandatees.rb'
require_relative 'lib/convert_reference_document.rb'
require_relative 'lib/convert_regulation_type.rb'
require_relative 'lib/convert_government_domains.rb'
require_relative 'lib/update_number_of_pages.rb'
require_relative 'lib/update_number_of_extracts.rb'

BASE_URI = 'http://themis.vlaanderen.be/id/%{resource}/%{id}'
CONCEPT_URI = 'http://themis.vlaanderen.be/id/concept/%{resource}/%{id}'

FOAF = RDF::Vocab::FOAF
ADMS = RDF::Vocabulary.new("http://www.w3.org/ns/adms#")
SKOS = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
PROV = RDF::Vocabulary.new("http://www.w3.org/ns/prov#")
GENERIEK = RDF::Vocabulary.new("https://data.vlaanderen.be/ns/generiek#")
PUB = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/publicatie/")
MANDAAT = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/mandaat#")
DOSSIER = RDF::Vocabulary.new("https://data.vlaanderen.be/ns/dossier#")
BESLUIT = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/besluit#")
BESLUITVORMING = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/besluitvorming#")
ELI = RDF::Vocabulary.new("http://data.europa.eu/eli/ontology#")
EXT = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/")
DCT = RDF::Vocabulary.new("http://purl.org/dc/terms/")
TMO = RDF::Vocabulary.new("http://www.semanticdesktop.org/ontologies/2008/05/20/tmo#")
FABIO = RDF::Vocabulary.new("http://purl.org/spar/fabio/")
RDFS = RDF::Vocabulary.new("https://www.w3.org/2000/01/rdf-schema#")

PUBLICATIEWIJZE_UITTREKSEL = RDF::URI "http://themis.vlaanderen.be/id/concept/publicatie-wijze/bd49553f-39af-4b47-9550-1662e1bde7e6"
PUBLICATIEWIJZE_EXTENSO = RDF::URI "http://themis.vlaanderen.be/id/concept/publicatie-wijze/5659be06-3361-46b2-a0dd-69b4e6adb7e4"

REGELGEVING_TYPE_DECREET = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/bf6101a9-d06b-44d4-b629-13965654c8c2";
REGELGEVING_TYPE_BVR = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/ea7f5f79-f81c-459b-a0f7-d8e90e2d9b88";
REGELGEVING_TYPE_MB = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/49bad4d9-745b-4a71-b6c6-0eac34e6bdd4";
REGELGEVING_TYPE_BESLUIT = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/77808a0d-b080-4750-8e1c-8e8bfc609cd1";
REGELGEVING_TYPE_BERICHT = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/e580b153-8ba3-4450-84b8-87c50a60870c";
REGELGEVING_TYPE_OMZENDBRIEF = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/d34bdc39-48ac-4743-a7cd-de25105fddf2";
REGELGEVING_TYPE_KB = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/b7f2fd2c-2a33-4745-bb66-f969d846356f";
REGELGEVING_TYPE_ERRATUM = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/02d57dd4-bc84-4dd3-8a85-7e3ac4af2a7e";
REGELGEVING_TYPE_ANDERE = RDF::URI "http://themis.vlaanderen.be/id/concept/regelgeving-type/0916ac88-1a96-4e6b-a87b-b7f6dd4d9652";

PUBLIC_GRAPH = "http://mu.semte.ch/graphs/public"
KANSELARIJ_GRAPH = "http://mu.semte.ch/graphs/organizations/kanselarij"

DATASOURCE = RDF::URI "http://vlaanderen.be/dossier-opvolging-access-db/DOSSIEROPVOLGING-H.xml"
PROVISIONAL_BELEIDSDOMEIN_FULL_NAME = PUB['beleidsdomein#provisioir']

PUBLICATIE_STATUS_TE_PUBLICEREN = RDF::URI "http://themis.vlaanderen.be/id/concept/publicatie-status/fa62e050-3960-440d-bed9-1c3d3e9923a8"
PUBLICATIE_STATUS_GEPUBLICEERD = RDF::URI "http://themis.vlaanderen.be/id/concept/publicatie-status/2f8dc814-bd91-4bcf-a823-baf1cdc42475"

def run(publicaties, actions)
  Mu.log.info "[STARTED] Starting publication legacy conversion"

  if actions.include? "validate"
    errors = ConvertGovernmentDomains.validate publicaties.map { |n| AccessDB.record n }
    if errors.any?
      raise StandardError.new errors.join('\n')
    end
  end

  if actions.include? "convert"
    file_timestamp = DateTime.now.strftime("%Y%m%d%H%M%S")
    publications_ttl_output_file_name = "legacy-publications"
    publications_ttl_output_file = "#{Configuration::Environment.output_dir}/#{file_timestamp}-#{publications_ttl_output_file_name}"

    $errors_csv = CSV.open(
      "#{Configuration::Environment.output_dir}/#{file_timestamp}-errors.csv", mode="a+", encoding: "UTF-8")

    Mu.log.info "-- Input file : #{AccessDB.input_file}"
    Mu.log.info "-- Output file : #{publications_ttl_output_file}"

    $kanselarij_graph = RDF::Graph.new

    batch_number = 1
    batch_size = 1000
    publicaties.each_with_index do |publicatie, index|
      dossiernummer = publicatie.css('dossiernummer').text
      Mu.log.info "Processing dossiernummer #{dossiernummer} (#{index + 1}/#{publicaties.size}) ... "
      process_publicatie publicatie
      Mu.log.info "Processing dossiernummer #{dossiernummer} DONE."

      if (index > 0 and index % batch_size == 0) or index == publicaties.size - 1
        Mu.log.info "[ONGOING] Writing generated data to file for records #{(batch_number - 1) * batch_size + 1} until #{[batch_number * batch_size, index + 1].min}..."
        RDF::Writer.open("#{publications_ttl_output_file}-#{batch_number}.ttl") { |writer| writer << $kanselarij_graph }
        File.open("#{publications_ttl_output_file}-#{batch_number}.graph", "w+") { |f| f.puts(KANSELARIJ_GRAPH) }
        Mu.log.info "done"
        $kanselarij_graph = RDF::Graph.new
        batch_number += 1
      end
    end

    $errors_csv.close
    Mu.log.info "Processed #{publicaties.size} records."
  end

  if actions.include? "update--number-of-pages"
    publication_flow_records = publicaties.map { |node| AccessDB.record(node) }
    LegacyPublicationConversion::UpdateNumberOfPages.run publication_flow_records
  end

  if actions.include? 'update--number-of-extracts'
    publication_flow_records = publicaties.map { |node| AccessDB.record(node) }
    LegacyPublicationConversion::UpdateNumberOfExtracts.run publication_flow_records
  end
end

def process_publicatie(publicatie)
    dossiernummer = publicatie.css('dossiernummer').text || ""

    opschrift =  publicatie.css('opschrift').text || ""
    datum = publicatie.css('datum').text || ""
    soort = publicatie.css('soort').text || ""
    trefwoord = publicatie.css('trefwoord').text || ""
    bevoegde_ministers = publicatie.css('bevoegde_x0020_minister_x0028_s_x0029_').text || ""
    document_nr = publicatie.css('document_x0020_nr').text || ""
    aantal_bladzijden = (publicatie.css('aantal_x0020_blz').text || "").to_i
    opdrachtgever = publicatie.css('opdrachtgever').text || ""
    opdracht_formeel_ontvangen = publicatie.css('opdracht_x0020_formeel_x0020_ontvangen').text || ""
    wijze_van_publicatie = publicatie.css('wijze_x0020_van_x0020_publicatie').text || ""
    vertaling_aangevraagd = publicatie.css('vertaling_x0020_aangevraagd').text || ""
    limiet_vertaling = publicatie.css('limiet_x0020_vertaling').text || ""
    vertaling_ontvangen = publicatie.css('vertaling_x0020_ontvangen').text || ""
    drukproef_aangevraagd = publicatie.css('drukproef_x0020_aangevraagd').text || ""
    drukproef_ontvangen = publicatie.css('drukproef_x0020_ontvangen').text || ""
    naar_BS_voor_publicatie = publicatie.css('naar_x0020_BS_x0020_voor_x0020_publicatie').text || ""
    limiet_publicatie = publicatie.css('limiet_x0020_publicatie').text || ""
    gevraagde_publicatiedatum = publicatie.css('gevraagde_x0020_publicatiedatum').text || ""
    publicatiedatum = publicatie.css('PUBLICATIEDATUM').text || ""
    opmerkingen = publicatie.css('opmerkingen').text || ""
    werknummer_BS = publicatie.css('werknummer_x0020_BS').text || ""

    rec = AccessDB::Record.new(publicatie)

    publication_number, publication_number_suffix = convert_publication_number rec

    if publication_number == 0 and publication_number_suffix&.downcase == 'subsidie'
      # 0-subsidie publications are exported to a seperate CSV file and should not be imported in Kaleidos
      return
    end

    if publication_number.nil?
      $errors_csv << [rec.dossiernummer, 'dossiernummer', 'irregular']
      return
    end

    if opschrift.empty? and datum.empty? and document_nr.empty?
      $errors_csv << [dossiernummer, "no-sufficient-data", "basic", opschrift, datum, document_nr]
      return
    end

    dossier_date = get_dossier_date rec
    if dossier_date.nil?
      $errors_csv << [dossiernummer, "no-sufficient-data", "dates", datum, opdracht_formeel_ontvangen]
      return
    end

    opening_date = get_opening_date rec

    identification_uri = create_identification(
      publication_number: publication_number,
      publication_number_suffix: publication_number_suffix
    )

    mandatee_uris = ConvertMandatees.convert(rec)

    reference_document_uri, case_uri, treatment_uri = ConvertReferenceDocument.convert(rec)

    if reference_document_uri.nil?
      case_uri = create_case(title: opschrift)
      treatment_uri = create_treatment(start_date: dossier_date)
    end

    remark = []
    remark << "trefwoord: #{trefwoord}" unless trefwoord.empty?
    remark << "opdrachtgever: #{opdrachtgever}" unless opdrachtgever.empty?
    if rec.vertaling_ontvangen
      translation_end_date_str = rec.vertaling_ontvangen.strftime "%d/%m/%Y"
      remark << "vertaling ontvangen: #{ translation_end_date_str }"
    end
    if rec.drukproef_ontvangen
      proofing_end_date_str = rec.drukproef_ontvangen.strftime "%d/%m/%Y"
      remark << "drukproef ontvangen: #{ proofing_end_date_str }"
    end

    remark << "opmerkingen: #{opmerkingen}" unless opmerkingen.empty?
    remark = remark.join("\n")

    publication_mode = get_publication_mode(rec)
    regelgeving_type = ConvertRegulationType.convert(rec)

    beleidsdomein_uri_list = ConvertGovernmentDomains.convert(rec)

    publication_uri = create_publicationflow()

    publication_status = get_publication_status(rec)

    translation_subcase = create_translation_subcase(
      rec,
      publication_uri: publication_uri,
    )

    publication_subcase = create_publication_subcase(
      rec,
      publication_uri: publication_uri,
      publication_status: publication_status,
    )

    numac_number_uri = create_numac_number(werknummer_BS) unless werknummer_BS.empty?


    $errors_csv << [dossiernummer, "publication-date", "missing"] if publicatiedatum.empty?

    closing_date = rec.publicatiedatum

    set_publicationflow(
      publication_uri: publication_uri,
      identification: identification_uri,
      short_title: opschrift,
      mandatees: mandatee_uris,
      reference_document: reference_document_uri,
      creation_date: dossier_date,
      opening_date: opening_date,
      closing_date: closing_date,
      regulation_type: regelgeving_type,
      publication_mode: publication_mode,
      numac_number: numac_number_uri,
      remark: remark,
      publication_status: publication_status,
      caze: case_uri,
      treatment: treatment_uri,
      pages: aantal_bladzijden,
      document_number: document_nr,
      beleidsdomein_uri_list: beleidsdomein_uri_list
    )
end

def get_dossier_date rec
  rec.datum || rec.opdracht_formeel_ontvangen
end

def get_opening_date rec
  rec.opdracht_formeel_ontvangen || rec.datum
end

def convert_publication_number r
  dossiernummer = r.dossiernummer.strip
  identifier_match = dossiernummer.match('(?<number>\d+)[-/]?(?<version>.+)?')
  if identifier_match.nil?
    return nil
  end

  publication_number = Integer identifier_match[:number]
  publication_number_suffix = identifier_match[:version]
  if publication_number_suffix
    publication_number_suffix = publication_number_suffix.strip
    publication_number_suffix = nil if publication_number_suffix.empty?
  end

  return publication_number, publication_number_suffix
end

def create_identification args
  structured_identifier = create_structured_identifier(
    publication_number: args[:publication_number],
    publication_number_suffix: args[:publication_number_suffix]
  )

  publication_number_full = args[:publication_number].to_s
  if args[:publication_number_suffix]
    publication_number_full = publication_number_full + ' ' + args[:publication_number_suffix]
  end

  uuid = Mu.generate_uuid()
  identification_uri = RDF::URI(BASE_URI % { :resource => 'identificator', :id => uuid})
  $kanselarij_graph << RDF.Statement(identification_uri, RDF.type, ADMS.Identifier)
  $kanselarij_graph << RDF.Statement(identification_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(identification_uri, SKOS.notation, publication_number_full)
  $kanselarij_graph << RDF.Statement(identification_uri, ADMS.schemaAgency, 'ovrb')
  $kanselarij_graph << RDF.Statement(identification_uri, GENERIEK.gestructureerdeIdentificator, structured_identifier)
  $kanselarij_graph << RDF.Statement(identification_uri, DCT.source, DATASOURCE)

  identification_uri
end

# @param [String] dossiernummer
def create_structured_identifier args
  uuid = Mu.generate_uuid()
  structured_identification_uri = RDF::URI(BASE_URI % { :resource => 'structured-identificator', :id => uuid})
  $kanselarij_graph << RDF.Statement(structured_identification_uri, RDF.type, GENERIEK.GestructureerdeIdentificator)
  $kanselarij_graph << RDF.Statement(structured_identification_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(structured_identification_uri, GENERIEK.lokaleIdentificator, args[:publication_number])
  $kanselarij_graph << RDF.Statement(structured_identification_uri, GENERIEK.versieIdentificator, args[:publication_number_suffix]) if args[:publication_number_suffix]
  $kanselarij_graph << RDF.Statement(structured_identification_uri, DCT.source, DATASOURCE)

  structured_identification_uri
end

def create_case(data)
  uuid = Mu.generate_uuid()
  case_uri = RDF::URI(BASE_URI % { :resource => 'dossier', :id => uuid})
  $kanselarij_graph << RDF.Statement(case_uri, RDF.type, DOSSIER.Dossier)
  $kanselarij_graph << RDF.Statement(case_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(case_uri, DCT.alternative, data[:title])
  $kanselarij_graph << RDF.Statement(case_uri, DCT.source, DATASOURCE)
  case_uri
end

def create_treatment(data)
  uuid = Mu.generate_uuid()
  treatment_uri = RDF::URI(BASE_URI % { :resource => 'behandeling-van-agendapunt', :id => uuid})
  $kanselarij_graph << RDF.Statement(treatment_uri, RDF.type, BESLUIT.BehandelingVanAgendapunt)
  $kanselarij_graph << RDF.Statement(treatment_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(treatment_uri, DOSSIER['Activiteit.startdatum'], data[:start_date].to_date)
  $kanselarij_graph << RDF.Statement(treatment_uri, DCT.source, DATASOURCE)
  treatment_uri
end

def get_publication_mode(rec)
  wijze = rec.wijze_van_publicatie
  if wijze
    wijze.strip!
    wijze.downcase!
    case wijze
      when 'uittreksel'
        mode = PUBLICATIEWIJZE_UITTREKSEL
      when 'extenso'
        mode = PUBLICATIEWIJZE_EXTENSO
    end
  end
  mode
end

def get_publication_status(rec)
  if rec.publicatiedatum
    PUBLICATIE_STATUS_GEPUBLICEERD
  else
    PUBLICATIE_STATUS_TE_PUBLICEREN
  end
end

def create_translation_subcase(rec, data)
  activity_start_date = rec.vertaling_aangevraagd
  activity_end_date = rec.vertaling_ontvangen
  due_date = rec.limiet_vertaling

  subcase_start_date = rec.vertaling_aangevraagd || get_dossier_date(rec)
  subcase_end_date = rec.vertaling_ontvangen

  uuid = Mu.generate_uuid()
  subcase_uri = RDF::URI(BASE_URI % { :resource => 'procedurestap', :id => uuid})
  $kanselarij_graph << RDF.Statement(subcase_uri, RDF.type, PUB.VertalingProcedurestap)
  $kanselarij_graph << RDF.Statement(subcase_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.startdatum'], subcase_start_date)
  $kanselarij_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.einddatum'], subcase_end_date) if subcase_end_date
  $kanselarij_graph << RDF.Statement(subcase_uri, TMO.dueDate, due_date) if due_date
  $kanselarij_graph << RDF.Statement(subcase_uri, DCT.source, DATASOURCE)

  # Generation of activities disabled since not enough information is available in Access for a sensible conversion
  # if subcase_start_date or subcase_end_date
  #   request_activity_uuid = Mu.generate_uuid()
  #   request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => request_activity_uuid})
  #   $kanselarij_graph << RDF.Statement(request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
  #   $kanselarij_graph << RDF.Statement(request_activity_uri, MU_CORE.uuid, request_activity_uuid)
  #   $kanselarij_graph << RDF.Statement(request_activity_uri, DOSSIER['Activiteit.startdatum'], activity_start_date) if activity_start_date
  #   $kanselarij_graph << RDF.Statement(request_activity_uri, DOSSIER['Activiteit.einddatum'], activity_start_date) if activity_start_date # request_activity.end_date == request_activity.start_date // Access DB does not contain end date
  #   $kanselarij_graph << RDF.Statement(request_activity_uri, PUB.aanvraagVindtPlaatsTijdensVertaling, subcase_uri)
  #   $kanselarij_graph << RDF.Statement(request_activity_uri, DCT.source, DATASOURCE)

  #   translation_activity_uuid = Mu.generate_uuid()
  #   translation_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'vertaal-activiteit', :id => translation_activity_uuid})
  #   $kanselarij_graph << RDF.Statement(translation_activity_uri, RDF.type, PUB.VertaalActiviteit)
  #   $kanselarij_graph << RDF.Statement(translation_activity_uri, MU_CORE.uuid, translation_activity_uuid)
  #   $kanselarij_graph << RDF.Statement(translation_activity_uri, DOSSIER['Activiteit.startdatum'], activity_start_date) if activity_start_date
  #   $kanselarij_graph << RDF.Statement(translation_activity_uri, DOSSIER['Activiteit.einddatum'], activity_end_date) if activity_end_date
  #   $kanselarij_graph << RDF.Statement(translation_activity_uri, PUB.vertalingsactiviteitVanAanvraag, request_activity_uri)
  #   $kanselarij_graph << RDF.Statement(translation_activity_uri, PUB.vertalingVindtPlaatsTijdens, subcase_uri)
  #   $kanselarij_graph << RDF.Statement(translation_activity_uri, DCT.source, DATASOURCE)
  # end

  $kanselarij_graph << RDF.Statement(data[:publication_uri], PUB.doorlooptVertaling, subcase_uri)
end

def create_publication_subcase(rec, data)
  proofing_start_date = rec.drukproef_aangevraagd
  proofing_end_date = rec.drukproef_ontvangen
  publication_start_date = rec.naar_BS_voor_publicatie
  due_date = rec.limiet_publicatie
  target_end_date = rec.gevraagde_publicatiedatum
  publication_end_date = rec.publicatiedatum

  subcase_start_date = rec.drukproef_aangevraagd || get_dossier_date(rec)
  subcase_end_date = rec.publicatiedatum

  publication_subcase_uuid = Mu.generate_uuid()
  subcase_uri = RDF::URI(BASE_URI % { :resource => 'procedurestap', :id => publication_subcase_uuid})
  $kanselarij_graph << RDF.Statement(subcase_uri, RDF.type, PUB.PublicatieProcedurestap)
  $kanselarij_graph << RDF.Statement(subcase_uri, MU_CORE.uuid, publication_subcase_uuid)
  $kanselarij_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.startdatum'], subcase_start_date)
  $kanselarij_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.einddatum'], subcase_end_date) if subcase_end_date
  $kanselarij_graph << RDF.Statement(subcase_uri, TMO.dueDate, due_date) if due_date
  $kanselarij_graph << RDF.Statement(subcase_uri, TMO.targetEndTime, target_end_date) if target_end_date
  $kanselarij_graph << RDF.Statement(subcase_uri, DCT.source, DATASOURCE)

  # Generation of activities disabled since not enough information is available in Access for a sensible conversion
  # if proofing_start_date or proofing_end_date
  #   proofing_request_activity_uuid = Mu.generate_uuid()
  #   proofing_request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => proofing_request_activity_uuid})
  #   $kanselarij_graph << RDF.Statement(proofing_request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
  #   $kanselarij_graph << RDF.Statement(proofing_request_activity_uri, MU_CORE.uuid, proofing_request_activity_uuid)
  #   $kanselarij_graph << RDF.Statement(proofing_request_activity_uri, DOSSIER['Activiteit.startdatum'], proofing_start_date) if proofing_start_date
  #   $kanselarij_graph << RDF.Statement(proofing_request_activity_uri, DOSSIER['Activiteit.einddatum'], proofing_start_date) if proofing_start_date # request_activity.end_date == request_activity.start_date / Access DB does not contain end date
  #   $kanselarij_graph << RDF.Statement(proofing_request_activity_uri, PUB.aanvraagVindtPlaatsTijdensPublicatie, subcase_uri)
  #   $kanselarij_graph << RDF.Statement(proofing_request_activity_uri, DCT.source, DATASOURCE)

  #   proofing_activity_uuid = Mu.generate_uuid()
  #   proofing_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'drukproef-activiteit', :id => proofing_activity_uuid})
  #   $kanselarij_graph << RDF.Statement(proofing_activity_uri, RDF.type, PUB.DrukproefActiviteit)
  #   $kanselarij_graph << RDF.Statement(proofing_activity_uri, MU_CORE.uuid, proofing_activity_uuid)
  #   $kanselarij_graph << RDF.Statement(proofing_activity_uri, DOSSIER['Activiteit.startdatum'], proofing_start_date) if proofing_start_date
  #   $kanselarij_graph << RDF.Statement(proofing_activity_uri, DOSSIER['Activiteit.einddatum'], proofing_end_date) if proofing_end_date
  #   $kanselarij_graph << RDF.Statement(proofing_activity_uri, PUB.drukproefactiviteitVanAanvraag, proofing_request_activity_uri)
  #   $kanselarij_graph << RDF.Statement(proofing_activity_uri, PUB.drukproefVindtPlaatsTijdens, subcase_uri)
  #   $kanselarij_graph << RDF.Statement(proofing_activity_uri, DCT.source, DATASOURCE)
  # end

  if publication_start_date or publication_end_date
  # Generation of request activity disabled since not enough information is available in Access for a sensible conversion
  #   publication_request_activity_uuid = Mu.generate_uuid()
  #   publication_request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => publication_request_activity_uuid})
  #   $kanselarij_graph << RDF.Statement(publication_request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
  #   $kanselarij_graph << RDF.Statement(publication_request_activity_uri, MU_CORE.uuid, publication_request_activity_uuid)
  #   $kanselarij_graph << RDF.Statement(publication_request_activity_uri, DOSSIER['Activiteit.startdatum'], publication_start_date) if publication_start_date
  #   $kanselarij_graph << RDF.Statement(publication_request_activity_uri, DOSSIER['Activiteit.einddatum'], publication_start_date) if publication_start_date
  #   $kanselarij_graph << RDF.Statement(publication_request_activity_uri, PUB.aanvraagVindtPlaatsTijdensPublicatie, subcase_uri)
  #   $kanselarij_graph << RDF.Statement(publication_request_activity_uri, DCT.source, DATASOURCE)

    publication_activity_uuid = Mu.generate_uuid()
    publication_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'publicatie-activiteit', :id => publication_activity_uuid})
    $kanselarij_graph << RDF.Statement(publication_activity_uri, RDF.type, PUB.PublicatieActiviteit)
    $kanselarij_graph << RDF.Statement(publication_activity_uri, MU_CORE.uuid, publication_activity_uuid)
    $kanselarij_graph << RDF.Statement(publication_activity_uri, DOSSIER['Activiteit.startdatum'], publication_start_date) if publication_start_date
    $kanselarij_graph << RDF.Statement(publication_activity_uri, DOSSIER['Activiteit.einddatum'], publication_end_date) if publication_end_date
  #  $kanselarij_graph << RDF.Statement(publication_activity_uri, PUB.publicatieactiviteitVanAanvraag, publication_request_activity_uri)
    $kanselarij_graph << RDF.Statement(publication_activity_uri, PUB.publicatieVindtPlaatsTijdens, subcase_uri)

    if data[:publication_status] === PUBLICATIE_STATUS_GEPUBLICEERD
      decision_uri = create_decision publication_date: publication_end_date
      $kanselarij_graph << RDF.Statement(publication_activity_uri, PROV.generated, decision_uri)
    end

   $kanselarij_graph << RDF.Statement(publication_activity_uri, DCT.source, DATASOURCE)
  end

  $kanselarij_graph << RDF.Statement(data[:publication_uri], PUB.doorlooptPublicatie, subcase_uri)
end

def create_numac_number(werknummer_BS)
  uuid = Mu.generate_uuid()
  numac_uri = RDF::URI(BASE_URI % { :resource => 'identificator', :id => uuid})
  $kanselarij_graph << RDF.Statement(numac_uri, RDF.type, ADMS.Identifier)
  $kanselarij_graph << RDF.Statement(numac_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(numac_uri, SKOS.notation, werknummer_BS)
  $kanselarij_graph << RDF.Statement(numac_uri, ADMS.schemaAgency, 'Belgisch Staatsblad')
  $kanselarij_graph << RDF.Statement(numac_uri, DCT.source, DATASOURCE)

  numac_uri
end

def create_decision data
  uuid = Mu.generate_uuid()
  uri = RDF::URI(BASE_URI % { resource: 'besluit', id: uuid })
  $kanselarij_graph << RDF.Statement(uri, RDF.type, ELI.LegalResource)
  $kanselarij_graph << RDF.Statement(uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(uri, ELI['date_publication'], data[:publication_date].to_date) # VOC['predicate'] syntax: RDF library replaces underscore by camelcasing
  return uri
end

def create_publicationflow()
  uuid = Mu.generate_uuid()
  publication_uri = RDF::URI(BASE_URI % { :resource => 'publicatie-aangelegenheid', :id => uuid})
  $kanselarij_graph << RDF.Statement(publication_uri, RDF.type, PUB.Publicatieaangelegenheid)
  $kanselarij_graph << RDF.Statement(publication_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(publication_uri, DCT.source, DATASOURCE)

  publication_uri
end

def create_publication_status_change data
  uuid = Mu.generate_uuid()
  activity_uri = RDF::URI(BASE_URI % { :resource => 'publicatie-status-wijziging', :id => uuid})
  $kanselarij_graph << RDF.Statement(activity_uri, RDF.type, PUB.PublicatieStatusWijziging)
  $kanselarij_graph << RDF.Statement(activity_uri, MU_CORE.uuid, uuid)
  $kanselarij_graph << RDF.Statement(activity_uri, PROV.startedAtTime, data[:date])

  activity_uri
end

def set_publicationflow(data)
  publication_uri = data[:publication_uri]

  $kanselarij_graph << RDF.Statement(publication_uri, DCT.created, data[:creation_date])
  $kanselarij_graph << RDF.Statement(publication_uri, ADMS.identifier, data[:identification])
  $kanselarij_graph << RDF.Statement(publication_uri, DOSSIER.behandelt, data[:caze])
  $kanselarij_graph << RDF.Statement(publication_uri, DCT.subject, data[:treatment])
  $kanselarij_graph << RDF.Statement(publication_uri, DCT.alternative, data[:short_title]) if data[:short_title]
  $kanselarij_graph << RDF.Statement(publication_uri, PUB.regelgevingType, data[:regulation_type]) if data[:regulation_type]
  $kanselarij_graph << RDF.Statement(publication_uri, PUB.publicatieWijze, data[:publication_mode]) if data[:publication_mode]
  # Reference document link is disabled since document reference from Access export is too vague
  # to uniquely identify the document that is subject of the publication. Only agendaitem-treatment can be identified.
  # The regulation type of the publication cannot be used as additional filter
  # since we don't have document types in Kaleidos DB for documents originating from Doris
  # $kanselarij_graph << RDF.Statement(publication_uri, PUB.referentieDocument, data[:reference_document]) unless data[:reference_document].nil?
  # $kanselarij_graph << RDF.Statement(publication_uri, FABIO.hasPageCount, data[:pages]) if data[:pages] > 0
  $kanselarij_graph << RDF.Statement(publication_uri, PUB.identifier, data[:numac_number]) if data[:numac_number]
  $kanselarij_graph << RDF.Statement(publication_uri, RDFS.comment, data[:remark]) if data[:remark]
  $kanselarij_graph << RDF.Statement(publication_uri, DOSSIER.openingsdatum, data[:opening_date].to_date)
  $kanselarij_graph << RDF.Statement(publication_uri, DOSSIER.sluitingsdatum, data[:closing_date].to_date) if data[:closing_date]
  $kanselarij_graph << RDF.Statement(publication_uri, EXT.legacyDocumentNumberMSAccess, data[:document_number]) unless data[:document_number].empty?

  data[:beleidsdomein_uri_list].each do |beleidsdomein|
    $kanselarij_graph << RDF.Statement(publication_uri, PROVISIONAL_BELEIDSDOMEIN_FULL_NAME, beleidsdomein)
  end

  data[:mandatees].each do |mandatee|
    $kanselarij_graph << RDF.Statement(publication_uri, EXT.heeftBevoegdeVoorPublicatie, mandatee)
  end

  $kanselarij_graph << RDF.Statement(publication_uri, ADMS.status, data[:publication_status])

  if data[:publication_status] === PUBLICATIE_STATUS_GEPUBLICEERD
    status_change_uri = create_publication_status_change date: data[:closing_date] if data[:closing_date]
    $kanselarij_graph << RDF.Statement(data[:publication_uri], PROV.hadActivity, status_change_uri)
  else
    status_change_uri = create_publication_status_change date: data[:opening_date]
    $kanselarij_graph << RDF.Statement(data[:publication_uri], PROV.hadActivity, status_change_uri)
  end
end
