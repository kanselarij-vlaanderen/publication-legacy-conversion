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
  
    def self.government_domains
      path = File.join(__dir__, "../configuration/government-domains.csv")
      # relative path does not work in Docker container because of different working directory
      return CSV.open path, "rt", encoding: "UTF-8" # otherwise Ruby 2.5 assumes ASCII
    end  
  end

  module Environment
    def self.safe
      !(ENV['SAFE']&.downcase === "off")
    end
  end
end