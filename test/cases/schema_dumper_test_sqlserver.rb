require 'cases/sqlserver_helper'
require 'cases/schema_dumper_test'
require 'stringio'


class SchemaDumperTestSqlserver < ActiveRecord::TestCase

  setup :find_all_tables

  context 'For primary keys' do

    should 'honor nonstandards' do
      table_dump('movies') do |output|
        match = output.match(%r{create_table "movies"(.*)do})
        assert_not_nil(match, "nonstandardpk table not found")
        assert_match %r(primary_key: "movieid"), match[1], "non-standard primary key not preserved"
      end
    end

  end

  context 'For integers' do

    should 'include limit constraint that match logic for smallint and bigint in #extract_limit' do
      table_dump('integer_limits') do |output|
        assert_match %r{c_int_1.*limit: 2}, output
        assert_match %r{c_int_2.*limit: 2}, output
        assert_match %r{c_int_3.*}, output
        assert_match %r{c_int_4.*}, output
        assert_no_match %r{c_int_3.*:limit}, output
        assert_no_match %r{c_int_4.*:limit}, output
        assert_match %r{c_int_5.*limit: 8}, output
        assert_match %r{c_int_6.*limit: 8}, output
        assert_match %r{c_int_7.*limit: 8}, output
        assert_match %r{c_int_8.*limit: 8}, output
      end
    end

  end

  context 'For strings' do

    should 'have varchar(max) dumped as text' do
      table_dump('sql_server_strings') do |output|
        assert_match %r{t.text.*varchar_max}, output
      end
    end

  end


  private

  def find_all_tables
    @all_tables ||= ActiveRecord::Base.connection.tables
  end

  def standard_dump(ignore_tables = [])
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = [*ignore_tables]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    stream.string
  end

  def table_dump(*table_names)
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = @all_tables-table_names
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    yield stream.string
    stream.string
  end

end


class SchemaDumperTest < ActiveRecord::TestCase

  COERCED_TESTS = [
    :test_schema_dump_keeps_large_precision_integer_columns_as_decimal,
    :test_types_line_up,
    :test_schema_dumps_partial_indices
  ]

  include SqlserverCoercedTest

  def test_coerced_schema_dump_keeps_large_precision_integer_columns_as_decimal
    output = standard_dump
    assert_match %r{t.decimal\s+"atoms_in_universe",\s+precision: 38,\s+scale: 0}, output
  end

   def test_coerced_types_line_up
    column_definition_lines.each do |column_set|
      next if column_set.empty?
      lengths = column_set.map do |column|
        if match = column.match(/t\.(?:integer|decimal|float|datetime|timestamp|time|date|text|binary|string|boolean|uuid)\s+"/)
          match[0].length
        end
      end
      assert_equal 1, lengths.uniq.length
    end
  end

  def test_coerced_schema_dumps_partial_indices
    index_definition = standard_dump.split(/\n/).grep(/add_index.*company_partial_index/).first.strip
    assert_equal 'add_index "companies", ["firm_id", "type"], name: "company_partial_index", where: "([rating]>(10))"', index_definition
  end

end


