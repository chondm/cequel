require 'stringio'

module Cequel

  module Schema

    class Table

      attr_reader :name
      attr_writer :compact_storage

      def initialize(name)
        @name = name
        @partition_keys, @nonpartition_keys, @columns, @properties,
          @clustering_order = [], [], [], [], []
      end

      def add_partition_key(name, type)
        column = Column.new(name, type)
        @columns << column
        @partition_keys << column
      end

      def add_key(name, type, clustering_order = nil)
        column = Column.new(name, type)
        @columns << column
        if @partition_keys.empty?
          unless clustering_order.nil?
            raise ArgumentError,
              "Can't set clustering order for partition key #{name}"
          end
          @partition_keys << column
        else
          @nonpartition_keys << column
          @clustering_order << (clustering_order || :asc)
        end
      end

      def add_column(name, type)
        @columns << Column.new(name, type)
      end

      def add_list(name, type)
        @columns << List.new(name, type)
      end

      def add_set(name, type)
        @columns << Set.new(name, type)
      end

      def add_map(name, key_type, value_type)
        @columns << Map.new(name, key_type, value_type)
      end

      def add_property(name, value)
        @properties << TableProperty.new(name, value)
      end

      def create_cql
        "CREATE TABLE #{@name} (#{columns_cql}, #{keys_cql})".tap do |cql|
          properties = properties_cql
          cql << " WITH #{properties}" if properties
        end
      end

      private

      def columns_cql
        @columns.map(&:to_cql).join(', ')
      end

      def key_columns_cql
        @keys.map { |key| "#{key.name} #{key.type}" }.join(', ')
      end

      def keys_cql
        partition_cql = @partition_keys.map { |key| key.name }.join(', ')
        if @nonpartition_keys.any?
          nonpartition_cql =
            @nonpartition_keys.map { |key| key.name }.join(', ')
          "PRIMARY KEY ((#{partition_cql}), #{nonpartition_cql})"
        else
          "PRIMARY KEY ((#{partition_cql}))"
        end
      end

      def properties_cql
        properties_fragments = @properties.map { |property| property.to_cql }
        properties_fragments << 'COMPACT STORAGE' if @compact_storage
        if @nonpartition_keys.any?
          clustering_fragment =
            @nonpartition_keys.zip(@clustering_order).
            map { |key, order| "#{key.name} #{order.upcase}" }.join(',')
          properties_fragments << "CLUSTERING ORDER BY (#{clustering_fragment})"
        end
        properties_fragments.join(' AND ') if properties_fragments.any?
      end

    end

  end

end
