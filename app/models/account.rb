class Account < ActiveRecord::Base

  belongs_to :user
  has_many :statements, dependent: :destroy, autosave: true

  validates_presence_of :user
  validates_presence_of :acct_type, :number, :index_string
  validates_uniqueness_of :number, scope: [:user, :acct_type]

  def sync_statements(sync_parms, session_key)
    agent = Mechanize.new
    page = nil
    while page.nil?
      if session_key.nil?
        page = agent.post "https://www.scbeasy.com/v1.3/eng/LOGIN.ASP", "LOGIN" => sync_parms[:sync_username], "PASSWD" => sync_parms[:sync_password]
        fields = page.forms.first.fields
        field = fields.select { |f| f.type == 'HIDDEN' and f.name == 'SESSIONEASY'}.first
        session_key = field.value
      end
      page = agent.post "https://www.scbeasy.com/v1.4/site/en/acc/acc_bnk_pst.asp", "SESSIONEASY" => session_key, "SELACC_SHOW" => self.index_string
      if page.forms and page.forms.first and page.forms.first.name == "ERROR_SCODE"
        session_key = nil
        page = nil
      end
    end
    select = page.search('select#Select_Month')
    stmts = []
    select.css("option").each do |opt|
      next unless matches = /^([A-Za-z]+) ([0-9]+)$/.match(opt.text)
      month = Date::MONTHNAMES.index matches[1]
      year = matches[2].to_i
      stmts.push({ month: month, year: year, date: opt.text, value: opt.attr('value') })
      statement = self.statements.find_by_month_and_year month.to_i, year.to_i
      if statement
        statement.update index_string: opt.attr('value')
      else
        statement = self.statements.create month: month, year: year, index_string: opt.attr('value')
      end
    end
    self.sync_date = Date.today
    self.save
    return session_key
  end

  def merge_account(account)
    matching_account = self.accounts.find_by_acct_type_and_number(account[:acct_type], account[:number])
    if matching_account.nil?
      self.accounts.push Account.new(account)
    else
      matching_account.update account
    end
  end


end
