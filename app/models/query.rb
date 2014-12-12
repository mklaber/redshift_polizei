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
    # returns sql query with stripped comments
    # supports:
    # - singe line --
    # - multi-line /**/ comments
    #
    def self.strip_comments(q)
      q = q.gsub(/--(.*)/, '') # singe line -- comments
      q = q.gsub(/(\/\*).+(\*\/)/m, '') # multi-line /**/ comments
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
      is_select ||= (qstr.start_with?('set client_encoding'))
      is_select ||= (qstr.start_with?('set statement_timeout'))
      is_select ||= (qstr.start_with?('set query_group'))
      is_select ||= (qstr.start_with?('set search_path'))
      is_select ||= (qstr.start_with?('set datestyle'))
      return ((is_select) ? 0 : 1)
    end
  end
end
