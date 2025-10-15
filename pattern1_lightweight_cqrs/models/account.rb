# frozen_string_literal: true

class Account < ApplicationRecord
  has_many :transactions, dependent: :destroy

  validates :account_number, presence: true, uniqueness: true
  validates :owner_name, presence: true
  validates :balance, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: %w[active closed] }

  scope :active, -> { where(status: 'active') }
  scope :closed, -> { where(status: 'closed') }

  def active?
    status == 'active'
  end

  def closed?
    status == 'closed'
  end

  def close!
    update!(status: 'closed')
  end
end
