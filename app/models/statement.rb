class Statement < ActiveRecord::Base

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
      values = rows[row_i].search('td').collect { |cell| mystrip(cell.text) }
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

  private

  def mystrip(str)
    return str unless str and str.length > 0
    while str and str.length > 0 and str[0].ord == 160
      str = str.slice(1,1000)
    end
    return str.strip
  end

end
