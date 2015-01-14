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

    def enqueue(user, options={})
      Jobs::ExportJob.enqueue(self.id, user.id, options)
    end

    def last3_runs
      Models::JobRun.last3_job_runs(self)
    end

    def runs
      Models::JobRun.job_runs(self)
    end

    def runs_unfinished(user=nil)
      Models::JobRun.unfinished_job_runs(self, user)
    end

    def runs_done(user=nil)
      Models::JobRun.done_job_runs(self, user)
    end

    def running?
      Models::JobRun.job_running?(self)
    end

    def queued?
      Models::JobRun.job_queued?(self)
    end

    def done?
      Models::JobRun.job_done?(self)
    end
  end
end
