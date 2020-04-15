=begin
METRICS API

The SASHIMI API represents a RESTful implementation of SUSHI automation intended to returns COUNTER Research Data Release 1 reports

OpenAPI spec version: 1.0.0
Contact: support@datacite.org
Generated by: https://github.com/swagger-api/swagger-codegen.git

=end
class ReportsController < ApplicationController

  # include validation methods for sushi
  include Helpeable

  prepend_before_action :authenticate_user_from_token!
  before_action :set_report, only: [:show, :destroy]
  before_action :set_user_hash, only: [:create, :update, :destroy]
  before_action :validate_monthly_report, only: [:create, :update]
  authorize_resource :except => [:index, :show]

  def index
    page = (params.dig(:page, :number) || 1).to_i
    size = (params.dig(:page, :size) || 25).to_i
    from = (page - 1) * size

    sort = case params[:sort]
           when "-name" then { "name.keyword" => { order: 'desc' }}
           when "created" then { created: { order: 'asc' }}
           when "-created" then { created: { order: 'desc' }}
           else { "name.keyword" => { order: 'asc' }}
           end

    if params[:id].present?
      collection = Report.where(uid: params[:id].split(","))
    elsif params[:created_by].present?
      collection = Report.where(created_by: params[:created_by])
    elsif params[:year].present?
      collection = Report.where(year: params[:year])
    elsif params[:client_id].present?
      collection = Report.where(client_id: params[:client_id])
    else
      collection = Report.all
    end

    total = collection.size
    total_pages = (total.to_f / size).ceil

    @reports = Kaminari.paginate_array(collection, total_count: total).page(page).per(size)

    @meta = {
      total: total,
      "total-pages": total_pages,
      page: page
    }
    render json: @reports, meta: @meta, include: @include, each_serializer: HeaderSerializer
  end

  def destroy
    if @report.destroy
      head :no_content
    else
      Rails.logger.error @report.errors.inspect
      render jsonapi: serialize(@report.errors), status: :unprocessable_entity
    end
  end

  def show
    render json: @report
  end

  def update
    fail ActiveRecord::RecordInvalid unless validate_uuid(params[:id]) == true
    @report = Report.where(uid: params[:id]).first
    exists = @report.present?
    
    if exists && params[:compressed].present?
      @report.report_subsets.destroy_all 
      @report.report_subsets <<  ReportSubset.new(compressed: safe_params[:compressed]) 
      authorize! :delete_all, @report.report_subsets
    end
    # create report if it doesn't exist already
    @report = Report.new(safe_params.merge({uid: params[:id]})) unless @report.present?
    authorize! :update, @report

    if @report.update_attributes(safe_params.merge(@user_hash))
      render json: @report, status: exists ? :ok : :created
    else
      Rails.logger.warn @report.errors.inspect
      render json: serialize(@report.errors), status: :unprocessable_entity
    end
  end

  def create
    @report = Report.where(created_by: params[:report_header].dig(:created_by))
    .where(month: get_month(params[:report_header].dig(:reporting_period,"begin_date")))
    .where(year: get_year(params[:report_header].dig(:reporting_period,"begin_date")))
    .where(client_id: params.merge(@user_hash)[:client_id])
    .first
    exists = @report.present?

    @report.report_subsets <<  ReportSubset.new(compressed: safe_params[:compressed]) if @report.present? &&  params[:compressed].present?
    # add_subsets

    @report = Report.new(safe_params.merge(@user_hash)) unless @report.present?
    authorize! :create, @report

    if @report.save
      render json: @report, status: :created
    else
      Rails.logger.error @report.errors.inspect
      render json: @report.errors, status: :unprocessable_entity
    end
  end

  protected

  def set_report
    @report = Report.where(uid: params[:id]).first

    fail ActiveRecord::RecordNotFound unless @report.present?
  end

  def set_user_hash
    @user_hash = { client_id: current_user.client_id, provider_id: current_user.provider_id }
  end

  def validate_monthly_report
    # period =safe_params.fetch("reporting_period",nil)
    fail JSON::ParserError, "Reports are monthly, reporting dates need to be within the same month" if get_month(params[:report_header].dig(:reporting_period,"begin_date")) !=  get_month(params[:report_header].dig(:reporting_period,"end_date"))
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the SUSHI specification" unless params[:report_header].present?

    case(true)
      when params[:report_datasets].present? && params[:report_header].fetch(:release) == "rd1" && params[:encoding] != "gzip"
        return usage_report_params
      when params[:report_header].fetch(:release) == "drl" && params[:encoding] == "gzip" 
        return resolution_report_params
      when params[:compressed].present? && params[:encoding] == "gzip" && params[:report_header].fetch(:release) == "rd1" 
        return compressed_report_params
      when params[:encoding] == "gzip" && params[:compressed].nil? && params[:report_header].fetch(:release) == "rd1" 
        return decompressed_report_params
      else
        fail JSON::ParserError, "Report protocol is incorrect" 
    end
  end

  def usage_report_params
    Rails.logger.info "Normal Report"
    fail JSON::ParserError, "You need to provide a payload following the SUSHI specification" unless params[:report_datasets].present? and params[:report_header].present? 

    header, datasets = params.require([:report_header, :report_datasets])
    header[:report_datasets] = datasets

    nested_names = [:name, :value]
    nested_types = [:type, :value]

    header.permit(
      :report_name, :report_id, :release, :created, :created_by, 
      report_attributes: nested_names, 
      report_filters: nested_names, 
      reporting_period: ["end_date", "begin_date"], 
      exceptions: [:message, :severity, :data, :code, "help_url"], 
      report_datasets: [
        "dataset-title", 
        :yop,
        :uri,
        :platform,
        "data-type", 
        :publisher,
        "publisher-id": nested_types, 
        "dataset-dates": nested_types, 
        performance: [
          period: ["end-date", "begin-date"],
          instance: ["access-method", "metric-type", :count, "country-counts": COUNTRY_CODES]
        ],
        "dataset-contributors": nested_types,
        "dataset-attributes": nested_types,
        "dataset-id": nested_types
      ]
    )
  end

  def resolution_report_params
    Rails.logger.info "Resolutions Report"
    fail  fail JSON::ParserError, "Resolution Reports need to be compressed" unless params[:compressed].present? and params[:encoding] == "gzip" and params[:report_header].present? 
    # header, report = params.require([:report_header, :gzip])
    # header[:compressed] = Base64.decode64(report)
    # header
    header, report = params.require([:report_header, :compressed])
    header[:compressed] = Rails.env.test? ?  report.string : rewind_compressed_params(report)
    header
  end

  def compressed_report_params
    Rails.logger.info "Compressed Report"
    fail JSON::ParserError, "You need to provide a payload following the SUSHI specification and int compressed" unless params[:compressed].present? and params[:report_header].present? 
    header, report = params.require([:report_header, :compressed])
    header[:compressed] = Rails.env.test? ?  report.string : rewind_compressed_params(report)
    header
  end

  def decompressed_report_params
    Rails.logger.info "not posssible"
    fail JSON::ParserError, "You need to provide a payload following the SUSHI specification" unless params[:report_datasets].present? and params[:report_header].present? 
    header, datasets = params.require([:report_header, :report_datasets])
    header[:report_datasets] = datasets
    header
  end

  def rewind_compressed_params(params)
    # https://github.com/inossidabile/wash_out/issues/132
    params.rewind
    params.read
  end
end
