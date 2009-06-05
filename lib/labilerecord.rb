$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module LabileRecord
  VERSION = '0.0.9'
  # TODO: refactor into a clean method
  # try to load a postgres adapter
  begin
    require 'pg'
  rescue LoadError
    begin
      require 'postgres'
    rescue LoadError
      raise LoadError, 'no postgres adapters available to load; ensure rubygems or a postgres connection adapter path is required'
    end
  end
  
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
      self
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
        send "<<", row
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
    end
    
    def connection
      LabileRecord::Base.connection
    end
    
    def to_insert_sql(table_name=nil)
      # return: [INSERT INTO table_name] (column_list) VALUES(value_list);
      sql = ""
      each do |row|
        non_nil_column_names = []
        non_nil_values = []
        row.each_with_index do |column, i|
          non_nil_column_names << fields[i].name if !column.nil?
          non_nil_values << column if !column.nil?
        end
        sql += %Q[
          #{"INSERT INTO " + table_name.to_s if table_name} (#{ non_nil_column_names.map {|c| '"' + c + '"'} * "," }) VALUES (#{ non_nil_values.map {|c| "'" + c + "'"} * "," });
        ].strip + "\n"
      end
      sql
    end
  end
  
  class Field
    attr_reader :name
    attr_reader :type
    attr_reader :type_id

    def initialize(name, type, type_id)
      @name = name
      @type = type
      @type_id = type_id
    end
  end
  
  class Row < Array
    def initialize(fields)
      @fields = fields
    end

    def method_missing(meth, *args)
      if ( field_index = @fields.index(meth.id2name) )
        at field_index
      else
        super(meth, *args)
      end
    end
  end
end