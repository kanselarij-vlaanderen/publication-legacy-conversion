require 'linkeddata'
require 'nokogiri'
require_relative 'access_db.rb'
require_relative 'linked_db.rb'
require_relative 'query_mandatees.rb'

MU = RDF::Vocabulary.new('http://mu.semte.ch/vocabularies/')
MU_CORE = RDF::Vocabulary.new(MU.to_uri.to_s + 'core/')

BASE_URI = 'http://themis.vlaanderen.be/id/%{resource}/%{id}'
CONCEPT_URI = 'http://themis.vlaanderen.be/id/concept/%{resource}/%{id}'

FOAF = RDF::Vocab::FOAF
ADMS = RDF::Vocabulary.new("http://www.w3.org/ns/adms#")
SKOS = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
GENERIEK = RDF::Vocabulary.new("https://data.vlaanderen.be/ns/generiek#")
PUB = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/publicatie/")
MANDAAT = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/mandaat#")
DOSSIER = RDF::Vocabulary.new("https://data.vlaanderen.be/ns/dossier#")
BESLUIT = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/besluit#")
BESLUITVORMING = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/besluitvorming#")
EXT = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/")
DCT = RDF::Vocabulary.new("http://purl.org/dc/terms/")
TMO = RDF::Vocabulary.new("http://www.semanticdesktop.org/ontologies/2008/05/20/tmo#")
FABIO = RDF::Vocabulary.new("http://purl.org/spar/fabio/#")
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

KANSELARIJ_GRAPH = "http://mu.semte.ch/graphs/organizations/kanselarij"
MINISTERS_GRAPH = "http://mu.semte.ch/graphs/ministers"

DATASOURCE = RDF::URI "http://vlaanderen.be/dossier-opvolging-access-db/DOSSIEROPVOLGING-H.xml"
PUBLISHED_STATUS = RDF::URI "http://themis.vlaanderen.be/id/concept/publicatie-status/2f8dc814-bd91-4bcf-a823-baf1cdc42475"

$public_graph = RDF::Graph.new

$errors = Array.new

# publicaties.nil? => all publicaties
def run(input_dir="/data/input/", output_dir="/data/output/", publicaties = nil)
  log.info "[STARTED] Starting publication legacy conversion"

  legacy_input_file_name = "legacy_data.xml"
  legacy_input_file = "#{input_dir}#{legacy_input_file_name}"

  file_timestamp = DateTime.now.strftime("%Y%m%d%H%M%S")

  ttl_output_file_name = "import-legacy-publications"
  ttl_output_file = "#{output_dir}#{file_timestamp}-#{ttl_output_file_name}"
  error_output_file_name = "errors.txt"
  error_output_file = "#{output_dir}#{file_timestamp}-#{error_output_file_name}"

  $errors_csv = CSV.open(
    "#{output_dir}#{file_timestamp}-errors.csv", mode='wb')
  
  $query_mandatees = QueryMandatees.new(
    "#{input_dir}mandatees-corrections.csv")

  log.info "-- Input file : #{legacy_input_file}"
  log.info "-- Output file : #{ttl_output_file}"

  publicaties = AccessDB.nodes if publicaties.nil?

  log.info "graph: #{graph}"

  start = -1
  batch_number = 1
  batch_size = 1000
  publications_length = publicaties.size

  publicaties.each_with_index do |publicatie, index|
    process_publicatie publicatie if index > start

    if index > 0 and index <= start and index % batch_size == 0
      log.info "[ONGOING] Skipping records #{index-batch_size} until #{index}..."
    end
    if (index > 0 and index > start and index % batch_size == 0) or index == publications_length -1
      log.info "[ONGOING] Writing generated data to files for records #{index-batch_size} until #{index}..."
      RDF::Writer.open("#{ttl_output_file}-#{batch_number}.ttl") { |writer| writer << $public_graph }
      File.open("#{ttl_output_file}-#{batch_number}.graph", "w+") { |f| f.puts(KANSELARIJ_GRAPH)}
      File.open(error_output_file, "a+") { |f| f.puts($errors) }
      log.info "done"
      $public_graph = RDF::Graph.new
      $errors = Array.new
      batch_number += 1
    end
  end

  log.info "Processed #{publicaties.size} records."

end

def process_publicatie(publicatie)
    dossiernummer = publicatie.css('dossiernummer').text || ""
    log.info "Processing dossiernummer #{dossiernummer}... "

    opschrift =  publicatie.css('opschrift').text || ""
    datum = publicatie.css('datum').text || ""
    soort = publicatie.css('soort').text || ""
    trefwoord = publicatie.css('trefwoord').text || ""
    bevoegde_ministers = publicatie.css('bevoegde_x0020_minister_x0028_s_x0029_').text || ""
    document_nr = publicatie.css('document_x0020_nr').text || ""
    aantal_bladzijden = publicatie.css('aantal_x0020_blz').text || ""
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

    if opschrift.empty? and datum.empty? and document_nr.empty?
      error = "ERROR: No sufficient data found for publication #{dossiernummer}"
      if not error.nil?
        log.info error
        $errors << error
      end
      return
    end

    dossier_date = datum.empty? ? opdracht_formeel_ontvangen : datum
    if dossier_date.empty?
      error = "ERROR: No date found for publication #{dossiernummer}"
      if not error.nil?
        log.info error
        $errors << error
      end
      return
    end

    openingsdatum = opdracht_formeel_ontvangen.empty? ? datum : opdracht_formeel_ontvangen

    identification_uri = create_identification(dossiernummer)

    mandatee_uris = $query_mandatees.query(rec)

    reference_document_uri = nil
    unless document_nr.empty?
      documents = query_reference_document(dossiernummer, document_nr)
      validate_result(documents, "Publication #{dossiernummer} query reference document #{document_nr}", true, true) unless documents.nil?
      if documents and documents.length > 0
        reference_document_uri = documents.first[:stukUri]
        case_uri = documents.first[:caseUri]
        treatment_uri = documents.first[:treatmentUri]
        if reference_document_uri.nil? or case_uri.nil? or treatment_uri.nil?
          $errors << "ERROR: no document, case or treatment found for publication #{dossiernummer} with document number '#{document_nr}'."
        end
      else
        $errors << "ERROR: no document found for publication #{dossiernummer} with document number '#{document_nr}'."
      end
    end

    if reference_document_uri.nil?
      case_uri = create_case(opschrift)
      treatment_uri = create_treatment(dossier_date)
    end

    number_of_pages = aantal_bladzijden if aantal_bladzijden

    remark = []
    remark << "trefwoord: #{trefwoord} " unless trefwoord.empty?
    remark << "opdrachtgever: #{opdrachtgever} " unless opdrachtgever.empty?
    remark << "opmerkingen: #{opmerkingen} " unless opmerkingen.empty?
    remark = remark.join("\n")

    unless wijze_van_publicatie.empty?
      mode = validate(map_mode(wijze_van_publicatie), "map mode #{dossiernummer} #{dossier_date}", wijze_van_publicatie)
    end

    regelgeving_type = validate(map_regelgeving_type(soort), "map regelgeving type #{dossiernummer}", soort)

    publication_uri = create_publicationflow()

    translation_subcase = create_translation_subcase(
      publication_uri: publication_uri,
      publicatiedatum: publicatiedatum,
      created: dossier_date,
      vertaling_aangevraagd:  vertaling_aangevraagd,
      vertaling_ontvangen: vertaling_ontvangen,
      limiet_vertaling: limiet_vertaling
    )

    publication_subcase = create_publication_subcase(
      publication_uri: publication_uri,
      created: dossier_date,
      drukproef_aangevraagd: drukproef_aangevraagd,
      drukproef_ontvangen: drukproef_ontvangen,
      naar_BS_voor_publicatie: naar_BS_voor_publicatie,
      limiet_publicatie: limiet_publicatie,
      gevraagde_publicatiedatum: gevraagde_publicatiedatum,
      publicatiedatum: publicatiedatum
    )

    numac_number_uri = create_numac_number(werknummer_BS) unless werknummer_BS.empty?

    $errors << "ERROR: No publication date found for publication #{dossiernummer}." if publicatiedatum.empty?

    set_publicationflow(
      publication_uri: publication_uri,
      identification: identification_uri,
      short_title: opschrift,
      regulation_type: regelgeving_type,
      mandatees: mandatee_uris,
      reference_document: reference_document_uri,
      created: dossier_date,
      mode: mode,
      numac_number: numac_number_uri,
      remark: remark,
      caze: case_uri,
      openingsdatum: openingsdatum,
      treatment: treatment_uri,
      pages: number_of_pages,
      document_number: document_nr,
    )
    log.info "Processing dossiernummer #{dossiernummer} DONE."
end

def create_identification(dossiernummer)
  structured_identifier = create_structured_identifier(dossiernummer)

  uuid = generate_uuid()
  identification_uri = RDF::URI(BASE_URI % { :resource => 'identificator', :id => uuid})
  $public_graph << RDF.Statement(identification_uri, RDF.type, ADMS.Identifier)
  $public_graph << RDF.Statement(identification_uri, MU_CORE.uuid, uuid)
  $public_graph << RDF.Statement(identification_uri, SKOS.notation, dossiernummer)
  $public_graph << RDF.Statement(identification_uri, ADMS.schemaAgency, 'ovrb')
  $public_graph << RDF.Statement(identification_uri, GENERIEK.gestructureerdeIdentificator, structured_identifier)
  $public_graph << RDF.Statement(identification_uri, DCT.source, DATASOURCE)

  identification_uri
end

def create_structured_identifier(dossiernummer)
  identificator = dossiernummer.match('(?<number>\d+)(?<version>[a-zA-Z0-9]*)')
  local_identificator = identificator[:number]
  version_identificator = identificator[:version]

  uuid = generate_uuid()
  structured_identification_uri = RDF::URI(BASE_URI % { :resource => 'structured-identificator', :id => uuid})
  $public_graph << RDF.Statement(structured_identification_uri, RDF.type, GENERIEK.GestructureerdeIdentificator)
  $public_graph << RDF.Statement(structured_identification_uri, MU_CORE.uuid, uuid)
  $public_graph << RDF.Statement(structured_identification_uri, GENERIEK.lokaleIdentificator, local_identificator)
  $public_graph << RDF.Statement(structured_identification_uri, GENERIEK.versieIdentificator, version_identificator) unless version_identificator.nil?
  $public_graph << RDF.Statement(structured_identification_uri, DCT.source, DATASOURCE)

  structured_identification_uri
end

def query_reference_document(dossiernummer, document_number)
  # reformatting document number from e.g. from 'VR/96/09.07/0547' to VR 1996 0907 DOC.0547 /

  titleParts = document_number.match('VR/(?<year>\d{2})/(?<day>[0-9]{2})\.(?<month>[0-9]{2})/(?<number>\d{4})')

  if titleParts.nil?
    error = "Error parsing document number '#{document_number} for publication #{dossiernummer}"
    $errors_csv << [dossiernummer, document_number]
    if not error.nil?
      log.info error
      $errors << error
      return
    end
  end

  year = titleParts[:year]
  year4 = year.to_i < 30 ? "20" + year : "19" + year

  docTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} DOC.#{titleParts[:number]}"
  medTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} MED.#{titleParts[:number]}"
  log.info "reformatting document_number '#{document_number}' into '#{docTitle}'"

  query =  " SELECT ?stukUri ?caseUri ?treatmentUri WHERE {"
  query += "   GRAPH <#{KANSELARIJ_GRAPH}> {"
  query += "     ?treatmentUri a <#{BESLUIT.BehandelingVanAgendapunt}> ;"
  query += "              <#{BESLUITVORMING.heeftOnderwerp}> ?agendaItem ."
  query += "     ?agendaItem <#{BESLUITVORMING.geagendeerdStuk}> ?stukUri ."
  query += "     ?caseUri a <#{DOSSIER.Dossier}> ;"
  query += "              <#{DOSSIER['Dossier.bestaatUit']}> ?stukUri ."
  query += "     ?stukUri a <#{DOSSIER.Stuk}> ;"
  query += "              <#{DCT.title}> ?title ."
  query += "   FILTER (strstarts(str(?title), ?titleValue) )"
  query += "   VALUES ?titleValue  { '#{docTitle}' '#{medTitle}' }"
  query += "   }"
  query += " } ORDER BY ?title"

  query(query)
end

def create_case(title)
  uuid = generate_uuid()
  case_uri = RDF::URI(BASE_URI % { :resource => 'dossier', :id => uuid})
  $public_graph << RDF.Statement(case_uri, RDF.type, DOSSIER.Dossier)
  $public_graph << RDF.Statement(case_uri, MU_CORE.uuid, uuid)
  $public_graph << RDF.Statement(case_uri, DCT.alternative, title)
  $public_graph << RDF.Statement(case_uri, DCT.source, DATASOURCE)
  case_uri
end

def create_treatment(date)
  startDate = DateTime.strptime(date, '%Y-%m-%dT%H:%M:%S')
  uuid = generate_uuid()
  treatment_uri = RDF::URI(BASE_URI % { :resource => 'behandeling-van-agendapunt', :id => uuid})
  $public_graph << RDF.Statement(treatment_uri, RDF.type, BESLUIT.BehandelingVanAgendapunt)
  $public_graph << RDF.Statement(treatment_uri, MU_CORE.uuid, uuid)
  $public_graph << RDF.Statement(treatment_uri, DOSSIER['Activiteit.startdatum'], startDate)
  $public_graph << RDF.Statement(treatment_uri, DCT.source, DATASOURCE)
  treatment_uri
end

def map_regelgeving_type(soort)
  case soort
    when 'mb'
      type = REGELGEVING_TYPE_MB
    when 'bvr'
      type = REGELGEVING_TYPE_BVR
    when 'decreet'
      type = REGELGEVING_TYPE_DECREET
    when 'besluit dir.-gen.',
         'besluit secr.-gen.',
         'besluit raad van bestuur'
      type = REGELGEVING_TYPE_BESLUIT
    when 'omzendbrief'
      type = REGELGEVING_TYPE_OMZENDBRIEF
    when 'bericht'
      type = REGELGEVING_TYPE_BERICHT
    when 'kb'
      type = REGELGEVING_TYPE_KB
    when 'erratum'
      type = REGELGEVING_TYPE_ERRATUM
    else
      type = REGELGEVING_TYPE_ANDERE
  end
  type
end

def map_mode(publicatie_wijze)
  case publicatie_wijze
    when 'uittreksel'
      mode = PUBLICATIEWIJZE_UITTREKSEL
    when 'extenso'
      mode = PUBLICATIEWIJZE_EXTENSO
  end
  mode
end

def create_translation_subcase(data)
  activity_start_date = DateTime.strptime(data[:vertaling_aangevraagd], '%Y-%m-%dT%H:%M:%S') unless data[:vertaling_aangevraagd].empty?
  activity_end_date = DateTime.strptime(data[:vertaling_ontvangen], '%Y-%m-%dT%H:%M:%S') unless data[:vertaling_ontvangen].empty?
  due_date = DateTime.strptime(data[:limiet_vertaling], '%Y-%m-%dT%H:%M:%S') unless data[:limiet_vertaling].empty?

  subcase_start_date = DateTime.strptime(data[:created], '%Y-%m-%dT%H:%M:%S') if activity_start_date.nil? and not data[:created].empty?
  subcase_end_date = DateTime.strptime(data[:publicatiedatum], '%Y-%m-%dT%H:%M:%S') if activity_end_date.nil? and not data[:publicatiedatum].empty?

  uuid = generate_uuid()
  subcase_uri = RDF::URI(BASE_URI % { :resource => 'procedurestap', :id => uuid})
  $public_graph << RDF.Statement(subcase_uri, RDF.type, PUB.VertalingProcedurestap)
  $public_graph << RDF.Statement(subcase_uri, MU_CORE.uuid, uuid)
  $public_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.startdatum'], activity_start_date) unless activity_start_date.nil?
  $public_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.einddatum'], activity_end_date) unless activity_end_date.nil?
  $public_graph << RDF.Statement(subcase_uri, TMO.dueDate, due_date) unless due_date.nil?
  $public_graph << RDF.Statement(subcase_uri, DCT.source, DATASOURCE)

  if subcase_start_date or subcase_end_date or due_date
    request_activity_uuid = generate_uuid()
    request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => request_activity_uuid})
    $public_graph << RDF.Statement(request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
    $public_graph << RDF.Statement(request_activity_uri, MU_CORE.uuid, request_activity_uuid)
    $public_graph << RDF.Statement(request_activity_uri, DOSSIER['Activiteit.startdatum'], activity_start_date) unless activity_start_date.nil?
    $public_graph << RDF.Statement(request_activity_uri, DOSSIER['Activiteit.einddatum'], activity_end_date) unless activity_end_date.nil? # request_activity.end_date == request_activity.start_date
    $public_graph << RDF.Statement(request_activity_uri, PUB.aanvraagVindtPlaatsTijdensVertaling, subcase_uri)
    $public_graph << RDF.Statement(request_activity_uri, DCT.source, DATASOURCE)

    translation_activity_uuid = generate_uuid()
    translation_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'vertaal-activiteit', :id => translation_activity_uuid})
    $public_graph << RDF.Statement(translation_activity_uri, RDF.type, PUB.VertaalActiviteit)
    $public_graph << RDF.Statement(translation_activity_uri, MU_CORE.uuid, translation_activity_uuid)
    $public_graph << RDF.Statement(translation_activity_uri, DOSSIER['Activiteit.startdatum'], activity_start_date) unless activity_start_date.nil?
    $public_graph << RDF.Statement(translation_activity_uri, DOSSIER['Activiteit.einddatum'], activity_end_date) unless activity_end_date.nil?
    $public_graph << RDF.Statement(translation_activity_uri, PUB.vertalingsactiviteitVanAanvraag, request_activity_uri)
    $public_graph << RDF.Statement(translation_activity_uri, PUB.vertalingVindtPlaatsTijdens, subcase_uri)
    $public_graph << RDF.Statement(translation_activity_uri, DCT.source, DATASOURCE)
  end

  $public_graph << RDF.Statement(data[:publication_uri], PUB.doorlooptVertaling, subcase_uri)
end

def create_publication_subcase(data)
  proofingStartDate = DateTime.strptime(data[:drukproef_aangevraagd], '%Y-%m-%dT%H:%M:%S') unless data[:drukproef_aangevraagd].empty?
  proofingEndDate = DateTime.strptime(data[:drukproef_ontvangen], '%Y-%m-%dT%H:%M:%S') unless data[:drukproef_ontvangen].empty?
  publicationStartDate = DateTime.strptime(data[:naar_BS_voor_publicatie], '%Y-%m-%dT%H:%M:%S') unless data[:naar_BS_voor_publicatie].empty?
  dueDate = DateTime.strptime(data[:limiet_publicatie], '%Y-%m-%dT%H:%M:%S') unless data[:limiet_publicatie].empty?
  targetEndDate = DateTime.strptime(data[:gevraagde_publicatiedatum], '%Y-%m-%dT%H:%M:%S') unless data[:gevraagde_publicatiedatum].empty?
  publicationEndDate = DateTime.strptime(data[:publicatiedatum], '%Y-%m-%dT%H:%M:%S') unless data[:publicatiedatum].empty?

  subcase_start_date = DateTime.strptime(data[:created], '%Y-%m-%dT%H:%M:%S') if proofingStartDate.nil? and not data[:created].empty?
  subcase_end_date = publicationEndDate if proofingEndDate.nil? and not publicationEndDate.nil?

  publication_subcase_uuid = generate_uuid()
  subcase_uri = RDF::URI(BASE_URI % { :resource => 'procedurestap', :id => publication_subcase_uuid})
  $public_graph << RDF.Statement(subcase_uri, RDF.type, PUB.PublicatieProcedurestap)
  $public_graph << RDF.Statement(subcase_uri, MU_CORE.uuid, publication_subcase_uuid)
  $public_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.startdatum'], subcase_start_date) unless subcase_start_date.nil?
  $public_graph << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.einddatum'], subcase_end_date) unless subcase_end_date.nil?
  $public_graph << RDF.Statement(subcase_uri, TMO.dueDate, dueDate) unless dueDate.nil?
  $public_graph << RDF.Statement(subcase_uri, TMO.targetEndTime, targetEndDate) unless targetEndDate.nil?
  $public_graph << RDF.Statement(subcase_uri, DCT.source, DATASOURCE)

  if proofingStartDate or proofingEndDate
    proofing_request_activity_uuid = generate_uuid()
    proofing_request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => proofing_request_activity_uuid})
    $public_graph << RDF.Statement(proofing_request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
    $public_graph << RDF.Statement(proofing_request_activity_uri, MU_CORE.uuid, proofing_request_activity_uuid)
    $public_graph << RDF.Statement(proofing_request_activity_uri, DOSSIER['Activiteit.startdatum'], proofingStartDate) unless proofingStartDate.nil?
    $public_graph << RDF.Statement(proofing_request_activity_uri, DOSSIER['Activiteit.einddatum'], proofingStartDate) unless proofingStartDate.nil?
    $public_graph << RDF.Statement(proofing_request_activity_uri, PUB.aanvraagVindtPlaatsTijdensPublicatie, subcase_uri)
    $public_graph << RDF.Statement(proofing_request_activity_uri, DCT.source, DATASOURCE)

    proofing_activity_uuid = generate_uuid()
    proofing_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'drukproef-activiteit', :id => proofing_activity_uuid})
    $public_graph << RDF.Statement(proofing_activity_uri, RDF.type, PUB.DrukproefActiviteit)
    $public_graph << RDF.Statement(proofing_activity_uri, MU_CORE.uuid, proofing_activity_uuid)
    $public_graph << RDF.Statement(proofing_activity_uri, DOSSIER['Activiteit.startdatum'], proofingStartDate) unless proofingStartDate.nil?
    $public_graph << RDF.Statement(proofing_activity_uri, DOSSIER['Activiteit.einddatum'], proofingEndDate) unless proofingEndDate.nil?
    $public_graph << RDF.Statement(proofing_activity_uri, PUB.drukproefactiviteitVanAanvraag, proofing_request_activity_uri)
    $public_graph << RDF.Statement(proofing_activity_uri, PUB.drukproefVindtPlaatsTijdens, subcase_uri)
    $public_graph << RDF.Statement(proofing_activity_uri, DCT.source, DATASOURCE)
  end

  if publicationStartDate or publicationEndDate
    publication_request_activity_uuid = generate_uuid()
    publication_request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => publication_request_activity_uuid})
    $public_graph << RDF.Statement(publication_request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
    $public_graph << RDF.Statement(publication_request_activity_uri, MU_CORE.uuid, publication_request_activity_uuid)
    $public_graph << RDF.Statement(publication_request_activity_uri, DOSSIER['Activiteit.startdatum'], publicationStartDate) unless publicationStartDate.nil?
    $public_graph << RDF.Statement(publication_request_activity_uri, DOSSIER['Activiteit.einddatum'], publicationStartDate) unless publicationStartDate.nil?
    $public_graph << RDF.Statement(publication_request_activity_uri, PUB.aanvraagVindtPlaatsTijdensPublicatie, subcase_uri)
    $public_graph << RDF.Statement(publication_request_activity_uri, DCT.source, DATASOURCE)

    publication_activity_uuid = generate_uuid()
    publication_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'publicatie-activiteit', :id => publication_activity_uuid})
    $public_graph << RDF.Statement(publication_activity_uri, RDF.type, PUB.DrukproefActiviteit)
    $public_graph << RDF.Statement(publication_activity_uri, MU_CORE.uuid, publication_activity_uuid)
    $public_graph << RDF.Statement(publication_activity_uri, DOSSIER['Activiteit.startdatum'], publicationStartDate) unless publicationStartDate.nil?
    $public_graph << RDF.Statement(publication_activity_uri, DOSSIER['Activiteit.einddatum'], publicationEndDate) unless publicationEndDate.nil?
    $public_graph << RDF.Statement(publication_activity_uri, PUB.publicatieactiviteitVanAanvraag, publication_request_activity_uri)
    $public_graph << RDF.Statement(publication_activity_uri, PUB.publicatieVindtPlaatsTijdens, subcase_uri)
    $public_graph << RDF.Statement(publication_activity_uri, DCT.source, DATASOURCE)
  end

  $public_graph << RDF.Statement(data[:publication_uri], PUB.doorlooptPublicatie, subcase_uri)
end

def create_numac_number(werknummer_BS)
  uuid = generate_uuid()
  numac_uri = RDF::URI(BASE_URI % { :resource => 'identificator', :id => uuid})
  $public_graph << RDF.Statement(numac_uri, RDF.type, ADMS.Identifier)
  $public_graph << RDF.Statement(numac_uri, MU_CORE.uuid, uuid)
  $public_graph << RDF.Statement(numac_uri, SKOS.notation, werknummer_BS)
  $public_graph << RDF.Statement(numac_uri, ADMS.schemaAgency, 'Belgisch Staatsblad')
  $public_graph << RDF.Statement(numac_uri, DCT.source, DATASOURCE)

  numac_uri
end

def create_publicationflow()
  uuid = generate_uuid()
  publication_uri = RDF::URI(BASE_URI % { :resource => 'publicatie-aangelegenheid', :id => uuid})
  $public_graph << RDF.Statement(publication_uri, RDF.type, PUB.Publicatieaangelegenheid)
  $public_graph << RDF.Statement(publication_uri, MU_CORE.uuid, uuid)
  $public_graph << RDF.Statement(publication_uri, DCT.source, DATASOURCE)
  $public_graph << RDF.Statement(publication_uri, ADMS.status, PUBLISHED_STATUS)

  publication_uri
end

def set_publicationflow(data)
  publication_uri = data[:publication_uri]

  creation_date = DateTime.strptime(data[:created], '%Y-%m-%dT%H:%M:%S') unless data[:created].empty?
  open_date = DateTime.strptime(data[:openingsdatum], '%Y-%m-%dT%H:%M:%S') unless data[:openingsdatum].empty?

  $public_graph << RDF.Statement(publication_uri, ADMS.identifier, data[:identification]) unless data[:identification].nil?
  $public_graph << RDF.Statement(publication_uri, DCT.alternative, data[:short_title]) unless data[:short_title].nil?
  $public_graph << RDF.Statement(publication_uri, PUB.regelgevingType, data[:regulation_type]) unless data[:regulation_type].nil?
  # disabled: impossible to determine reference document with current data
  # $public_graph << RDF.Statement(publication_uri, PUB.referentieDocument, data[:reference_document]) unless data[:reference_document].nil?
  $public_graph << RDF.Statement(publication_uri, DCT.created, creation_date) unless creation_date.nil?
  $public_graph << RDF.Statement(publication_uri, PUB.publicatieWijze, data[:mode]) unless data[:mode].nil?
  $public_graph << RDF.Statement(publication_uri, PUB.identifier, data[:numac_number]) unless data[:numac_number].nil?
  $public_graph << RDF.Statement(publication_uri, RDFS.comment, data[:remark]) unless data[:remark].nil?
  $public_graph << RDF.Statement(publication_uri, DOSSIER.behandelt, data[:caze]) unless data[:caze].nil?
  $public_graph << RDF.Statement(publication_uri, DOSSIER.openingsdatum, open_date) unless open_date.nil?
  $public_graph << RDF.Statement(publication_uri, DCT.subject, data[:treatment]) unless data[:treatment].nil?
  $public_graph << RDF.Statement(publication_uri, EXT.legacyDocumentNumberMSAccess, data[:document_number]) unless data[:document_number].empty?

  data[:mandatees].each do |mandatee|
    $public_graph << RDF.Statement(publication_uri, EXT.heeftBevoegdeVoorPublicatie, mandatee)
  end

  # disabled: impossible to determine reference document with current data
  # $public_graph << RDF.Statement(data[:reference_document], FABIO.hasPageCount, data[:pages]) unless (data[:reference_document].nil? or data[:pages].nil?)
end

def validate_result(result, name, optional, exact)
  error = nil
  error = "ERROR: query '#{name}' returned #{result.length} results. Expected: 1" if (result.length > 1 && exact)
  error = "ERROR: query '#{name}' returned no results. Expected: 1" if (!optional && result.length == 0)
  error = "ERROR: query '#{name}' returned no results." if (!optional and not exact)
  if not error.nil?
    log.info error
    $errors << error
  end
  result
end

def validate(result, name, value)
  error = nil
  error = "ERROR: '#{name}' for value '#{value}'." if result.nil? or result.to_s.empty?
  if not error.nil?
    log.info error
    $errors << error
  end
  result
end