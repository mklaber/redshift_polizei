module Models
  #
  # Audit Log Query Model
  #
  class Query < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # record_time            :integer          not null
    # db                     :string(255)      not null
    # user                   :string(255)      not null
    # pid                    :integer          not null
    # userid                 :integer          not null
    # xid                    :integer          not null
    # query                  :text             not null
    # logfile                :string(255)      not null
    # query_type             :integer          not null, 0 => select, 1 => non-select

    #
    # returns the given query to be used when showing in frontend
    #
    def self.query_for_display(q)
      # convert unexpanded newlines
      t = q.gsub('\n', "\n")
      t = self.strip_comments(t)
      t = t.strip
      t = t.gsub(/(\s)\s+/, '\1') # replace multiple whitespaces with the first one
    end

    #
    # returns sql query with stripped comments
    # supports:
    # - singe line --
    # - multi-line /**/ comments
    #
    def self.strip_comments(q)
      # replaced with space since it functions as a separator and removing it might make statement invalid
      # first multi-line comments so that single line comments can't remove the closer of multi-lines
      q = q.gsub(/(?<comment>(\/\*)(\g<comment>|.)*?(\*\/))/m, ' ') # multi-line /**/ comments
      q = q.gsub(/(--.*?(\n|\z))/, ' ') # singe line -- comments
    end

    #
    # returns the type of a sql query
    # currently:
    # - 0 => select
    # - 1 => non-select
    #
    def self.query_type(query)
      # determine what kind kind of query
      qstr = strip_comments(query.downcase).strip
      name_match = qstr.match(/^[a-zA-Z0-9_]+:/)
      if not(name_match.nil?)
        qstr = qstr[name_match[0].length, qstr.length].strip
      end
      is_select   = (qstr.start_with?('select'))
      is_select ||= (qstr.start_with?('show'))
      is_select ||= (qstr.start_with?('analyze'))
      is_select ||= (qstr.start_with?('declare'))
      is_select ||= (qstr.start_with?('fetch'))
      is_select ||= (qstr.start_with?('close'))
      is_select ||= (qstr.start_with?('set client_encoding'))
      is_select ||= (qstr.start_with?('set statement_timeout'))
      is_select ||= (qstr.start_with?('set query_group'))
      is_select ||= (qstr.start_with?('set search_path'))
      is_select ||= (qstr.start_with?('set datestyle'))
      is_select ||= (qstr == 'begin;')
      # select into is a manipulative query!
      if qstr.start_with?('select') && (m = qstr.match(/select[\s]+into/))
        is_select ||= false
      end
      return ((is_select) ? 0 : 1)
    end
  end
end
