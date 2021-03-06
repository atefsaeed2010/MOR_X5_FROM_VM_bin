# -*- encoding : utf-8 -*-
class PhonebooksController < ApplicationController

  layout "callc"

  before_filter :access_denied, :only => [:list, :add_new, :edit, :destroy, :new, :show], :if => lambda {not current_user or not (user? or admin?) }
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :authorize
  before_filter :check_localization
  before_filter :find_phonebook, :only => [:update, :edit, :destroy, :show]
  before_filter :find_user, :only => [:add_new]
  before_filter :find_phonebooks, :only => [:index, :list]
  before_filter :check_pbx_addon, :only => [:index, :list]

  def index
    redirect_to :action => :list and return false
  end

  def list
    @page_title = _('PhoneBook')
    @page_icon = "book.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PhoneBook"

    @phonebook = Phonebook.new
  end

  # before_filter:
  #   find_user
  def add_new
    @page_title = _('PhoneBook')
    @page_icon = "book.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PhoneBook"

    @phonebook = Phonebook.new(params[:phonebook]) do |p|
      p.added = Time.now
      p.user = @user
    end

    if @phonebook.valid? and @phonebook.save
      flash[:status] = _('record_successfully_added')
      redirect_to :action => 'list'
    else
      flash_errors_for(_("Please_fill_all_fields"), @phonebook)
      find_phonebooks
      render :list
    end
  end

  # before_filter:
  #   find_phonebook
  def show
    @page_title = _('PhoneBook_details')
    @page_icon = "view.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PhoneBook"

    @is_phonebook_owner = @phonebook.user_id == current_user.id
  end

  def new
    @phonebook = Phonebook.new
  end

  # before_filter:
  #   find_phonebook
  def create
    @phonebook = Phonebook.new(params[:phonebook])
    if @phonebook.save
      redirect_to :action => 'list'
    else
      flash_errors_for(_("Record_was_not_saved"), @phonebook)
      render :new
    end
  end

  # before_filter:
  #   find_phonebook
  def edit
    @page_title = _('Edit_PhoneBook')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PhoneBook"
  end

  # before_filter:
  #   find_phonebook
  def update
    if @phonebook.update_attributes(params[:phonebook])
      flash[:status] = _('record_successfully_updated')
      redirect_to :action => 'list'
    else
      flash_errors_for(_("Record_was_not_saved"), @phonebook)
      redirect_to :action => 'edit', :id => @phonebook.id
    end
  end

  # before_filter:
  #   find_phonebook
  def destroy
    user_id = @phonebook.user_id

    @phonebook.destroy
    flash[:status] = _('record_successfully_deleted')
    redirect_to :action => 'list', :id => user_id
  end

  private

  def find_phonebook
    if params[:action] == "show" and !admin?
      @phonebook = Phonebook.where(:id => params[:id]).first
    else
      @phonebook = Phonebook.where(:id => params[:id], :user_id => current_user.id).first
    end

	unless @phonebook
	  if admin?
		  flash[:notice] = _('Record_was_not_found')
		  redirect_to :action => :list and return false
	  else
		  dont_be_so_smart
		  redirect_to :action => :root and return false
	  end
	end

  end

  def find_user
    @user = User.where(:id => session[:user_id]).first
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_phonebooks
    user_id = session[:user_id]
    @user = User.where(:id => user_id).first

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => :list and return false
    end

    @phonebooks = Phonebook.user_phonebooks(@user)

  end

  def check_pbx_addon
    if !pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    end
  end
end
