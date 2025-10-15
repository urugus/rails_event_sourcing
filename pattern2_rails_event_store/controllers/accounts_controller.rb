# frozen_string_literal: true

class AccountsController < ApplicationController
  # POST /accounts
  # 口座開設
  def create
    result = CommandHandlers::OpenAccount.new.call(
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
    result = CommandHandlers::DepositMoney.new.call(
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
    result = CommandHandlers::WithdrawMoney.new.call(
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

  # GET /accounts/:account_number/history
  # 取引履歴
  def history
    result = Queries::GetAccountHistory.new.call(
      account_number: params[:account_number],
      limit: params[:limit]&.to_i || 100
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
    stream_name = "Account$#{params[:account_number]}"
    event_store = Rails.configuration.event_store

    begin
      events = event_store.read.stream(stream_name).to_a

      render json: {
        success: true,
        account_number: params[:account_number],
        event_count: events.size,
        events: events.map do |event|
          {
            event_id: event.event_id,
            event_type: event.event_type,
            data: event.data,
            metadata: event.metadata
          }
        end
      }
    rescue RubyEventStore::Stream::StreamNotFound
      render json: {
        success: false,
        error: "口座が見つかりません"
      }, status: :not_found
    end
  end
end
