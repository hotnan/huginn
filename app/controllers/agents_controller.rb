class AgentsController < ApplicationController
  include DotHelper
  include ActionView::Helpers::TextHelper
  include SortableTable
  require 'uri'
  require 'net/http'
  require 'base64'

  def index
    set_table_sort sorts: %w[name created_at last_check_at last_event_at last_receive_at], default: { created_at: :desc }

    @agents = current_user.agents.preload(:scenarios, :controllers).reorder(table_sort).page(params[:page])

    if show_only_enabled_agents?
      @agents = @agents.where(disabled: false)
    end

    respond_to do |format|
      format.html
      format.json { render json: @agents }
    end
  end

  def toggle_visibility
    if show_only_enabled_agents?
      mark_all_agents_viewable
    else
      set_only_enabled_agents_as_viewable
    end

    redirect_to agents_path
  end

  def handle_details_post
    @agent = current_user.agents.find(params[:id])
    if @agent.respond_to?(:handle_details_post)
      render :json => @agent.handle_details_post(params) || {}
    else
      @agent.error "#handle_details_post called on an instance of #{@agent.class} that does not define it."
      head 500
    end
  end

  def run
    @agent = current_user.agents.find(params[:id])
    Agent.async_check(@agent.id)

    respond_to do |format|
      format.html { redirect_back "Agent run queued for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def type_details
    @agent = Agent.build_for_type(params[:type], current_user, {})
    initialize_presenter

    render json: {
        can_be_scheduled: @agent.can_be_scheduled?,
        default_schedule: @agent.default_schedule,
        can_receive_events: @agent.can_receive_events?,
        can_create_events: @agent.can_create_events?,
        can_control_other_agents: @agent.can_control_other_agents?,
        can_dry_run: @agent.can_dry_run?,
        options: @agent.default_options,
        description_html: @agent.html_description,
        oauthable: render_to_string(partial: 'oauth_dropdown', locals: { agent: @agent }),
        form_options: render_to_string(partial: 'options', locals: { agent: @agent })
    }
  end

  def event_descriptions
    html = current_user.agents.find(params[:ids].split(",")).group_by(&:type).map { |type, agents|
      agents.map(&:html_event_description).uniq.map { |desc|
        "<p><strong>#{type}</strong><br />" + desc + "</p>"
      }
    }.flatten.join()
    render :json => { :description_html => html }
  end

  def remove_events
    @agent = current_user.agents.find(params[:id])
    @agent.events.delete_all

    respond_to do |format|
      format.html { redirect_back "All emitted events removed for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def propagate
    respond_to do |format|
      if AgentPropagateJob.can_enqueue?
        details = Agent.receive! # Eventually this should probably be scoped to the current_user.
        format.html { redirect_back "Queued propagation calls for #{details[:event_count]} event(s) on #{details[:agent_count]} agent(s)" }
        format.json { head :ok }
      else
        format.html { redirect_back "Event propagation is already scheduled to run." }
        format.json { head :locked }
      end
    end
  end

  def destroy_memory
    @agent = current_user.agents.find(params[:id])
    @agent.update!(memory: {})

    respond_to do |format|
      format.html { redirect_back "Memory erased for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def show
    @agent = current_user.agents.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def new
    agents = current_user.agents

    if id = params[:id]
      @agent = agents.build_clone(agents.find(id))
    else
      @agent = agents.build
    end

    @agent.scenario_ids = [params[:scenario_id]] if params[:scenario_id] && current_user.scenarios.find_by(id: params[:scenario_id])

    initialize_presenter

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def edit
    @agent = current_user.agents.find(params[:id])
    initialize_presenter
  end

  def create
    build_agent

    respond_to do |format|
      if @agent.save
        format.html { redirect_back "'#{@agent.name}' was successfully created.", return: agents_path }
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
      else
        initialize_presenter
        format.html { render action: "new" }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @agent = current_user.agents.find(params[:id])

    respond_to do |format|
      if @agent.update_attributes(agent_params)
        format.html { redirect_back "'#{@agent.name}' was successfully updated.", return: agents_path }
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
      else
        initialize_presenter
        format.html { render action: "edit" }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def leave_scenario
    @agent = current_user.agents.find(params[:id])
    @scenario = current_user.scenarios.find(params[:scenario_id])
    @agent.scenarios.destroy(@scenario)

    respond_to do |format|
      format.html { redirect_back "'#{@agent.name}' removed from '#{@scenario.name}'" }
      format.json { head :no_content }
    end
  end

  def destroy
    @agent = current_user.agents.find(params[:id])
    @agent.destroy

    respond_to do |format|
      format.html { redirect_back "'#{@agent.name}' deleted" }
      format.json { head :no_content }
    end
  end

  def validate
    build_agent

    if @agent.validate_option(params[:attribute])
      render plain: 'ok'
    else
      render plain: 'error', status: 403
    end
  end

  def complete
    build_agent

    render json: @agent.complete_option(params[:attribute])
  end

  def destroy_undefined
    current_user.undefined_agents.destroy_all

    redirect_back "All undefined Agents have been deleted."
  end

  def create_pin
    @agent = current_user.agents.find(params[:id])
    service_tocken = Service.find_by_user_id_and_provider(current_user.id, 'pinterest')
    if service_tocken.present?
      client = Pinterest::Client.new(service_tocken.token)
      me = client.me.first.drop(1)
      @user_name =  URI.parse(me[0].url).path[1..-2]

      client_boards = client.get_boards
      client_boards1 =  client_boards.first.drop(1)
      client_boards2 = client_boards1.flatten!
      @boards = []
      client_boards2.each do |c|
        @boards << c.name
      end
    else
      redirect_to agents_path, notice: "Access token not provided."
    end
  end

  def publish_pin
    board =  params[:Boards].downcase
    service_tocken = Service.find_by_user_id_and_provider(current_user.id, 'pinterest')
    if service_tocken.present?
      client = Pinterest::Client.new(service_tocken.token)
      demo = client.create_pin({
        board: params[:user_name] + "/" + board,
        note: params[:note],
        link: params[:link],
        image_url: params[:image_url]
      })
      redirect_to agents_path, notice: "Publish pin successfully."
    else 
      redirect_to agents_path, notice: "Access token not provided."
    end
  end

  protected

  # Sanitize params[:return] to prevent open redirect attacks, a common security issue.
  def redirect_back(message, options = {})
    if path = filtered_agent_return_link(options)
      redirect_to path, notice: message
    else
      super agents_path, notice: message
    end
  end

  def build_agent
    @agent = Agent.build_for_type(agent_params[:type],
                                  current_user,
                                  agent_params.except(:type))
  end

  def initialize_presenter
    if @agent.present? && @agent.is_form_configurable?
      @agent = FormConfigurableAgentPresenter.new(@agent, view_context)
    end
  end

  private
  def show_only_enabled_agents?
    !!cookies[:huginn_view_only_enabled_agents]
  end

  def set_only_enabled_agents_as_viewable
    cookies[:huginn_view_only_enabled_agents] = {
      value: "true",
      expires: 1.year.from_now
    }
  end

  def mark_all_agents_viewable
    cookies.delete(:huginn_view_only_enabled_agents)
  end
end
