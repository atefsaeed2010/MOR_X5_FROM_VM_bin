# -*- encoding : utf-8 -*-
#require 'pdf/wrapper'

class CcpanelController < ApplicationController

  #before_filter :cdr2calls, :check_localization
  before_filter :check_localization
  before_filter :check_calingcards_enabled
  before_filter :check_authentication, :only => [:card_details, :rates, :call_list, :speeddials, :speeddial_add_new, :speeddial_edit, :speeddial_update, :speeddial_destroy]
  before_filter :find_card, :only => [:card_details, :rates]
  before_filter :find_tariff, :only => [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_csv, :generate_personal_wholesale_rates_pdf]
  before_filter :check_paypal, :only => [:display_cart, :checkout, :empty_cart, :remove_from_cart]

  def index
    redirect_to action: 'list'
  end

  def list
    @page_title = _('Calling_Card_Panel')
    join_sql = "LEFT JOIN (SELECT cardgroup_id, count(*) AS 'not_sold_count' FROM cards where sold = 0 GROUP BY cardgroup_id) AS not_sold ON cardgroups.id = not_sold.cardgroup_id"
    session[:ccpanel_display_paypal] = Confline.get_value('Paypal_Enabled', 0)
    if session[:ccpanel_display_paypal].to_i == 1
      @cardgroups = Cardgroup.includes(:tax).joins(join_sql).where('owner_id = 0 AND not_sold_count > 0').order('name ASC').all
    end
    session[:default_currency] = Currency.find(1).name
  end

  def try_to_login
    if session[:cclogin] == true
      redirect_to controller: 'ccpanel', action: 'index' and return false
    end

    if cc_single_login_active?
      card = Card.includes(:cardgroup).where(['CONCAT(cards.number, cards.pin) = ?', params['login']]).first
    else
      card = Card.includes(:cardgroup).where(['cards.number = ? AND cards.pin = ?', params['login_num'], params['login_pin']]).first
    end

    if card
      session[:card_id] = card.id
      session[:card_number] = card.number
      session[:nice_number_digits] = Confline.get_value('Nice_Number_Digits', 0).to_i
      session[:cclogin] = true
      session[:items_per_page] = Confline.get_value('Items_Per_Page', 0).to_i
      session[:default_currency] = Currency.find(1).name
      session[:show_currency] = session[:default_currency]
      flash[:status] = _('login_successfully')
      redirect_to controller: 'ccpanel', action: 'card_details' and return false
    else
      flash[:notice] = _('bad_cc_login')
      redirect_to controller: 'ccpanel', action: 'index' and return false
    end
  end

  def logout
    session[:cclogin] = false
    session[:card_id] = nil
    session[:card_number] = nil
    flash[:status] = _('logged_off')
    redirect_to controller: 'ccpanel', action: 'index' and return false
  end

  ############# MENU ####################

  def card_details
    @page_title = _('Card')
    @cg = @card.cardgroup
  end

  def call_list
    @page_title = _('Calls')
    @card = Card.includes(:cardgroup, :calls).where(['cards.id = ?', session[:card_id]]).first
    @calls = @card.calls
    @cg = @card.cardgroup
    @total_billsec = 0
    @total_price = 0
    for call in @calls do
      @total_billsec += call.billsec.to_i
      @total_price += call.user_price.to_d
    end
    @total_price_with_vat = @total_price + @cg.get_tax.count_tax_amount(@total_price)
  end

  ############# CART ####################

  def add_to_cart
    cg = Cardgroup.includes(:tax).where(['cardgroups.id = ? AND cardgroups.owner_id = 0', params[:id]]).first
    @cart = find_cart
    params_cards = params[:cards]
    params_cards ? amount = params_cards[:amount].to_i : amount = 0
    success = true
    if amount > 0
      [1..amount].each do
        success = @cart.add_product(cg)
      end
    end
    if success
      status = _('Card_added')
    else
      status = _('One_Or_More_Cards_Were_Not_Added')
    end
    flash[:status] = status + ': ' + cg.name
    redirect_to(action: 'display_cart')
  end

  def display_cart
    @page_title = _('Shopping_cart')
    @page_icon = 'cart.png'
    @cart = find_cart
    @items = @cart.items
    #my_debug "@cart.items.size: " + @cart.items.size.to_s
    if @items.empty?
      redirect_to_index(_('Your_cart_is_currently_empty'))
    end

    if params[:context] == :checkout
      render(layout: false)
    end
  end

  def empty_cart
    find_cart.empty!
    flash[:status] = _('Your_cart_is_now_empty')
    redirect_to(action: 'index')
  end

  def remove_from_cart
    @cart = find_cart
    @cart.remove_item(params[:cg_id])
    flash[:notice] = _('Item_removed_from_cart')
    redirect_to(action: 'display_cart')
  end

  ######################## CHECKOUT ####################################
  def checkout
    @page_title = _('Checkout')
    @page_icon = 'cart_edit.png'
    url = session[:url] + Web_Dir
    @paypal_return_url = url  + '/ccpanel/paypal_complete'
    @paypal_cancel_url = url + '/ccpanel/display_cart'
    @paypal_ipn_url = url + '/ccpanel/paypal_ipn'
    @paypal_currency = Confline.get_value('Paypal_Default_Currency')

    #	@hanza_ipn_url = "https://lt.hanza.net/cgi-bin/lip/pangalink.jsp"
    #	@hanza_return_url = "http://mor.upnet.lt/store/hanza_ipn"

    @paypal_test = Confline.get_value('PayPal_Test').to_s.to_i

    cart_items = @cart.items
    @cart = find_cart
    @items = cart_items
    if @items.empty?
      redirect_to_index(_('Theres_nothing_in_your_cart'))
    else
      Ccorder.clean_orders
      @order = Ccorder.create_by(params)
      @order.save
      # begin
      cclineitems = cart_items
      cardgroups = {}
      cclineitems.each do |cclineitem|
        cardgroups[cclineitem.cardgroup_id] ? cardgroups[cclineitem.cardgroup_id] += 1 : cardgroups[cclineitem.cardgroup_id] = 1
      end
      cardgroups.each do
          |id, count| Cclineitem.new(ccorder_id: @order.id, cardgroup_id: id, quantity: count, price: Cardgroup.where(['id = ?', id]).first.price).save
      end
      # end
    end
    @total_amount = @cart.total_price * Currency::count_exchange_rate(session[:default_currency], @paypal_currency)
  end

  def paypal_ipn
    if Confline.get_value('PayPal_Enabled', 0).to_i == 0
      dont_be_so_smart
      redirect_to :root and return false
    end

    my_debug('paypal_ipn accessed')
    notify = Paypal::Notification.new(request.raw_post)
    debug_message = []
    # if notify.acknowledge
    paypal_email = Confline.get_value('PayPal_Email', 0).to_s
    if paypal_email == notify.business
      debug_message << 'business email is valid'
      debug_message << 'notify acknowledged'
      if @order = Ccorder.where(['id = ?', notify.item_id]).first
        debug_message << 'found order'
        @order.update_by_notification(notify)

        # my_debug(@order.shipped_at)

        @order.save

        debug_message << 'transaction succesfully completed'
      else
        debug_message << 'transaction NOT completed'
      end
    else
      debug_message << 'Hack attempt: Email is not equal as paypal account email'
    end
    debug_message.each { |message| MorLog.my_debug(message) }
    #    else
    #      MorLog.my_debug('notify NOT acknowledged')
    #    end
    render nothing: true
  end

  def paypal_complete
    @page_title = _('Payment_status')
    @page_icon = 'money.png'

    session[:tx] = params[:tx] || params[:txn_id]
  end

  def tx_status
    @sold_cards = []
    @tx = session[:tx]
    @cart = find_cart
    items = @cart.items
    if @order = Ccorder.where(['transaction_id = ?', @tx]).first
      @status = 1
      if @order.completed == 0
        # providing with items which are sold
        for item in items
          cg = item.cardgroup
          if cg
            # id = cg.id

            # new card to sell
            @card = cg.groups_salable_card
            if @card
              item.card_id = @card.id # saving additional field to recognize card later
              @sold_cards << @card
              @card.sold = 1
              @card.save
            end
          end
        end

        my_debug '@cart.items.size: ' + items.size.to_s

        @order.completed = 1
        @order.cclineitems << items
        @order.save

        EmailsController::send_to_users_paypal_email(@order)

        @cart.empty!
      else
        # showing card data from db
        for item in @order.cclineitems
          card = Card.where(id: item.card_id).first
          @sold_cards << card if card
        end
      end

    else
      @status = 0
    end

    render(layout: false)
  end

  # before_filter
  #   find_card
  def rates
    @page_title = _('Rates')
    @page_icon = 'coins.png'
    @cardgroup = @card.cardgroup
    @tariff = @cardgroup.tariff
    tariff_id = @tariff.id
    tariff_currency = @tariff.currency
    items_per_page = session[:items_per_page]
    show_currency = session[:show_currency]
    @page = 1
    @page = params[:page].to_i if params[:page]

    @st = 'A'
    @st = params[:st].upcase if params[:st]

    @show_currency_selector = true
    @dgroups = ( @dgroups ||= Destinationgroup.where('name like ?', "#{@st}%").order('name ASC, desttype ASC').all)

    @rates = @tariff.rates_by_st(@st, 10000, '')
    @total_pages = (@rates.length.to_f / items_per_page.to_f).ceil
    @all_rates = @rates
    all_rates_size = @all_rates.size - 1
    @rates = []
    @rates_cur2 = []
    @rates_free2 = []
    @rates_d = []
    iend = ((items_per_page * @page) - 1)
    iend = all_rates_size if iend > all_rates_size
    for index in ((@page - 1) * items_per_page)..iend
      @rates << @all_rates[index]
    end
    #----

    sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{tariff_id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code AND directions.name like '#{@st}%' ORDER by directions.name ASC;"
    rates = Rate.find_by_sql(sql)

    exrate = Currency.count_exchange_rate(tariff_currency, show_currency)
    ratedetails = Ratedetail.where("rate_id in (SELECT rates.id FROM rates, destinations, directions WHERE rates.tariff_id = #{tariff_id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code AND directions.name like '#{@st}%')").order('rate DESC').all

    for rate in rates
      rate_d = ratedetails.select { |ratedetail| ratedetail.rate_id.to_i == rate.id.to_i }
      get_provider_rate_details(rate_d, exrate)
      @rates_cur2[rate.id] = @rate_cur
      @rates_free2[rate.id] = @rate_free
      @rates_d[rate.id] = @rate_increment_s
    end

    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id

    @show_values_without_vat = confline('CCShop_show_values_without_VAT_for_user').to_i
    @exchange_rate = count_exchange_rate(tariff_currency, show_currency)
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], show_currency)
  end

  def get_provider_rate_details(rate_d, exrate)
    @rate_details = rate_d

    if @rate_details.size > 0
      @rate_increment_s = @rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices( exrate: exrate, prices: [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d])
    end
    @rate_details
  end

  # ====================== Speed dials =============================

  def speeddials
    @page_title = _('Speed_Dials')
    @page_icon = 'book.png'
    card_id = session[:card_id]
    @card = Card.where(id: card_id).first
    @sp = Phonebook.where(card_id: card_id).all
  end

  def speeddial_add_new
    card = Card.where(id:  session[:card_id]).first
    number = params[:number] unless params[:number].blank?
    name = params[:name] unless params[:name].blank?
    speeddial = params[:speeddial] unless params[:speeddial].blank?

    ph = Phonebook.new(name: name, number: number, added: Time.now, speeddial: speeddial, user_id: 0, card_id: card.id)
    ph.save ? flash[:status] = _('speeddial_successfully_created') : flash_errors_for(_('Speeddial_not_created'), ph)

    redirect_to action: 'speeddials'
  end

  def speeddial_edit
    @page_title = _('Edit_Speed_Dial')
    @page_icon = 'edit.png'

    @phonebook = Phonebook.where(id: params[:id], card_id: session[:card_id]).first
    unless @phonebook
      dont_be_so_smart
      redirect_to action: 'speeddials' and return false
    end
  end

  def speeddial_update
    @phonebook = Phonebook.where(id: params[:id], card_id: session[:card_id]).first
    params_phonebook = params[:phonebook]
    unless @phonebook
      dont_be_so_smart
      redirect_to action: 'speeddials' and return false
    end
    if params_phonebook[:speeddial].length < 2
      flash[:notice] = _('Speeddial_can_only_be_2_and_more_digits')
      redirect_to action: 'speeddials' and return false
    end
    if @phonebook.update_attributes(params_phonebook)
      flash[:status] = _('Updated')
      redirect_to action: 'speeddials'
    else
      redirect_to action: 'speeddial_edit', id: @phonebook.id
    end
  end

  def speeddial_destroy
    ph = Phonebook.where(id: params[:id], card_id: session[:card_id]).first
    unless ph
      dont_be_so_smart
      redirect_to action: 'speeddials' and return false
    end
    ph.destroy
    flash[:status] = _('Deleted')
    redirect_to action: 'speeddials'
  end

  def generate_personal_rates_pdf
    show_currency = session[:show_currency]
    rates = Rate.joins('LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)').where(['rates.tariff_id = ?', @tariff.id]).order('destinationgroups.name, destinationgroups.desttype ASC').all
    options = {
        name: @tariff.name,
        pdf_name: _('Users_rates'),
        currency: show_currency
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_user_rates_pdf(pdf, rates, @tariff, options)
    file = pdf.render
    filename = "Rates-#{show_currency}.pdf"
    testable_file_send(file, filename, 'application/pdf')
  end

  def generate_personal_rates_csv
    filename = "Rates-#{session[:show_currency]}.csv"
    if testing?
      render text: @tariff.generate_user_rates_csv(session)
    else
      send_data(@tariff.generate_user_rates_csv(session), type: 'text/csv; charset=utf-8; header=present', filename: filename)
    end
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_csv
    if testing?
      render text: @tariff.generate_personal_wholesale_rates_csv(session)
    else
      filename = "Rates-#{(session[:show_currency]).to_s}.csv"
      send_data(@tariff.generate_personal_wholesale_rates_csv(session), type: 'text/csv; charset=utf-8; header=present', filename: filename)
    end
  end

  # before_filter : tariff
  def generate_personal_wholesale_rates_pdf
    show_currency = session[:show_currency]
    sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{@tariff.id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name ASC;"
    rates = Rate.find_by_sql(sql)
    options = {
        # font size
        fontsize: 6,
        title_fontsize1: 16,
        title_fontsize2: 10,
        header_size_add: 1,
        page_number_size: 8,
        # positions
        first_page_pos: 150,
        second_page_pos: 70,
        page_num_pos: 780,
        header_eleveation: 20,
        step_size: 15,
        title_pos1: 50,
        title_pos2: 70,

        first_page_items: 40,
        second_page_items: 45,

        # col possitions
        col1_x: 30,
        col2_x: 205,
        col3_x: 250,
        col4_x: 310,
        col5_x: 350,
        col6_x: 420,
        col7_x: 470,

        currency: show_currency
    }
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(rates, @tariff, nil, options)
    send_data pdf.render, filename: "Rates-#{(show_currency).to_s}.pdf", type: 'application/pdf'
  end

  # ====================== Private =============================

  private

  def find_cart
    session[:cart] ||= Cart.new
  end

  def redirect_to_index(msg = nil)
    flash[:notice] = msg if msg
    redirect_to(action: 'index')
  end

  def find_card
    @card = Card.includes([:cardgroup]).where(['cards.id = ?', session[:card_id]]).first

    unless @card && @card.cardgroup
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to controller: 'ccpanel', action: 'index' and return false
    end
  end

  def check_authentication
    card_id = session[:card_id]
    if !card_id || card_id.size == 0
      flash[:notice] = _('Must_login_first')
      redirect_to action: 'list' and return false
    end
  end

  def find_tariff
    @tariff = Tariff.where(id: params[:id]).first

    unless @tariff
      flash[:notice] = _('Tariff_was_not_found')
      redirect_to action: 'index' and return false
    end

    unless @tariff.real_currency
      flash[:notice] =_('Tariff_currency_not_found')
      redirect_to action: 'index' and return false
    end
  end

  def testing?
    params[:test]
  end

  def check_paypal
    if Confline.get_value('Paypal_Enabled', 0).to_i == 0
      dont_be_so_smart
      redirect_to action: 'index' and return false
    end
  end

  def check_calingcards_enabled
    unless cc_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to controller: 'callc', action: 'login' and return false
    end
  end
end
