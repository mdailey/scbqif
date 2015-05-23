class CreateAccounts < ActiveRecord::Migration
  def change
    create_table :accounts do |t|
      t.string :type
      t.string :number
      t.string :index_string

      t.timestamps
    end
  end
end
