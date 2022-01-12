module Configuration
  module Files
    def self.regulation_types_keys
      path = File.join(__dir__, "../configuration/regulation-types-keys.csv")
      # relative path does not work in Docker container because of different working directory
      return CSV.open path, "rt", encoding: "UTF-8" # otherwise Ruby 2.5 assumes ASCII
    end

    def self.regulation_types_uris
      path = File.join(__dir__, "../configuration/regulation-types-uris.csv")
      # relative path does not work in Docker container because of different working directory
      return CSV.open path, "rt", encoding: "UTF-8" # otherwise Ruby 2.5 assumes ASCII
    end

    def self.government_domains_keys
      path = File.join(__dir__, "../configuration/government-domains-keys.csv")
      # relative path does not work in Docker container because of different working directory
      return CSV.open path, "rt", encoding: "UTF-8" # otherwise Ruby 2.5 assumes ASCII
    end

    def self.government_domains_uris
      path = File.join(__dir__, "../configuration/government-domains-uris.csv")
      # relative path does not work in Docker container because of different working directory
      return CSV.open path, "rt", encoding: "UTF-8" # otherwise Ruby 2.5 assumes ASCII
    end

    def self.government_domains_ignore
      path = File.join(__dir__, "../configuration/government-domains-ignore.csv")
      # relative path does not work in Docker container because of different working directory
      return CSV.open path, "rt", encoding: "UTF-8" # otherwise Ruby 2.5 assumes ASCII
    end

    def self.mandatees_corrections
      path = File.join(__dir__, "../configuration/mandatees-corrections.csv")
      # relative path does not work in Docker container because of different working directory
      return CSV.open path, "rt", encoding: "UTF-8" # otherwise Ruby 2.5 assumes ASCII
    end
  end

  module Output
    def self.government_domains
      output_dir = Configuration::Environment.output_dir
      file = File.join __dir__, "..", output_dir, "government-domains-mapping.csv"
      return CSV.open file, "wt", encoding: "UTF-8"
    end
  end

  module Environment
    def self.safe
      !(ENV['SAFE']&.downcase === "off")
    end

    def self.input_dir
      return ENV['INPUT_DIR'] || '/data/input/'
    end

    def self.output_dir
      return ENV['OUTPUT_DIR'] || '/data/output/'
    end
  end
end
