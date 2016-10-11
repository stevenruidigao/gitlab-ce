class SlashCommandsController < ApplicationController
  respond_to :json

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :find_project

  attr_reader :project

  def trigger
    if service
      render json: service.new(@project, user, params).execute
    else
      render json: unavailable
    end
  end

  private

  def unavailable
    {
      response_type: :ephemeral,
      text: 'This slash command has not been registered yet.',
    }
  end

  def project_unavailable(path)
    {
      response_type: :ephemeral,
      text: "The #{path} doesn't exist or you don't have access."
    }
  end

  def project_not_found(path)
    {
      response_type: :ephemeral,
      text: "We were unable to find a project for: #{path}"
    }
  end

  def find_project
    path = "#{params[:team_domain]}/#{params[:channel_name]}"
    @project = Project.find_with_namespace(path)

    render json: project_not_found(path) unless can?(user, :read_project, @project)
  end

  def user
    @user ||= User.find_by(username: params[:user_name])
  end

  def service
    command = params[:command]

    if command == '/issue' && project.issues_enabled? && project.default_issues_tracker?
      Mattermost::IssueService
    elsif command == '/merge-request' && project.merge_requests_enabled?
      Mattermost::MergeRequestService
    elsif command == '/deploy'
      Mattermost::DeployService
    else
      nil
    end
  end
end
