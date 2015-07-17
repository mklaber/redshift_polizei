require_relative '../../main'

module Jobs

  ##
  # job to save SQL to recreate granted permissions for a table
  # later on.
  #
  # Please see `BaseJob` class documentation on how to run
  # any job using its general interface.
  #
  class TablePermissionsSQL < Desmond::BaseJobNoJobId
    def execute
      fail ArgumentError, 'missing schema_name' if self.options[:schema_name].blank?
      fail ArgumentError, 'missing table_name'  if self.options[:table_name].blank?
      fail ArgumentError, 'missing s3 bucket'   if self.options[:bucket].blank?
      fail ArgumentError, 'missing s3 key'      if self.options[:key].blank?

      permissions_sqls  = []

      # retrieve table
      table  = Models::Table.find_by!(
        schema: Models::Schema.find_by!(name: self.options[:schema_name]),
        name: self.options[:table_name])
      schema_name = Desmond::PGUtil.escape_identifier(table.schema.name)
      table_name  = Desmond::PGUtil.escape_identifier(table.name)
      owner_name  = Desmond::PGUtil.escape_identifier(table.owner.name)

      # retrieve owner of table
      permissions_sqls << "ALTER TABLE #{schema_name}.#{table_name} OWNER TO #{owner_name}"

      # retrieve the declared permissions of the table from our database cache
      permissions = Models::Permission.where(dbobject: table, declared: true)
      # build SQL out of retrieved permissions
      permissions_sqls += permissions.map do |perm|
        perms       = []
        perms      << 'SELECT'     if perm.has_select
        perms      << 'INSERT'     if perm.has_insert
        perms      << 'UPDATE'     if perm.has_update
        perms      << 'DELETE'     if perm.has_delete
        perms      << 'REFERENCES' if perm.has_references
        perms_string = perms.join(', ')
        entity_name = nil
        if perm.entity.is_a?(Models::DatabaseGroup)
          entity_name = 'GROUP ' + Desmond::PGUtil.escape_identifier(perm.entity.name)
        elsif perm.entity.is_a?(Models::DatabaseUser)
          entity_name = Desmond::PGUtil.escape_identifier(perm.entity.name)
        else
          fail "Unsupported permission entity: #{perm.entity.class.name}"
        end
        "GRANT #{perms_string} ON #{schema_name}.#{table_name} TO #{entity_name}"
      end

      AWS::S3.new.buckets[self.options[:bucket]].objects.create(
        self.options[:key],
        permissions_sqls.join(";\n")
      )

      true
    end
  end
end
