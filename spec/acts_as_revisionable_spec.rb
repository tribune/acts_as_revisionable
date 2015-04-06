require 'spec_helper'

describe ActsAsRevisionable do

  before(:all) do
    ActsAsRevisionable::Test.create_database
    ActsAsRevisionable::RevisionRecord.create_table

    ActiveRecord::Base.store_full_sti_class = true

    class RevisionableTestSubThing < ActiveRecord::Base
      connection.create_table(:revisionable_test_sub_things) do |t|
        t.column :name, :string
        t.column :revisionable_test_many_thing_id, :integer
      end unless table_exists?
    end

    class RevisionableTestManyThing < ActiveRecord::Base
      connection.create_table(:revisionable_test_many_things) do |t|
        t.column :name, :string
        t.column :revisionable_test_model_id, :integer
      end unless table_exists?

      has_many :sub_things, :class_name => 'RevisionableTestSubThing'
    end

    class RevisionableTestManyOtherThing < ActiveRecord::Base
      connection.create_table(:revisionable_test_many_other_things) do |t|
        t.column :name, :string
        t.column :revisionable_test_model_id, :integer
      end unless table_exists?
    end

    class RevisionableTestCompositeKeyThing < ActiveRecord::Base
      connection.create_table(:revisionable_test_composite_key_things, :id => false) do |t|
        t.column :name, :string
        t.column :revisionable_test_model_id, :integer
        t.column :other_id, :integer
      end unless table_exists?
      self.primary_keys = "revisionable_test_model_id", "other_id"
      belongs_to :revisionable_test_model
    end

    class RevisionableTestOneThing < ActiveRecord::Base
      connection.create_table(:revisionable_test_one_things) do |t|
        t.column :name, :string
        t.column :revisionable_test_model_id, :integer
      end unless table_exists?
    end

    class NonRevisionableTestModel < ActiveRecord::Base
      connection.create_table(:non_revisionable_test_models) do |t|
        t.column :name, :string
      end unless table_exists?
    end

    class NonRevisionableTestModelsRevisionableTestModel < ActiveRecord::Base
      connection.create_table(:non_revisionable_test_models_revisionable_test_models, :id => false) do |t|
        t.column :non_revisionable_test_model_id, :integer
        t.column :revisionable_test_model_id, :integer
      end unless table_exists?
    end

    class RevisionableTestModel < ActiveRecord::Base
      connection.create_table(:revisionable_test_models) do |t|
        t.column :name, :string
        t.column :secret, :integer
      end unless table_exists?

      has_many :many_things, :class_name => 'RevisionableTestManyThing', :dependent => :destroy
      has_many :many_other_things, :class_name => 'RevisionableTestManyOtherThing', :dependent => :destroy
      has_one :one_thing, :class_name => 'RevisionableTestOneThing'
      has_and_belongs_to_many :non_revisionable_test_models
      has_many :composite_key_things, :class_name => 'RevisionableTestCompositeKeyThing', :dependent => :destroy

      attr_protected :secret

      acts_as_revisionable :limit => 3, :dependent => :keep,
                           :associations => [:one_thing, :non_revisionable_test_models,
                                             {:many_things => :sub_things}, :composite_key_things]

      def set_secret(val)
        self.secret = val
      end

      private

      def secret=(val)
        self[:secret] = val
      end
    end

    class RevisionRecord2 < ActsAsRevisionable::RevisionRecord
      self.table_name = "revision_records_2"
      create_table
      connection.add_column(table_name, :label, :string)
      connection.add_column(table_name, :updated_by, :string)
      connection.add_column(table_name, :version, :integer)
    end

    class OtherRevisionableTestModel < ActiveRecord::Base
      connection.create_table(table_name) do |t|
        t.string :name
        t.integer :secret
        t.string :updated_by
      end unless table_exists?

      acts_as_revisionable :on_update => true, :class_name => RevisionRecord2,
                           :meta => {:label => lambda{|record| "name was '#{record.name}'"},
                                     :updated_by => :updated_by, :version => 1}
    end

    module ActsAsRevisionable
      class RevisionableNamespaceModel < ActiveRecord::Base
        connection.create_table(:revisionable_namespace_models) do |t|
          t.column :name, :string
          t.column :type_name, :string
        end unless table_exists?

        self.inheritance_column = :type_name
        acts_as_revisionable :dependent => :keep, :on_destroy => true, :encoding => :xml
        self.store_full_sti_class = false
      end

      class RevisionableSubclassModel < RevisionableNamespaceModel
      end
    end
  end

  after :all do
    ActsAsRevisionable::Test.delete_database
  end

  before :each do
    RevisionableTestModel.delete_all
    RevisionableTestManyThing.delete_all
    RevisionableTestManyOtherThing.delete_all
    RevisionableTestSubThing.delete_all
    RevisionableTestOneThing.delete_all
    NonRevisionableTestModelsRevisionableTestModel.delete_all
    NonRevisionableTestModel.delete_all
    ActsAsRevisionable::RevisionRecord.delete_all
    ActsAsRevisionable::RevisionableNamespaceModel.delete_all
    OtherRevisionableTestModel.delete_all
    RevisionRecord2.delete_all
  end

  context "injected methods" do
    it "should be able to inject revisionable behavior onto ActiveRecord::Base" do
      ActiveRecord::Base.should respond_to(:acts_as_revisionable)
    end

    it "should add as has_many :record_revisions association" do
      RevisionableTestModel.new.revision_records.should == []
    end

    it "should parse the revisionable associations" do
      RevisionableTestModel.revisionable_associations.should == {:composite_key_things=>true, :non_revisionable_test_models=>true, :one_thing=>true, :many_things=>{:sub_things=>true}}
    end
  end

  context "accessing revisions" do
    let(:record_1){ RevisionableTestModel.create!(:name => "record 1") }
    let(:record_2){ OtherRevisionableTestModel.create!(:name => "record 2") }

    it "should be able to get a revision for a model" do
      revision_1 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_2 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_3 = RevisionRecord2.create!(record_2)
      record_1.find_revision(1).should == revision_1
      record_1.find_revision(2).should == revision_2
      record_1.find_revision(3).should == nil
      record_2.find_revision(1).should == revision_3
    end

    it "should be able to get a revision for an id" do
      revision_1 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_2 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_3 = RevisionRecord2.create!(record_2)
      RevisionableTestModel.find_revision(record_1.id, 1).should == revision_1
      RevisionableTestModel.find_revision(record_1.id, 2).should == revision_2
      RevisionableTestModel.find_revision(record_1.id, 3).should == nil
      OtherRevisionableTestModel.find_revision(record_2.id, 1).should == revision_3
    end

    it "should be able to get the last revision for a model" do
      revision_1 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_2 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_3 = RevisionRecord2.create!(record_2)
      record_1.last_revision.should == revision_2
      record_2.last_revision.should == revision_3
    end

    it "should be able to get the last revision for an id" do
      revision_1 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_2 = ActsAsRevisionable::RevisionRecord.create!(record_1)
      revision_3 = RevisionRecord2.create!(record_2)
      RevisionableTestModel.last_revision(record_1.id).should == revision_2
      OtherRevisionableTestModel.last_revision(record_2.id).should == revision_3
    end
  end

  context "storing revisions" do
    it "should not save a revision for a new record" do
      record = RevisionableTestModel.new(:name => "test")
      record.store_revision do
        record.save!
      end
      ActsAsRevisionable::RevisionRecord.count.should == 0
    end

    it "should only store revisions when a record is updated in a store_revision block" do
      record = RevisionableTestModel.create!(:name => "test")
      record.name = "new name"
      record.save!
      ActsAsRevisionable::RevisionRecord.count.should == 0
      record.store_revision do
        record.name = "newer name"
        record.save!
      end
      ActsAsRevisionable::RevisionRecord.count.should == 1
    end

    it "should always store revisions whenever a record is saved if :on_update is true" do
      record = OtherRevisionableTestModel.create!(:name => "test")
      record.name = "new name"
      record.save!
      RevisionRecord2.count.should == 1
      record.store_revision do
        record.name = "newer name"
        record.save!
      end
      RevisionRecord2.count.should == 2
    end

    it "should only store revisions when a record is destroyed in a store_revision block" do
      record_1 = RevisionableTestModel.create!(:name => "test")
      record_1.store_revision do
        record_1.name = "newer name"
        record_1.save!
      end
      record_2 = RevisionableTestModel.create!(:name => "test")
      record_2.store_revision do
        record_2.name = "newer name"
        record_2.save!
      end
      ActsAsRevisionable::RevisionRecord.count.should == 2
      record_1.destroy
      ActsAsRevisionable::RevisionRecord.count.should == 2
      record_2.store_revision do
        record_2.destroy
      end
      ActsAsRevisionable::RevisionRecord.count.should == 3
    end

    it "should always store revisions whenever a record is destroyed if :on_destroy is true" do
      record_1 = ActsAsRevisionable::RevisionableNamespaceModel.create!(:name => "test")
      record_1.store_revision do
        record_1.name = "newer name"
        record_1.save!
      end
      record_2 = ActsAsRevisionable::RevisionableNamespaceModel.create!(:name => "test")
      record_2.store_revision do
        record_2.name = "newer name"
        record_2.save!
      end
      ActsAsRevisionable::RevisionRecord.count.should == 2
      record_1.destroy
      ActsAsRevisionable::RevisionRecord.count.should == 3
      record_2.store_revision do
        record_2.destroy
      end
      ActsAsRevisionable::RevisionRecord.count.should == 4
    end

    it "should be able to create a revision record" do
      record_1 = RevisionableTestModel.create!(:name => "test")
      ActsAsRevisionable::RevisionRecord.count.should == 0
      record_1.create_revision!
      ActsAsRevisionable::RevisionRecord.count.should == 1
    end

    it "should set metadata on the revison when creating a revision record using a complex attribute to value mapping" do
      record_1 = OtherRevisionableTestModel.create!(:name => "test", :updated_by => "dude")
      RevisionRecord2.count.should == 0
      record_1.create_revision!
      RevisionRecord2.count.should == 1
      revision = record_1.last_revision
      revision.label.should == "name was 'test'"
      revision.updated_by.should == "dude"
      revision.version.should == 1
    end

    it "should set metadata on the revison when creating a revision record using a simply string to define a method to copy" do
      meta_value = OtherRevisionableTestModel.acts_as_revisionable_options[:meta]
      begin
        OtherRevisionableTestModel.acts_as_revisionable_options[:meta] = "label"
        record_1 = OtherRevisionableTestModel.create!(:name => "test", :updated_by => "dude")
        record_1.stub(:label => "this is a label")
        record_1.create_revision!
        revision = record_1.last_revision
        revision.label.should == "this is a label"
        revision.updated_by.should == nil
        revision.version.should == nil
      ensure
        OtherRevisionableTestModel.acts_as_revisionable_options[:meta] = meta_value
      end
    end

    it "should set metadata on the revison when creating a revision record using an array of attribute names to copy" do
      meta_value = OtherRevisionableTestModel.acts_as_revisionable_options[:meta]
      begin
        OtherRevisionableTestModel.acts_as_revisionable_options[:meta] = [:label, "version"]
        record_1 = OtherRevisionableTestModel.create!(:name => "test", :updated_by => "dude")
        record_1.stub(:label => "this is a label", :version => 100)
        record_1.create_revision!
        revision = record_1.last_revision
        revision.label.should == "this is a label"
        revision.updated_by.should == nil
        revision.version.should == 100
      ensure
        OtherRevisionableTestModel.acts_as_revisionable_options[:meta] = meta_value
      end
    end

    it "should not create a revision entry if revisioning is disabled" do
      record = RevisionableTestModel.create!(:name => "test")
      ActsAsRevisionable::RevisionRecord.count.should == 0
      record.store_revision do
        record.name = "new name"
        record.save!
      end
      ActsAsRevisionable::RevisionRecord.count.should == 1
      record.disable_revisioning do
        record.store_revision do
          record.name = "newer name"
          record.save!
        end
      end
      ActsAsRevisionable::RevisionRecord.count.should == 1
    end

    it "should truncate the revisions when new ones are created" do
      record = RevisionableTestModel.create!(:name => "test")
      5.times do |i|
        record.store_revision do
          record.update_attribute(:name, "name #{i}")
        end
      end
      ActsAsRevisionable::RevisionRecord.count.should == 3
      record.revision_records.map(&:revision).should == [5, 4, 3]
    end

    it "should not save a revision if an update raises an exception" do
      err_class = Class.new(StandardError)

      model = RevisionableTestModel.new(:name => 'test')
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.name = 'new_name'
      begin
        model.store_revision do
          ActsAsRevisionable::RevisionRecord.count.should == 1
          raise err_class, "update failed"
        end
      rescue err_class => err
        # rescue our specific error to avoid silencing rspec's failures
      end
      ActsAsRevisionable::RevisionRecord.count.should == 0
    end

    it "should not save a revision if an update fails with errors" do
      model = RevisionableTestModel.new(:name => 'test')
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.name = 'new_name'
      model.store_revision do
        ActsAsRevisionable::RevisionRecord.count.should == 1
        model.save!
        model.errors.add(:name, "isn't right")
      end
      ActsAsRevisionable::RevisionRecord.count.should == 0
    end

    it "should mark the last revision for a deleted record as being trash" do
      model = ActsAsRevisionable::RevisionableNamespaceModel.new(:name => 'test')
      model.save!
      model.store_revision do
        model.name = "new name"
        model.save!
      end
      model.destroy
      ActsAsRevisionable::RevisionRecord.count.should == 2
      ActsAsRevisionable::RevisionRecord.last_revision(ActsAsRevisionable::RevisionableNamespaceModel, model.id).should be_trash
    end
  end

  context "restoring revisions" do
    # NOTE: to ensure accurate tests, isolate the restored model in a tap block.
    # This, helps to prevent accidentally using the memory-restore to verify a db-restore.

    it "should restore a record without associations" do
      orig_name, orig_secret = 'test'.freeze    , 1234
      new_name , new_secret  = 'new_name'.freeze, 5678

      model = RevisionableTestModel.new(:name => orig_name)
      model.set_secret(orig_secret)
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.name = new_name
      model.set_secret(new_secret)
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      model.name.should == new_name
      model.secret.should == new_secret

      model.restore_revision(1).tap do |mem_restored|
        mem_restored.name.should == orig_name
        mem_restored.secret.should == orig_secret
        mem_restored.id.should == model.id

        mem_restored.store_revision do
          mem_restored.save!
        end
      end
      RevisionableTestModel.count.should == 1
      ActsAsRevisionable::RevisionRecord.count.should == 2
      RevisionableTestModel.find(model.id).tap do |db_restored|
        db_restored.name.should == orig_name
        db_restored.secret.should == orig_secret
      end
    end

    it "should restore a record with has_many associations" do
      many_thing_1 = RevisionableTestManyThing.new(:name => 'many_thing_1')
      many_thing_1.sub_things.build(:name => 'sub_thing_1')
      many_thing_1.sub_things.build(:name => 'sub_thing_2')

      model = RevisionableTestModel.new(:name => 'test')
      model.many_things << many_thing_1
      model.many_things.build(:name => 'many_thing_2')
      model.many_other_things.build(:name => 'many_other_thing_1')
      model.many_other_things.build(:name => 'many_other_thing_2')
      model.save!
      model.reload
      RevisionableTestManyThing.count.should == 2
      RevisionableTestSubThing.count.should == 2
      RevisionableTestManyOtherThing.count.should == 2
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.store_revision do
        model.name = 'new_name'
        many_thing_1 = model.many_things.detect{|t| t.name == 'many_thing_1'}
        many_thing_1.name = 'new_many_thing_1'
        sub_thing_1 = many_thing_1.sub_things.detect{|t| t.name == 'sub_thing_1'}
        sub_thing_1.name = 'new_sub_thing_1'
        sub_thing_2 = many_thing_1.sub_things.detect{|t| t.name == 'sub_thing_2'}
        many_thing_1.sub_things.build(:name => 'sub_thing_3')
        many_thing_1.sub_things.delete(sub_thing_2)  # orphans sub_thing_2
        many_thing_2 = model.many_things.detect{|t| t.name == 'many_thing_2'}
        model.many_things.delete(many_thing_2)
        model.many_things.build(:name => 'many_thing_3')
        many_other_thing_1 = model.many_other_things.detect{|t| t.name == 'many_other_thing_1'}
        many_other_thing_1.name = 'new_many_other_thing_1'
        many_other_thing_2 = model.many_other_things.detect{|t| t.name == 'many_other_thing_2'}
        model.many_other_things.delete(many_other_thing_2)
        model.many_other_things.build(:name => 'many_other_thing_3')
        model.save!
        many_thing_1.save!
        sub_thing_1.save!
        many_other_thing_1.save!
      end

      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      RevisionableTestManyThing.count.should == 2
      RevisionableTestSubThing.count.should == 3
      RevisionableTestManyOtherThing.count.should == 2
      model.name.should == 'new_name'
      model.many_things.map(&:name).should =~ ['many_thing_3', 'new_many_thing_1']
      model.many_things.detect{|t| t.name == 'new_many_thing_1'}.sub_things.map(&:name).should =~ ['new_sub_thing_1', 'sub_thing_3']
      model.many_other_things.map(&:name).should =~ ['many_other_thing_3', 'new_many_other_thing_1']

      # restore to memory
      model.restore_revision(1).tap do |mem_restored|
        mem_restored.name.should == 'test'
        mem_restored.id.should == model.id
        mem_restored.many_things.map(&:name).should =~ ['many_thing_1', 'many_thing_2']
        mem_restored.many_things.detect{|t| t.name == 'many_thing_1'}.sub_things.map(&:name).should =~ ['sub_thing_1', 'sub_thing_2']
        mem_restored.many_other_things.map(&:name).should =~ ['many_other_thing_3', 'new_many_other_thing_1']
        mem_restored.valid?.should == true
      end

      # make sure the restore to memory didn't affect the database
      model.reload
      model.name.should == 'new_name'
      model.many_things(true).map(&:name).should =~ ['many_thing_3', 'new_many_thing_1']
      model.many_things.detect{|t| t.name == 'new_many_thing_1'}.sub_things.map(&:name).should =~ ['new_sub_thing_1', 'sub_thing_3']
      model.many_other_things.map(&:name).should =~ ['many_other_thing_3', 'new_many_other_thing_1']

      model.restore_revision!(1)
      RevisionableTestModel.count.should == 1
      RevisionableTestManyThing.count.should == 2
      RevisionableTestSubThing.count.should == 3
      # orphaned
      expect( RevisionableTestSubThing.where(name: 'sub_thing_3', revisionable_test_many_thing_id: nil).exists? ).to be true

      RevisionableTestManyOtherThing.count.should == 2
      ActsAsRevisionable::RevisionRecord.count.should == 2
      RevisionableTestModel.find(model.id).tap do |db_restored|
        db_restored.name.should == 'test'
        db_restored.many_things.map(&:name).should =~ ['many_thing_1', 'many_thing_2']
        db_restored.many_things.detect{|t| t.name == 'many_thing_1'}.sub_things.map(&:name).should =~ ['sub_thing_1', 'sub_thing_2']
        db_restored.many_things.detect{|t| t.name == 'many_thing_2'}.sub_things.map(&:name).should =~ []
        db_restored.many_other_things.map(&:name).should =~ ['many_other_thing_3', 'new_many_other_thing_1']
      end
    end

    it "should restore a record with has_one associations" do
      model = RevisionableTestModel.new(:name => 'test')
      model.build_one_thing(:name => 'other')
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0
      RevisionableTestOneThing.count.should == 1

      model.name = 'new_name'
      model.one_thing.name = 'new_other'
      model.store_revision do
        model.one_thing.save!
        model.save!
      end

      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      model.name.should == 'new_name'
      model.one_thing.name.should == 'new_other'

      # restore to memory
      model.restore_revision(1).tap do |mem_restored|
        mem_restored.name.should == 'test'
        mem_restored.one_thing.name.should == 'other'
        mem_restored.one_thing.id.should == model.one_thing.id
      end

      # make sure restore to memory didn't affect the database
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      model.name.should == 'new_name'
      model.one_thing(true).name.should == 'new_other'

      model.restore_revision!(1)
      RevisionableTestModel.count.should == 1
      RevisionableTestOneThing.count.should == 1
      ActsAsRevisionable::RevisionRecord.count.should == 2
      RevisionableTestModel.find(model.id).tap do |db_restored|
        db_restored.name.should == 'test'
        db_restored.one_thing.name.should == 'other'
        db_restored.one_thing.id.should == model.one_thing.id
      end
    end

    it "should restore a record with has_and_belongs_to_many associations" do
      other_1 = NonRevisionableTestModel.create!(:name => 'one')
      other_2 = NonRevisionableTestModel.create!(:name => 'two')
      model = RevisionableTestModel.new(:name => 'test')
      model.non_revisionable_test_models = [other_1, other_2]
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0
      NonRevisionableTestModel.count.should == 2

      model.name = 'new_name'
      other_1.name = '111'
      other_3 = NonRevisionableTestModel.create!(:name => '333')
      model.store_revision do
        model.non_revisionable_test_models = [other_1, other_3]
        other_1.save!
        model.save!
      end

      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      NonRevisionableTestModel.count.should == 3
      model.name.should == 'new_name'
      model.non_revisionable_test_models.map(&:name).should =~ ['111', '333']

      # restore to memory
      model.restore_revision(1).tap do |mem_restored|
        mem_restored.name.should == 'test'
        mem_restored.non_revisionable_test_models.map(&:name).should =~ ['111', 'two']
      end

      # make sure the restore to memory didn't affect the database
      model.reload
      model.name.should == 'new_name'
      model.non_revisionable_test_models(true).map(&:name).should =~ ['111', '333']

      model.restore_revision!(1)
      NonRevisionableTestModelsRevisionableTestModel.count.should == 2
      RevisionableTestModel.count.should == 1
      NonRevisionableTestModel.count.should == 3
      ActsAsRevisionable::RevisionRecord.count.should == 2
      RevisionableTestModel.find(model.id).tap do |db_restored|
        db_restored.name.should == 'test'
        db_restored.non_revisionable_test_models.map(&:name).should =~ ['111', 'two']
      end
    end

    it "should handle namespaces and single table inheritance" do
      model = ActsAsRevisionable::RevisionableNamespaceModel.new(:name => 'test')
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.name = 'new_name'
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      model.name.should == 'new_name'

      model.restore_revision(1).tap do |mem_restored|
        mem_restored.class.should == ActsAsRevisionable::RevisionableNamespaceModel
        mem_restored.name.should == 'test'
        mem_restored.id.should == model.id
      end
    end

    it "should handle single table inheritance" do
      model = ActsAsRevisionable::RevisionableSubclassModel.new(:name => 'test')
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.name = 'new_name'
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      model.name.should == 'new_name'

      model.restore_revision(1).tap do |mem_restored|
        mem_restored.class.should == ActsAsRevisionable::RevisionableSubclassModel
        mem_restored.name.should == 'test'
        mem_restored.id.should == model.id
        mem_restored.type_name.should == 'RevisionableSubclassModel'
      end
    end

    it "should handle composite primary keys" do
      # PART 1: save model w/ 2 children - no revisioning
      thing_1 = RevisionableTestCompositeKeyThing.new(:name => 'thing_1')
      thing_1.other_id = 1
      thing_2 = RevisionableTestCompositeKeyThing.new(:name => 'thing_2')
      thing_2.other_id = 2
      thing_3 = RevisionableTestCompositeKeyThing.new(:name => 'thing_3')
      thing_3.other_id = 3

      model = RevisionableTestModel.new(:name => 'test')
      model.composite_key_things << thing_1
      model.composite_key_things << thing_2
      model.save!
      model.reload
      RevisionableTestCompositeKeyThing.count.should == 2
      ActsAsRevisionable::RevisionRecord.count.should == 0

      # PART 2: modify children - with revisioning
      model.store_revision do
        thing_1 = model.composite_key_things.detect{|t| t.name == 'thing_1'}
        thing_1.name = 'new_thing_1'
        thing_2 = model.composite_key_things.detect{|t| t.name == 'thing_2'}
        # CPK 6.x has a bug where you can only delete using ID(s) but not records
        model.composite_key_things.delete(thing_2.id)  # destroys thing_2
        model.composite_key_things << thing_3
        model.save!
        thing_1.save!
      end

      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      RevisionableTestCompositeKeyThing.count.should == 2
      model.composite_key_things.map(&:name).should =~ ['new_thing_1', 'thing_3']

      # PART 3: restore only to memory
      model.restore_revision(1).tap do |mem_restored|
        mem_restored.composite_key_things.map(&:name).should =~ ['thing_1', 'thing_2']
        mem_restored.valid?.should == true
      end

      # make sure the restore to memory didn't affect the database
      model.reload
      model.composite_key_things(true).map(&:name).should =~ ['new_thing_1', 'thing_3']
      RevisionableTestCompositeKeyThing.count.should == 2

      # PART 4: restore to database
      model.restore_revision!(1)
      RevisionableTestModel.count.should == 1
      RevisionableTestCompositeKeyThing.count.should == 2
      RevisionableTestModel.find(model.id).tap do |db_restored|
        db_restored.name.should == 'test'
        db_restored.composite_key_things.map(&:name).should =~ ['thing_1', 'thing_2']
      end
    end

    it "should restore a deleted record" do
      model = ActsAsRevisionable::RevisionableNamespaceModel.new(:name => 'test')
      model.save!
      model.store_revision do
        model.name = "new name"
        model.save!
      end
      model.destroy
      ActsAsRevisionable::RevisionRecord.count.should == 2
      ActsAsRevisionable::RevisionableNamespaceModel.restore_last_revision!(model.id)
    end
  end

  context "cleaning up revisions" do
    it "should destroy revisions if :dependent => :keep was not specified" do
      model = OtherRevisionableTestModel.create!(:name => 'test')
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.name = 'new_name'
      model.store_revision do
        model.save!
      end
      model.reload
      RevisionRecord2.count.should == 1
      model.name.should == 'new_name'

      model.destroy
      RevisionRecord2.count.should == 0
    end

    it "should not destroy revisions if :dependent => :keep was specified" do
      model = ActsAsRevisionable::RevisionableSubclassModel.new(:name => 'test')
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 0

      model.name = 'new_name'
      model.store_revision do
        model.save!
      end
      model.reload
      ActsAsRevisionable::RevisionRecord.count.should == 1
      model.name.should == 'new_name'

      # Destroy adds a revision in this model
      model.destroy
      ActsAsRevisionable::RevisionRecord.count.should == 2
    end

    it "should empty the trash by deleting all revisions for records that have been deleted for a specified period" do
      record_1 = ActsAsRevisionable::RevisionableNamespaceModel.create!(:name => 'test')
      record_1.store_revision do
        record_1.update_attribute(:name, "new")
      end
      record_1.store_revision do
        record_1.update_attribute(:name, "newer")
      end
      record_1.store_revision do
        record_1.destroy
      end
      record_2 = ActsAsRevisionable::RevisionableNamespaceModel.create!(:name => 'test 2')
      record_2.store_revision do
        record_2.update_attribute(:name, "new 2")
      end

      now = Time.now
      ActsAsRevisionable::RevisionRecord.count.should == 4
      ActsAsRevisionable::RevisionableNamespaceModel.empty_trash(60)
      ActsAsRevisionable::RevisionRecord.count.should == 4
      Time.stub(:now => now + 61)
      ActsAsRevisionable::RevisionableNamespaceModel.empty_trash(60)
      ActsAsRevisionable::RevisionRecord.count.should == 1
    end
  end

  context "squash_pk_changes" do
    it "squash PK changes when all PK values set" do
      cpk_rec = RevisionableTestCompositeKeyThing.new
      cpk_rec.revisionable_test_model_id = 123
      cpk_rec.other_id = 456
      cpk_rec.name = 'foobar'
      RevisionableTestModel.send(:squash_pk_changes, cpk_rec)
      expect(cpk_rec.changes).to eq ( {'name' => [nil, 'foobar']} )
      expect(cpk_rec.revisionable_test_model_id).to eq 123
      expect(cpk_rec.other_id).to eq 456
    end

    it "doesn't squash if PK is partially null (safety-check)" do
      cpk_rec = RevisionableTestCompositeKeyThing.new
      cpk_rec.revisionable_test_model_id = 123
      cpk_rec.name = 'foobar'
      RevisionableTestModel.send(:squash_pk_changes, cpk_rec)
      expect(cpk_rec.changes).to eq (
        {'revisionable_test_model_id' => [nil, 123], 'name' => [nil, 'foobar']}
      )
      expect(cpk_rec.revisionable_test_model_id).to eq 123
      expect(cpk_rec.other_id).to be nil
    end
  end
end
