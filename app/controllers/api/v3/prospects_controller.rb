class Api::V3::ProspectsController < ApplicationController
  before_action :set_prospect, only: [:show, :update, :destroy]
  before_action :authenticate_user!

  # GET /prospects
  # GET /prospects.json
  def index
    @prospects = Prospect.all
  end

  # GET /prospects/1
  # GET /prospects/1.json
  def show
  end

  # POST /prospects
  # POST /prospects.json
  def create
    @prospect = Prospect.new(prospect_params)

    if @prospect.save
      render :show, status: :created, location: @prospect
    else
      render json: @prospect.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /prospects/1
  # PATCH/PUT /prospects/1.json
  def update
    if @prospect.update(prospect_params)
      render :show, status: :ok, location: @prospect
    else
      render json: @prospect.errors, status: :unprocessable_entity
    end
  end

  # DELETE /prospects/1
  # DELETE /prospects/1.json
  def destroy
    @prospect.destroy
  end

  def sample
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_prospect
    @prospect = Prospect.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def prospect_params
    params.require(:prospect).permit(:full_name, :image_url, :last_processed, :processed_count, :prospected_by_company_id, :prospected_by_user_id, :lead_id, :account_id, :account_name, :title)
  end
end
