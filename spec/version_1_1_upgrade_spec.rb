require 'spec_helper'

describe "upgrade to version 1.1" do

  before :each do
    ActsAsRevisionable::Test.create_database
  end

  after :each do
    ActsAsRevisionable::Test.delete_database
  end

  def get_column(table_name, col_name)
    columns = connection.columns(table_name)
    columns.detect{|c| c.name == col_name.to_s }
  end
  def get_column_type(table_name, col_name)
    get_column(table_name, col_name).type
  end
  def get_column_default(table_name, col_name)
    col = get_column(table_name, col_name)
    if col.respond_to?(:type_cast_from_database)
      # in AR 4.2, column defaults must be manually cast
      col.type_cast_from_database(col.default)
    else
      col.default
    end
  end

  let(:connection) { ActsAsRevisionable::RevisionRecord.connection }
  let(:rev_rec_table) { ActsAsRevisionable::RevisionRecord.table_name }
  let(:old_idx_spec) {
    [ :revision_records,
      [:revisionable_type, :revisionable_id, :revision],
      name: "revisionable", unique: true ]
   }
   let(:pk_idx_spec) { [:revision_records,
                        :revisionable_id, name: "#{rev_rec_table}_id"] }
   let(:type_created_idx_spec) {
     [ :revision_records,
       [:revisionable_type, :created_at, :trash],
       name: "#{rev_rec_table}_type_and_created_at" ]
   }

  it "should update an older table definition with the latest definition on create_table" do
    connection.create_table(:revision_records) do |t|
      t.string :revisionable_type, null: false, limit: 100
      t.integer :revisionable_id, null: false
      t.integer :revision, null: false
      t.binary :data, limit: (connection.adapter_name.match(/mysql/i) ? 5.megabytes : nil)
      t.timestamp :created_at, null: false
    end
    connection.add_index(:revision_records,
                         [:revisionable_type, :revisionable_id, :revision],
                         name: "revisionable", unique: true)

    # sanity pre-checks
    expect(get_column(:revision_records, :trash)).to be nil
    expect(connection.index_exists?(*old_idx_spec)).to be true
    expect(connection.index_exists?(*pk_idx_spec)).to be false
    expect(connection.index_exists?(*type_created_idx_spec)).to be false

    ActsAsRevisionable::RevisionRecord.update_version_1_table

    # post-checks
    expect(get_column_type(:revision_records, :trash)).to eq :boolean
    expect(get_column_default(:revision_records, :trash)).to eq false
    expect(connection.index_exists?(*old_idx_spec)).to be false
    expect(connection.index_exists?(*pk_idx_spec)).to be true
    expect(connection.index_exists?(*type_created_idx_spec)).to be true
  end

end
