$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module LabileRecord
  VERSION = '0.0.1'
  require 'pg'
  
  class Base
    class << self
      def connection(*args)
        @connection
      end

      def connection=(*args)
        @connection = PGconn.open(*args)
      end
    end
  end
  
  class Query < Array
    attr_reader :result
    attr_reader :fields
    attr_reader :string

    def initialize(query_string)
      @string = query_string
    end
    
    def exec!
      @result = connection.exec(@string)
      parse_fields
      parse_result_data
    end
    
    def parse_result_data
      columns = @result.fields
      row_count = @result.num_tuples
      field_names = @fields.map {|field| field.name}
      # iterate rows
      (0..(row_count-1)).each do |row_index|
        row = Row.new(field_names)
        columns.each do |column_name|
          row << @result[row_index][column_name]
        end
        push row
      end
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
      LabileRecord::Base.connection
    end
  end
  
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