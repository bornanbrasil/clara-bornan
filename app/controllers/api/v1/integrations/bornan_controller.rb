class Api::V1::Integrations::BornanController < Api::BaseController
  # Se sua base tiver outro filtro (ex.: authenticate_user!), ele já vem do Api::BaseController
  require 'faraday'
  require 'json'

  def create
    account = find_account!
    user    = current_user || (defined?(Current) ? Current.user : nil)
    raise ActiveRecord::RecordNotFound, 'account not found' unless account
    raise StandardError, 'unauthorized' unless user

    chatwoot_token = ensure_personal_access_token!(user)
    # frontend_url   = ENV.fetch('FRONTEND_URL', request.base_url)
    frontend_url   = 'https://chat.bornan.com.br'

    defaults = {
      rejectCall: false,
      groupsIgnore: false,
      alwaysOnline: false,
      readMessages: false,
      readStatus: false,
      syncFullHistory: true,
      chatwootAccountId: account.id.to_s,
      chatwootToken: chatwoot_token.to_s,
      chatwootUrl: frontend_url,
      chatwootSignMsg: false,
      chatwootReopenConversation: false,
      chatwootConversationPending: false,
      chatwootImportContacts: true,
      chatwootMergeBrazilContacts: true,
      chatwootImportMessages: true,
      chatwootDaysLimitImportMessages: 60,
      chatwootAutoCreate: true,
      chatwootOrganization: 'BornanChat',
      chatwootLogo: 'https://chat.bornan.com.br/brand-assets/logo_thumbnail.svg'
    }

    pld  = params.require(:payload).permit!
    mode = pld[:mode].to_s

    base = defaults.merge(
      chatwootNameInbox: pld[:chatwootNameInbox].to_s,
      instanceName: pld[:instanceName].to_s
    )

    body =
      case mode
      when 'qrcode'
        base.merge(qrcode: true, integration: 'WHATSAPP-BAILEYS')
      when 'business'
        base.merge(
          qrcode: false,
          integration: 'WHATSAPP-BUSINESS',
          token: pld[:token].to_s,
          number: pld[:number].to_s,
          businessId: pld[:businessId].to_s
        )
      else
        render json: { error: 'invalid_mode' }, status: :unprocessable_entity and return
      end

    Rails.logger.debug { "[BornanProvision] chatwootToken.class=#{chatwoot_token.class} value_preview=#{chatwoot_token.to_s[0, 6]}..." }

    Rails.logger.debug { "[BornanProvision] body=#{body.to_json}" }

    resp = Faraday.post("#{ENV.fetch('EVOLUTION_API_URL', nil)}/instance/create") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['apikey'] = ENV.fetch('EVOLUTION_API_KEY_GLOBAL', nil)
      req.body = body.to_json
      req.options.open_timeout = 5
      req.options.timeout = 20
    end
    Rails.logger.debug { "[BornanProvision] status=#{resp.status} body=#{resp.body}" }

    unless resp.success?
      Rails.logger.error("[BornanProvision] status=#{resp.status} body=#{resp.body}")
      render json: { error: 'provision_failed', status: resp.status, detail: resp.body }, status: :bad_gateway and return
    end

    parsed = begin
      JSON.parse(resp.body)
    rescue StandardError
      {}
    end
    render json: {
      ok: true,
      external_instance_id: parsed['id'] || parsed['instanceId'] || body[:instanceName]
    }
  end

  private

  # Tenta encontrar a conta pelo parâmetro recebido do front;
  # se não vier, utiliza o contexto atual do usuário.
  def find_account!
    if params[:account_id].present?
      Account.find_by(id: params[:account_id])
    elsif defined?(Current) && Current.account
      Current.account
    elsif current_user && current_user.respond_to?(:accounts)
      current_user.accounts.first
    end
  end

  def ensure_personal_access_token!(user)
    if defined?(AccessToken)
      rec = AccessToken.find_by(owner: user)
      return rec.token.to_s if rec&.token.present?

      new_token = SecureRandom.hex(24)
      AccessToken.create!(owner: user, token: new_token)
      return new_token.to_s
    end

    return user.access_token.to_s if user.respond_to?(:access_token) && user.access_token.present?

    new_token = SecureRandom.hex(24)
    user.update!(access_token: new_token) if user.respond_to?(:access_token=)
    new_token.to_s
  end
end
