@include = -> @client '/player.js': ->
  doPlay = =>
    window.SocialCalc ?= {}
    SocialCalc._username = Math.random().toString()
    SocialCalc.isConnected = true
    SocialCalc.hadSnapshot = false
    SocialCalc._room ?= window.location.hash.replace('#', '')
    SocialCalc._room = SocialCalc._room.replace(/^_+/, '')
    unless SocialCalc._room
        window.location = '/_start'
        return
    
    try window.history.pushState {}, '', '/'+SocialCalc._room
    @connect()

    emit = (data) => @emit { data }
    SocialCalc.Callbacks.broadcast = (type, data={}) =>
      return unless SocialCalc.isConnected
      data.user = SocialCalc._username
      data.room = SocialCalc._room
      data.type = type
      emit data

    SocialCalc.isConnected = true
    SocialCalc.Callbacks.broadcast "ask.log"
    SocialCalc.RecalcInfo.LoadSheet = (ref) ->
      ref = ref.replace(/[^a-zA-Z0-9]+/g, "").toLowerCase()
      emit { type: "ask.recalc", user: SocialCalc._username, room: ref }

    @on data: ->
      return unless SocialCalc?.isConnected
      return if @data.user == SocialCalc._username
      return if @data.to and @data.to != SocialCalc._username
      return if @data.room and @data.room != SocialCalc._room and @data.type != "recalc"

      editor = SocialCalc.CurrentSpreadsheetControlObject.editor
      switch @data.type
        when "chat"
          window.addmsg? @data.msg
        when "ecells"
          for user, ecell of @data.ecells
            continue if user == SocialCalc._username
            peerClass = " " + user + " defaultPeer"
            find = new RegExp(peerClass, "g")
            cr = SocialCalc.coordToCr(ecell)
            cell = SocialCalc.GetEditorCellElement(editor, cr.row, cr.col)
            cell.element.className += peerClass if cell.element.className.search(find) == -1
        when "ecell"
            peerClass = " " + @data.user + " defaultPeer"
            find = new RegExp(peerClass, "g")
            if @data.original
              origCR = SocialCalc.coordToCr(@data.original)
              origCell = SocialCalc.GetEditorCellElement(editor, origCR.row, origCR.col)
              origCell.element.className = origCell.element.className.replace(find, "")
              if @data.original is editor.ecell.coord or @data.ecell is editor.ecell.coord
                SocialCalc.Callbacks.broadcast "ecell",
                  to: @data.user
                  ecell: editor.ecell.coord
            cr = SocialCalc.coordToCr(@data.ecell)
            cell = SocialCalc.GetEditorCellElement(editor, cr.row, cr.col)
            cell.element.className += peerClass if cell.element.className.search(find) == -1
        when "ask.ecell"
          SocialCalc.Callbacks.broadcast "ecell",
            to: @data.user
            ecell: editor.ecell.coord
        when "log"
          break if SocialCalc.hadSnapshot
          SocialCalc.hadSnapshot = true
          spreadsheet = SocialCalc.CurrentSpreadsheetControlObject
          parts = spreadsheet.DecodeSpreadsheetSave(@data.snapshot) if @data.snapshot
          if parts
            if parts.sheet
              spreadsheet.sheet.ResetSheet()
              spreadsheet.ParseSheetSave @data.snapshot.substring(parts.sheet.start, parts.sheet.end)
            # spreadsheet.editor.LoadEditorSettings @data.snapshot.substring(parts.edit.start, parts.edit.end)  if parts.edit
          window.addmsg? @data.chat.join("\n"), true
          cmdstr = (
            line for line in @data.log when not /^re(calc|display)$/.test(line)
          ).join("\n")
          if cmdstr.length
            refreshCmd = "recalc"
            editor = SocialCalc.CurrentSpreadsheetControlObject.editor
            # if editor.context.sheetobj.attribs.recalc != "off"
            #   refreshCmd = "recalc"
            SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands cmdstr + "\n#{refreshCmd}\n", false, true
          else
            SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands "recalc\n", false, true
#          editor.MoveECellCallback.broadcast = (e) ->
#            SocialCalc.Callbacks.broadcast "my.ecell"
#              ecell: e.ecell.coord
        when "recalc"
          if @data.force
            SocialCalc.Formula.SheetCache.sheets = {}
            SocialCalc.CurrentSpreadsheetControlObject?.sheet.recalconce = true
          parts = SocialCalc.CurrentSpreadsheetControlObject.DecodeSpreadsheetSave(@data.snapshot) if @data.snapshot
          if parts?.sheet
            SocialCalc.RecalcLoadedSheet(
              @data.room,
              @data.snapshot.substring(parts.sheet.start, parts.sheet.end),
              true # recalc
            )
            SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands "recalc\n", false, true
          else
            SocialCalc.RecalcLoadedSheet(@data.room, "", true)
        when "execute"
          SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands @data.cmdstr, @data.saveundo, true
      return

  window.doresize = -> spreadsheet.DoOnResize()
  scc = SocialCalc.Constants
  b1 = window.location.search.charAt(1) or "4"
  b2 = window.location.search.charAt(2) or "C"
  b3 = window.location.search.charAt(3) or "8"
  b4 = window.location.search.charAt(4) or "9"
  b5 = window.location.search.charAt(5) or "8"
  scc.SCToolbarbackground = "background-color:#4040" + b1 + "0;"
  scc.SCTabbackground = "background-color:#CC" + b2 + ";"
  scc.SCTabselectedCSS = "font-size:small;padding:6px 30px 6px 8px;color:#FFF;background-color:#4040" + b1 + "0;cursor:default;border-right:1px solid #CC" + b2 + ";"
  scc.SCTabplainCSS = "font-size:small;padding:6px 30px 6px 8px;color:#FFF;background-color:#8080" + b3 + "0;cursor:default;border-right:1px solid #CC" + b2 + ";"
  scc.SCToolbartext = "font-size:x-small;font-weight:bold;color:#FFF;padding-bottom:4px;"
  scc.ISCButtonBorderNormal = "#4040" + b1 + "0"
  scc.ISCButtonBorderHover = "#99" + b4 + ""
  scc.ISCButtonBorderDown = "#FFF"
  scc.ISCButtonDownBackground = "#88" + b5 + ""
  SocialCalc.Popup.LocalizeString = SocialCalc.LocalizeString
  $ ->
    spreadsheet = new SocialCalc.SpreadsheetControl()
    document.getElementById("msgtext").value = ""
    savestr = document.getElementById("savestr")
    spreadsheet.InitializeSpreadsheetControl "tableeditor", 0, 0, 0
    spreadsheet.ExecuteCommand "redisplay", ""
    spreadsheet.ExecuteCommand "set sheet defaulttextvalueformat text-wiki"
    spreadsheet.ExportCallback = (s) ->
      alert SocialCalc.ConvertSaveToOtherFormat(SocialCalc.Clipboard.clipboard, "csv")

  SocialCalc.Callbacks.expand_wiki = (val) -> """
    <div class="wiki">#{
      (new Document.Parser.Wikitext()).parse(
        val, new Document.Emitter.HTML()
      )
    }</div>
  """
  do doPlay
