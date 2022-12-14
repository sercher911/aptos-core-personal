# frozen_string_literal: true

# Copyright (c) Aptos
# SPDX-License-Identifier: Apache-2.0

class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  layout 'settings'

  def profile; end

  def profile_update
    user_params = params.fetch(:user, {}).permit(:username, :email)
    if @user.update(user_params)
      notice = if @user.pending_reconfirmation?
                 "A verification email has been sent to #{@user.unconfirmed_email}"
               else
                 'User profile updated'
               end
      redirect_to settings_profile_path, notice:
    else
      render :profile, status: :unprocessable_entity
    end
  end

  def notifications
    @email_preferences = current_user.notification_preferences.where(delivery_method: :email).first ||
                         NotificationPreference.new(user: current_user, delivery_method: :email)
  end

  def notifications_update
    email_params = params.fetch(:notification_preference, {}).permit(:node_upgrade_notification,
                                                                     :governance_proposal_notification)

    @email_preferences = current_user.notification_preferences.where(delivery_method: :email).first ||
                         NotificationPreference.new(user: current_user, delivery_method: :email, **email_params)

    success = if @email_preferences.persisted?
                @email_preferences.update(email_params)
              else
                @email_preferences.save
              end

    if success
      redirect_to settings_notifications_path, notice: 'Notification settings updated.'
    else
      render :notifications, status: :unprocessable_entity
    end
  end

  def connections
    store_location_for(current_user, request.path)
    @authorizations = @user.authorizations.group_by(&:provider)
  end

  def connections_delete
    store_location_for(current_user, request.path)
    authorizations = @user.authorizations
    @authorizations = authorizations.group_by(&:provider)

    auth_id = params.fetch(:authorization, {}).require(:id).to_i
    authorization = authorizations.find { |auth| auth.id == auth_id }

    if authorization.nil?
      flash[:alert] = 'Connection not found'
      render :connections, status: :unprocessable_entity
    elsif authorizations.length == 1
      flash[:alert] = 'Cannot remove the last connection'
      render :connections, status: :unprocessable_entity
    elsif authorization.destroy
      redirect_to settings_connections_path, notice: 'Connection removed'
    else
      flash[:alert] = 'Unable to remove connection'
      render :connections, status: :unprocessable_entity
    end
  end

  def delete_account
    verif_num = params.fetch(:user).require(:verification_number)
    verif_text = params.fetch(:user).require(:verification_text).to_s.downcase
    expected = "delete my account #{verif_num}".downcase
    if verif_text == expected
      current_user.destroy!
      redirect_to root_path, notice: 'Account deleted'
    else
      flash[:alert] = 'Account deletion confirmation text entered incorrectly'
      render :profile, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end
end
