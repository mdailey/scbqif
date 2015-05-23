class AddMonthYearToStatements < ActiveRecord::Migration

  def change
    remove_column :statements, :issue_date, :date
    add_column :statements, :month, :integer
    add_column :statements, :year, :integer
    add_column :statements, :index_string, :string
  end

end
