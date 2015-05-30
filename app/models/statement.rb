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
    while page.nil?
      if session_key.nil?
        page = agent.post "https://www.scbeasy.com/v1.3/eng/LOGIN.ASP", "LOGIN" => sync_parms[:sync_username], "PASSWD" => sync_parms[:sync_password]
        fields = page.forms.first.fields
        field = fields.select { |f| f.type == 'HIDDEN' and f.name == 'SESSIONEASY'}.first
        session_key = field.value
      end
      post_params = {  "SESSIONEASY" => session_key, "Seq_No" => "", "Page_No" => "", "Select_ACCOUNT_NO" => self.account.index_string, "Select_Month" => self.index_string }
      page = agent.post "https://www.scbeasy.com/v1.4/site/en/acc/acc_bnk_pst.asp", post_params
      if page.forms and page.forms.first and page.forms.first.name == "ERROR_SCODE"
        session_key = nil
        page = nil
      end
    end
    tables = page.search('table[border="1"]')
    rows = tables.first.search('tr')
    fields = rows[0].search('td').collect { |cell| cell.text }
    self.transactions.clear
    for row_i in 1..rows.size-2 do
      values = rows[row_i].search('td').collect { |cell| Strip::mystrip(cell.text) }
      self.transactions << Transaction.create_from_record(fields, values)
    end
    total = rows[rows.size-1].search('td').collect { |cell| cell.text }
    self.fetch_date = Time.now.to_date
    self.save!
    return session_key
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
