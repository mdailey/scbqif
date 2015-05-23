class User < ActiveRecord::Base

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :accounts, dependent: :destroy, autosave: true

  def sync_accounts(sync_parms)
    agent = Mechanize.new
    page = agent.post "https://www.scbeasy.com/v1.3/eng/LOGIN.ASP", "LOGIN" => sync_parms[:sync_username], "PASSWD" => sync_parms[:sync_password]
    fields = page.forms.first.fields
    field = fields.select { |f| f.type == 'HIDDEN' and f.name == 'SESSIONEASY'}.first
    session_key = field.value
    page = agent.post "https://www.scbeasy.com/v1.4/site/en/acc/acc_mpg.asp", "SESSIONEASY" => session_key
    trs = page.search('tr').select do |tr|
      if !tr.search('td').select { |td| td.text =~ /^\s*Savings\s*$/ and td.parent == tr }.empty?
        acct_td = tr.search('td').select { |td| td.text =~ /XXX/ }.first
        acct_onclick = tr.search('a').first.attr('onclick')
        index_string = /AccBal\(\'(.*)\'\)/.match(acct_onclick)[1]
        account = { acct_type: 'Savings', number: acct_td.text.strip, index_string: index_string }
        self.merge_account account
      end
      if !tr.search('td').select { |td| td.text =~ /^\s*Credit Card\s*$/ and td.parent == tr }.empty?
        acct_td = tr.search('td').select { |td| td.text =~ /XXX/ }.first
        acct_onclick = tr.search('a').first.attr('onclick')
        index_string = /CreditBal\((.*)\)/.match(acct_onclick)[1]
        account = { acct_type: 'Credit Card', number: acct_td.text, index_string: index_string }
        self.merge_account account
      end
    end
    self.sync_date = Date.today
    self.save
    return session_key, self.accounts
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
