class AddDayToStatements < ActiveRecord::Migration
  def change
    add_column :statements, :day, :integer
  end
end
