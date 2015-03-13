##
# 'pg' gem utility functions based of same Desmond class
#
class RSUtil < Desmond::PGUtil
  ##
  # returns a dedicted RedShift connection
  # required +options+ if `DesmondConfig.system_connection_allowed?` is false:
  # - username: custom username to use for connection
  # - password: custom password to use for connection
  # optional +options+
  # - username: custom username to use for connection
  # - password: custom password to use for connection
  # - timeout: connection timeout to use
  #
  def self.dedicated_connection(options={})
    super({ system_connection_allowed: true,
      connection_id: "redshift_#{DesmondConfig.environment}" }.merge(options))
  end
end
