module LabileRecord
  class Field
    attr_reader :name
    attr_reader :type
    attr_reader :type_id

    def initialize(name, type, type_id)
      @name = name
      @type = type
      @type_id = type
    end
  end
end