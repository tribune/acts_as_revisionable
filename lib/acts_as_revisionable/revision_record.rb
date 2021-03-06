require 'zlib'
require 'yaml'

module ActsAsRevisionable
  class RevisionRecord < ActiveRecord::Base

    before_create :set_revision_number
    attr_reader :data_encoding

    self.table_name = :revision_records

    class << self
      # Find a specific revision record.
      def find_revision(klass, id, revision)
        where(revisionable_type: klass.base_class.to_s, revisionable_id: id,
              revision: revision).first
      end
      
      # Find the last revision record for a class.
      def last_revision(klass, id, revision = nil)
        where(revisionable_type: klass.base_class.to_s, revisionable_id: id).
          order("revision DESC").first
      end

      # Truncate the revisions for a record. Available options are :limit and :max_age.
      def truncate_revisions(revisionable_type, revisionable_id, options)
        return unless options[:limit] || options[:minimum_age]

        conditions = ['revisionable_type = ? AND revisionable_id = ?', revisionable_type.base_class.to_s, revisionable_id]
        if options[:minimum_age]
          conditions.first << ' AND created_at <= ?'
          conditions << options[:minimum_age].seconds.ago
        end

        start_deleting_revision = where(conditions).order('revision DESC').
                                    offset(options[:limit]).first
        if start_deleting_revision
          delete_all(['revisionable_type = ? AND revisionable_id = ? AND revision <= ?', revisionable_type.base_class.to_s, revisionable_id, start_deleting_revision.revision])
        end
      end

      # Empty the trash by deleting records older than the specified maximum age in seconds.
      # The +revisionable_type+ argument specifies the class to delete revision records for.
      def empty_trash(revisionable_type, max_age)
        sql = "revisionable_id IN (SELECT revisionable_id from #{table_name} WHERE created_at <= ? AND revisionable_type = ? AND trash = ?) AND revisionable_type = ?"
        args = [max_age.seconds.ago, revisionable_type.name, true, revisionable_type.name]
        delete_all([sql] + args)
      end

      # Create the table to store revision records.
      def create_table
        connection.create_table table_name do |t|
          t.string :revisionable_type, :null => false, :limit => 100
          t.integer :revisionable_id, :null => false
          t.integer :revision, :null => false
          t.binary :data, :limit => (connection.adapter_name.match(/mysql/i) ? 5.megabytes : nil)
          t.timestamp :created_at, :null => false
          t.boolean :trash, :default => false
        end
        
        connection.add_index table_name, :revisionable_id, :name => "#{table_name}_id"
        connection.add_index table_name, [:revisionable_type, :created_at, :trash], :name => "#{table_name}_type_and_created_at"
      end
      
      # Update a version 1.0.x table to the latest version. This method only needs to be called
      # from a migration if you originally created the table with a version 1.0.x version of the gem.
      def update_version_1_table
        # Added in version 1.1.0
        connection.add_column(:revision_records, :trash, :boolean, :default => false)
        connection.add_index(:revision_records, :revisionable_id, :name => "#{table_name}_id")
        connection.add_index(:revision_records,
                             [:revisionable_type, :created_at, :trash],
                             :name => "#{table_name}_type_and_created_at")

        # Removed in 1.1.0
        connection.remove_index(:revision_records, :name => "revisionable")
      end
    end

    # Create a revision record based on a record passed in. The attributes of the original record will
    # be serialized. If it uses the acts_as_revisionable behavior, associations will be revisioned as well.
    def initialize(record, encoding = :ruby)
      super({})
      @data_encoding = encoding
      self.revisionable_type = record.class.base_class.name
      self.revisionable_id = record.id
      associations = record.class.revisionable_associations if record.class.respond_to?(:revisionable_associations)
      self.data = Zlib::Deflate.deflate(serialize_hash(serialize_attributes(record, associations)))
    end

    # Returns the attributes that are saved in the revision.
    def revision_attributes
      return nil unless self.data
      uncompressed = Zlib::Inflate.inflate(self.data)
      deserialize_hash(uncompressed)
    end

    # Restore the revision to the original record. If any errors are encountered restoring attributes, they
    # will be added to the errors object of the restored record.
    def restore(klass = nil)
      restore_class = self.revisionable_type.constantize

      # Check if we have a type field, if yes, assume single table inheritance and restore the actual class instead of the stored base class
      sti_type = self.revision_attributes[restore_class.inheritance_column]
      if sti_type
        begin
          if !restore_class.store_full_sti_class && !sti_type.start_with?("::")
            sti_type = "#{restore_class.parent.name}::#{sti_type}"
          end
          restore_class = sti_type.constantize
        rescue NameError => e
          raise e
          # Seems our assumption was wrong and we have no STI
        end
      elsif klass
        restore_class = klass
      end

      record = restore_class.new
      restore_record(record, revision_attributes)
      return record
    end
    
    # Mark this revision as being trash. When trash records are restored, all
    # their revision history is restored as well.
    def trash!
      update_attribute(:trash, true)
    end

    private

    def serialize_hash(hash)
      encoding = data_encoding.blank? ? :ruby : data_encoding
      case encoding.to_sym
      when :yaml
        return YAML.dump(hash)
      when :xml
        return hash.to_xml(:root => 'revision')
      else
        return Marshal.dump(hash)
      end
    end

    def deserialize_hash(data)
      if data.starts_with?('---')
        return YAML.load(data)
      elsif data.starts_with?('<?xml')
        return Hash.from_xml(data)['revision']
      else
        return Marshal.load(data)
      end
    end

    def set_revision_number
      last_revision =
        self.class.where(revisionable_type: self.revisionable_type,
                         revisionable_id: self.revisionable_id).maximum(:revision) || 0
      self.revision = last_revision + 1
    end

    def serialize_attributes(record, revisionable_associations, already_serialized = {})
      return if already_serialized["#{record.class}.#{record.id}"]
      attrs = record.attributes.dup
      primary_key = record.class.primary_key.to_s if record.class.primary_key
      attrs.delete(primary_key) unless record.class.columns_hash.include?(primary_key)
      already_serialized["#{record.class}.#{record.id}"] = true

      if revisionable_associations.kind_of?(Hash)
        record.class.reflections.values.each do |association|
          if revisionable_associations[association.name]
            assoc_name = association.name.to_s
            if association.macro == :has_many
              attrs[assoc_name] = record.send(association.name).collect{|r| serialize_attributes(r, revisionable_associations[association.name], already_serialized)}
            elsif association.macro == :has_one
              associated = record.send(association.name)
              unless associated.nil?
                attrs[assoc_name] = serialize_attributes(associated, revisionable_associations[association.name], already_serialized)
              else
                attrs[assoc_name] = nil
              end
            elsif association.macro == :has_and_belongs_to_many
              attrs[assoc_name] = record.send("#{association.name.to_s.singularize}_ids")
            end
          end
        end
      end

      return attrs
    end

    def attributes_and_associations(klass, hash)
      attrs = {}
      association_attrs = {}

      if hash
        hash.each_pair do |key, value|
          if ActsAsRevisionable.reflect_on_assoc_compat(klass, key)
            association_attrs[key] = value
          else
            attrs[key] = value
          end
        end
      end

      return [attrs, association_attrs]
    end

    def restore_association(record, association, association_attributes)
      association = association.to_sym
      reflection = ActsAsRevisionable.reflect_on_assoc_compat(record.class, association)
      associated_record = nil

      begin
        if reflection.macro == :has_many
          if association_attributes.kind_of?(Array)
            # Note: do NOT try calling record.send(association).pop until it's empty. It will be an infinite loop!
            # Set in-memory cache & mark assoc as loaded.
            record.association(association).target = []

            association_attributes.each do |attrs|
              restore_association(record, association, attrs)
            end
          else
            associated_record = record.send(association).build
            restore_record(associated_record, association_attributes)
          end
        elsif reflection.macro == :has_one
          associated_record = reflection.klass.new
          restore_record(associated_record, association_attributes)
          record.send("#{association}=", associated_record)
        elsif reflection.macro == :has_and_belongs_to_many
          record.send("#{association.to_s.singularize}_ids=", association_attributes)
        end
      rescue => e
        record.errors.add(association, "could not be restored from the revision: #{e.message}")
      end
      
      if associated_record && !associated_record.errors.empty?
        record.errors.add(association, 'could not be restored from the revision')
      end
    end

    # Restore a record and all its associations.
    def restore_record(record, attributes)
      assign_primary_key(record, attributes)

      attrs, association_attrs = attributes_and_associations(record.class, attributes)
      attrs.each_pair do |key, value|
        begin
          record.send("#{key}=", value)
        rescue
          record.errors.add(key.to_sym, "could not be restored to #{value.inspect}")
        end
      end

      association_attrs.each_pair do |key, values|
        restore_association(record, key, values) if values
      end
      

      # Check if the record already exists in the database and restore its state.
      # This must be done last because otherwise associations on an existing record
      # can be deleted when a revision is restored to memory.
      if record_exists?(record)
        set_persisted(record)
      end
    end

    # Modifies record
    def assign_primary_key(record, attributes)
      pk_def = record.class.primary_key
      return false if pk_def == nil

      # Also handles composite key
      pk_cols = pk_def.is_a?(Array) ? pk_def : [pk_def]
      pk_cols.each do |col|
        assign_method = "#{col}="
        record.send(assign_method, attributes[col.to_s])
      end
      nil
    end

    def record_exists?(mem_record)
      model_klass = mem_record.class
      pk_def = model_klass.primary_key
      return false if pk_def == nil

      # Also handles composite key
      pk_cols = pk_def.is_a?(Array) ? pk_def : [pk_def]

      pk_val_map = pk_cols.each_with_object(Hash.new) {|col, h|
        h[col] = mem_record.send(col)
      }
      # Don't query if PK contains nils
      if pk_val_map.values.any?(&:nil?)
        false
      else
        model_klass.where(pk_val_map).exists?
      end
    # This rescue was copied from the previous rev; not sure what errors might happen
    #rescue
    #  nil
    end

    def set_persisted(record)
      # HACK: relies on AR internals. Keep this isolated in its own method.
      # TODO: Can we try fetching the record before setting its attributes? That way the persisted state will already be correct.
      record.instance_variable_set(:@new_record, nil) if record.instance_variable_defined?(:@new_record)
    end
  end
end
