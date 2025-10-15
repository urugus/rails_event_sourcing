# frozen_string_literal: true

class AccountsController < ApplicationController
  # POST /accounts
  # 口座開設
  def create
    result = Accounts::Commands::OpenAccount.call(
      account_number: params[:account_number],
      owner_name: params[:owner_name],
      initial_balance: params[:initial_balance]&.to_f || 0
    )

    if result.success?
      render json: {
        success: true,
        account: {
          id: result.account.id,
          account_number: result.account.account_number,
          owner_name: result.account.owner_name,
          balance: result.account.balance,
          status: result.account.status
        }
      }, status: :created
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end

  # POST /accounts/:account_number/deposit
  # 入金
  def deposit
    result = Accounts::Commands::Deposit.call(
      account_number: params[:account_number],
      amount: params[:amount].to_f,
      description: params[:description]
    )

    if result.success?
      render json: {
        success: true,
        transaction: {
          id: result.transaction.id,
          type: result.transaction.transaction_type,
          amount: result.transaction.amount,
          balance_after: result.transaction.balance_after,
          description: result.transaction.description,
          executed_at: result.transaction.executed_at
        }
      }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end

  # POST /accounts/:account_number/withdraw
  # 出金
  def withdraw
    result = Accounts::Commands::Withdraw.call(
      account_number: params[:account_number],
      amount: params[:amount].to_f,
      description: params[:description]
    )

    if result.success?
      render json: {
        success: true,
        transaction: {
          id: result.transaction.id,
          type: result.transaction.transaction_type,
          amount: result.transaction.amount,
          balance_after: result.transaction.balance_after,
          description: result.transaction.description,
          executed_at: result.transaction.executed_at
        }
      }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end

  # GET /accounts/:account_number/balance
  # 残高照会
  def balance
    result = Accounts::Queries::GetBalance.call(
      account_number: params[:account_number]
    )

    if result.success?
      render json: {
        success: true,
        account_number: result.account.account_number,
        owner_name: result.account.owner_name,
        balance: result.balance,
        status: result.account.status
      }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :not_found
    end
  end

  # GET /accounts/:account_number/transactions
  # 取引履歴
  def transactions
    result = Accounts::Queries::GetTransactionHistory.call(
      account_number: params[:account_number],
      limit: params[:limit]&.to_i || 100,
      offset: params[:offset]&.to_i || 0
    )

    if result.success?
      render json: {
        success: true,
        transactions: result.transactions.map do |t|
          {
            id: t.id,
            type: t.transaction_type,
            amount: t.amount,
            balance_after: t.balance_after,
            description: t.description,
            executed_at: t.executed_at
          }
        end
      }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :not_found
    end
  end
end
