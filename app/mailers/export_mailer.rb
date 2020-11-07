class ExportMailer < ActionMailer::Base
  default from: "anders+support@proleads.io", 'Content-Transfer-Encoding' => 'base64'
  layout 'mailer'

  def url_export(file)
    attachments["urls.csv"] = { :data => file, :type => "text/csv; charset=utf-8; header=present" }
    mail(to: "anders@proleads.io",
         subject: "Rescue csv export")
  end

  private

  def recipient(email_address)
    return 'anders@proleads.io' if Rails.env.development?

    email_address
  end
end
