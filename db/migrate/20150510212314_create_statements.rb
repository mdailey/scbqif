class CreateStatements < ActiveRecord::Migration
  def change
    create_table :statements do |t|
      t.date :issue_date
      t.date :fetch_date
      t.references :account, index: true

      t.timestamps
    end
  end
end
