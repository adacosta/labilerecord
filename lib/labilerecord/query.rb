module LabileRecord
  class Query < LabileRecord::Base
    attr_reader :data
    attr_reader :result
    attr_reader :fields
    attr_reader :string

    def initialize(query_string)
      @string = query_string
    end
    
    def exec
      @result = connection.exec(@string)
      parse_fields
      parse_result_data
    end
    
    def parse_result_data
      columns = @result.fields
      row_count = @result.num_tuples
      field_names = @fields.map {|field| field.name}
      rows = []
      # iterate rows
      (0..(row_count-1)).each do |row_index|
        row = Row.new(field_names)
        columns.each do |column_name|
          row << @result[row_index][column_name]
        end
        rows << row
      end
      @data = rows
    end
    
    def parse_fields
      @fields = @field_names = []
      @result.fields.each_with_index do |field_name, i|
        pg_field_type_id = @result.ftype(i)
        type = connection.exec("SELECT typname FROM 
                                pg_type WHERE oid = #{pg_field_type_id}")
        field_type_name = type[0][type.fields[0]].to_s
        @fields << Field.new( field_name, field_type_name, pg_field_type_id)
      end
      @fields
    end
    
    def connection
      self.class.superclass.connection
    end
  end
end