require 'builder'
require 'strip'

class Transaction < ActiveRecord::Base
  include Strip

  belongs_to :statement
  validates_presence_of :statement

  def self.create_from_record(fields, values)
    hash = Hash[fields.zip values]
    timestamp = "#{hash['Date']} #{hash['Time']}".to_datetime
    amount = 0
    withdrawal = hash['Withdrawal'].tr(',','')
    deposit = hash['Deposits'].tr(',','')
    if withdrawal and !withdrawal.empty?
      amount = withdrawal.to_d
      raise "unexpected widthdrawal amount" unless amount < 0
    elsif deposit and !deposit.empty?
      amount = deposit.to_d
      raise "unexpected deposit amount" unless amount > 0
    end
    new_balance = hash['Balance'].tr(',','')
    trans = Transaction.new timestamp: timestamp, trans_type: hash['Transaction'], channel: hash['Channel'],
                            description: hash['Description'], check_no: Strip::mystrip(hash['Chq No']), amount: amount,
                            new_balance: new_balance
  end

  # Thanks to "bankjob" gem

  def to_ofx
    buf = ""
    # Set margin=5 to indent it nicely within the output from Statement.to_ofx
    x = ::Builder::XmlMarkup.new(target: buf, indent: 2, margin: 5)
    # Statement transaction
    x.STMTTRN do
      x.TRNTYPE self.trans_type
      x.DTPOSTED ofx_timestamp
      # Amount of transaction [amount] can be , or . separated
      x.TRNAMT self.amount
      x.FITID ofx_id
      x.CHECKNUM self.check_no unless self.check_no.nil? or self.check_no.empty?
      # SCB does not give a payee record
      #buf << self.payee.to_ofx unless self.payee.nil?
      x.MEMO description
    end
    buf
  end

  private

  # Thanks to "bankjob" gem for the example
  def ofx_id
    text = "#{self.timestamp}:#{self.description}:#{self.trans_type}:#{self.amount}:#{self.new_balance}"
    Digest::MD5.hexdigest(text)
  end

  def ofx_timestamp
    self.timestamp.strftime '%Y%m%d%H%M%S'
  end

end
