class ServicesController < ApplicationController
  include SortableTable

  before_action :upgrade_warning, only: :index

  def index
    @service = Service.new
    set_table_sort sorts: %w[provider name global], default: { provider: :asc }

    @services = current_user.services.reorder(table_sort).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @services }
    end
  end

  def create
    tocken = params[:service][:secret]
    if tocken.present?
      client = Pinterest::Client.new(tocken)
      me = client.me.first.drop(1)
      user_name =  URI.parse(me[0].url).path[1..-2]
      status = client.me.status if client.me.status.present?
      u_name = Service.find_by_token(tocken)
      
      if u_name.present?
        redirect_to services_path, notice: "Access tocken already exist."
      else
        if status == "failure"
          redirect_to services_path, notice: "Access tocken is invalid."
        else
          Service.create(user_id: current_user.id, provider: "pinterest", token: tocken, name: user_name)
        end
      end
    end
  end

  def destroy
    @services = current_user.services.find(params[:id])
    @services.destroy

    respond_to do |format|
      format.html { redirect_to services_path }
      format.json { head :no_content }
    end
  end

  def toggle_availability
    @service = current_user.services.find(params[:id])
    @service.toggle_availability!

    respond_to do |format|
      format.html { redirect_to services_path }
      format.json { render json: @service }
    end
  end
end
