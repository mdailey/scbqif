class CreateTransactions < ActiveRecord::Migration
  def change
    create_table :transactions do |t|
      t.datetime :timestamp
      t.string :trans_type
      t.string :channel
      t.string :description
      t.string :check_no
      t.decimal :amount
      t.decimal :new_balance
      t.references :statement

      t.timestamps
    end
  end
end
