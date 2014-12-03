require './app/main'

DEFAULT_REPORT_NAMESPACE = 'Reports::'
#
# Retrieve a report subclass base on its name.
# Tries '<name>' and 'Reports::<name>'
#
def get_report_class(name)
  report = nil
  begin
    # try to get by name directly
    report = name.constantize
  rescue NameError
    # if couldn't be found, try default namespace
    begin
      report = (DEFAULT_REPORT_NAMESPACE + name).constantize
    rescue NameError
      # ignore this, original error will be raised
    end
    # reraise error if couldn't be fixed
    raise if report.nil?
  end
  return report
end

def renew_all_reports
  renew_reports(nil)
end

#
# Renews the given reports.
# Accepts list of classes or strings.
# If parameter is empty or nil, uses all Reports::Base subclasses
#
def renew_reports(reports)
  return renew_reports(Reports::Base.descendants) if reports.nil?
  return renew_reports(Reports::Base.descendants) if reports.is_a?(Array) && reports.empty?
  return renew_reports([reports]) if not reports.is_a?(Array)

  begin
    # disable cache, making it always miss, but writes work regularly
    Caches::BaseCache.cache.disable
    # query reports data making it override the cache
    reports.each do |report|
      begin
        # get the class of the report, if name is given
        report = get_report_class(report) if report.is_a?(String)
        # run the report
        report.new.run
      rescue NotImplementedError
        PolizeiLogger.logger.error "Error running report #{report}"
        raise
      end
    end
  ensure
    # make sure to reenable the cache afterwards
    Caches::BaseCache.cache.enable
  end
end

if __FILE__ == $0
  renew_reports(ARGV)
end
