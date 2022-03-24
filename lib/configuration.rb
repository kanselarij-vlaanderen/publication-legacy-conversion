module Configuration
  module Files
    def self.regulation_types_keys
      path = File.join("/app/configuration/regulation-types-keys.csv")
      return CSV.open path, "rt", encoding: "UTF-8"
    end

    def self.regulation_types_uris
      path = File.join("/app/configuration/regulation-types-uris.csv")
      return CSV.open path, "rt", encoding: "UTF-8"
    end

    def self.government_domains_keys
      path = File.join("/app/configuration/government-domains-keys.csv")
      return CSV.open path, "rt", encoding: "UTF-8"
    end

    def self.government_domains_uris
      path = File.join("/app/configuration/government-domains-uris.csv")
      return CSV.open path, "rt", encoding: "UTF-8"
    end

    def self.government_domains_ignore
      path = File.join("/app/configuration/government-domains-ignore.csv")
      return CSV.open path, "rt", encoding: "UTF-8"
    end

    def self.government_domains_full_name &block
      path = File.join("/app/configuration/government-domains-full-name.csv")
      return CSV.open path, "rt", encoding: "UTF-8", col_sep: ';', &block
    end

    def self.mandatees_corrections
      path = File.join("/app/configuration/mandatees-corrections.csv")
      return CSV.open path, "rt", encoding: "UTF-8"
    end
  end

  module Output
    def self.government_domains &block
      output_dir = Configuration::Environment.output_dir
      file = File.join output_dir, "government-domains-mapping.csv"
      return CSV.open file, "wt", encoding: "UTF-8", quote_empty: false, &block
    end
  end

  module Environment
    def self.safe
      !(ENV['SAFE']&.downcase === "off")
    end

    def self.input_dir
      return ENV['INPUT_DIR'] || '/data/input'
    end

    def self.output_dir
      return ENV['OUTPUT_DIR'] || '/data/output'
    end
  end
end
