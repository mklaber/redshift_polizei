require './app/main'

module CSVStreams
  class Reader
    def initialize
      @eof = false
    end

    def read
      raise NotImplementedError
    end

    def close
      raise NotImplementedError
    end

    def eof?
      @eof
    end
  end

  class CSVReader < Reader
    attr_reader :name

    def initialize(name, options={})
      super()
      @name = name
      @options = {
        delimiter: ',',
        include_headers: false,
        headers: nil,
        newline: "\n"
      }.merge(options)
      @read_headers = false
    end

    def delimiter
      @options[:delimiter]
    end

    def headers
      @options[:headers] || []
    end

    def header_line
      self.headers.join(self.delimiter) + self.newline
    end

    def newline
      @options[:newline]
    end

    def read
      if @options[:include_headers] && not(@read_headers)
        @read_headers = true
        self.header_line
      end
    end

    def close
      raise NotImplementedError
    end
  end

  class CSVRecordHashReader < CSVReader
    def initialize(name, hash_reader, options={})
      super(name, options)
      @reader = hash_reader
    end

    def headers
      hdrs = super()
      if hdrs.size == 0
        hdrs = @reader.columns
      end
      hdrs
    end

    def read
      tmp = super()
      if tmp.nil?
        tmp = @reader.read.map { |hash| hash.values.join(self.delimiter)}.join(self.newline)
        # joining the hash records, doesn't put a newline at the end, so the next section will be in the same line!
        # => append a new line at the end of the section
        tmp += self.newline if tmp.size > 0
      end
      yield(tmp) if block_given?
      tmp
    end

    def eof?
      @reader.eof?
    end

    def close
      @reader.close
    end
  end

  class ActiveRecordCursorReader < Reader
    def initialize(name, query, options={})
      super()
      @name = name
      @query = query
      @options = {
        fetch_size: 1000,
      }.merge(options)
      # we need to use the same connection throughout
      @conn = (@options[:connection] || ActiveRecord::Base).connection
      # create the cursor
      @conn.execute("BEGIN; DECLARE #{@name} CURSOR FOR #{@query};")
      # create fetch query
      @fetchq = "FETCH FORWARD #{@options[:fetch_size].to_i} FROM #{@name};"
      @closeq = "CLOSE #{@name}; END;"
      @bugg = nil
    end

    def columns
      @buff = read
      @buff[0].keys
    end

    def read
      if not(@buff.nil?)
        tmp = @buff
        @buff = nil
        return tmp
      end
      tmp = @conn.select_all(@fetchq)
      @eof = true if tmp.empty?
      yield(tmp) if block_given?
      tmp
    end

    def close
      @conn.execute(@closeq)
    end

    def eof?
      @eof
    end
  end

  class ActiveRecordCustomConnectionCursorReader < ActiveRecordCursorReader
    def initialize(name, query, configuration, username, password, options={})
      # construct connection config with the provided credentials
      # important to clone the config, otherwise we'll chnage the ActiveRecord internal connection credentials
      redshift_config = ActiveRecord::Base.configurations[configuration.to_s].clone
      redshift_config['username'] = username
      redshift_config['password'] = password
      DummyModelARCursorReader.establish_connection(redshift_config)
      super(name, query, options.merge(connection: DummyModelARCursorReader))
    end

    class DummyModelARCursorReader < ActiveRecord::Base
      # common base class for RedShift communication
      self.abstract_class = true
      # even with abstract_class it looks for the table, this fixes that
      def self.columns
        @columns ||= []
      end
    end
  end

  class S3Writer
    def initialize(bucket, name, options={})
      # create empty s3 object
      @o = AWSConfig.s3_sdk(options).buckets[bucket].objects.create(name, '')
    end

    def public_url
      @o.url_for(:read).to_s
    end

    def write_from(reader)
      begin
        @o.write(estimated_content_length: 1024) do |buffer, bytes|
          while bytes > 0 && not(reader.eof?)
            t = reader.read
            buffer.write(t)
            bytes -= t.size
          end
        end
      rescue => e
        # remove object if error occurred
        @o.delete
        raise e
      end
    end
  end
end

if __FILE__ == $0
  c = CSVStreams::CSVRecordHashReader.new(
    "jop",
    CSVStreams::ActiveRecordCustomConnectionCursorReader.new("test_cursor", "SELECT * FROM tobias.test ORDER BY id", :redshift_development, 'tobias', 'KXSJwdjo32987', fetch_size: 3),
    delimiter: '|',
    newline: "\r\n",
    include_headers: true
  )
  while not c.eof? do
    c.read do |record|
      puts record
    end
  end
  #S3Writer.new('amg-tobi-test', 'test-export').write_from(c)
end
