module Models
  #
  # Model representing an export job
  #
  class ExportJob < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # name                   :string(255)      not null
    # user_id                :integer          not null
    # success_email          :string(255)      null
    # failure_email          :string(255)      null
    # public                 :integer          not null
    # query                  :integer          not null
    # export_format          :string           not null
    # export_options         :json             not null

    belongs_to :user

    def unique_id
      "polizei_export_#{self.id}"
    end

    def enqueue(user, query, options={})
      Desmond::ExportJob.enqueue(unique_id, user.id, query, options)
    end

    def self.test(user, query, options={})
      Desmond::ExportJob.test(user.id, query, options)
    end

    def last3_runs
      export_runs(Desmond::ExportJob.last_runs(unique_id, 3))
    end

    def runs_unfinished(user=nil)
      export_runs(Desmond::ExportJob.runs_unfinished(unique_id, user.id))
    end

    def success_email_to
      "#{self.user.email}, #{self.success_email}"
    end

    def failure_email_to
      "#{self.user.email}, #{self.failure_email}"
    end

    private
      def export_runs(desmond_runs)
        desmond_runs.map { |r| ExportJobRun.new(r) }
      end

    class ExportJobRun
      def initialize(desmond_run)
        @run = desmond_run
        @datetime_format = '%F %T UTC'
      end

      def user
        Models::User.find(@run.user_id)
      end

      def completed_at
        @run.completed_at.strftime(@datetime_format)
      end

      def executed_at
        @run.executed_at.strftime(@datetime_format)
      end

      def queued_at
        @run.queued_at.strftime(@datetime_format)
      end

      def done?
        @run.done?
      end

      def failed?
        @run.failed?
      end

      def running?
        @run.running?
      end

      def queued?
        @run.queued?
      end
    end
  end
end
