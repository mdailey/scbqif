module StatementsHelper

  def fetch_date_td_tag(statement)
    alert_class = nil
    if statement.fetch_date.nil?
      alert_class = "alert"
    else
      stmt_date = "#{Date::MONTHNAMES[statement.month]} #{statement.year}"
      last_day_of_stmt = stmt_date.to_date + 1.month - 1.day
      if statement.fetch_date <= last_day_of_stmt
        alert_class = "alert"
      end
    end
    td_string = alert_class ? "<td class=\"#{alert_class}\">" : "<td>"
    td_string = td_string + (statement.fetch_date ? statement.fetch_date.to_s : 'Never') + "</td>"
  end

end
