module LabileRecord
  class Row < Array
    def initialize(fields)
      @fields = fields
    end

    def method_missing(meth,*args)
      if ( field_index = @fields.index(meth.id2name) )
        at field_index
      else
        super
      end
    end
  end
end