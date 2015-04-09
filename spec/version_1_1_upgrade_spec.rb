require 'spec_helper'

describe "upgrade to version 1.1" do

  before :each do
    ActsAsRevisionable::Test.create_database
  end
  
  after :each do
    ActsAsRevisionable::Test.delete_database
  end
  
  it "should update an older table definition with the latest definition on create_table" do
    connection = ActsAsRevisionable::RevisionRecord.connection
    
    connection.create_table(:revision_records) do |t|
      t.string :revisionable_type, :null => false, :limit => 100
      t.integer :revisionable_id, :null => false
      t.integer :revision, :null => false
      t.binary :data, :limit => (connection.adapter_name.match(/mysql/i) ? 5.megabytes : nil)
      t.timestamp :created_at, :null => false
    end
    connection.add_index :revision_records, [:revisionable_type, :revisionable_id, :revision], :name => "revisionable", :unique => true
    
    ActsAsRevisionable::RevisionRecord.update_version_1_table
    
    columns = connection.columns(:revision_records)
    trash_column = columns.detect{|c| c.name == 'trash'}
    expect(trash_column.type).to eq :boolean
    trash_column_default =
      if trash_column.respond_to?(:type_cast_from_database)
        # in AR 4.2, column defaults must be manually cast
        trash_column.type_cast_from_database(trash_column.default)
      else
        trash_column.default
      end
    expect(trash_column_default).to be false
    
    if connection.respond_to?(:index_exists?)
      connection.index_exists?(:revision_records, [:revisionable_type, :revisionable_id, :revision], :name => "revisionable", :unique => true).should_not
      connection.index_exists?(:revision_records, :revisionable_id, :name => "revision_record_id").should
      connection.index_exists?(:revision_records, [:revisionable_type, :created_at, :trash], :name => "revisionable_type_and_created_at").should
      skip "TODO why are the above lines missing their predicates?"
    else
      STDERR.puts("Could not check if indexes were updated with this version of ActiveRecord")
    end
  end
  
end
