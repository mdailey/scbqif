json.array!(@users) do |user|
  json.extract! user, :id, :name, :email, :password, :is_issuer, :is_admin
  json.url user_url(user, format: :json)
end
