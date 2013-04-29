# Copyright 2010-2012 RethinkDB, all rights reserved.
render_body = ->
    template = Handlebars.templates['body-structure-template']

    $('body').html(template())

    window.alert_update_view = new AlertUpdates
    $('.updates_container').html window.alert_update_view.render().$el


    # Set up common DOM behavior
    $('.modal').modal
        backdrop: true
        keyboard: true

    # Set actions on developer tools
    $('#dev-tools #pause-application').on 'click', (event) -> debugger

class AlertUpdates extends Backbone.View
    has_update_template: Handlebars.templates['has_update-template']
    className: 'settings alert'

    events:
        'click .no_update_btn': 'deactivate_update'
        'click .close': 'close'

    initialize: =>
        if window.localStorage?
            try
                check_updates = JSON.parse window.localStorage.check_updates
                if check_updates isnt false
                    @check()
            catch err
                # Non valid json doc in check_updates. Let's reset the setting
                window.localStorage.check_updates = JSON.stringify true
                @check()
        else
            # No localstorage, let's just check for updates
            @check()

    close: (event) =>
        event.preventDefault()
        if @next_version?
            window.localStorage.ignore_version = JSON.stringify @next_version
        @hide()

    hide: =>
        @$el.slideUp 'fast'


    check: =>
        # If it's fail, it's fine - like if the user is just on a local network without access to the Internet.
        $.getJSON "http://update.rethinkdb.com/update_for/#{window.VERSION}?callback=?", @render_updates

    render_updates: (data) =>
        if data.status is 'need_update'
            try
                ignored_version = JSON.parse(window.localStorage.ignore_version)
            catch err
                ignored_version = null
            if (not ignored_version) or @compare_version(ignored_version, data.last_version) < 0
                @next_version = data.last_version # Save it so users can ignore the update
                @$el.html @has_update_template
                    last_version: data.last_version
                    link_changelog: data.link_changelog
                @$el.slideDown 'fast'

    compare_version: (v1, v2) =>
        v1_array_str = v1.split('.')
        v2_array_str = v2.split('.')
        v1_array = []
        for value in v1_array_str
            v1_array.push parseInt value
        v2_array = []
        for value in v2_array_str
            v2_array.push parseInt value

        for value, index in v1_array
            if value < v2_array[index]
                return -1
            else if value > v2_array[index]
                return 1
        return 0

   
    render: =>
        return @

    deactivate_update: =>
        @$el.slideUp 'fast'
        if window.localStorage?
            window.localStorage.check_updates = JSON.stringify false

class Settings extends Backbone.View
    settings_template: Handlebars.templates['settings-template']
    events:
        'click .check_updates_btn': 'change_settings'
        'click .close': 'close'

    close: (event) =>
        event.preventDefault()
        @$el.parent().hide()
        @$el.remove()

    initialize: (args) =>
        @alert_view = args.alert_view
        if window.localStorage?.check_updates?
            @check_updates = JSON.parse window.localStorage.check_updates
        else
            @check_updates = false


    change_settings: (event) =>
        update = @$(event.target).data('update')
        if update is 'on'
            @check_updates = true
            if window.localStorage?
                window.localStorage.check_updates = JSON.stringify true
            @alert_view.check()
        else if update is 'off'
            @check_updates = false
            @alert_view.hide()
            if window.localStorage?
                window.localStorage.check_updates = JSON.stringify false
                window.localStorage.removeItem('ignore_version')
        @render()

    render: =>
        @$el.html @settings_template
            check_value: if @check_updates then 'off' else 'on'
        @delegateEvents()
        return @
 

class IsDisconnected extends Backbone.View
    el: 'body'
    className: 'is_disconnected_view'
    template: Handlebars.templates['is_disconnected-template']
    message: Handlebars.templates['is_disconnected_message-template']
    initialize: =>
        log_initial '(initializing) sidebar view:'
        @render()

    render: =>
        @.$('#modal-dialog > .modal').css('z-index', '1')
        @.$('.modal-backdrop').remove()
        @.$el.append @template
        @.$('.is_disconnected').modal
            'show': true
            'backdrop': 'static'
        @animate_loading()

    animate_loading: =>
        if @.$('.three_dots_connecting')
            if @.$('.three_dots_connecting').html() is '...'
                @.$('.three_dots_connecting').html ''
            else
                @.$('.three_dots_connecting').append '.'
            setTimeout(@animate_loading, 300)

    display_fail: =>
        @.$('.animation_state').fadeOut 'slow', =>
            $('.reconnecting_state').html(@message)
            $('.animation_state').fadeIn('slow')
