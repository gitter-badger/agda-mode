{EventEmitter} = require 'events'
Q = require 'q'
_ = require 'lodash'
{$} = require 'atom-space-pen-views'
{log, warn, error} = require './logger'

# Components
Executable  = require './executable'
PanelModel  = require './panel/model'
PanelView   = require './panel/view'
TextBuffer  = require './text-buffer'
InputMethod = require './input-method'
Config      = require './config'

class Core extends EventEmitter

    @loaded: false
    panels: []
    constructor: (@editor) ->

        # initialize all components
        @executable     = new Executable    @
        @panelModel     = new PanelModel    @
        @textBuffer     = new TextBuffer    @
        @inputMethod    = new InputMethod   @
        @config         = new Config

        # initialize informations about this editor
        @filepath = @editor.getPath()

        log 'Core', 'initialized:', @filepath


        #############
        #   Views   #
        #############

        # register panel view, fuck Atom's everchanging always outdated documentation
        atom.views.addViewProvider PanelModel, (model) =>
            view = new PanelView
            view.setModel model
            return $(view).get(0)

        # instantiate
        @panel = atom.workspace.addBottomPanel
            item: atom.views.getView @panelModel
            visible: false
            className: 'agda-panel'




        #########################
        #   Components Events   #
        #########################

        # Executable
        @executable.on 'info-action', (type, content) =>
            log 'Executable', '=> info-action'
            switch type
                when '*All Goals*'
                    if content.length > 0
                        @panelModel.set 'Goals', content, 'info'
                    else
                        @panelModel.set 'No Goals', [], 'success'
                when '*Error*'

                    # the first line with !=< we want to do cosmetic surgery with, -1 if not found
                    index = _.findIndex(content, (line) -> /!=</.test line)

                    if not @config.rawOutput() and index isnt -1
                        pre       = _.take content, index
                        expecting = 'expecting: ' + content[index].split(/!=</)[1]
                        got       = '      got: ' + content[index].split(/!=</)[0]
                        post      = _.drop content, index + 1
                        result = pre.concat([expecting, got]).concat(post)
                        @panelModel.set 'Error', result, 'error'
                    else
                        @panelModel.set 'Error', content, 'error'
                when '*Type-checking*'
                    @panelModel.set 'Type Checking', content
                when '*Current Goal*'
                    @panelModel.set 'Current Goal', content
                when '*Context*'
                    @panelModel.set 'Context', content
                when '*Goal type etc.*'
                    @panelModel.set 'Goal Type and Context', content
                when '*Normal Form*'
                    @panelModel.set 'Normal Form', content
                when '*Intro*'
                    @panelModel.set 'Intro', ['No introduction forms found']
                when '*Auto*'
                    @panelModel.set 'Auto', ['No solution found']

        @executable.on 'goals-action', (goals) =>
            log 'Executable', '=> goals-action'
            @textBuffer.goalsAction goals

        @executable.on 'give-action', (goalIndex, content, parenthesis) =>
            log 'Executable', '=> give-action'
            @textBuffer.giveAction goalIndex, content, parenthesis

        @executable.on 'make-case-action', (content) =>
            log 'Executable', '=> make-case-action'
            @textBuffer.makeCaseAction content
                .then => @load()

        @executable.on 'goto', (filepath, position) =>
            log 'Executable', '=> goto'
            @textBuffer.goto filepath, position

        @executable.on 'highlight-load-and-delete-action', (filepath) =>
            log 'Executable', '=> highlight-load-and-delete-action'
            @textBuffer.highlightLoadAndDelete filepath

        @executable.on 'parse-error', (err) =>
            error 'Executable', err

    #####################
    #   Editor Events   #
    #####################

    activate: ->
        log 'Core', 'activated:', @filepath
        @panel.show()
    deactivate: ->
        log 'Core', 'deactivated:', @filepath
        @panel.hide()
    destroy: ->
        log 'Core', 'destroyed:', @filepath
        @quit()



    ################
    #   Commands   #
    ################

    load: ->
        log 'Command', 'load'
        @panel.show()
        @executable.load().then (process) =>
            @panelModel.set 'Loading'
            @loaded = true

    quit: -> if @loaded
        log 'Command', 'warn'
        @loaded = false
        @executable.quit()
        @panel.hide()
        @textBuffer.removeGoals()

    restart: -> if @loaded
        log 'Command', 'restart'
        @quit()
        @load()

    nextGoal: -> if @loaded
        log 'Command', 'next-goal'
        @textBuffer.nextGoal()

    previousGoal: -> if @loaded
        log 'Command', 'previous-goal'
        @textBuffer.previousGoal()

    give: -> if @loaded
        log 'Command', 'give'
        @textBuffer.give()

    goalType: -> if @loaded
        log 'Command', 'goal-type'
        @textBuffer.goalType()

    context: -> if @loaded
        log 'Command', 'context'
        @textBuffer.context()

    goalTypeAndContext: -> if @loaded
        log 'Command', 'goal-type-and-context'
        @textBuffer.goalTypeAndContext()

    goalTypeAndInferredType: -> if @loaded
        log 'Command', 'goal-type-inferred-type'
        @textBuffer.goalTypeAndInferredType()

    refine: -> if @loaded
        log 'Command', 'refine'
        @textBuffer.refine()

    case: -> if @loaded
        log 'Command', 'case'
        @textBuffer.case()

    auto: -> if @loaded
        log 'Command', 'auto'
        @textBuffer.auto()

    normalize: -> if @loaded
        log 'Command', 'normalize'
        @panelModel.set 'Normalize', [], 'info'
        @panelModel.placeholder = 'expression here'
        @panelModel.query().then (expr) =>
            @executable.normalize expr
            @textBuffer.focus()

    inputSymbol: ->
        log 'Command', 'input-symbol'
        unless @loaded
            @panel.show()
            @panelModel.set 'Input Method only, Agda not loaded', [], 'warning'
        @inputMethod.activate()

module.exports = Core
