require 'linkeddata'
require 'nokogiri'

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

PUBLIC_GRAPH = RDF::Graph.new

ERRORS = Array.new

get '/ingest' do
  log.info "[STARTED] Starting publication legacy conversion"

  input_dir = "/data/input/"
  legacy_input_file_name = "legacy_data.xml"
  legacy_input_file = "#{input_dir}#{legacy_input_file_name}"

  file_timestamp = DateTime.now.strftime("%Y%m%d%H%M%S")

  output_dir = "/data/output/"
  ttl_output_file_name = "import-legacy-publications"
  ttl_output_file = "#{output_dir}#{file_timestamp}-#{ttl_output_file_name}"
  error_output_file_name = "errors.txt"
  error_output_file = "#{output_dir}#{file_timestamp}-#{error_output_file_name}"

  log.info "-- Input file : #{legacy_input_file}"
  log.info "-- Output file : #{ttl_output_file}"

  doc = Nokogiri::XML(File.open(legacy_input_file))

  publicaties = doc.css('//Dossieropvolging')

  log.info "graph: #{graph}"

  batch_number = 1
  publications_length = publicaties.size

  doc.css('Dossieropvolging').each_with_index do |publicatie, index|
    process_publicatie publicatie

    if (index > 0 and index % 1000 == 0) or index == publications_length -1
      log.info "[ONGOING] Writing generated data to files for records #{index-1000} until #{index}..."
      RDF::Writer.open("#{ttl_output_file}-#{batch_number}.ttl") { |writer| writer << PUBLIC_GRAPH }
      File.open("#{ttl_output_file}-#{batch_number}.graph", "w+") { |f| f.puts(KANSELARIJ_GRAPH)}
      File.open(error_output_file, "a+") { |f| f.puts(ERRORS) }
      log.info "done"
      PUBLIC_GRAPH = RDF::Graph.new
      ERRORS = Array.new
      batch_number += 1
    end
  end

  log.info "Processed #{publicaties.size} records."

  status 200

end

def process_publicatie(publicatie)
  dossiernummer = publicatie.css('dossiernummer').text || ""
    log.info "Processing dossiernummer #{dossiernummer}... "

    opschrift =  publicatie.css('opschrift').text || ""
    datum = publicatie.css('datum').text || ""
    soort = publicatie.css('soort').text || ""
    trefwoord = publicatie.css('trefwoord').text || ""
    bevoegde_minister = publicatie.css('bevoegde_x0020_minister_x0028_s_x0029_').text || ""
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

    if opschrift.empty? and datum.empty? and document_nr.empty?
      error = "ERROR: No sufficient data found for publication #{dossiernummer}"
      if not error.nil?
        log.info error
        ERRORS << error
      end
      return
    end

    dossier_date = datum.empty? ? opdracht_formeel_ontvangen : datum
    if dossier_date.empty?
      error = "ERROR: No date found for publication #{dossiernummer}"
      if not error.nil?
        log.info error
        ERRORS << error
      end
      return
    end

    identification_uri = create_identification(dossiernummer)

    unless bevoegde_minister.empty?
      if bevoegde_minister == 'allen'
        mandatee_uris = query_all_mandatees(dossiernummer, dossier_date)
      else
        mandatee_uris = query_mandatees(dossiernummer, bevoegde_minister, dossier_date)
      end
    end

    reference_document_uri = nil
    unless document_nr.empty?
      documents = query_reference_document(dossiernummer, document_nr)
      validate_result(documents, "Publication #{dossiernummer} query reference document #{document_nr}", true, true) unless documents.nil?
      if documents and documents.length > 0
        reference_document_uri = documents.first[:stukUri]
      else
        ERRORS << "ERROR: no document found for publication #{dossiernummer} with document number '#{document_nr}'."
      end
    end

    if reference_document_uri
      cases = query_case(reference_document_uri)
      validate_result(cases, "Publication #{dossiernummer} query case #{document_nr}", false, true)
      case_uri = cases.first[:caseUri] if cases and cases.length > 0

      treatments = query_treatment(reference_document_uri)
      validate_result(treatments, "Publication #{dossiernummer} query treatment #{document_nr}", false, true)
      treatment_uri = treatments.first[:treatmentUri] if treatments and treatments.length > 0
    else
      case_uri = create_case(opschrift)
      treatment_uri = create_treatment(dossier_date)
    end

    pages = aantal_bladzijden if aantal_bladzijden.to_i == 1

    remark = ""
    remark += "trefwoord: #{trefwoord} " unless trefwoord.empty?
    remark += "opdrachtgever: #{opdrachtgever} " unless opdrachtgever.empty?
    remark += "opmerkingen: #{opmerkingen} " unless opmerkingen.empty?

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

    ERRORS << "ERROR: No publication date found for publication #{dossiernummer}." if publicatiedatum.empty?

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
      treatment: treatment_uri,
      pages: pages,
      document_number: document_nr
    )
    log.info "Processing dossiernummer #{dossiernummer} DONE."
end

def create_identification(dossiernummer)
  structured_identifier = create_structured_identifier(dossiernummer)

  uuid = generate_uuid()
  identification_uri = RDF::URI(BASE_URI % { :resource => 'identificator', :id => uuid})
  PUBLIC_GRAPH << RDF.Statement(identification_uri, RDF.type, ADMS.Identifier)
  PUBLIC_GRAPH << RDF.Statement(identification_uri, MU_CORE.uuid, uuid)
  PUBLIC_GRAPH << RDF.Statement(identification_uri, SKOS.notation, dossiernummer)
  PUBLIC_GRAPH << RDF.Statement(identification_uri, ADMS.schemaAgency, 'ovrb')
  PUBLIC_GRAPH << RDF.Statement(identification_uri, GENERIEK.gestructureerdeIdentificator, structured_identifier)
  PUBLIC_GRAPH << RDF.Statement(identification_uri, DCT.source, DATASOURCE)

  identification_uri
end

def create_structured_identifier(dossiernummer)
  identificator = dossiernummer.match('(?<number>\d+)(?<version>[a-zA-Z0-9]*)')
  local_identificator = identificator[:number]
  version_identificator = identificator[:version]

  uuid = generate_uuid()
  structured_identification_uri = RDF::URI(BASE_URI % { :resource => 'structured-identificator', :id => uuid})
  PUBLIC_GRAPH << RDF.Statement(structured_identification_uri, RDF.type, GENERIEK.GestructureerdeIdentificator)
  PUBLIC_GRAPH << RDF.Statement(structured_identification_uri, MU_CORE.uuid, uuid)
  PUBLIC_GRAPH << RDF.Statement(structured_identification_uri, GENERIEK.lokaleIdentificator, local_identificator)
  PUBLIC_GRAPH << RDF.Statement(structured_identification_uri, GENERIEK.versieIdentificator, version_identificator) unless version_identificator.nil?
  PUBLIC_GRAPH << RDF.Statement(structured_identification_uri, DCT.source, DATASOURCE)

  structured_identification_uri
end

def query_mandatees(dossiernummer, names, date)
  ministers = names.split('/').map(&:strip).map(&:downcase)
  mandatees = Array.new

  publicationDate = DateTime.strptime(date, '%Y-%m-%dT%H:%M:%S')

  ministers.each do |minister|
    query =  " SELECT ?mandateeUri WHERE {"
    query += "   GRAPH <#{MINISTERS_GRAPH}> {"
    query += "     ?mandateeUri a <#{MANDAAT.Mandataris}> ;"
    query += "                  <#{MANDAAT.isBestuurlijkeAliasVan}> ?person ; "
    query += "                  <#{MANDAAT.start}> ?start ; "
    query += "                  <#{MANDAAT.einde}> ?end . "
    query += "     ?person <#{FOAF.familyName}> ?name ."
    query += "     FILTER (contains(lcase(str(?name)), #{minister.sparql_escape}))"
    query += "     FILTER ( ?start <= #{publicationDate.sparql_escape})"
    query += "     FILTER ( ?end >= #{publicationDate.sparql_escape})"
    query += "   }"
    query += " } LIMIT 1"

    mandatee = query(query)
    validate_result(mandatee, "Publication #{dossiernummer} query mandatee #{minister}", true, true)
    mandatee_uri = mandatee.first[:mandateeUri] if mandatee and mandatee.length > 0

    if mandatee_uri.nil?
      ERRORS << "ERROR: No mandatee found for publication #{dossiernummer} having minister value '#{minister}'"
    else
      mandatees << mandatee_uri
    end
  end

  mandatees
end

def query_all_mandatees(dossiernummer, date)
  mandatees = Array.new

  publicationDate = DateTime.strptime(date, '%Y-%m-%dT%H:%M:%S')

  query =  " SELECT ?mandateeUri WHERE {"
  query += "   GRAPH <#{MINISTERS_GRAPH}> {"
  query += "     ?mandateeUri a <#{MANDAAT.Mandataris}> ;"
  query += "                  <#{MANDAAT.start}> ?start ; "
  query += "                  <#{MANDAAT.einde}> ?end . "
  query += "     FILTER ( ?start < #{publicationDate.sparql_escape})"
  query += "     FILTER ( ?end > #{publicationDate.sparql_escape})"
  query += "   }"
  query += " }"

  mandatees_query_result = query(query)
  validate_result(mandatees_query_result, "Publication #{dossiernummer} query mandatee", true, false)

  if mandatees_query_result and mandatees_query_result.length > 0
    mandatees_query_result.each do |mandatee|
      mandatee_uri = mandatee[:mandateeUri]

      if mandatee_uri.nil?
        ERRORS << "ERROR: No mandatees found for publication #{dossiernummer}"
      else
        mandatees << mandatee_uri
      end
    end
  end

  mandatees
end


def query_reference_document(dossiernummer, document_number)
  # reformatting document number from e.g. from 'VR/96/09.07/0547' to VR 1996 0907 DOC.0547 /

  titleParts = document_number.match('VR/(?<year>\d{2})/(?<day>[0-9]{2})\.(?<month>[0-9]{2})/(?<number>\d{4})')

  if titleParts.nil?
    error = "Error parsing document number '#{document_number} for publication #{dossiernummer}"
    if not error.nil?
      log.info error
      ERRORS << error
      return
    end
  end

  year = titleParts[:year]
  year4 = year.to_i < 30 ? "20" + year : "19" + year

  docTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} DOC.#{titleParts[:number]}"
  medTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} MED.#{titleParts[:number]}"
  log.info "reformatting document_number '#{document_number}' into '#{docTitle}'"

  query =  " SELECT ?stukUri WHERE {"
  query += "   GRAPH <#{KANSELARIJ_GRAPH}> {"
  query += "     ?stukUri a <#{DOSSIER.Stuk}> ;"
  query += "              <#{DCT.title}> ?title ."
  query += "   FILTER (strstarts(str(?title), ?titleValue) )"
  query += "   VALUES ?titleValue  { '#{docTitle}' '#{medTitle}' }"
  query += "   }"
  query += " } ORDER BY ?title LIMIT 1"

  query(query)
end

def create_case(title)
  uuid = generate_uuid()
  case_uri = RDF::URI(BASE_URI % { :resource => 'dossier', :id => uuid})
  PUBLIC_GRAPH << RDF.Statement(case_uri, RDF.type, DOSSIER.Dossier)
  PUBLIC_GRAPH << RDF.Statement(case_uri, MU_CORE.uuid, uuid)
  PUBLIC_GRAPH << RDF.Statement(case_uri, DCT.alternative, title)
  PUBLIC_GRAPH << RDF.Statement(case_uri, DCT.source, DATASOURCE)
  case_uri
end

def create_treatment(date)
  startDate = DateTime.strptime(date, '%Y-%m-%dT%H:%M:%S')
  uuid = generate_uuid()
  treatment_uri = RDF::URI(BASE_URI % { :resource => 'behandeling-van-agendapunt', :id => uuid})
  PUBLIC_GRAPH << RDF.Statement(treatment_uri, RDF.type, BESLUIT.BehandelingVanAgendapunt)
  PUBLIC_GRAPH << RDF.Statement(treatment_uri, MU_CORE.uuid, uuid)
  PUBLIC_GRAPH << RDF.Statement(treatment_uri, DOSSIER['Activiteit.startdatum'], startDate)
  PUBLIC_GRAPH << RDF.Statement(treatment_uri, DCT.source, DATASOURCE)
  treatment_uri
end

def query_case(reference_document_uri)
  query =  " SELECT ?caseUri WHERE {"
  query += "   GRAPH <#{KANSELARIJ_GRAPH}> {"
  query += "     ?caseUri a <#{DOSSIER.Dossier}> ;"
  query += "              <#{DOSSIER['Dossier.bestaatUit']}> <#{reference_document_uri}> ."
  query += "   }"
  query += " } LIMIT 1"

  query(query)
end

def query_treatment(reference_document_uri)
  query =  " SELECT ?treatmentUri WHERE {"
  query += "   GRAPH <#{KANSELARIJ_GRAPH}> {"
  query += "     ?agendaItem <#{BESLUITVORMING.geagendeerdStuk}> <#{reference_document_uri}> ."
  query += "     ?treatmentUri a <#{BESLUIT.BehandelingVanAgendapunt}> ;"
  query += "              <#{BESLUITVORMING.heeftOnderwerp}> ?agendaItem ."
  query += "   }"
  query += " } LIMIT 1"

  query(query)
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
  startDate = DateTime.strptime(data[:vertaling_aangevraagd], '%Y-%m-%dT%H:%M:%S') unless data[:vertaling_aangevraagd].empty?
  endDate = DateTime.strptime(data[:vertaling_ontvangen], '%Y-%m-%dT%H:%M:%S') unless data[:vertaling_ontvangen].empty?
  dueDate = DateTime.strptime(data[:limiet_vertaling], '%Y-%m-%dT%H:%M:%S') unless data[:limiet_vertaling].empty?

  startDate = DateTime.strptime(data[:created], '%Y-%m-%dT%H:%M:%S') if startDate.nil? and not data[:created].empty?
  endDate = DateTime.strptime(data[:publicatiedatum], '%Y-%m-%dT%H:%M:%S') if endDate.nil? and not data[:publicatiedatum].empty?

  uuid = generate_uuid()
  subcase_uri = RDF::URI(BASE_URI % { :resource => 'procedurestap', :id => uuid})
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, RDF.type, PUB.VertalingProcedurestap)
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, MU_CORE.uuid, uuid)
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.startdatum'], startDate) unless startDate.nil?
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.einddatum'], endDate) unless endDate.nil?
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, TMO.dueDate, dueDate) unless dueDate.nil?
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, DCT.source, DATASOURCE)

  if startDate or endDate or dueDate
    request_activity_uuid = generate_uuid()
    request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => request_activity_uuid})
    PUBLIC_GRAPH << RDF.Statement(request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
    PUBLIC_GRAPH << RDF.Statement(request_activity_uri, MU_CORE.uuid, request_activity_uuid)
    PUBLIC_GRAPH << RDF.Statement(request_activity_uri, DOSSIER['Activiteit.startdatum'], startDate) unless startDate.nil?
    PUBLIC_GRAPH << RDF.Statement(request_activity_uri, DOSSIER['Activiteit.einddatum'], startDate) unless startDate.nil?
    PUBLIC_GRAPH << RDF.Statement(request_activity_uri, PUB.aanvraagVindtPlaatsTijdensVertaling, subcase_uri)
    PUBLIC_GRAPH << RDF.Statement(request_activity_uri, DCT.source, DATASOURCE)

    translation_activity_uuid = generate_uuid()
    translation_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'vertaal-activiteit', :id => translation_activity_uuid})
    PUBLIC_GRAPH << RDF.Statement(translation_activity_uri, RDF.type, PUB.VertaalActiviteit)
    PUBLIC_GRAPH << RDF.Statement(translation_activity_uri, MU_CORE.uuid, translation_activity_uuid)
    PUBLIC_GRAPH << RDF.Statement(translation_activity_uri, DOSSIER['Activiteit.startdatum'], startDate) unless startDate.nil?
    PUBLIC_GRAPH << RDF.Statement(translation_activity_uri, DOSSIER['Activiteit.einddatum'], endDate) unless endDate.nil?
    PUBLIC_GRAPH << RDF.Statement(translation_activity_uri, PUB.vertalingsactiviteitVanAanvraag, request_activity_uri)
    PUBLIC_GRAPH << RDF.Statement(translation_activity_uri, PUB.vertalingVindtPlaatsTijdens, subcase_uri)
    PUBLIC_GRAPH << RDF.Statement(translation_activity_uri, DCT.source, DATASOURCE)
  end

  PUBLIC_GRAPH << RDF.Statement(data[:publication_uri], PUB.doorlooptVertaling, subcase_uri)
end

def create_publication_subcase(data)
  proofingStartDate = DateTime.strptime(data[:drukproef_aangevraagd], '%Y-%m-%dT%H:%M:%S') unless data[:drukproef_aangevraagd].empty?
  proofingEndDate = DateTime.strptime(data[:drukproef_ontvangen], '%Y-%m-%dT%H:%M:%S') unless data[:drukproef_ontvangen].empty?
  publicationStartDate = DateTime.strptime(data[:naar_BS_voor_publicatie], '%Y-%m-%dT%H:%M:%S') unless data[:naar_BS_voor_publicatie].empty?
  dueDate = DateTime.strptime(data[:limiet_publicatie], '%Y-%m-%dT%H:%M:%S') unless data[:limiet_publicatie].empty?
  targetEndDate = DateTime.strptime(data[:gevraagde_publicatiedatum], '%Y-%m-%dT%H:%M:%S') unless data[:gevraagde_publicatiedatum].empty?
  publicationEndDate = DateTime.strptime(data[:publicatiedatum], '%Y-%m-%dT%H:%M:%S') unless data[:publicatiedatum].empty?

  proofingStartDate = DateTime.strptime(data[:created], '%Y-%m-%dT%H:%M:%S') if proofingStartDate.nil? and not data[:created].empty?
  proofingEndDate = publicationEndDate if proofingEndDate.nil? and not publicationEndDate.nil?

  publicationStartDate = DateTime.strptime(data[:created], '%Y-%m-%dT%H:%M:%S') if publicationStartDate.nil? and not data[:created].empty?

  publication_subcase_uuid = generate_uuid()
  subcase_uri = RDF::URI(BASE_URI % { :resource => 'procedurestap', :id => publication_subcase_uuid})
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, RDF.type, PUB.PublicatieProcedurestap)
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, MU_CORE.uuid, publication_subcase_uuid)
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.startdatum'], proofingStartDate) unless proofingStartDate.nil?
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, DOSSIER['Procedurestap.einddatum'], publicationEndDate) unless publicationEndDate.nil?
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, TMO.dueDate, dueDate) unless dueDate.nil?
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, TMO.targetEndTime, targetEndDate) unless targetEndDate.nil?
  PUBLIC_GRAPH << RDF.Statement(subcase_uri, DCT.source, DATASOURCE)

  if proofingStartDate or proofingEndDate
    proofing_request_activity_uuid = generate_uuid()
    proofing_request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => proofing_request_activity_uuid})
    PUBLIC_GRAPH << RDF.Statement(proofing_request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
    PUBLIC_GRAPH << RDF.Statement(proofing_request_activity_uri, MU_CORE.uuid, proofing_request_activity_uuid)
    PUBLIC_GRAPH << RDF.Statement(proofing_request_activity_uri, DOSSIER['Activiteit.startdatum'], proofingStartDate) unless proofingStartDate.nil?
    PUBLIC_GRAPH << RDF.Statement(proofing_request_activity_uri, DOSSIER['Activiteit.einddatum'], proofingStartDate) unless proofingStartDate.nil?
    PUBLIC_GRAPH << RDF.Statement(proofing_request_activity_uri, PUB.aanvraagVindtPlaatsTijdensPublicatie, subcase_uri)
    PUBLIC_GRAPH << RDF.Statement(proofing_request_activity_uri, DCT.source, DATASOURCE)

    proofing_activity_uuid = generate_uuid()
    proofing_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'drukproef-activiteit', :id => proofing_activity_uuid})
    PUBLIC_GRAPH << RDF.Statement(proofing_activity_uri, RDF.type, PUB.DrukproefActiviteit)
    PUBLIC_GRAPH << RDF.Statement(proofing_activity_uri, MU_CORE.uuid, proofing_activity_uuid)
    PUBLIC_GRAPH << RDF.Statement(proofing_activity_uri, DOSSIER['Activiteit.startdatum'], proofingStartDate) unless proofingStartDate.nil?
    PUBLIC_GRAPH << RDF.Statement(proofing_activity_uri, DOSSIER['Activiteit.einddatum'], proofingEndDate) unless proofingEndDate.nil?
    PUBLIC_GRAPH << RDF.Statement(proofing_activity_uri, PUB.drukproefactiviteitVanAanvraag, proofing_request_activity_uri)
    PUBLIC_GRAPH << RDF.Statement(proofing_activity_uri, PUB.drukproefVindtPlaatsTijdens, subcase_uri)
    PUBLIC_GRAPH << RDF.Statement(proofing_activity_uri, DCT.source, DATASOURCE)
  end

  if publicationStartDate or publicationEndDate
    publication_request_activity_uuid = generate_uuid()
    publication_request_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'aanvraag-activiteit', :id => publication_request_activity_uuid})
    PUBLIC_GRAPH << RDF.Statement(publication_request_activity_uri, RDF.type, PUB.AanvraagActiviteit)
    PUBLIC_GRAPH << RDF.Statement(publication_request_activity_uri, MU_CORE.uuid, publication_request_activity_uuid)
    PUBLIC_GRAPH << RDF.Statement(publication_request_activity_uri, DOSSIER['Activiteit.startdatum'], publicationStartDate) unless publicationStartDate.nil?
    PUBLIC_GRAPH << RDF.Statement(publication_request_activity_uri, DOSSIER['Activiteit.einddatum'], publicationStartDate) unless publicationStartDate.nil?
    PUBLIC_GRAPH << RDF.Statement(publication_request_activity_uri, PUB.aanvraagVindtPlaatsTijdensPublicatie, subcase_uri)
    PUBLIC_GRAPH << RDF.Statement(publication_request_activity_uri, DCT.source, DATASOURCE)

    publication_activity_uuid = generate_uuid()
    publication_activity_uri = RDF::URI(CONCEPT_URI % { :resource => 'publicatie-activiteit', :id => publication_activity_uuid})
    PUBLIC_GRAPH << RDF.Statement(publication_activity_uri, RDF.type, PUB.DrukproefActiviteit)
    PUBLIC_GRAPH << RDF.Statement(publication_activity_uri, MU_CORE.uuid, publication_activity_uuid)
    PUBLIC_GRAPH << RDF.Statement(publication_activity_uri, DOSSIER['Activiteit.startdatum'], publicationStartDate) unless publicationStartDate.nil?
    PUBLIC_GRAPH << RDF.Statement(publication_activity_uri, DOSSIER['Activiteit.einddatum'], publicationEndDate) unless publicationEndDate.nil?
    PUBLIC_GRAPH << RDF.Statement(publication_activity_uri, PUB.publicatieactiviteitVanAanvraag, publication_request_activity_uri)
    PUBLIC_GRAPH << RDF.Statement(publication_activity_uri, PUB.publicatieVindtPlaatsTijdens, subcase_uri)
    PUBLIC_GRAPH << RDF.Statement(publication_activity_uri, DCT.source, DATASOURCE)
  end

  PUBLIC_GRAPH << RDF.Statement(data[:publication_uri], PUB.doorlooptPublicatie, subcase_uri)
end

def create_numac_number(werknummer_BS)
  uuid = generate_uuid()
  numac_uri = RDF::URI(BASE_URI % { :resource => 'identificator', :id => uuid})
  PUBLIC_GRAPH << RDF.Statement(numac_uri, RDF.type, ADMS.Identifier)
  PUBLIC_GRAPH << RDF.Statement(numac_uri, MU_CORE.uuid, uuid)
  PUBLIC_GRAPH << RDF.Statement(numac_uri, SKOS.notation, werknummer_BS)
  PUBLIC_GRAPH << RDF.Statement(numac_uri, ADMS.schemaAgency, 'Belgisch Staatsblad')
  PUBLIC_GRAPH << RDF.Statement(numac_uri, DCT.source, DATASOURCE)

  numac_uri
end

def create_publicationflow()
  uuid = generate_uuid()
  publication_uri = RDF::URI(BASE_URI % { :resource => 'publicatie-aangelegenheid', :id => uuid})
  PUBLIC_GRAPH << RDF.Statement(publication_uri, RDF.type, PUB.Publicatieaangelegenheid)
  PUBLIC_GRAPH << RDF.Statement(publication_uri, MU_CORE.uuid, uuid)
  PUBLIC_GRAPH << RDF.Statement(publication_uri, DCT.source, DATASOURCE)
  PUBLIC_GRAPH << RDF.Statement(publication_uri, ADMS.status, PUBLISHED_STATUS)

  publication_uri
end

def set_publicationflow(data)
  publication_uri = data[:publication_uri]

  creation_date = DateTime.strptime(data[:created], '%Y-%m-%dT%H:%M:%S') unless data[:created].empty?

  PUBLIC_GRAPH << RDF.Statement(publication_uri, ADMS.identifier, data[:identification]) unless data[:identification].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, DCT.alternative, data[:short_title]) unless data[:short_title].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, PUB.regelgevingType, data[:regulation_type]) unless data[:regulation_type].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, PUB.referentieDocument, data[:reference_document]) unless data[:reference_document].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, DCT.created, creation_date) unless creation_date.nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, PUB.publicatieWijze, data[:mode]) unless data[:mode].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, PUB.identifier, data[:numac_number]) unless data[:numac_number].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, RDFS.comment, data[:remark]) unless data[:remark].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, DOSSIER.behandelt, data[:caze]) unless data[:caze].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, DCT.subject, data[:treatment]) unless data[:treatment].nil?
  PUBLIC_GRAPH << RDF.Statement(publication_uri, EXT.legacyDocumentNumberMSAccess, data[:document_number]) unless data[:document_number].empty?

  unless data[:mandatees].nil?
    data[:mandatees].each do |mandatee|
      PUBLIC_GRAPH << RDF.Statement(publication_uri, EXT.heeftBevoegdeVoorPublicatie, mandatee)
    end
  end

  PUBLIC_GRAPH << RDF.Statement(data[:reference_document], FABIO.hasPageCount, data[:pages]) unless (data[:reference_document].nil? or data[:pages].nil?)
end

def validate_result(result, name, optional, exact)
  error = nil
  error = "ERROR: query '#{name}' returned #{result.length} results. Expected: 1" if (result.length > 1 && exact)
  error = "ERROR: query '#{name}' returned no results. Expected: 1" if (!optional && result.length == 0)
  error = "ERROR: query '#{name}' returned no results." if (!optional and not exact)
  if not error.nil?
    log.info error
    ERRORS << error
  end
  result
end

def validate(result, name, value)
  error = nil
  error = "ERROR: '#{name}' for value '#{value}'." if result.nil? or result.to_s.empty?
  if not error.nil?
    log.info error
    ERRORS << error
  end
  result
end