class Account < ActiveRecord::Base

  belongs_to :user
  has_many :statements, dependent: :destroy, autosave: true

  validates_presence_of :user
  validates_presence_of :acct_type, :number, :index_string
  validates_uniqueness_of :number, scope: [:user, :acct_type]

  def sync_statements(sync_parms, session_key)
    agent = Mechanize.new
    page = nil
    count = 0
    while page.nil?
      if session_key.nil?
        page = agent.post "https://www.scbeasy.com/v1.3/eng/LOGIN.ASP", "LOGIN" => sync_parms[:sync_username], "PASSWD" => sync_parms[:sync_password]
        fields = page.forms.first.fields
        field = fields.select { |f| f.type == 'HIDDEN' and f.name == 'SESSIONEASY'}.first
        session_key = field.value
      end

      count = count + 1
      case self.acct_type
        when 'Credit Card'
          # Sign on to e-billing TODO: this takes a few seconds, would be good to give some feedback to user
          page = nil
          begin
            page = agent.post "https://www.scbeasy.com/v1.4/site/Library/epp_signon.asp",
                              "CARD" => self.index_string,
                              "SESSIONEASY" => session_key,
                              "LANG" => "E",
                              "COMMAND" => "ebill"
          rescue SocketError
            return { error: 'Could not connect to bank server' }
          end
          pp page
          if page.body =~ /Sorry, you cannot do this transaction at the moment./ and count <= 2
            session_key = nil
            page = nil
            next
          end
          if page.forms and page.forms.first and page.forms.first.name == "ERROR_SCODE" and count <= 2
            session_key = nil
            page = nil
            next
          end
          # Initialize account summary controller session
          page = agent.post "https://ebill.scbeasy.com/scbb2c/Dispatcher?controllerName=AccountSummaryController&commandName=Initial",
                            "Mask" => "1",
                            "SESSIONEASY" => session_key
          # Get the summary for default statement
          page = agent.post "https://ebill.scbeasy.com/scbb2c/Dispatcher",
                            "commandName" => 'ViewBill',
                            "controllerName" => "AccountSummaryController",
                            "definitionName" => "B2CAccountSummaryPage",
                            "elementName" => 'B2CAccountSummary/MainContent/MainContentCell/BillSummary/AccountCell/Account',
                            "filterFieldCompare" => "",
                            "filterFieldNameLow" => "",
                            "filterFieldNameHigh" => "",
                            "formCommand" => "",
                            "listProxyName" => "Empty",
                            "oldCommandName" => "defaultAction",
                            "pageChange" => "",
                            "pageSize" => "",
                            "selectedItem" => self.index_string,
                            "sortDirection" => "",
                            "state" => "",
                            "stateName" => "",
                            "viewName" => "B2CAccountSummary"
          select = page.search('select.SelectBox[name="StatementIndex"]')
          stmts = []
          select.css("option").each do |opt|
            next unless matches = /^([0-9]+)\/([0-9]+)\/([0-9]+)$/.match(opt.text)
            day = matches[1].to_i
            month = matches[2].to_i
            year = matches[3].to_i
            stmts.push({ month: month, year: year, date: opt.text, value: opt.attr('value') })
            statement = self.statements.find_by_day_and_month_and_year day, month, year
            if statement
              statement.update index_string: opt.attr('value')
            else
              statement = self.statements.create day: day, month: month, year: year, index_string: opt.attr('value')
            end
          end

        else
          # Normal bank accounts
          page = agent.post "https://www.scbeasy.com/v1.4/site/en/acc/acc_bnk_pst.asp",
                            "SESSIONEASY" => session_key, "SELACC_SHOW" => self.index_string
          if page.forms and page.forms.first and page.forms.first.name == "ERROR_SCODE" and count <= 2
            session_key = nil
            page = nil
            next
          end
          return unless page
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
