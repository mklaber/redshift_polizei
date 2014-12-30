module Models
  #
  # Model representing an queued/running/finished export job
  #
  class JobRun < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # job_id                 :integer          not null
    # job_class              :string(255)      not null
    # user_id                :integer          not null
    # status                 :string(255)      not null
    # executed_at            :timestamp        null
    # details                :json             not null

    belongs_to :user

    after_initialize :init

    def init
      self.details ||= {}
    end

    def job
      self.job_class.constantize.find(self.job_id)
    end

    def queued?
      self['status'] == 'queued'
    end

    def running?
      self['status'] == 'running'
    end

    def unfinished?
      (self.queued? || self.running?)
    end

    def failed?
      self['status'] == 'failed'
    end

    def done?
      self['status'] == 'done'
    end

    def queue_time
      self.created_at
    end

    def run_time
      self.executed_at
    end

    def done_time
      return nil if not(self.done? || self.failed?)
      self.updated_at
    end

    def waiting_time
      if self.run_time.nil?
        Time.now - self.queue_time
      else
        self.run_time - self.queue_time
      end
    end

    def running_time
      self.done_time - self.run_time
    end

    def overall_time
      self.waiting_time + self.running_time
    end

    def self.last3_job_runs(job, status=nil, user=nil)
      self.job_runs(job, status, user).order(created_at: :desc).take(3)
    end

    def self.job_queued?(job, user=nil)
      self.queued_job_runs(job, user).exists?
    end

    def self.job_running?(job, user=nil)
      self.running_job_runs(job, user).exists?
    end

    def self.job_done?(job, user=nil)
      self.done_job_runs(job, user).exists?
    end

    def self.queued_job_runs(job, user=nil)
      self.job_runs(job, 'queued', user)
    end

    def self.running_job_runs(job, user=nil)
      self.job_runs(job, 'running', user)
    end

    def self.unfinished_job_runs(job, user=nil)
      self.job_runs(job, ['queued', 'running'], user)
    end

    def self.done_job_runs(job, user=nil)
      self.job_runs(job, 'done', user)
    end

    def self.job_runs(job, status=nil, user=nil)
      q = self.where(job_class: job.class.name, job_id: job.id)
      q = q.where(status: status) unless status.nil?
      q = q.where(user: user) unless user.nil?
      q
    end
  end
end
