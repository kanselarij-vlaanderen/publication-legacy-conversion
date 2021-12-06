module ConvertRegulationType
  def self.initialize
    mapping_keys_csv = Configuration::Files.regulation_types_keys
    @mapping_keys = mapping_keys_csv.to_h
    mapping_uris_csv = Configuration::Files.regulation_types_uris
    @mapping_uris = mapping_uris_csv.to_h
  end
  initialize

  def self.convert rec
    regulation_type = rec.soort
    if regulation_type
      regulation_type.strip!
      regulation_type.downcase!

      key = @mapping_keys[regulation_type]
      if key.nil?
        $errors_csv << [rec.dossiernummer, "regulation-type", "not-found", regulation_type]
        return
      end
      uri = @mapping_uris[key]
      if uri.nil?
        raise StandardError.new "no URI for regulation type key #{key}"
      end

      return RDF::URI uri
    end
  end
end