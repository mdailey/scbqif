require 'strip'

class Statement < ActiveRecord::Base
  include Strip

  belongs_to :account
  has_many :transactions, dependent: :destroy, autosave: true
  validates_presence_of :account

  def sync_transactions(sync_parms)
    agent = Mechanize.new
    page = nil
    session_key = sync_parms[:bank_session_key]
    count = 0
    while page.nil?
      if session_key.nil?
        page = agent.post "https://www.scbeasy.com/v1.3/eng/LOGIN.ASP", "LOGIN" => sync_parms[:sync_username], "PASSWD" => sync_parms[:sync_password]
        fields = page.forms.first.fields
        field = fields.select { |f| f.type == 'HIDDEN' and f.name == 'SESSIONEASY'}.first
        session_key = field.value
      end
      count = count + 1
      case self.account.acct_type
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

          return { error: "Could not authenticate - retry username/password?" } if page.title == "noncompleate"

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
                            "selectedItem" => self.account.index_string,
                            "sortDirection" => "",
                            "state" => "",
                            "stateName" => "",
                            "viewName" => "B2CAccountSummary"
          select = page.search('select.SelectBox[name="StatementIndex"]')
          opts = select.css("option").select do |opt|
            pat = "0*#{self.day}\/0*#{self.month}\/#{self.year}"
            /^#{pat}$/.match(opt.text)
          end
          return { error: "Statement not found" } unless opts.size == 1
          stmt_index = opts.first.attr('value')

          # Get the summary for this statement
          page = agent.post "https://ebill.scbeasy.com/scbb2c/Dispatcher",
                            "AccountIndex" => self.account.index_string,
                            "StatementIndex" => stmt_index,
                            "commandName" => 'SelectStatement',
                            "controllerName" => 'B2CController',
                            "definitionName" => '{#DefinitionName}',
                            "elementName" => '{#SectionName}',
                            "filterFieldCompare" => "",
                            "filterFieldNameHigh" => "",
                            "filterFieldNameLow" => "",
                            "formCommand" => 'CFiFORMEDIT',
                            "listProxyName" => "Empty",
                            "oldCommandName" => "defaultAction",
                            "pageChange" => "",
                            "pageSize" => "",
                            "selectedItem" => "",
                            "sortDirection" => "",
                            "state" => "",
                            "stateName" => "",
                            "viewName" => "SCBSDefinition_V6Summary"

          tables = page.search('table.TableBasic[width="743"]').select do |table|
            table.text =~ /TRANSACTION USED THIS PERIOD/ and !(table.search('tr').first.attr('style') == "height:450px")
          end
          return { error: "Statement data not found" } unless tables.size == 1
          rows = tables.first.search('tr')
          start_processing = false
          trans_date = nil
          payee = nil
          amount = nil
          trans_type = nil
          self.transactions.clear
          rows.each do |row|
            if row.text =~ /TRANSACTION USED THIS PERIOD/
              start_processing = true
              next
            end
            next unless start_processing
            cells = row.search('td')
            if cells[0].text !~ /^[0-9]*\/[0-9]*$/
              next unless payee =~ /CREDIT VOUCHER/
            end
            if payee =~ /CREDIT VOUCHER/
              payee = "#{payee} #{cells[2].text}"
              amount = "#{amount.gsub(/^-/,'').strip}"
              trans_type = 'credit'
            else
              trans_date = cells[1].text
              payee = cells[2].text
              amount = "-#{cells[4].text.gsub(/,/, '').gsub('-$','').strip}"
              trans_type = 'debit'
            end
            next if payee =~ /^CREDIT VOUCHER$/
            if payee =~ /PAYMENT RECEIVED/
              amount = amount.gsub(/^-/,'')
              trans_type = 'credit'
            end
            self.transactions << Transaction.new(
                timestamp: "#{trans_date}/#{self.year}".to_datetime,
                description: payee,
                amount: amount.to_d,
                trans_type: trans_type
            )
            payee = nil
          end
        else
          # Normal bank account
          post_params = {  "SESSIONEASY" => session_key, "Seq_No" => "", "Page_No" => "", "Select_ACCOUNT_NO" => self.account.index_string, "Select_Month" => self.index_string }
          page = agent.post "https://www.scbeasy.com/v1.4/site/en/acc/acc_bnk_pst.asp", post_params
          if page.forms and page.forms.first and page.forms.first.name == "ERROR_SCODE"
            session_key = nil
            page = nil
            next
          end
          return { error: "Could not authenticate - retry username/password?" } if page.nil?
          tables = page.search('table[border="1"]')
          rows = tables.first.search('tr')
          fields = rows[0].search('td').collect { |cell| cell.text }
          self.transactions.clear
          for row_i in 1..rows.size-2 do
            values = rows[row_i].search('td').collect { |cell| Strip::mystrip(cell.text) }
            self.transactions << Transaction.create_from_record(fields, values)
          end
          total = rows[rows.size-1].search('td').collect { |cell| cell.text }
        end
    end
    self.fetch_date = Time.now.to_date
    self.save!
    return { session_key: session_key }
  end

  def to_qif
    require 'qif'
    tempfile = Tempfile.new ['statement', '.qif']
    Qif::Writer.open(tempfile) do |qif|
      self.transactions.each do |trans|
        qif << Qif::Transaction.new(
          date: trans.timestamp.to_date,
          amount: trans.amount.to_s,
          memo: trans.description,
          payee: ""
        )
      end
    end
    tempfile
  end

  def to_ofx
    require 'builder'
    tempfile = Tempfile.new ['statement', '.ofx']
    ofx = generate_ofx2_header
    ofx << generate_ofx_body
    tempfile.write ofx
    tempfile.rewind
    tempfile
  end

  private

  def closing_balance
    transactions.sort_by(&:timestamp).last.new_balance
  end

  def closing_available
    return closing_balance
  end

  # Taken from example in "bankjob" gem

  def generate_ofx2_header
    return <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<?OFX OFXHEADER="200" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE" VERSION="200"?>
    EOF
  end

  def ofx_start_date
    "#{Date::MONTHNAMES[self.month]} 1 #{self.year}".to_time.strftime '%Y%m%d%H%M%S'
  end

  def ofx_end_date
    ("#{Date::MONTHNAMES[self.month]} 1 #{self.year}".to_time + 1.month - 1.second).strftime '%Y%m%d%H%M%S'
  end

  def generate_ofx_body
    buf = ""
    x = ::Builder::XmlMarkup.new(target: buf, indent: 2)
    x.OFX do
      # Bank Message Response
      x.BANKMSGSRSV1 do
        # Statement-transaction aggregate response
        x.STMTTRNRS do
          # Statement response
          x.STMTRS do
            # Currency
            x.CURDEF 'THB'
            x.BANKACCTFROM do
              # Bank identifier
              x.BANKID 'SCB'
              # Account number
              x.ACCTID self.account.number
              # Account type
              x.ACCTTYPE self.account.acct_type
            end
            # Transactions
            x.BANKTRANLIST do
              x.DTSTART ofx_start_date
              x.DTEND ofx_end_date
              transactions.each do |transaction|
                buf << transaction.to_ofx
              end
            end
            # The final balance at the end of the statement
            x.LEDGERBAL do
              # Balance amount
              x.BALAMT closing_balance
              # Balance date
              x.DTASOF ofx_end_date
            end
            # Final available balance
            x.AVAILBAL do
              x.BALAMT closing_available
              x.DTASOF ofx_end_date
            end
          end
        end
      end
    end
    return buf
  end

end
