module Cequel

  module Schema

    class Keyspace

      def initialize(keyspace)
        @keyspace = keyspace
      end

      def read_table(name)
        table_query = @keyspace.execute(<<-CQL, @keyspace.name, name)
          SELECT * FROM system.schema_columnfamilies
          WHERE keyspace_name = ? AND columnfamily_name = ?
        CQL
        table_data = table_query.first.to_hash
        Table.read(table_data)
      end

      def create_table(name, &block)
        table = Table.new(name)
        TableDSL.apply(table, &block)
        table.create_cql.each do |statement|
          @keyspace.execute(statement)
        end
      end

      def drop_table(name)
        @keyspace.execute("DROP TABLE #{name}")
      end

    end

  end

end
