$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module LabileRecord
  VERSION = '0.0.11'

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
      def connection
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

    def to_insert_sql(table_name=nil, quote="'")
      # return: [INSERT INTO table_name] (column_list) VALUES(value_list);
      sql = ""
      each do |row|
        non_nil_column_names = []
        non_nil_values = []
        row.each_with_index do |column, i|
          non_nil_column_names << fields[i].name if !column.nil?
          non_nil_values << column if !column.nil?
        end
        sql << %Q[#{"INSERT INTO " + table_name.to_s if table_name} (#{ non_nil_column_names.map { |c| quote_object(c) } * "," })\n]
        sql << "VALUES ("
        non_nil_values.each_with_index do |v, i|
          sql << quote_value(v, quote) + "::" + field_by_name(non_nil_column_names[i]).type
          sql << ',' if i < non_nil_values.length - 1
        end
        sql << ");\n"
      end
      sql
    end

    def to_static_set_sql(quote="'")
      rows_sql = ""
      self.each_with_index do |row, row_index|
        row_sql = "SELECT "
        self.fields.each_with_index do |field, field_index|
          row_field_value = row.send(field.name.to_sym)
          # builds: value + cast as column + [',' if not last row]
          row_sql << (row_field_value ? quote_value(row_field_value, quote) : "NULL")
          row_sql << "::" + field.type + %Q[ AS "#{field.name}"]
          row_sql << ", " if field_index < self.fields.length - 1
        end
        row_sql << " UNION\n" if row_index < self.length - 1
        rows_sql << row_sql
      end
      rows_sql
    end

    def field_by_name(name)
      self.fields.each do |field|
        return field if field.name == name
      end
    end

    private

    def quote_value(string, quote="'")
      quote + string.to_s + quote
    end

    def quote_object(string)
      '"' + string.to_s + '"'
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