# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :setup_infrastructure

  # POST /accounts
  # 口座開設
  def create
    result = CommandHandlers::OpenAccount.new(@repository).call(
      account_number: params[:account_number],
      owner_name: params[:owner_name],
      initial_balance: params[:initial_balance]&.to_f || 0
    )

    if result[:success]
      render json: result, status: :created
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # POST /accounts/:account_number/deposit
  # 入金
  def deposit
    result = CommandHandlers::DepositMoney.new(@repository).call(
      account_number: params[:account_number],
      amount: params[:amount].to_f,
      description: params[:description]
    )

    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # POST /accounts/:account_number/withdraw
  # 出金
  def withdraw
    result = CommandHandlers::WithdrawMoney.new(@repository).call(
      account_number: params[:account_number],
      amount: params[:amount].to_f,
      description: params[:description]
    )

    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # GET /accounts/:account_number/balance
  # 残高照会
  def balance
    result = Queries::GetAccountBalance.new.call(
      account_number: params[:account_number]
    )

    if result[:success]
      render json: result
    else
      render json: result, status: :not_found
    end
  end

  # GET /accounts/:account_number/transactions
  # 取引履歴
  def transactions
    result = Queries::GetTransactionHistory.new.call(
      account_number: params[:account_number],
      limit: params[:limit]&.to_i || 100,
      offset: params[:offset]&.to_i || 0
    )

    if result[:success]
      render json: result
    else
      render json: result, status: :not_found
    end
  end

  # GET /accounts/:account_number/events
  # イベント履歴（Event Store から直接取得）
  def events
    stream_name = "Account-#{params[:account_number]}"
    events = DomainEventModel.for_stream(stream_name).map do |event|
      {
        event_id: event.event_id,
        event_type: event.event_type,
        stream_version: event.stream_version,
        data: event.data,
        metadata: event.metadata,
        occurred_at: event.occurred_at
      }
    end

    render json: {
      success: true,
      account_number: params[:account_number],
      event_count: events.size,
      events: events
    }
  end

  private

  def setup_infrastructure
    @event_store = EventStore::ActiveRecordEventStore.new
    @repository = Domain::Repository.new(@event_store)

    # Event Handlers の登録
    @event_store.subscribe(EventHandlers::AccountProjection.new)
  end
end
