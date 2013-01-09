require File.expand_path('../spec_helper', __FILE__)

describe Cequel::Schema do
  describe '#create_table' do

    after do
      cequel.schema.drop_table(:posts)
    end

    describe 'with simple skinny table' do
      before do
        cequel.schema.create_table(:posts) do
          key :permalink, :ascii
          column :title, :text
        end
      end

      it 'should create key alias' do
        column_family('posts')['key_aliases'].should == %w(permalink).to_json
      end

      it 'should set key validator' do
        column_family('posts')['key_validator'].
          should == 'org.apache.cassandra.db.marshal.AsciiType'
      end

      it 'should set non-key columns' do
        column('posts', 'title')['validator'].should ==
          'org.apache.cassandra.db.marshal.UTF8Type'
      end
    end

    describe 'with multi-column primary key' do
      before do
        cequel.schema.create_table(:posts) do
          key :blog_subdomain, :ascii
          key :permalink, :ascii
          column :title, :text
        end
      end

      it 'should create key alias' do
        column_family('posts')['key_aliases'].
          should == %w(blog_subdomain).to_json
      end

      it 'should set key validator' do
        column_family('posts')['key_validator'].
          should == 'org.apache.cassandra.db.marshal.AsciiType'
      end

      it 'should create non-partition key components' do
        column_family('posts')['column_aliases'].
          should == %w(permalink).to_json
      end

      it 'should set type for non-partition key components' do
        # This will be a composite consisting of the non-partition key types
        # followed by UTF-8 for the logical column name
        column_family('posts')['comparator'].should ==
          'org.apache.cassandra.db.marshal.CompositeType(org.apache.cassandra.db.marshal.AsciiType,org.apache.cassandra.db.marshal.UTF8Type)'
      end
    end

  end

  def column_family(name)
    cequel.execute(<<-CQL, name).first.to_hash
      SELECT * FROM system.schema_columnfamilies
      WHERE keyspace_name = 'cequel_test' AND columnfamily_name = ?
    CQL
  end

  def column(column_family, column_name)
    cequel.execute(<<-CQL, column_family, column_name).first.to_hash
      SELECT * FROM system.schema_columns
      WHERE keyspace_name = 'cequel_test' AND columnfamily_name = ?
        AND column_name = ?
    CQL
  end

  def schema_query(query)
    result = cequel.execute(query)
    result.first.to_hash
  end

  def unpack_composite_column!(map, column, value)
    components = column.scan(/\x00.(.+?)\x00/m).map(&:first)
    last_component = components.pop
    components.each do |component|
      map[component] ||= {}
      map = map[component]
    end
    map[last_component] = value
  end
end
