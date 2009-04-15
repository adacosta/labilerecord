module LabileRecord
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
end