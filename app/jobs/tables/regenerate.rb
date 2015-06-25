require_relative '../../main'

module Jobs

  ##
  # job to recompute column encodings for Redshift tables
  #
  # Please see `BaseJob` class documentation on how to run
  # any job using its general interface.
  #
  class RegenerateTableJob < Desmond::BaseJobNoJobId
    ##
    # runs a job that recomputes the column encodings for a table
    #
    # the following +options+ are required:
    # - db
    #   - connection_id: ActiveRecord connection id used to connect to database
    #   - username: database username
    #   - password: database password
    #   - schema: schema of table
    #   - table: name of table
    # - s3
    #   - access_key_id: s3 access key
    #   - secret_access_key: s3 secret key
    #   - bucket: bucket to place unloaded data into
    #   - prefix: prefix to append to s3 data stored
    #
    # the following +options+ are additionally supported:
    # - db
    #   - timeout: connection timeout to database
    # TODO: additional options for archiving
    # - redshift: options for how Redshift should UNLOAD and COPY
    #   - allowoverwrite: if true, will use the ALLOWOVERWRITE unload option
    #   - gzip: if true, will use GZIP
    #   - quotes: if true, will use ADDQUOTES and REMOVEQUOTES
    #   - escape: if true, will use ESCAPE
    #   - null_as: string to use for NULL AS
    #
    def execute(job_id, user_id, options={})
      fail 'No database options!' if options[:db].nil?
      fail 'No s3 options!' if options[:s3].nil?

      # ensure dist key and sort keys are available for the table
      conn = Desmond::PGUtil.dedicated_connection(options[:db])
      schema = options[:db][:schema]
      table = options[:db][:table]
      avail_keys = TableUtils.get_columns(conn, {schema_name: schema, table_name: table})["#{schema}.#{table}"].map {|k| k['name']}
      dist_key = options[:db][:distkey_override]
      fail "Distribution key #{dist_key} not found. Keys Available: #{avail_keys}" unless dist_key.nil? or avail_keys.include?(dist_key)
      sort_keys = options[:db][:sortkeys_override]
      sort_keys.each do |key|
        fail "Sort key #{key} not found. Keys Available: #{avail_keys}" unless avail_keys.include?(key)
      end unless sort_keys.nil?

      # set up common options for archiving and restoring
      options = options.deep_merge({db: {skip_drop: false} })
      unless options[:redshift].nil?
        quotes = options[:redshift][:quotes]
        unload_options = {addquotes: quotes}.merge(options[:redshift])
        copy_options = {removequotes: quotes}.merge(options[:redshift])
        options = options.deep_merge({unload: unload_options})
        options = options.deep_merge({copy: copy_options})
      end

      # archive
      Jobs::ArchiveJob.run(job_id, user_id, options)

      # restore
      Jobs::RestoreJob.run(job_id, user_id, options)
    end

    ##
    # in case of success
    #
    def success(job_run, job_id, user_id, options={})
      subject = 'Regenerating table succeeded'
      body = "Succeeded in regenerating table #{options[:db][:schema]}.#{options[:db][:table]}"
      mail(options[:email], subject, body, options.fetch('mail', {}))
    end

    ##
    # in case of error
    #
    def error(job_run, job_id, user_id, options={})
      subject = 'ERROR: Regenerating table failed'
      body = "Failed to regenerate table #{options[:db][:schema]}.#{options[:db][:table]}
The following error description might be helpful: '#{job_run.error}'"

      mail_options = {
          cc: GlobalConfig.polizei('job_failure_cc'),
          bcc: GlobalConfig.polizei('job_failure_bcc')
      }.merge(options.fetch('mail', {}))
      mail(options[:email], subject, body, mail_options)
    end

    private

    ##
    # common sending code
    #
    def mail(to, subject, body, options={})
      pony_options = {to: to, subject: subject, body: body}.merge(options)
      Pony.mail(pony_options)
    end
  end
end
