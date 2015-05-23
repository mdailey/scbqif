class AddSyncDateToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :sync_date, :date
  end
end
