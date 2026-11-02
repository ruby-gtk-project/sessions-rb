# frozen_string_literal: true

require 'securerandom'

require 'gio2'

# BackgroundPortal talks to org.freedesktop.portal.Background, the two calls
# upstream makes through github.com/rymdport/portal/background from
# internal/components/main_window.go.
#
# RequestBackground asks the session for permission to keep running once the
# window is closed; SetStatus is the line of text shown next to the app in the
# system's background-apps list ("Timer Running", "Session Finished"), cleared
# by setting it to an empty string.
#
# RequestBackground follows the portal's request pattern: the call returns the
# object path of a Request object, and the real answer arrives later as a
# Response signal on that path. The handle token is chosen up front so the
# signal subscription can be in place before the call goes out, which is what
# the portal documentation asks for — otherwise a fast portal can answer before
# anyone is listening. The answer is delivered to a block rather than waited
# for, so the main loop keeps running while the permission dialog is up.
#
# Every call is guarded: outside a session with a portal (a plain X11 or
# Wayland session with no xdg-desktop-portal running) the calls fail, and
# upstream treats that the same way it treats a denial — log it and carry on
# running in the foreground.
#
class BackgroundPortal
  BUS_NAME = 'org.freedesktop.portal.Desktop'
  OBJECT_PATH = '/org/freedesktop/portal/desktop'
  BACKGROUND_INTERFACE = 'org.freedesktop.portal.Background'
  REQUEST_INTERFACE = 'org.freedesktop.portal.Request'
  REQUEST_PATH_PREFIX = '/org/freedesktop/portal/desktop/request'

  # The portal's response codes: 0 success, 1 cancelled by the user, 2 ended
  # some other way.
  RESPONSE_SUCCESS = 0

  TIMEOUT = 60_000

  def initialize
    @subscriptions = {}
  end

  # Asks for permission to run in the background, yielding true or false once
  # the portal has answered. A portal that cannot be reached yields false.
  def request(reason:, &on_answer)
    connection.then do |bus|
      if bus.nil?
        on_answer.call(false)
      else
        request_background(bus, reason, on_answer)
      end
    end
  end

  # Sets the status text shown in the background-apps list; an empty message
  # clears it.
  def status=(message)
    connection.then do |bus|
      unless bus.nil?
        call(
          bus,
          'SetStatus',
          "({'message': <#{quote(message)}>},)",
          '(a{sv})',
        )
      end
    end
  end

  private

    def request_background(bus, reason, on_answer)
      SecureRandom.hex(8).then do |token|
        handle = "#{REQUEST_PATH_PREFIX}/#{sender_token(bus)}/sessions_#{token}"
        subscribe(bus, handle, on_answer)

        call(
          bus,
          'RequestBackground',
          "('', {'handle_token': <#{quote("sessions_#{token}")}>, 'reason': <#{quote(reason)}>})",
          '(sa{sv})',
        ).then do |result|
          if result.nil?
            unsubscribe(bus, handle)
            on_answer.call(false)
          end
        end
      end
    end

    def subscribe(bus, handle, on_answer)
      @subscriptions[handle] = bus.signal_subscribe(
        BUS_NAME,
        REQUEST_INTERFACE,
        'Response',
        handle,
        nil,
        :none,
      ) do |_connection, _sender, _path, _interface, _signal, parameters|
        unsubscribe(bus, handle)
        on_answer.call(granted?(parameters))
      end
    end

    def unsubscribe(bus, handle)
      @subscriptions.delete(handle).then do |subscription|
        unless subscription.nil?
          bus.signal_unsubscribe(subscription)
        end
      end
    rescue StandardError => e
      warn "Could not unsubscribe from background portal response: #{e.message}"
    end

    # The Response signal carries (u response, a{sv} results); permission was
    # granted when the call succeeded and `background` came back true.
    def granted?(parameters)
      Array(parameters&.value).then do |values|
        values.first == RESPONSE_SUCCESS && Hash(values[1])['background'] == true
      end
    end

    # The request path the portal will use embeds the caller's unique bus name
    # with the leading colon dropped and the dots turned into underscores.
    def sender_token(bus) = bus.unique_name.to_s.sub(/\A:/, '').tr('.', '_')

    def call(bus, method_name, parameters, signature)
      bus.call_sync(
        BUS_NAME,
        OBJECT_PATH,
        BACKGROUND_INTERFACE,
        method_name,
        GLib::Variant.parse(parameters, signature),
        nil,
        :none,
        TIMEOUT,
        nil,
      )
    rescue StandardError => e
      warn "Could not call #{method_name} via background portal: #{e.message}"
      nil
    end

    def connection
      @connection ||= Gio.bus_get_sync(:session, nil)
    rescue StandardError => e
      warn "Could not connect to the session bus: #{e.message}"
      nil
    end

    # Single-quoted GVariant text, the one escape the format needs.
    def quote(text) = "'#{text.to_s.gsub('\\', '\\\\\\\\').gsub("'", "\\\\'")}'"
end
