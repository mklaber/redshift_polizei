module Models
  ##
  # RedShift permissions
  #
  class Permission < ActiveRecord::Base
    # entity                 :polymorphic      not null, user or group
    # dbobject               :polymorphic      not null, table or schema
    # has_select             :boolean          not null
    # has_insert             :boolean          not null
    # has_update             :boolean          not null
    # has_delete             :boolean          not null
    # has_references         :boolean          not null

    belongs_to :entity, polymorphic: true
    belongs_to :dbobject, polymorphic: true

    validates_inclusion_of :has_select, :has_insert, :has_update, :has_delete, :has_references, :in => [true, false]
    #validate :validate_unqiueness # this is a complex check (does three extra queries each time),
                                   # disabling because this slows mass-updates down significantly
                                   # (database checks anyways)
    validate :validate_entity_is_user_or_group, :validate_object_is_schema_or_table

    ##
    # returns all permissions for the given +user+.
    # +user+ can be `Models::DatabaseUser` or a username string.
    #
    def self.for_user(user, dbobject=nil, declared=false)
      get_all_permissions_for_entity(Models::DatabaseUser, user, dbobject, declared)
    end

    ##
    # returns all permissions for the given +group+.
    # +group+ can be `Models::DatabaseGroup` or a username string.
    #
    def self.for_group(group, dbobject=nil, declared=false)
      get_all_permissions_for_entity(Models::DatabaseGroup, group, dbobject, declared)
    end

    ##
    # returns all permissions for the given table.
    #
    def self.for_table(schema_name, table_name, entity_filter=nil, declared=false)
      fail ArgumentError, 'schema or table name cannot be nil' if schema_name.nil? || table_name.nil?
      table = Models::Table.find_by_full_name(schema_name, table_name)
      tmp = get_all_permissions_for(self.where(dbobject: table, declared: declared))
      tmp = tmp.where(entity_type: entity_filter) unless entity_filter.nil?
      tmp.sort do |p1, p2|
        (p1.entity.name <=> p2.entity.name)
      end
    end

    def as_json(options={})
      tmp = self.attributes
      tmp['dbobject'] = self.dbobject
      tmp['entity'] = self.entity
      tmp.delete('entity_id')
      tmp.delete('entity_type')
      tmp.delete('dbobject_id')
      tmp.delete('dbobject_type')
      tmp
    end

    private

    def self.get_all_permissions_for_entity(entity_class, entity, dbobject_filter, declared=false)
      fail ArgumentError, 'class or entity cannot be nil' if entity_class.nil? || entity.nil?
      entity = entity_class.find_by!(name: entity) if entity.is_a?(String)
      fail ArgumentError, "Unsupported entity type: #{group.class}" unless entity.is_a?(entity_class)
      tmp = get_all_permissions_for(self.where(entity: entity, declared: declared))
      tmp = tmp.where(dbobject_type: dbobject_filter) unless dbobject_filter.nil?
      tmp.sort do |p1, p2|
        schema_order = (p1.dbobject.schema.name <=> p2.dbobject.schema.name)
        if schema_order == 0
          (p1.dbobject.name <=> p2.dbobject.name)
        else
          schema_order
        end
      end
    end
    private_class_method :get_all_permissions_for_entity

    def self.get_all_permissions_for(filter)
      filter.includes(:entity).includes(:dbobject).includes(dbobject: :schema).includes(dbobject: :owner)
    end
    private_class_method :get_all_permissions_for

    def validate_unqiueness
      instance = self.class.where(entity: self.entity, dbobject: self.dbobject).first
      if !instance.nil? && instance.id != self.id
        errors.add(:entity, "and DBObject already defined as permission")
      end
    end

    def validate_entity_is_user_or_group
      unless self.entity_type == 'Models::DatabaseUser' || self.entity_type == 'Models::DatabaseGroup'
        errors.add(:entity, "needs to be a user or group, is: #{self.entity_type}")
      end
    end

    def validate_object_is_schema_or_table
      unless self.dbobject_type == 'Models::Table' || self.dbobject_type == 'Models::Schema'
        errors.add(:dbobject, "needs to be a schema or table, is: #{self.dbobject_type}")
      end
    end
  end
end
