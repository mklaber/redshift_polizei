require './app/main'

def renew_all_reports
  renew_reports(nil)
end

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
        report.new.run
      rescue NotImplementedError
        p "Error running report #{report}"
        raise
      end
    end
  ensure
    # make sure to reenable the cache afterwards
    Caches::BaseCache.cache.enable
  end
end

if __FILE__ == $0
  renew_reports([Reports::DiskSpace, Reports::Table])
end
