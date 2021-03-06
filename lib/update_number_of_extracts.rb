module LegacyPublicationConversion
  class AbortError < StandardError; end

  module UpdateNumberOfExtracts
    @kanselarij_graph = nil
    @errors_csv = nil

    def self.run(records)
      file_timestamp = DateTime.now.strftime("%Y%m%d%H%M%S")
      publications_ttl_output_file_name = "legacy-publications--update--number-of-extracts"
      publications_ttl_output_file = File.join(Configuration::Environment.output_dir,
                                               "#{file_timestamp}-#{publications_ttl_output_file_name}")
      @errors_csv = CSV.open(File.join(Configuration::Environment.output_dir, "#{file_timestamp}-errors.csv"), "a+",
                             encoding: "UTF-8")

      Mu.log.info "-- Input file : #{AccessDB.input_file}"
      Mu.log.info "-- Output file : #{publications_ttl_output_file}"

      kanselarij_graph = RDF::Graph.new

      batch_number = 1
      batch_size = 1000
      records.each_with_index do |record, index|
        dossiernummer = record.dossiernummer

        begin
          Mu.log.info "Updating number of pages for ##{dossiernummer} (#{index + 1}/#{records.size}) ... "

          kanselarij_graph.transaction(mutable: true) do |tx|
            @kanselarij_graph = tx
            process_record record
          end

          Mu.log.info "Updating number of pages ##{dossiernummer} DONE."
        rescue AbortError
          Mu.log.info "Updating number of pages ##{dossiernummer} SKIPPED."
          # record can not be converted, continue
        end

        next unless ((index + 1) % batch_size).zero? || index == records.size - 1

        Mu.log.info "[ONGOING] Writing generated data to file for records "\
                    "#{(batch_number - 1) * batch_size + 1} until #{[batch_number * batch_size, index + 1].min}..."
        RDF::Writer.open("#{publications_ttl_output_file}-#{batch_number}.ttl") do |writer|
          writer << kanselarij_graph
        end
        File.open("#{publications_ttl_output_file}-#{batch_number}.graph", "w+") do |f|
          f.puts(KANSELARIJ_GRAPH)
        end
        Mu.log.info "done"
        kanselarij_graph = RDF::Graph.new
        batch_number += 1
      end

      @errors_csv.close
      Mu.log.info "Processed #{records.size} records."
    end

    def self.process_record(rec)
      unless should_convert? rec
        @errors_csv << [rec.dossiernummer, "skip - should not convert"]
        raise AbortError, "skip #{rec.dossiernummer}"
      end

      publication_flow_uri, number_of_extracts = query_publication_flow rec
      if publication_flow_uri.nil?
        @errors_csv << [rec.dossiernummer, "skip - no resource found"]
        raise AbortError, "no-Kaleidos-record #{rec.dossiernummer}"
      end

      unless number_of_extracts.nil?
        @errors_csv << [rec.dossiernummer, "skip - resource already has number of extracts"]
        raise AbortError, "number of extracts exists for #{rec.dossiernummer}"
      end

      set_number_of_extracts publication_flow_uri, rec
    end

    # checks whether a publication-flow should be converted
    # These are the same checks as in conversion.rb
    def self.should_convert?(rec)
      publication_number, publication_number_suffix = convert_publication_number rec

      return false if publication_number.zero? && publication_number_suffix&.downcase == "subsidie"
      return false if publication_number.nil?
      return false if rec.opschrift.nil? && rec.datum.nil? && rec.document_nr.nil?

      dossier_date = get_dossier_date rec
      return false if dossier_date.nil?

      true
    end

    def self.query_publication_flow(rec)
      publication_number, publication_number_suffix = convert_publication_number rec
      publication_number_full = "#{publication_number} #{publication_number_suffix}".strip
      sparql = %(
        PREFIX adms: <http://www.w3.org/ns/adms#>
        PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
        PREFIX pub: <http://mu.semte.ch/vocabularies/ext/publicatie/>

        SELECT ?publicationFlowUri ?numberOfExtracts
        WHERE {
          GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
            ?publicationFlowUri adms:identifier ?publicationNumberUri .
            ?publicationNumberUri skos:notation #{publication_number_full.sparql_escape} .

            OPTIONAL { ?publicationFlowUri pub:aantalUittreksels ?numberOfExtracts . }
          }
        }
      )
      results = LinkedDB.query(sparql)
      if results.empty?
        @errors_csv << [rec.dossiernummer, "info - no resource found", sparql]
        nil
      elsif results.length > 1
        @errors_csv << [rec.dossiernummer, "info - found multiple resources", sparql]
        nil
      else
        [results[0][:publicationFlowUri], results[0][:numberOfExtracts]&.value]
      end
    end

    def self.set_number_of_extracts(publication_flow_uri, rec)
      return unless rec.aantal_uittreksels

      @kanselarij_graph << RDF.Statement(publication_flow_uri, PUB.aantalUittreksels, rec.aantal_uittreksels)
    end
  end
end
