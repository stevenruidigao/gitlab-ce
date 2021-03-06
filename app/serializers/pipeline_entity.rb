# frozen_string_literal: true

class PipelineEntity < Grape::Entity
  include RequestAwareEntity

  expose :id
  expose :user, using: UserEntity
  expose :active?, as: :active

  # Coverage isn't always necessary (e.g. when displaying project pipelines in
  # the UI). Instead of creating an entirely different entity we just allow the
  # disabling of this specific field whenever necessary.
  expose :coverage, unless: proc { options[:disable_coverage] }
  expose :source

  expose :created_at, :updated_at

  expose :path do |pipeline|
    project_pipeline_path(pipeline.project, pipeline)
  end

  expose :flags do
    expose :latest?, as: :latest
    expose :stuck?, as: :stuck
    expose :auto_devops_source?, as: :auto_devops
    expose :merge_request_event?, as: :merge_request
    expose :has_yaml_errors?, as: :yaml_errors
    expose :can_retry?, as: :retryable
    expose :can_cancel?, as: :cancelable
    expose :failure_reason?, as: :failure_reason
  end

  expose :details do
    expose :detailed_status, as: :status, with: DetailedStatusEntity
    expose :duration
    expose :finished_at
  end

  expose :ref do
    expose :name do |pipeline|
      pipeline.ref
    end

    expose :path do |pipeline|
      if pipeline.ref
        project_ref_path(pipeline.project, pipeline.ref)
      end
    end

    expose :tag?, as: :tag
    expose :branch?, as: :branch
    expose :merge_request_event?, as: :merge_request
  end

  expose :commit, using: CommitEntity
  expose :yaml_errors, if: -> (pipeline, _) { pipeline.has_yaml_errors? }

  expose :failure_reason, if: -> (pipeline, _) { pipeline.failure_reason? } do |pipeline|
    pipeline.present.failure_reason
  end

  expose :retry_path, if: -> (*) { can_retry? } do |pipeline|
    retry_project_pipeline_path(pipeline.project, pipeline)
  end

  expose :cancel_path, if: -> (*) { can_cancel? } do |pipeline|
    cancel_project_pipeline_path(pipeline.project, pipeline)
  end

  private

  alias_method :pipeline, :object

  def can_retry?
    can?(request.current_user, :update_pipeline, pipeline) &&
      pipeline.retryable?
  end

  def can_cancel?
    can?(request.current_user, :update_pipeline, pipeline) &&
      pipeline.cancelable?
  end

  def detailed_status
    pipeline.detailed_status(request.current_user)
  end
end
