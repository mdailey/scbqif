class Transaction < ActiveRecord::Base

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
                            description: hash['Description'], check_no: hash['Chq No'], amount: amount,
                            new_balance: new_balance
  end


end
