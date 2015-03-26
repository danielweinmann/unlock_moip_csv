require 'date'
require 'moip-assinaturas'
require 'httparty'

Moip::Assinaturas.config do |config|
  config.sandbox    = false
  config.token      = ENV['MOIP_TOKEN']
  config.key        = ENV['MOIP_KEY']
  config.http_debug = false
end

lines = [[
  'Subscription initiative',
  'Subscription code',
  'Subscription plan',
  'Subscription status',
  'Subscription customer',
  'Invoice id',
  'Invoice creation',
  'Invoice amount',
  'Invoice status code',
  'Invoice status description',
  'Invoice occurrence',
  'Payment id',
  'Payment moip_id',
  'Payment creation',
  'Payment status code',
  'Payment status description'
]]

subscriptions = Moip::Assinaturas::Subscription.list[:subscriptions]
subscriptions.each do |subscription|
  subscription_code = subscription['code']
  puts "Subscription #{subscription_code}..."
  invoices = Moip::Assinaturas::Invoice.list(subscription_code)[:invoices]
  invoices.each do |invoice|
    invoice_id = invoice['id']
    puts "  Invoice #{invoice_id}..."
    amount = invoice['amount'] / 100
    plan = subscription['plan']['code']
    initiative = plan[0..plan.length - amount.to_s.length - 1]
    payments = Moip::Assinaturas::Payment.list(invoice_id)[:payments]
    payments.each do |payment|
      payment_id = payment['id']
      moip_id = payment['moip_id']
      puts "    Payment #{payment_id}..."
      params = {
        body: {
          j_targetUrl: "/AdmReports.do?method=new_payments&ignore_full_text=false&hascomission=true&text=#{moip_id}&filterType=0&dbegin=#{(Date.today - 180).strftime('%d/%m/%Y')}&dend=#{Date.today.strftime('%d/%m/%Y')}&paytype=0&status=0&transtype=0",
          j_authenticationFailureUrl: '/AdmReports.do?method=new_payments',
          should_redirect: 'false',
          j_accessDisabledUrl: '/RegainLogin.do?method=accessdisabled',
          j_emailNotVerifiedUrl: '/RegainLogin.do?method=emailnotverified',
          j_username: ENV['MOIP_USERNAME'],
          j_password: ENV['MOIP_PASSWORD']
        }
      }
      response = HTTParty.post('https://www.moip.com.br/j_acegi_security_check', params)
      File.open(File.expand_path("../response.html", __FILE__), 'w') { |file| file.write(response.body) }
      abort

      # TODO get Moip's fee

      lines << [
        initiative,
        subscription_code,
        plan,
        subscription['status'],
        subscription['customer']['fullname'],
        invoice_id,
        "#{invoice['creation_date']['year']}/#{invoice['creation_date']['month']}/#{invoice['creation_date']['day']} #{invoice['creation_date']['hour']}:#{invoice['creation_date']['minute']}:#{invoice['creation_date']['second']}",
        amount,
        invoice['status']['code'],
        invoice['status']['description'],
        invoice['occurrence'],
        payment_id,
        moip_id,
        "#{payment['creation_date']['year']}/#{payment['creation_date']['month']}/#{payment['creation_date']['day']} #{payment['creation_date']['hour']}:#{payment['creation_date']['minute']}:#{payment['creation_date']['second']}",
        payment['status']['code'],
        payment['status']['description']
      ]
    end
  end
  break
end

# puts "Writing CSV..."
# CSV.open(File.expand_path("../#{Time.now.strftime('%Y-%m-%d %H%M%S')}_unlock_moip.csv", __FILE__), "wb") do |csv|
#   lines.each do |line|
#     csv << line
#   end
# end
# puts "...done!"
