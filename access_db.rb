module AccessDB
  extend self

  FIELDS = {
    dossiernummer: 'dossiernummer',
    opschrift: 'opschrift',
    soort: 'soort',
    datum: 'datum',
    trefwoord: 'trefwoord',
    bevoegde_ministers: 'bevoegde_x0020_minister_x0028_s_x0029_',
    document_nr: 'document_x0020_nr',
    aantal_bladzijden: 'aantal_x0020_blz',
    opdrachtgever: 'opdrachtgever',
    opdracht_formeel_ontvangen: 'opdracht_x0020_formeel_x0020_ontvangen',
    wijze_van_publicatie: 'wijze_x0020_van_x0020_publicatie',
    vertaling_aangevraagd: 'vertaling_x0020_aangevraagd',
    limiet_vertaling: 'limiet_x0020_vertaling',
    vertaling_ontvangen: 'vertaling_x0020_ontvangen',
    drukproef_aangevraagd: 'drukproef_x0020_aangevraagd',
    drukproef_ontvangen: 'drukproef_x0020_ontvangen',
    naar_BS_voor_publicatie: 'naar_x0020_BS_x0020_voor_x0020_publicatie',
    limiet_publicatie: 'limiet_x0020_publicatie',
    gevraagde_publicatiedatum: 'gevraagde_x0020_publicatiedatum',
    publicatiedatum: 'PUBLICATIEDATUM',
    opmerkingen: 'opmerkingen',
    werknummer_BS: 'werknummer_x0020_BS',
    beleidsdomein: 'beleidsdomein'
  }

  def self.initialize
    input_file = "data/input/legacy_data.xml"
    @doc = Nokogiri::XML(File.open(input_file)) { |c| c.noblanks }
  end

  initialize

  def self.by_dossiernummer(dossiernummers)
    dossiernummers
      .lazy
      .map { |dossiernummer|
        node = @doc.xpath("//Dossieropvolging/dossiernummer[.=\"#{dossiernummer}\"]")[0].parent
      }
      .map { |n| record(n) }
  end

  def self.nodes()
    return @doc.xpath('//Dossieropvolging')
  end

  def self.[](range = nil)
    records = @doc.xpath('//Dossieropvolging')

    if !range.nil?
      records = records[range]
    end
    
    records
      .lazy
      .map { |n| record(n) }
  end

  def record(node)
    Record.new node
    # fields.map { |key| 
    #   [key, field(node, key)]
    # } .to_h
  end
  
  def field(n, name)
    field_nodes = n > AccessDB::FIELDS[name]
    if field_nodes.length === 0
      nil
    else
      field_node = field_nodes[0]
      field_node.content
    end
  end

  class Record
    def initialize(record_node)
      @record_node = record_node
    end
  
    def method_missing name_sym
      AccessDB::field(@record_node, name_sym)
    end
  end
end