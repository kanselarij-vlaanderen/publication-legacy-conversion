module LegacyPublicationConversion
  class AbortError < StandardError; end

  module UpdateNumberOfPages
    def self.run records
      file_timestamp = DateTime.now.strftime('%Y%m%d%H%M%S')
      publications_ttl_output_file_name = 'legacy-publications--update--number-of-pages'
      publications_ttl_output_file = "#{Configuration::Environment.output_dir}/#{file_timestamp}-#{publications_ttl_output_file_name}"

      $errors_csv = CSV.open(
        "#{Configuration::Environment.output_dir}/#{file_timestamp}-errors.csv", mode = 'a+', encoding: 'UTF-8'
      )

      Mu.log.info "-- Input file : #{AccessDB.input_file}"
      Mu.log.info "-- Output file : #{publications_ttl_output_file}"

      kanselarij_graph = RDF::Graph.new

      batch_number = 1
      batch_size = 1000
      records.each_with_index do |record, index|
        dossiernummer = record.dossiernummer
        
        begin
          Mu.log.info "Updating number of pages for ##{dossiernummer} (#{index + 1}/#{records.size}) ... "
          
          kanselarij_graph.transaction(mutable:true) do |tx|
            $kanselarij_graph = tx
            process_record record
          end

          Mu.log.info "Updating number of pages ##{dossiernummer} DONE."
        rescue AbortError => x
          Mu.log.info "Updating number of pages ##{dossiernummer} SKIPPED."
          # record can not be converted, continue
        end

        if (index > 0 and index % batch_size == 0) or index == records.size - 1
          Mu.log.info "[ONGOING] Writing generated data to file for records #{(batch_number - 1) * batch_size + 1} until #{[
            batch_number * batch_size, index + 1
          ].min}..."
          RDF::Writer.open("#{publications_ttl_output_file}-#{batch_number}.ttl") do |writer|
            writer << kanselarij_graph
          end
          File.open("#{publications_ttl_output_file}-#{batch_number}.graph", 'w+') do |f|
            f.puts(KANSELARIJ_GRAPH)
          end
          Mu.log.info 'done'
          kanselarij_graph = RDF::Graph.new
          batch_number += 1
        end
      end

      $errors_csv.close
      Mu.log.info "Processed #{records.size} records."
    end

    def self.process_record rec
      if not should_convert? rec
        $errors_csv << [rec.dossiernummer, "skip"]
        raise AbortError.new "skip #{rec.dossiernummer}"
      end

      publication_flow_uri = query_publication_flow rec
      if publication_flow_uri.nil?
        $errors_csv << [rec.dossiernummer, "no-Kaleidos-record", rec.dossiernummer]
        raise AbortError.new "no-Kaleidos-record #{rec.dossiernummer}"
      end
      set_number_of_pages publication_flow_uri, rec
    end

    # checks whether a publication-flow should be converted
    # These are the same checks as in conversion.rb
    def self.should_convert? rec
        publication_number, publication_number_suffix = convert_publication_number rec

        return false if publication_number == 0 and publication_number_suffix&.downcase == 'subsidie'
        return false if publication_number.nil?
        return false if rec.opschrift.nil? and rec.datum.nil? and rec.document_nr.nil?
        dossier_date = get_dossier_date rec
        return false if dossier_date.nil?
    end

    def self.query_publication_flow rec
      publication_number, publication_number_suffix = convert_publication_number rec
      publication_number_full = publication_number.to_s
      if publication_number_suffix
        publication_number_full = publication_number_full + ' ' + publication_number_suffix
      end

      sparql = %{
        PREFIX adms: <http://www.w3.org/ns/adms#>
        PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
        SELECT ?publicationFlowUri
        WHERE {
          GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
            ?publicationFlowUri adms:identifier ?publicationNumberUri .
            ?publicationNumberUri skos:notation #{publication_number_full.sparql_escape} .
          }
        }
      }

      results = LinkedDB.query(sparql)
      if results.length === 0
        $errors_csv << [rec.dossiernummer, 'publication-flow', 'not-found', 'used:', nil, 'query parameters:', rec.dossiernummer, sparql]
        return
      elsif results.length >= 1
        result = results[0]
        if results.length > 1
          $errors_csv << [rec.dossiernummer, 'dossier', 'found-multiple', 'used:', result[:publicationFlowUri].value, 'query parameters:' , rec.dossiernummer, sparql]
        end
      end
      
      result[:publicationFlowUri]
    end

    def self.set_number_of_pages(publication_flow_uri, rec)
      $kanselarij_graph << RDF.Statement(publication_flow_uri, FABIO.hasPageCount, rec.aantal_bladzijden) if rec.aantal_bladzijden
    end
  end
end